# Rent roll: diagnóstico medido, 2026-09-07

La regresión se reprodujo con la query `analyses/summarized_rent_roll_bold_report.sql` y las vistas desplegadas: la versión con vistas superó el límite de 8 segundos, mientras la query directa encontrada en `../Bold_queries/Summarized_Rent_Roll/Rent_Roll.sql` completó en 538 ms. Al desalentar nested loops en la sesión de diagnóstico, la versión de vistas completó en 1.283 ms. La evidencia apunta a estimaciones de cardinalidad muy bajas y planes de joins costosos, combinados con procesamiento histórico global y CTE reutilizados que dificultan reducir filas temprano.

No se modificaron queries de negocio, vistas, índices, roles, RLS ni configuración global. Se agregaron herramientas locales y se ejecutaron SELECT/EXPLAIN con transacciones de solo lectura y timeout. Las cancelaciones cerraron/revirtieron su transacción.

## Contexto y límites

- PostgreSQL 17.7; base `sageintacct`; perfil `profiles_PROD_LECTURA.yml`; usuario `sage_uat_ro_user`, miembro de `readonly`; RLS encendido. Este usuario puede leer globalmente por las políticas de lectura, por lo que el ensayo permite observar pushdown sobre todas las compañías, pero **no reproduce las políticas específicas del usuario de Bold**.
- Muestra seleccionada de datos visibles: compañía 1066; `30 N. Michigan, Chicago, IL`; floor plan espacio; 243 unidades; fecha 2026-09-07; month-to-month True y False; ignore_end_date false. No fue provista por el usuario como su caso lento.
- `work_mem=4MB`, `jit=off`. Ejecuciones secuenciales; `EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS, TIMING OFF, SUMMARY, FORMAT JSON)`; límite 8.000 ms por consulta.
- Ruta completa: 25 vistas y 11 tablas, obtenidas del catálogo actual, no de un manifest anterior. El grafo no incluye transitivamente funciones ni subqueries de políticas RLS; las políticas están exportadas aparte.
- Primera pasada: parámetros date; comparación entre original y nueva: timestamp a medianoche para ambas, pues la original usa EXTRACT sobre la diferencia con effective_date. El tipo real ligado por Bold se debe corroborar para una reproducción exacta.
- Son tiempos individuales; no una mediana ni una prueba de concurrencia. Caches y carga no se controlaron. Los planes completados de la comparación tuvieron cero shared reads físicos, pero eso no descarta CPU, lecturas desde buffers ni disco temporal.
- Ambas versiones completadas devolvieron 243 filas. Eso **no** prueba igualdad de valores: hay diferencias de semántica en rangos, superficies de propiedad, borrados y cargos One Time. No sustituir la query actual por la original sobre la base de este benchmark.

## Resultado integrado

| Query / configuración | Execution Time | Filas | Temporales escritos |
|---|---:|---:|---:|
| Directa encontrada, configuración normal, timestamp | 538,358 ms | 243 | 0 bloques |
| Vistas actuales, configuración normal, timestamp | >8.000 ms, cancelada | sin medición final | desconocido |
| Vistas actuales, configuración normal, date | >8.000 ms, cancelada | sin medición final | desconocido |
| FILTERED_RENT_ROLL forzado MATERIALIZED, date | >8.000 ms, cancelada | sin medición final | desconocido |
| FILTERED_RENT_ROLL NOT MATERIALIZED, date | >8.000 ms, cancelada | sin medición final | desconocido |
| Vistas actuales, enable_nestloop=off en esta sesión, timestamp | 1.283,299 ms | 243 | 1.063 bloques |
| Directa encontrada, enable_nestloop=off en esta sesión, timestamp | 319,121 ms | 243 | ver plan |

El timeout frente a 538 ms da una diferencia observada mayor a 14,8 veces en esa muestra; no es una estimación del tiempo final de la query cancelada. La planificación del reporte con vistas que sí completó fue 13,357 ms: allí el costo dominante fue ejecución, no planificación.

El experimento `enable_nestloop=off` se aplicó únicamente mediante opciones de conexión; no es un cambio propuesto para producción. Cambia la elección de varios joins, por lo que prueba sensibilidad al plan, no identifica por sí solo un único join culpable. PostgreSQL puede seguir usando nested loops donde no hay alternativas.

## Dónde aumenta el trabajo

| Etapa aislada, configuración normal/date | Tiempo | Interpretación |
|---|---:|---|
| properties / dim_property | <1 ms | La propiedad seleccionada se encuentra rápidamente. |
| dim_unit | 2,127 ms | El filtro de compañía/propiedad sí puede llegar a la base en esta rama. |
| dim_lease | 53,253 ms | Enriquecimiento de leases aislado, con alcance acotado por el probe. |
| int_unit_sqft_ranges | 184,108 ms | Construye CTE globales antes de restringir la propiedad. |
| int_property_sqft_totals | 47,723 ms | Historial global de superficies de propiedad. |
| int_charges_effective_ranges | 491,342 ms | La compañía se filtra después de WindowAgg. |
| fct_lease_charge | 447,651 ms | Mantiene el costo de construir rangos de cargos. |
| fct_summarized_rent_roll_detail | >8.000 ms | El salto aparece al componer rangos/leases/cargos. |
| rpt_summarized_rent_roll | >8.000 ms | Hereda el costo del fact. |
| CTE UNIT_BASE de Bold | 746,887 ms | 243 filas; contiene un join que descarta millones de parejas. |
| CTE LEASE_BASE de Bold | 860,659 ms | 175 filas; vuelve a necesitar la rama de unidades. |
| CTE FILTERED_RENT_ROLL | >8.000 ms | Expansión histórica integrada antes de la agregación final. |
| CTE CHARGE_AGG | >8.000 ms | Hereda el costo del rent roll. |

Estos tiempos no se suman: cada prueba vuelve a ejecutar sus dependencias y el optimizador puede producir un plan distinto según la proyección final. Ejemplo: `LEASES_PER_UNIT` termina en 1.146,718 ms porque solo necesita contar leases; no representa el costo de devolver todos los importes del reporte.

### 1. Estimaciones bajas y nested loops

En `20260907_actual/cte__unit_base.nodes.json`:

- El CTE UNIT_BASE estima 1 fila, devuelve 243.
- El nested loop en `0.0.0.0` descarta **2.666.439 parejas** por el join, con un loop del nodo.
- LEASE_BASE estima 1 fila y devuelve 175.

En `20260907_plans/report__current.nodes.json`, el join con cargos aparece como Nested Loop Left, estimando 1 fila, con claves property/unit/lease y condiciones de solapamiento en `Join Filter` (`0.2.1.0.0.0`). El plan normal integrado se canceló: no se conoce su número real de repeticiones. El experimento con otros joins consigue terminar sin cambiar datos ni la lógica de las vistas.

Esto importa al crecer la compañía: subestimar una entrada grande favorece planes que repiten trabajo pensado para muy pocas filas. Es necesario corregir cómo llegan las claves y filtros a esas ramas, y evaluar estadísticas/índices con el plan concreto. No hay evidencia para adjudicar todo a falta de índices o resolverlo solo aumentando memoria.

### 2. Cargos: filtro de compañía después de la ventana

En `20260907_actual/dependency__int_charges_effective_ranges.nodes.json`:

- `WindowAgg`, nodo `0.0.0`: **160.216 filas**.
- Su padre `Subquery Scan`, nodo `0.0`, aplica `company_relation_id = 1066` junto con la condición de rango válido.
- Ese padre descarta **145.764 filas** y conserva 14.452 antes del filtro adicional de propiedad del probe. Los descartes combinan compañía y validez; no atribuir todos únicamente a compañía.
- Los scans de cargos, amounts, unidades, propiedades y charge controls que alimentan la ventana no tienen el filtro de compañía en esa rama.

El plan integrado alternativo que termina también procesa 160.216 filas en la ventana de cargos. La query directa encontrada materializa CHARGES_TOT con **1.078 filas** de la propiedad, después de aplicar filtros de compañía/propiedad/fecha en su propia construcción. Es una diferencia relacional concreta.

### 3. Superficies: CTE reutilizados sin alcance de compañía

`int_unit_sqft_ranges` utiliza `units_base` dos veces y `sqft_events` dos veces. La revisión previa había mencionado solo `sqft_events`; **units_base también es candidato a materialización implícita**.

En la ejecución aislada:

- CTE units_base: **36.957 unidades**, frente a 243 seleccionadas.
- CTE sqft_events / WindowAgg: **42.853 eventos**.

`int_property_sqft_totals` reutiliza tanto `properties_base` como `sqft_events`. En el plan integrado observado, procesa **10.974 propiedades** y **13.068 eventos**. La rama de superficies de unidad y la de propiedad aparecen dos veces en la query integrada: una desde UNIT_BASE y otra desde el fact de rent roll. El número de objetos VIEW no demuestra cuánto trabajo se repite; aquí se observa en los planes.

### 4. Temporales y memoria

En el reporte integrado que completa con el plan alternativo hay 1.063 bloques temporales escritos y 1.061 leídos: aproximadamente **8,3 MiB escritos**, usando bloques de 8 KiB. El sort que alimenta la ventana de cargos desborda a disco.

Esto muestra temporales aun sin `AS MATERIALIZED` explícito. Tampoco prueba que los temporales sean el principal causante del timeout normal: el plan alternativo tiene esos temporales y termina en 1,28 s. `enable_nestloop=off` no reduce la ventana global a la compañía; mejora el acceso a sus resultados.

## Qué corrige del diagnóstico anterior

Una vista normal se expande en el árbol relacional y puede recibir filtros del query exterior. Es incorrecto afirmar que, por ser VIEW, necesariamente calcula todo antes de filtrar. Aquí compañía/propiedad aparecen en `Index Cond` sobre properties en dos ramas del plan integrado. Otras ramas sí procesan información global antes de reducirla, por CTE reutilizados, ventanas y la forma de los joins.

Tampoco es universal que `lead()` impida empujar cualquier filtro: preservar particiones completas permite ciertas transformaciones. Debe verse qué predicado cruza qué nodo. La prueba de cargos documenta un predicado concreto que quedó arriba de WindowAgg.

Los contadores acumulados de tablas observados anteriormente no permitían atribuir costo a este reporte. Estos resultados se apoyan en EXPLAIN ANALYZE de las consultas concretas. El antiguo perfil dbt_reporting no veía datos por RLS; esos planes vacíos no eran benchmarks válidos.

La query directa encontrada aplica los parámetros dentro de CHARGE_CONTROL y UNITS, además de su WHERE final. La posición textual del WHERE final no permite concluir equivalencia de ejecución con las vistas históricas.

## Herramientas y evidencia

- `tools/rent_roll_diagnostic.py`: genera y ejecuta la ruta completa, probes por CTE, variantes MATERIALIZED, comparación original y experimento de joins.
- `tools/README_rent_roll_diagnostic.md`: comandos, interpretación de nodos, manejo de timeouts y protocolo para varias propiedades/compañías.
- `tools/rent_roll_parameters.example.json`: muestra usada, reemplazable por los valores reales de Bold.
- `target/rent_roll_diagnostics/20260907_plans`: 45 planes estimados, definición desplegada de cada vista, índices, RLS y grafo.
- `target/rent_roll_diagnostics/20260907_actual`: 45 pruebas ejecutadas con timeout, incluidas todas las tablas/vistas y los CTE de la entrada.
- `target/rent_roll_diagnostics/20260907_comparison_02`: original y nueva con los mismos parámetros timestamp y plan normal.
- `target/rent_roll_diagnostics/20260907_join_experiment`: tres etapas del fact histórico, reporte completo y original, con el experimento de joins.

La carpeta `20260907_comparison` corresponde a un intento que falló al generar pruebas locales por un problema del parser ya corregido; no se usa como evidencia. Los planes e inventarios están bajo target, ignorado por Git. Los archivos generados no contienen contraseñas ni filas de negocio, pero sí nombres de propiedades, parámetros y metadatos internos.

## Próxima intervención basada en evidencia

Priorizar la rama que une superficies, leases y cargos en `fct_summarized_rent_roll_detail`, y los CTE units_base/properties_base/sqft_events en las dos vistas de superficies. La meta es reducir las entradas históricas usando las claves de compañía/propiedad/unidad antes de combinarlas, conservando el significado de las ventanas y los LEFT JOIN. Comparar cada variante contra la query actual con los mismos parámetros y usuario; medir filas/loops/buffers, no solo milisegundos.

Después evaluar índices y estadísticas para las claves usadas por esos planes. No desplegar globalmente `enable_nestloop=off` ni aplicar `NOT MATERIALIZED` a todo como solución. La variante NOT MATERIALIZED solo en FILTERED_RENT_ROLL ya se probó y no evitó el timeout.

Falta reproducir con los parámetros exactos y usuario/contexto RLS de Bold, verificar equivalencia de resultados y medir una matriz de tamaños y concurrencia para establecer la curva completa de escalabilidad. La herramienta deja esos ensayos preparados; esta muestra ya reproduce la regresión y localiza mecanismos observables.
