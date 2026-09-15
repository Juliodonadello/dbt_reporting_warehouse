"""Read-only full-path diagnostic. Requires psycopg2, PyYAML and sqlparse.
EXPLAIN ANALYZE is opt-in; queries run sequentially with timeouts and RLS intact.
Only plans/metadata are saved, not business result rows or credentials.
"""
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import time
import psycopg2
from psycopg2 import sql
import sqlparse
import yaml

PROJECT = Path(__file__).resolve().parents[1]

def save(path, value):
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, default=str), encoding='utf-8')

def records(cur):
    return [dict(zip([d.name for d in cur.description], row)) for row in cur.fetchall()]

def ctes(query):
    stmt = sqlparse.parse(query)[0]
    if next(t for t in stmt.tokens if not t.is_whitespace).normalized != 'WITH':
        return {}
    offset=0; depth=0; depths={}; end=None
    for token in stmt.flatten():
        depths[offset]=depth
        if token.normalized=='SELECT' and depth==0:
            end=offset; break
        if token.value=='(': depth+=1
        elif token.value==')': depth-=1
        offset+=len(token.value)
    if end is None: raise ValueError('Cannot locate main SELECT')
    prefix=str(stmt)[:end]
    pattern=r'(?:\bWITH|,)\s*([a-z_]\w*)\s+AS\s+(?:(?:NOT\s+)?MATERIALIZED\s+)?\('
    names=[m[1] for m in re.finditer(pattern,prefix,re.I) if depths.get(m.start())==0]
    return {name:prefix+'\nSELECT * FROM '+name for name in names}

def flatten(n, path='0'):
    r = {k:v for k,v in n.items() if k not in ('Plans','Output','Workers')}
    r['path'] = path
    if 'Actual Loops' in n:
        for field in ('Actual Rows','Rows Removed by Filter','Rows Removed by Join Filter'):
            r[field+' All Loops'] = n.get(field,0)*n['Actual Loops']
    return [r]+[x for i,c in enumerate(n.get('Plans',[])) for x in flatten(c,f'{path}.{i}')]

def inventory(cur, entry):
    roots = sorted(set(re.findall(r'"reporting"\."(\w+)"',entry)))
    cur.execute("""WITH RECURSIVE tree(oid) AS (
      SELECT to_regclass('reporting.'||x) FROM unnest(%s::text[]) x
      UNION
      SELECT d.refobjid FROM tree t JOIN pg_rewrite r ON r.ev_class=t.oid
      JOIN pg_depend d ON d.classid='pg_rewrite'::regclass AND d.objid=r.oid
      WHERE d.refclassid='pg_class'::regclass AND d.refobjid<>t.oid)
      SELECT c.oid,n.nspname AS schema,c.relname AS name,c.relkind AS kind,
      c.relrowsecurity AS rls,c.relforcerowsecurity AS force_rls,c.reloptions,
      pg_get_userbyid(c.relowner) AS owner,c.reltuples::bigint AS estimated_rows,
      CASE WHEN c.relkind IN ('v','m') THEN pg_get_viewdef(c.oid,true) END AS definition,
      ARRAY(SELECT a.attname FROM pg_attribute a WHERE a.attrelid=c.oid AND a.attnum>0
      AND NOT a.attisdropped ORDER BY a.attnum) AS columns
      FROM tree t JOIN pg_class c ON c.oid=t.oid JOIN pg_namespace n ON n.oid=c.relnamespace
      ORDER BY n.nspname,c.relname""",(roots,))
    nodes = records(cur)
    oids = [n['oid'] for n in nodes]
    cur.execute("""SELECT DISTINCT r.ev_class AS parent,d.refobjid AS child
      FROM pg_rewrite r JOIN pg_depend d ON d.classid='pg_rewrite'::regclass AND d.objid=r.oid
      WHERE r.ev_class=ANY(%s) AND d.refobjid=ANY(%s)
      AND d.refclassid='pg_class'::regclass AND d.refobjid<>r.ev_class""",(oids,oids))
    result = {'roots':roots,'nodes':nodes,'edges':records(cur)}
    relations = [n['schema']+'.'+n['name'] for n in nodes]
    for label,query in {
      'indexes':"SELECT schemaname,tablename,indexname,indexdef FROM pg_indexes WHERE (schemaname||'.'||tablename)=ANY(%s) ORDER BY 1,2,3",
      'policies':"SELECT schemaname,tablename,policyname,roles,cmd,qual,with_check FROM pg_policies WHERE (schemaname||'.'||tablename)=ANY(%s) ORDER BY 1,2,3",
    }.items():
        cur.execute(query,(relations,)); result[label] = records(cur)
    return result

def bind(cur, query, params):
    def literal(v):
        return cur.mogrify('%s',(v,)).decode(cur.connection.encoding)
    values = {k: ', '.join(literal(v) for v in value) if isinstance(value,list) else literal(value)
              for k,value in params.items()}
    return re.sub(r'@(\w+)',lambda m: values[m[1]],query).strip().rstrip(';')

def probes(cur, text, params, inv):
    bound = bind(cur,text,params)
    prop = bind(cur,"SELECT p.id FROM public.properties p WHERE p.company_relation_id::integer=@REAL_COMPANY_ID AND p.name IN (@Property_Name) AND p.deleted_at IS NULL",params)
    unit = bind(cur,f"SELECT u.id FROM public.units u WHERE u.property_id IN ({prop}) AND u.deleted_at IS NULL AND coalesce(u.floorplan,' ') IN (@floorPlan)",params)
    lease = f'SELECT l.id FROM public.leases l WHERE l.property_id IN ({prop}) AND l.deleted_at IS NULL'
    charge = f'SELECT r.id FROM public.lease_recurring_charges r WHERE r.unit_id IN ({unit}) AND r.deleted_at IS NULL'
    result = {}
    for n in inv['nodes']:
        conditions = []
        if 'company_relation_id' in n['columns']:
            conditions.append('v.company_relation_id::integer='+str(params['REAL_COMPANY_ID']))
        for col,select in [('prop_id',prop),('property_id',prop),('unit_id',unit),('lease_id',lease),('recurring_charge_id',charge)]:
            if col in n['columns']:
                conditions.append(f'v.{col} IN ({select})'); break
        if n['schema']=='public' and n['name'] in ('units','properties'):
            conditions.append('v.id IN ('+(unit if n['name']=='units' else prop)+')')
        if n['name'] in ('tenants','stg_tenants'):
            key = 'id' if n['name']=='tenants' else 'tenant_id'
            conditions.append(f'v.{key} IN (SELECT l."primaryTenantId" FROM public.leases l WHERE l.id IN ({lease}))')
        if not conditions and n['name']!='dim_frequency':
            continue
        ref = sql.Identifier(n['schema'],n['name']).as_string(cur)
        result['dependency__'+n['name']] = f'SELECT v.* FROM {ref} v'+(' WHERE '+' AND '.join(conditions) if conditions else '')
    result.update({'cte__'+name.lower():query for name,query in ctes(bound).items()})
    detail=next(n for n in inv['nodes'] if n['name']=='fct_summarized_rent_roll_detail')
    stages=ctes(detail['definition'])
    for name,query in stages.items():
        result['model_cte__'+name]=query+f' WHERE company_relation_id={params["REAL_COMPANY_ID"]} AND prop_id IN ({prop})'
    result['report__current'] = bound
    for label,hint in [('forced_materialized','MATERIALIZED'),('not_materialized','NOT MATERIALIZED')]:
        result['report__'+label] = re.sub(r'(FILTERED_RENT_ROLL\s+AS)\s*(?:NOT\s+MATERIALIZED\s+|MATERIALIZED\s+)?\(',lambda m:m[1]+' '+hint+' (',bound,count=1,flags=re.I)
    return result

def explain(conn,query,analyze,timeout):
    start = time.monotonic()
    try:
        with conn.cursor() as cur:
            cur.execute('SET LOCAL statement_timeout=%s',(timeout,))
            opts = 'ANALYZE, BUFFERS, VERBOSE, SETTINGS, TIMING OFF, SUMMARY, FORMAT JSON' if analyze else 'VERBOSE, SETTINGS, FORMAT JSON'
            cur.execute(f'EXPLAIN ({opts}) '+query)
            data = cur.fetchone()[0][0]
        return {'status':'ok','analyze':analyze,'explain':data,'nodes':flatten(data['Plan'])}
    except psycopg2.Error as exc:
        return {'status':'timeout' if exc.pgcode=='57014' else 'error','sqlstate':exc.pgcode,
                'message':str(exc).splitlines()[0],'wall_ms':round((time.monotonic()-start)*1000,2)}
    finally:
        conn.rollback()

def summary(out,results,context):
    lines = ['# Rent roll: mediciones','','Contexto: `'+json.dumps(context,ensure_ascii=False,default=str)+'`','',
      'Ejecuciones individuales con caches y carga no controlados. Los probes aislados pueden diferir del plan integrado.',
      'TIMING OFF evita cronometrar cada nodo. Execution Time sigue midiendo toda la consulta.',
      'Buffers de padres incluyen hijos: no sumar todos los nodos. Filas/descartes se multiplican por loops.','',
      '| Prueba | Estado | Planning ms | Execution ms | Filas | Temp written blocks |',
      '|---|---|---:|---:|---:|---:|']
    for name,r in results.items():
        e=r.get('explain',{}); p=e.get('Plan',{})
        lines.append(f"| {name} | {r['status']} | {e.get('Planning Time','—')} | {e.get('Execution Time','—')} | {p.get('Actual Rows','—')} | {p.get('Temp Written Blocks','—')} |")
    lines += ['','Los *.nodes.json muestran filtros, Index Cond, loops y filas descartadas. Un timeout no produce un plan ANALYZE parcial.']
    (out/'RESULTS.md').write_text('\n'.join(lines),encoding='utf-8')

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--profile',type=Path,required=True)
    ap.add_argument('--target')
    ap.add_argument('--entry',type=Path,default=PROJECT/'analyses/summarized_rent_roll_bold_report.sql')
    ap.add_argument('--params',type=Path)
    ap.add_argument('--original',type=Path,help='Original SELECT for a same-session comparison')
    ap.add_argument('--asof-type',choices=['date','timestamp'],default='date')
    ap.add_argument('--disable-nestloop',action='store_true',help='Controlled planner experiment, this connection only')
    ap.add_argument('--sample',action='store_true')
    ap.add_argument('--analyze',action='store_true')
    ap.add_argument('--only',help='Regex matching probe names')
    ap.add_argument('--timeout-ms',type=int,default=8000)
    ap.add_argument('--budget-seconds',type=int,default=120)
    ap.add_argument('--out',type=Path,required=True)
    a=ap.parse_args()
    if min(a.timeout_ms,a.budget_seconds)<1: ap.error('Limits must be positive')
    a.out.mkdir(parents=True,exist_ok=False)
    cfg=yaml.safe_load(a.profile.read_text(encoding='utf-8-sig'))['bold_reporting']
    c=cfg['outputs'][a.target or cfg['target']]
    conn=psycopg2.connect(host=c['host'],port=c.get('port',5432),dbname=c['dbname'],user=c['user'],
      password=c.get('password',c.get('pass')),connect_timeout=10,application_name='codex_rent_roll_diagnostic',
      options=f'-c default_transaction_read_only=on -c statement_timeout={a.timeout_ms} -c lock_timeout=2000'+(' -c enable_nestloop=off' if a.disable_nestloop else ''))
    conn.set_session(readonly=True)
    text=a.entry.read_text(encoding='utf-8-sig'); results={}
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT current_database() AS database,current_user AS db_user,version(),current_setting('row_security') AS row_security,current_setting('work_mem') AS work_mem,current_setting('jit') AS jit,current_setting('default_transaction_read_only') AS read_only,pg_has_role(current_user,'readonly','member') AS readonly_member")
            context=records(cur)[0]
            context['disable_nestloop_experiment']=a.disable_nestloop
            context.update(entry=str(a.entry),entry_sha256=hashlib.sha256(text.encode()).hexdigest(),timestamp_utc=dt.datetime.now(dt.timezone.utc).isoformat())
            inv=inventory(cur,text); save(a.out/'inventory.json',inv)
            graph=['flowchart TD']+[f'  n{n["oid"]}["{n["schema"]}.{n["name"]}"]' for n in inv['nodes']]
            graph += [f'  n{e["parent"]} --> n{e["child"]}' for e in inv['edges']]
            (a.out/'dependencies.mmd').write_text('\n'.join(graph),encoding='utf-8')
            params=None
            if a.params: params=json.loads(a.params.read_text(encoding='utf-8-sig'))
            elif a.sample:
                cur.execute("SELECT p.company_relation_id,p.name,coalesce(u.floorplan,' '),count(*) FROM public.properties p JOIN public.units u ON u.property_id=p.id WHERE p.deleted_at IS NULL AND u.deleted_at IS NULL GROUP BY 1,2,3 ORDER BY count(*) DESC,1,2,3 LIMIT 1")
                sample=cur.fetchone()
                if sample:
                    params=dict(REAL_COMPANY_ID=int(sample[0]),Property_Name=[sample[1]],floorPlan=[sample[2]],AsOfDate=dt.date.today().isoformat(),month_to_month=['True','False'],ignore_end_date=False)
                    context.update(sample_not_user_case=True,sample_units=sample[3])
            if params is None:
                context['blocked']='No parameters/visible sample. Inventory only; no performance claim.'
                save(a.out/'context.json',context); summary(a.out,results,context); print(context['blocked']); return
            for key in ('Property_Name','floorPlan','month_to_month'):
                if not isinstance(params.get(key),list) or not params[key]: raise ValueError(key+' must be a nonempty list')
            if not isinstance(params.get('ignore_end_date'),bool): raise ValueError('ignore_end_date must be boolean')
            params['REAL_COMPANY_ID']=int(params['REAL_COMPANY_ID'])
            params['AsOfDate']=dt.datetime.fromisoformat(str(params['AsOfDate'])).date()
            if a.asof_type=='timestamp':
                params['AsOfDate']=dt.datetime.combine(params['AsOfDate'],dt.time())
            context['asof_parameter_type']=a.asof_type
            context['parameters']=params
            cur.execute('SELECT count(*) FROM reporting.dim_unit WHERE company_relation_id=%s AND prop_name=ANY(%s) AND floor_plan=ANY(%s)',(params['REAL_COMPANY_ID'],params['Property_Name'],params['floorPlan']))
            context['visible_selected_units']=cur.fetchone()[0]
            save(a.out/'parameters.json',params); save(a.out/'context.json',context)
            queries=probes(cur,text,params,inv)
            if a.original:
                original=a.original.read_text(encoding='utf-8-sig')
                statements=sqlparse.parse(original)
                if len(statements)!=1 or statements[0].get_type()!='SELECT':
                    raise ValueError('Original must contain one SELECT statement')
                context['original_path']=str(a.original)
                context['original_sha256']=hashlib.sha256(original.encode()).hexdigest()
                original=bind(cur,original,params)
                queries.update({'original_cte__'+name.lower():q for name,q in ctes(original).items()})
                queries['original__full']=original
                save(a.out/'context.json',context)
        conn.rollback()
        for name,query in queries.items(): (a.out/(name+'.sql')).write_text(query+';\n',encoding='utf-8')
        if not context['visible_selected_units']:
            context['blocked']='Selected units invisible/empty: benchmark invalid. Check role/RLS/parameters.'
            save(a.out/'context.json',context); summary(a.out,results,context); print(context['blocked']); return
        start=time.monotonic()
        for name,query in queries.items():
            if a.only and not re.search(a.only,name): continue
            remaining=a.budget_seconds-(time.monotonic()-start)
            if remaining<=0: results[name]={'status':'skipped_budget'}; continue
            result=explain(conn,query,a.analyze,min(a.timeout_ms,max(1,int(remaining*1000))))
            results[name]=result
            save(a.out/(name+'.plan.json'),{k:v for k,v in result.items() if k!='nodes'})
            if 'nodes' in result: save(a.out/(name+'.nodes.json'),result['nodes'])
            print(name,result['status'],result.get('explain',{}).get('Execution Time'),flush=True)
            summary(a.out,results,context)
        summary(a.out,results,context)
    finally: conn.close()

if __name__=='__main__': main()
