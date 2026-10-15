with LEASES_TOT AS (
  SELECT "reporting"."stg_leases"."lease_id" AS "LEASE_ID",
		  "reporting"."stg_lease_units"."unit_id" AS "UNIT_ID",
		  "reporting"."stg_leases"."lease_start" AS "lease_start",
		  "reporting"."stg_leases"."lease_end" AS "lease_end",
		  "reporting"."stg_leases"."lease_name" AS "LEASE_NAME",
		  "reporting"."stg_tenants"."tenant_name"  as "TENANT",
		  "reporting"."stg_properties"."prop_name" AS "PROP_NAME",
		  "reporting"."stg_properties"."company_relation_id" AS "COMP_ID"

	FROM "reporting"."stg_leases"
  INNER JOIN "reporting"."stg_lease_units"
	  ON "reporting"."stg_leases"."lease_id" ="reporting"."stg_lease_units"."lease_id"
  INNER JOIN "reporting"."stg_tenants"
	  ON "reporting"."stg_leases"."primary_tenant_id" = "reporting"."stg_tenants"."tenant_id" 
  INNER JOIN "reporting"."stg_properties"
	  ON "reporting"."stg_leases"."property_id" = "reporting"."stg_properties"."property_id"

	  WHERE
	  (
		  (
			  @ignore_end_date = true
			  AND "reporting"."stg_leases"."lease_raw_status" = 'current'
			  AND COALESCE(
				  "reporting"."stg_lease_units"."move_in",
				  "reporting"."stg_leases"."lease_start"
			  ) <= @FromDate
		  )
		  OR
		  (
			  @ignore_end_date = false
			  AND COALESCE(
				  "reporting"."stg_lease_units"."move_in",
				  "reporting"."stg_leases"."lease_start"
			  ) <= @FromDate
			  AND
			  (
				  (
					  CAST("reporting"."stg_leases"."month_to_month_flag" AS TEXT) = 'true'
					  AND
					  (
						  "reporting"."stg_leases"."lease_termination" IS NULL
						  OR "reporting"."stg_leases"."lease_termination" > @FromDate
					  )
				  )
				  OR "reporting"."stg_leases"."lease_end" IS NULL
				  OR "reporting"."stg_leases"."lease_end" > @FromDate
			  )
		  )
	  )
		  AND "reporting"."stg_leases"."deleted_at" IS NULL
		  AND "reporting"."stg_leases"."lease_raw_status" <> 'canceled'
		  AND CAST("reporting"."stg_properties"."company_relation_id" AS INT) = CAST(@REAL_COMPANY_ID AS INT)

  ORDER BY "reporting"."stg_lease_units"."unit_id" 
),
LEASE_MAX_END AS (
  SELECT "UNIT_ID", 
  MAX("lease_end") "END",
  SUM(CASE WHEN "lease_end" IS NULL THEN 1 ELSE 0 END) AS "END_NULL"
  FROM LEASES_TOT
  GROUP BY "UNIT_ID"
),
LEASES AS (
	SELECT LEASES_TOT.*, 
		LEASE_MAX_END."END" AS "END",
		LEASE_MAX_END."END_NULL" AS "END_NULL"
	FROM LEASES_TOT
	INNER JOIN LEASE_MAX_END
		ON LEASES_TOT."UNIT_ID" = LEASE_MAX_END."UNIT_ID"
		AND LEASES_TOT."lease_end" = LEASE_MAX_END."END"
),
FINAL AS (
	select LEASES."UNIT_ID",
	  "END", --fecha de cuando se vacia la unidad
	  "END_NULL", -- flag si la unidad no se vacia nunca (lease_end = null)
	  CASE 
		WHEN "END_NULL" >= 1 THEN 'OCCUPIED'
		WHEN "END" > @FromDate THEN 'OCCUPIED'
	  	ELSE 'VACANT'
	  END AS "UNIT_STATUS"
	FROM LEASES
 ),
 UNITS AS (
  SELECT 
    "reporting"."stg_properties"."property_id" AS "PROP_ID",
    "reporting"."stg_properties"."prop_name" AS "PROP_NAME",
    "reporting"."stg_units"."unit_id" AS "UNIT_ID",
    "reporting"."stg_units"."unit_name" AS "UNIT_NAME",
  	"reporting"."stg_units"."unit_class" AS "UNIT_CLASS",
    MAX(COALESCE(uq."unit_sq_ft_value", "reporting"."stg_units"."base_unit_sq_ft")) AS "UNIT_SQ_FT"
  
  FROM "reporting"."stg_units"
  INNER JOIN "reporting"."stg_properties"
    ON "reporting"."stg_units"."property_id" = "reporting"."stg_properties"."property_id"
  
  LEFT JOIN (
    SELECT DISTINCT ON ("unit_id") 
      "unit_id",
      "unit_sq_ft_value",
      "as_of_date"
    FROM "reporting"."stg_unit_square_footage_items"
    WHERE "square_footage_type" IN (@SqFtType) --'Total'
      AND "as_of_date" <= @ToDate
    ORDER BY "unit_id", "as_of_date" DESC
  ) AS uq
    ON uq."unit_id" = "reporting"."stg_units"."unit_id"
  
  WHERE "reporting"."stg_properties"."deleted_at" IS NULL
    AND ("reporting"."stg_units"."deleted_at" IS NULL)
    AND "reporting"."stg_properties"."prop_name" IN (@Property_Name)
    AND CAST("reporting"."stg_properties"."company_relation_id" AS INT) = CAST(@REAL_COMPANY_ID AS INT)
	AND "reporting"."stg_units"."unit_status_raw" = 'active'
  
  GROUP BY 
    "reporting"."stg_properties"."property_id",
    "reporting"."stg_properties"."prop_name",
    "reporting"."stg_units"."unit_id",
    "reporting"."stg_units"."unit_name",
  	"reporting"."stg_units"."unit_class"
)

 select  "reporting"."stg_leases"."lease_id" AS "id",
"reporting"."stg_leases"."lease_name" AS "LEASE_NAME",
"reporting"."stg_leases"."lease_raw_status" AS "LEASE_STATUS",
FINAL."END" AS "PREVIOUS_LEASE_END",
"reporting"."stg_leases"."move_in",
"reporting"."stg_leases"."company_relation_id",
"reporting"."stg_leases"."property_id",
"reporting"."stg_tenants"."tenant_name"  as "TENANT",
"reporting"."stg_properties"."prop_name" as "PROP_NAME",
UNITS."UNIT_NAME" as "UNIT_NAME",
UNITS."UNIT_SQ_FT" as "UNIT_SQ_FT",
CASE WHEN FINAL."UNIT_STATUS" IS NULL THEN 'VACANT' ELSE FINAL."UNIT_STATUS" END AS "UNIT_STATUS",
CASE
	WHEN FINAL."END_NULL" >= 1 THEN '0' -- EL FLAG END_NULL INDICA UNIDAD OCUPADA
	WHEN FINAL."END_NULL"  is null AND FINAL."END_NULL" IS NULL THEN CAST(ROUND(("reporting"."stg_leases"."move_in" - CAST(@FromDate AS DATE))/ 30.44,0) AS TEXT) -- VACIA POR EL JOIN A NIVEL UNIT, UNIDAD VACANTE. SIN LEASE PREVIO
	WHEN "reporting"."stg_leases"."move_in" > FINAL."END" THEN CAST(ROUND(("reporting"."stg_leases"."move_in" - FINAL."END")/ 30.44,0) AS TEXT) -- CASO DE INTERES, MESES CON LA UNIDAD VACIA
	WHEN "reporting"."stg_leases"."move_in" < FINAL."END" THEN  '0' -- NO SE VACIA NUNCA, EL MOVE ES ANTERIOR AL PREVIOUS_LEASE_END
	ELSE ''
	END AS "Vacancy",
CASE
	WHEN FINAL."END_NULL" >= 1 THEN '0' -- EL FLAG END_NULL INDICA UNIDAD OCUPADA
	WHEN FINAL."END_NULL"  is null AND FINAL."END_NULL" IS NULL THEN CAST(ROUND(("reporting"."stg_leases"."move_in" - CAST(@FromDate AS DATE))/ 30.44/12,2) AS TEXT) -- VACIA POR EL JOIN A NIVEL UNIT, UNIDAD VACANTE. SIN LEASE PREVIO
	WHEN "reporting"."stg_leases"."move_in" > FINAL."END" THEN CAST(ROUND(("reporting"."stg_leases"."move_in" - FINAL."END")/ 30.44/12,2) AS TEXT) -- CASO DE INTERES, MESES CON LA UNIDAD VACIA
	WHEN "reporting"."stg_leases"."move_in" <= FINAL."END" THEN  '0' -- NO SE VACIA NUNCA, EL MOVE ES ANTERIOR AL PREVIOUS_LEASE_END
	ELSE ''
	END AS "Vacancy_years"
	
FROM "reporting"."stg_leases"
INNER JOIN "reporting"."stg_properties"
	ON "reporting"."stg_leases"."property_id" = "reporting"."stg_properties"."property_id"
INNER JOIN "reporting"."stg_tenants"
		ON "reporting"."stg_leases"."primary_tenant_id" = "reporting"."stg_tenants"."tenant_id"
INNER JOIN "reporting"."stg_lease_units"
		ON "reporting"."stg_leases"."lease_id" ="reporting"."stg_lease_units"."lease_id"
INNER JOIN UNITS
ON "reporting"."stg_lease_units"."unit_id" = UNITS."UNIT_ID"
LEFT JOIN FINAL
	ON FINAL."UNIT_ID" = UNITS."UNIT_ID"

where "reporting"."stg_leases"."deleted_at" is null
	AND CAST("reporting"."stg_properties"."company_relation_id" AS INT) = CAST(@REAL_COMPANY_ID AS INT)
	AND "reporting"."stg_properties"."prop_name" IN (@Property_Name)
	AND "reporting"."stg_leases"."move_in" < @ToDate
	AND "reporting"."stg_leases"."move_in" >= @FromDate
	AND CAST("reporting"."stg_leases"."lease_raw_status" AS TEXT) IN (@Lease_status)
	

ORDER BY "reporting"."stg_properties"."company_relation_id",
"reporting"."stg_properties"."prop_name",
UNITS."UNIT_NAME",
"reporting"."stg_tenants"."tenant_name"
