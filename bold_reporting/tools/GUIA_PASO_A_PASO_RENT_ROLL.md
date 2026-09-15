# Guía paso a paso: localizar el cuello de botella del rent roll

Query de entrada: `bold_reporting/analyses/summarized_rent_roll_bold_report.sql`.

Los pasos 1 a 6 usan exclusivamente los diagnósticos guardados el **7 de septiembre de 2026**. No consultan producción. Los pasos 7 a 10 explican cómo repetir mediciones y probar hipótesis. Los números históricos sirven como referencia, no como tiempos garantizados de una ejecución nueva.

## 1. Preparar las rutas y verificar qué se midió

Abrí PowerShell y ejecutá:

```powershell
$rrRepo='C:\Users\julio\OneDrive\Documents\Sage\repos\dbt'
$rrDiag=Join-Path $rrRepo 'bold_reporting\target\rent_roll_diagnostics'
$rrActual=Join-Path $rrDiag '20260907_actual'
$rrComparison=Join-Path $rrDiag '20260907_comparison_02'
$rrAlternative=Join-Path $rrDiag '20260907_join_experiment'

Get-Content -Raw (Join-Path $rrComparison 'context.json')
```

Comprobá estos campos antes de comparar resultados:

| Campo | Valor del caso guardado | Por qué importa |
|---|---|---|
| `parameters.REAL_COMPANY_ID` | 1066 | Determina la compañía seleccionada. |
| `parameters.Property_Name` | 30 N. Michigan, Chicago, IL | Es una muestra, no necesariamente tu caso lento. |
| `visible_selected_units` | 243 | Cero filas no sería una prueba representativa. |
| `parameters.AsOfDate` | 2026-09-07 | No usar automáticamente la fecha actual al repetir. |
| `parameters.floorPlan` | Un espacio | No confundirlo con una lista vacía. |
| `parameters.month_to_month` | True y False | Ambos valores incluidos. |
| `parameters.ignore_end_date` | false | Afecta qué leases entran. |
| `db_user` | sage_uat_ro_user | Tiene acceso global de lectura; no reproduce exactamente el RLS de Bold. |
| `asof_parameter_type` | timestamp | La comparación original/nueva usó el mismo tipo. |
| `disable_nestloop_experiment` | false | Es el plan normal. |

**Decisión:** si querés reproducir el incidente de Bold, anotá sus seis parámetros y usuario/contexto RLS. El perfil dbt_reporting usado anteriormente no veía filas; un EXPLAIN sobre esa selección vacía no permite diagnosticar rendimiento.

## 2. Confirmar que la demora está en SQL y localizar el primer salto

Abrí primero:

```powershell
Get-Content -Raw (Join-Path $rrComparison 'RESULTS.md')
Get-Content -Raw (Join-Path $rrActual 'RESULTS.md')
```

En la comparación integrada, la query directa termina en **538 ms**; la de vistas se cancela a los **8 segundos**. Esto reproduce una demora del lado de PostgreSQL bajo el contexto del ensayo. No mide red ni render de Bold.

En la segunda tabla seguí esta ruta, en vez de buscar solamente el SELECT final:

| Prueba | Tiempo guardado | Qué aporta |
|---|---:|---|
| `dependency__dim_unit` | 2 ms | Obtener las unidades seleccionadas es barato. |
| `dependency__int_unit_sqft_ranges` | 184 ms | Construir rangos ya agrega trabajo. |
| `dependency__int_charges_effective_ranges` | 491 ms | La rama histórica de cargos tiene un costo visible. |
| `dependency__fct_summarized_rent_roll_detail` | Timeout de 8 s | El salto aparece al combinar las ramas. |
| `cte__unit_base` | 747 ms | La base de unidades del reporte también es costosa. |
| `cte__lease_base` | 861 ms | Devuelve 175 leases seleccionados. |
| `cte__filtered_rent_roll` | Timeout de 8 s | Hereda la composición histórica del fact. |
| `cte__charge_agg` | Timeout de 8 s | No demuestra que SUM sea la causa: recibe una entrada costosa. |

**Decisión:** la primera zona que merece inspección es `fct_summarized_rent_roll_detail` y sus joins con superficies/leases/cargos. No comenzar por el ORDER BY final.

No sumes los tiempos de la tabla: las pruebas se ejecutaron por separado y cada una vuelve a evaluar dependencias. Tampoco uses `SELECT COUNT(*)` para reemplazar estos probes: PostgreSQL puede eliminar columnas y joins que sí necesita el reporte real.

## 3. Comprobar si compañía filtra antes o después de la ventana

Leé los nodos de cargos:

```powershell
$rrChargeNodes=Get-Content -Raw (Join-Path $rrActual 'dependency__int_charges_effective_ranges.nodes.json') | ConvertFrom-Json

$rrChargeNodes |
  Where-Object { $_.path -in @('0.0','0.0.0') } |
  Select-Object path,'Node Type','Actual Rows','Actual Loops',Filter |
  Format-List
```

El resultado guardado muestra:

```text
0.0.0  WindowAgg      160.216 filas
0.0    Subquery Scan   14.452 filas
       Filter: company_relation_id = 1066 AND condición de rango válido
```

El nodo `0.0.0` es hijo de `0.0`: primero produce filas, después su padre las filtra. Acá el filtro de compañía está por encima de la ventana. Los descartes incluyen también rangos inválidos; no atribuyas todos únicamente a otras compañías. El resultado final del probe de propiedad es aún menor: 1.548 filas.

Para comprobar que una rama diferente sí filtra temprano:

```powershell
$rrFullNodes=Get-Content -Raw (Join-Path $rrAlternative 'report__current.nodes.json') | ConvertFrom-Json
$rrFullNodes |
  Where-Object { $_.'Index Cond' -match '1066' -or $_.Filter -match '1066' } |
  Select-Object path,'Node Type','Relation Name','Actual Rows','Index Cond',Filter |
  Format-List
```

Vas a encontrar el filtro en `Index Cond` sobre properties, devolviendo una propiedad. **Conclusión:** algunos filtros llegan a la base y otros no. La pregunta se responde rama por rama, no contando vistas ni mirando dónde está escrito el WHERE final.

Los `path` identifican nodos dentro de estos archivos concretos. Una nueva planificación puede asignarles otra ruta.

## 4. Identificar CTE que construyen conjuntos globales

```powershell
$rrSqftNodes=Get-Content -Raw (Join-Path $rrActual 'dependency__int_unit_sqft_ranges.nodes.json') | ConvertFrom-Json
$rrSqftNodes |
  Where-Object { $_.'Subplan Name' -like 'CTE *' } |
  Select-Object path,'Node Type','Subplan Name','Actual Rows','Actual Loops' |
  Format-Table -AutoSize
```

Buscá:

- `CTE units_base`: **36.957 unidades**.
- `CTE sqft_events`: **42.853 eventos**.

La selección tenía 243 unidades. Es evidencia de una entrada amplia antes de restringir el resultado. En `int_unit_sqft_ranges`, ambos CTE se referencian más de una vez; lo mismo ocurre con `properties_base` y `sqft_events` en `int_property_sqft_totals`.

Para ir del plan al SQL exacto desplegado:

```powershell
$rrInventory=Get-Content -Raw (Join-Path $rrActual 'inventory.json') | ConvertFrom-Json
$rrInventory.nodes |
  Where-Object { $_.name -eq 'int_unit_sqft_ranges' } |
  Select-Object -ExpandProperty definition
```

Cambiá el nombre por `int_property_sqft_totals` o `fct_summarized_rent_roll_detail` para inspeccionar las siguientes etapas. `dependencies.mmd` contiene el grafo completo. Las definiciones del inventario son las de la fecha de captura, no necesariamente las desplegadas hoy.

**Decisión:** comprobar dónde se puede reducir por IDs completos de compañía/propiedad/unidad conservando el historial necesario. No agregar un filtro de fecha debajo de LEAD sin verificar que no cambie el cálculo del siguiente evento.

## 5. Detectar estimaciones incorrectas y joins con demasiado trabajo

```powershell
$rrUnitNodes=Get-Content -Raw (Join-Path $rrActual 'cte__unit_base.nodes.json') | ConvertFrom-Json
$rrUnitNodes |
  Where-Object { $_.path -in @('0.0','0.0.0.0') } |
  Select-Object path,'Node Type','Plan Rows','Actual Rows','Actual Loops','Rows Removed by Join Filter' |
  Format-List
```

Vas a ver **1 fila estimada frente a 243 reales**. El nested loop del nodo `0.0.0.0` descarta **2.666.439 parejas** para devolver 243 filas.

Qué significa cada campo:

| Campo | Cómo interpretarlo |
|---|---|
| `Plan Rows` | Filas que el optimizador esperaba por ejecución del nodo. |
| `Actual Rows` | Promedio de filas producidas por ejecución. |
| `Actual Loops` | Cuántas veces se ejecutó. Cero significa que no se ejecutó. |
| `Actual Rows All Loops` | El script multiplica filas por loops para aproximar trabajo total. |
| `Rows Removed by Join Filter` | Parejas descartadas por la condición del join, promedio por loop. |
| `Join Filter` | Condición usada para descartar esas parejas. |

**Decisión:** si la estimación es diminuta y los descartes/repeticiones son grandes, investigá cardinalidades y elección del join. El nested loop no es malo por definición; el problema es seleccionarlo para una entrada mucho mayor a la prevista o repetir una rama costosa.

El plan normal del reporte completo alcanzó timeout: `20260907_plans/report__current.nodes.json` muestra su estructura estimada, pero no contiene mediciones reales de loops. No completar esa información con números de otro plan.

## 6. Separar el efecto de joins del efecto de temporales

```powershell
Get-Content -Raw (Join-Path $rrAlternative 'RESULTS.md')

$rrFullNodes |
  Where-Object { $_.'Sort Space Type' -eq 'Disk' -or $_.'Hash Batches' -gt 1 } |
  Select-Object path,'Node Type','Sort Method','Sort Space Type','Hash Batches','Temp Read Blocks','Temp Written Blocks' |
  Format-Table -AutoSize
```

Con `enable_nestloop=off` solo en esa sesión, el reporte termina en **1.283 ms** y devuelve 243 filas. Aun así escribe **1.063 bloques temporales**, unos 8,3 MiB con bloques de 8 KiB.

**Conclusión permitida:** el resultado es sensible al plan de joins; evitar ciertos nested loops mejora mucho esta muestra. También hay procesamiento global y desborde de memoria que permanecen.

**Conclusión no demostrada:** que un único join explique toda la demora o que los temporales sean su causa principal. El experimento cambia varios joins y el plan rápido también tiene temporales.

No sumes buffers/temporales de todos los nodos: los padres incluyen trabajo de sus hijos. `TIMING OFF` conserva el tiempo total de ejecución, pero estos archivos no ofrecen tiempos individuales fiables por nodo.

## 7. Repetir la comparación con los parámetros que te interesan

Desde este paso los comandos sí ejecutan consultas si incluyen `--analyze`. Usá la misma sesión PowerShell de los pasos anteriores:

```powershell
Set-Location -LiteralPath $rrRepo
$env:PYTHONPATH=Join-Path $rrRepo 'venv\Lib\site-packages'
$rrPython='C:\Users\julio\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
$rrTool=Join-Path $rrRepo 'bold_reporting\tools\rent_roll_diagnostic.py'
$rrProfile='C:\Users\julio\.dbt\profiles_PROD_LECTURA.yml'
$rrParams=Join-Path $rrRepo 'bold_reporting\tools\rent_roll_parameters.example.json'
$rrOriginal='C:\Users\julio\OneDrive\Documents\Sage\repos\Bold_queries\Summarized_Rent_Roll\Rent_Roll.sql'
```

`$rrParams` reproduce la muestra anterior. Para otro caso, guardá una copia del JSON en el editor, reemplazá sus seis valores y apuntá `$rrParams` a esa copia. Elegí el perfil con el usuario/contexto adecuado para la comparación. No cambies fecha, tipo de parámetro o rol entre las dos versiones.

```powershell
$rrRun=Join-Path $rrDiag ('comparison_'+(Get-Date -Format 'yyyyMMdd_HHmmssfff'))
& $rrPython $rrTool --profile $rrProfile --params $rrParams --original $rrOriginal --asof-type timestamp --only '^(report__current|original__full)$' --analyze --timeout-ms 8000 --budget-seconds 40 --out $rrRun
Get-Content -Raw (Join-Path $rrRun 'RESULTS.md')
```

La carpeta de salida debe ser nueva. El script usa transacciones de solo lectura y cancela cada consulta al llegar al límite. Sacar `--analyze` genera planes estimados sin ejecutar el SELECT. Conservá `context.json`, SQL, planes e inventario de cada corrida.

La comparación usa timestamp a medianoche para ambas queries porque la original resta AsOfDate de effective_date y aplica EXTRACT al intervalo. Confirmá el tipo real que liga Bold. Si tus parámetros llevan hora distinta de medianoche, el script actual no la conserva: está diseñado para una fecha de corte.

Si hay timeout, registrá `>8 s`, no `8 s` como duración exacta. Si termina con `error`, revisá `message/sqlstate` antes de interpretar un problema de rendimiento. `skipped_budget` significa que no se ejecutó la prueba.

## 8. Repetir solo la rama sospechosa

Para las seis etapas de la query final:

```powershell
$rrRun=Join-Path $rrDiag ('ctes_'+(Get-Date -Format 'yyyyMMdd_HHmmssfff'))
& $rrPython $rrTool --profile $rrProfile --params $rrParams --asof-type timestamp --only '^cte__' --analyze --timeout-ms 8000 --budget-seconds 90 --out $rrRun
```

Para las tres etapas internas del fact histórico:

```powershell
$rrRun=Join-Path $rrDiag ('fact_stages_'+(Get-Date -Format 'yyyyMMdd_HHmmssfff'))
& $rrPython $rrTool --profile $rrProfile --params $rrParams --asof-type timestamp --only '^model_cte__' --analyze --timeout-ms 8000 --budget-seconds 60 --out $rrRun
```

Para una única dependencia:

```powershell
$rrRun=Join-Path $rrDiag ('charges_'+(Get-Date -Format 'yyyyMMdd_HHmmssfff'))
& $rrPython $rrTool --profile $rrProfile --params $rrParams --asof-type timestamp --only '^dependency__int_charges_effective_ranges$' --analyze --timeout-ms 8000 --budget-seconds 30 --out $rrRun
```

Los probes `model_cte__` conservan todo el historial de compañía/propiedad: no son snapshots a AsOfDate. Los `dependency__` aplican alcance por claves disponibles. Leer el `.sql` generado antes de interpretar qué conjunto se está midiendo. Los probes aislados orientan; confirmar siempre la conclusión en el reporte completo.

Si preferís tu cliente SQL, abrí uno de los `.sql` generados, que ya tiene parámetros ligados, y ejecutalo así:

```sql
BEGIN READ ONLY;
SET LOCAL statement_timeout = '8s';
SET LOCAL lock_timeout = '2s';

EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS, TIMING OFF, SUMMARY, FORMAT JSON)
-- Pegar aquí el WITH ... SELECT completo del archivo .sql generado.

ROLLBACK;
```

No ejecutes la plantilla sin pegar la query. Después de un timeout, ejecutá ROLLBACK en esa misma sesión: algunos clientes detienen el lote al encontrar el error. No envuelvas la query en COUNT(*) ni agregues LIMIT para medir el reporte completo.

## 9. Probar una hipótesis por vez

Para repetir el experimento de joins, partí del comando de comparación del paso 7, agregá `--disable-nestloop` y usá otra carpeta de salida. Mantené todos los demás parámetros iguales.

Para aislar el hint de FILTERED_RENT_ROLL:

```powershell
$rrRun=Join-Path $rrDiag ('cte_hint_'+(Get-Date -Format 'yyyyMMdd_HHmmssfff'))
& $rrPython $rrTool --profile $rrProfile --params $rrParams --asof-type timestamp --only '^report__' --analyze --timeout-ms 8000 --budget-seconds 60 --out $rrRun
```

Esto compara current, forced_materialized y not_materialized. El 7/9 las tres variantes alcanzaron timeout con parámetros date. No esperar que cambiar solo ese hint corrija los CTE internos de las vistas.

Para evaluar una futura reescritura, índice o estadística, cambiá una cosa por vez en el entorno de prueba y conservá ambos planes. Compará tiempo, filas procesadas, loops, descartes y temporales. Antes de considerar una mejora válida, verificá también los valores del resultado: igual cantidad de filas no prueba igualdad de rentas, superficies o vacancias.

## 10. Comprobar escalabilidad, no solo una ejecución rápida

Prepará tres JSON: una propiedad, varias y todas las propiedades de la misma compañía. Conservá fecha, floor plans, flags, usuario y tipos. Ejecutá la comparación del paso 7 para cada JSON, sin simultaneidad. En un entorno de prueba, repetí al menos tres veces por caso y compará medianas; con timeouts conservá el límite como tal.

Registrá: unidades seleccionadas, filas finales, tiempo de cada versión, mayor error estimado/real, filas de WindowAgg, descartes por join y bloques temporales. Después repetí con compañías de distinto tamaño.

Interpretación:

- Una selección pequeña que procesa grandes conjuntos globales señala trabajo poco relacionado con el alcance pedido.
- Descartes o loops que crecen mucho más que las unidades seleccionadas señalan amplificación del trabajo en joins.
- Un cambio abrupto de tiempo junto con un cambio de tipo de join señala sensibilidad a estimaciones/planificación; no necesariamente una curva suave.
- Temporales crecientes, junto con sorts en disco o más batches de hash, señalan presión de memoria.

Para demostrar crecimiento por datos de otras compañías, se necesita además comparar snapshots/datasets controlados manteniendo fija la compañía seleccionada; variar solo sus propiedades no prueba esa dimensión. Probar concurrencia es un ensayo separado, preferentemente fuera de producción.

El primer objetivo concreto en esta ruta es explicar y reducir el trabajo de la combinación histórica en `fct_summarized_rent_roll_detail`, empezando por las entradas de superficies y cargos. Los diagnósticos ya muestran dónde buscar; los ensayos anteriores permiten comprobar si una intervención cambia realmente esos mecanismos.
