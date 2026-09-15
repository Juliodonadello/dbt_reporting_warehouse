# Diagnóstico reproducible del rent roll

Entrada: `analyses/summarized_rent_roll_bold_report.sql`. El script descubre la cadena **desplegada** por `pg_rewrite` / `pg_depend`: no depende de un manifest viejo. Guarda las definiciones, índices y políticas RLS. No ejecuta DDL, no cambia roles ni desactiva RLS.

## Ejecutar

Desde la raíz `dbt`, usando las dependencias existentes:

```powershell
$env:PYTHONPATH=(Resolve-Path 'venv\Lib\site-packages').Path
$rentRollPython='C:\Users\julio\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'

# Plan estimado, sin ejecutar el reporte. Carpeta de salida nueva en cada corrida.
& $rentRollPython bold_reporting\tools\rent_roll_diagnostic.py `
  --profile C:\Users\julio\.dbt\profiles_PROD_LECTURA.yml `
  --params bold_reporting\tools\rent_roll_parameters.example.json `
  --out bold_reporting\target\rent_roll_diagnostics\plans_01

# Ejecutar la ruta completa, secuencialmente; cada consulta se cancela a los 8 s.
& $rentRollPython bold_reporting\tools\rent_roll_diagnostic.py `
  --profile C:\Users\julio\.dbt\profiles_PROD_LECTURA.yml `
  --params bold_reporting\tools\rent_roll_parameters.example.json `
  --analyze --timeout-ms 8000 --budget-seconds 240 `
  --out bold_reporting\target\rent_roll_diagnostics\actual_01
```

El JSON de ejemplo es una muestra de producción, no necesariamente el caso lento de Bold. Copiarlo y reemplazar los seis parámetros para reproducir el caso. Las listas nunca deben estar vacías. Las fechas son ISO y `ignore_end_date` es booleano. Los valores se citan con el adaptador PostgreSQL; no se concatenan sin escape.

`--sample` selecciona una propiedad visible grande cuando no se usa `--params`; el contexto la etiqueta como muestra. `--only 'report__'` ejecuta únicamente las tres variantes del reporte. `--only 'cte__|dependency__int_'` se concentra en los CTE y modelos intermedios. El presupuesto cubre el bucle de planes; conexión, inventario y generación tienen tiempo adicional, también con timeout SQL. No se ejecutan variantes en paralelo contra producción.

La query directa localizada se puede incluir con `--original ..\Bold_queries\Summarized_Rent_Roll\Rent_Roll.sql --asof-type timestamp --only 'report__current|original__full'`. El tipo timestamp se aplica a ambas queries: la original contiene `EXTRACT(DAY FROM (@AsOfDate - effective_date))`, que necesita un intervalo cuando la columna es date. Comprobar el tipo real que liga el proveedor de Bold; no comparar una query con date y otra con timestamp sin registrar esa diferencia.

`--disable-nestloop` agrega `enable_nestloop=off` únicamente a esta conexión. Es un experimento para evaluar sensibilidad a la elección del join, no una recomendación de configuración global; PostgreSQL puede usar nested loops cuando no existe alternativa. `--only 'model_cte__'` mide los tres CTE internos desplegados de `fct_summarized_rent_roll_detail`, filtrados por compañía y propiedad pero conservando todo su historial; esos probes no equivalen a la salida a una fecha del reporte.

El usuario debe tener acceso a los datos seleccionados. Si la selección devuelve cero unidades, el script no presenta un benchmark de esa consulta vacía. Para reproducir exactamente Bold hay que usar su usuario y contexto RLS: un usuario general de lectura permite probar pushdown sobre toda la base, pero no reproduce el costo de las políticas específicas del usuario Bold.

## Qué produce

- `inventory.json`: vistas/tablas, aristas, SQL desplegado, índices y políticas aplicables a las tablas de la ruta. Dependencias internas de funciones y subconsultas RLS no forman parte del grafo de vistas; las políticas se guardan aparte.
- `dependencies.mmd`: grafo Mermaid de las 25 vistas y 11 tablas de la ruta observada el 2026-09-07.
- `context.json` / `parameters.json`: fecha, versión, rol, RLS, work_mem, parámetros y hash de la query final.
- `dependency__*.sql`: pruebas aisladas de cada dependencia, acotadas a compañía/propiedad/unidades según sus claves disponibles. Se conserva la proyección completa para no esconder joins por `COUNT(*)`.
- `cte__*.sql`: cada CTE de la query de Bold como salida. Conserva la lista WITH original; PostgreSQL elimina los CTE no utilizados.
- `model_cte__*.sql`: etapas internas del fact histórico desplegado.
- `original__full.sql` / `original_cte__*.sql`: query directa y sus etapas cuando se indica `--original`.
- `report__current.sql`: query exacta con parámetros ligados.
- `report__forced_materialized.sql` / `report__not_materialized.sql`: comparación que cambia únicamente el hint de `FILTERED_RENT_ROLL`; no altera las vistas.
- `*.plan.json`: plan JSON original con estado de ejecución o timeout.
- `*.nodes.json`: lista de nodos, filtros, índices, filas, loops y temporales para localizar la rama costosa.
- `RESULTS.md`: comparación compacta de tiempos y filas.

Los archivos incluyen nombres de propiedades, metadatos y definiciones internas. Se guardan bajo `target`, ya ignorado por Git. No subirlos a visualizadores públicos. Los planes JSON se pueden inspeccionar localmente en un visor de EXPLAIN o directamente como texto.

## Cómo interpretar

1. Revisar `report__current.plan.json` antes de atribuir el costo de un probe aislado al reporte completo. PostgreSQL puede podar columnas, eliminar joins o mover filtros en el contexto integrado.
2. Buscar `CTE Scan`, `WindowAgg`, `Materialize`, `Sort` y nodos con `Actual Loops` alto. CTE materializado y operador `Materialize` no son lo mismo; un sort/hash también puede escribir temporales sin ninguno de ellos.
3. Seguir `company_relation_id` y las claves de propiedad/unidad: ¿el filtro está en `Index Cond`, en el scan, arriba de `WindowAgg` o recién en un join? Filtrar por claves completas de partición puede ser compatible con una ventana; una ventana no es una barrera absoluta para todo filtro.
4. Comparar `Plan Rows` con `Actual Rows` por loop. Para trabajo total: `Actual Rows * Actual Loops`; lo mismo para `Rows Removed by Filter/Join Filter`. Los campos `All Loops` del archivo de nodos ya hacen ese cálculo. Un `Seq Scan` por sí solo no demuestra un error.
5. Comparar filas de los hijos de joins con sus salidas y descartes. Los joins por solapamiento pueden considerar muchas parejas aunque produzcan pocas filas.
6. `Temp Written Blocks` / `Temp Read Blocks`, `Sort Space Type: Disk` y `Hash Batches > 1` localizan desbordes. Los contadores de padres incluyen hijos: no sumarlos. `work_mem` es por operación, no un presupuesto único de la consulta.
7. Separar `Planning Time` de `Execution Time`. El primero ayuda a detectar costo de planificación de joins; no basta contar vistas.
8. Un timeout es evidencia de duración superior al límite, no entrega cardinalidades parciales. No aumentar automáticamente el límite ni `work_mem` en producción.

`TIMING OFF` evita medir cada nodo pero mantiene `Execution Time`, filas y buffers. Si hace falta tiempo por nodo, ejecutar una sola consulta seleccionada con `TIMING ON`, considerando la sobrecarga. Los resultados de esta herramienta no descargan las filas del reporte: tampoco miden transporte ni render de Bold.

## Comparación con la query original y escalabilidad

Usar la query original real, los mismos parámetros, usuario, tipos, aislamiento y contexto RLS. Ejecutar `EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS, TIMING OFF, FORMAT JSON)` en una transacción de solo lectura con `SET LOCAL statement_timeout`. No sustituirla por un modelo histórico que antes se materializaba como tabla: es otra comparación.

Medir casos de 1, varias y todas las propiedades de **la misma compañía**, conservando la fecha. Alternar original/nueva en varias repeticiones y comparar medianas, buffers, temporales y filas procesadas. Repetir en compañías pequeñas y grandes. Un tiempo que crece con las filas globales mientras la selección se mantiene pequeña señala falta de reducción temprana. Una sola muestra no demuestra la curva completa ni la concurrencia.

Un control adicional útil es sustituir las vistas por sus SELECT exactos como subqueries, conservando CTE, joins y semántica de seguridad. Si los planes coinciden, el problema está en las operaciones relacionales, no en el hecho de tener objetos VIEW.

Referencias oficiales: [reescritura de vistas](https://www.postgresql.org/docs/17/rules-views.html), [CTE e inlining](https://www.postgresql.org/docs/17/queries-with.html#QUERIES-WITH-CTE-MATERIALIZATION), [lectura de EXPLAIN](https://www.postgresql.org/docs/17/using-explain.html).
