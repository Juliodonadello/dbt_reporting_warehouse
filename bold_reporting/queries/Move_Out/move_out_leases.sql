with UNITS AS (
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
"reporting"."stg_leases"."actual_move_out" as "ACTUAL_MOVE_OUT",
"reporting"."stg_leases"."intended_move_out" as "INTENDED_MOVE_OUT",
"reporting"."stg_leases"."reason_for_termination" as "REASON_FOR_TERMINATION",
"reporting"."stg_leases"."company_relation_id",
"reporting"."stg_leases"."property_id",
"reporting"."stg_tenants"."tenant_name"  as "TENANT",
"reporting"."stg_properties"."prop_name" as "PROP_NAME",
UNITS."UNIT_NAME" as "UNIT_NAME",
UNITS."UNIT_SQ_FT" as "UNIT_SQ_FT",
"reporting"."stg_leases"."lease_end" AS "LEASE_END"

	
FROM "reporting"."stg_leases"
INNER JOIN "reporting"."stg_properties"
	ON "reporting"."stg_leases"."property_id" = "reporting"."stg_properties"."property_id"
INNER JOIN "reporting"."stg_tenants"
		ON "reporting"."stg_leases"."primary_tenant_id" = "reporting"."stg_tenants"."tenant_id"
INNER JOIN "reporting"."stg_lease_units"
		ON "reporting"."stg_leases"."lease_id" ="reporting"."stg_lease_units"."lease_id"
INNER JOIN UNITS
ON "reporting"."stg_lease_units"."unit_id" = UNITS."UNIT_ID"

where "reporting"."stg_leases"."deleted_at" is null
	AND CAST("reporting"."stg_properties"."company_relation_id" AS INT)  = CAST(@REAL_COMPANY_ID AS INT)
	AND "reporting"."stg_properties"."prop_name" IN (@Property_Name)
	AND
	(
		(
			@ignore_end_date = true
			AND
			(
				"reporting"."stg_leases"."actual_move_out" < @ToDate
				OR "reporting"."stg_leases"."intended_move_out" < @ToDate
			)
			AND
			(
				"reporting"."stg_leases"."actual_move_out" >= @FromDate
				OR "reporting"."stg_leases"."intended_move_out" >= @FromDate
			)
		)
		OR
		(
			@ignore_end_date = false
			AND
			(
				"reporting"."stg_leases"."actual_move_out" < @ToDate
				OR "reporting"."stg_leases"."intended_move_out" < @ToDate
				OR "reporting"."stg_leases"."lease_end" < @ToDate
			)
			AND
			(
				"reporting"."stg_leases"."actual_move_out" >= @FromDate
				OR "reporting"."stg_leases"."intended_move_out" >= @FromDate
				OR "reporting"."stg_leases"."lease_end" >= @FromDate
			)
		)
	)
	AND CAST("reporting"."stg_leases"."lease_raw_status" AS TEXT) IN (@Lease_Status)

ORDER BY "reporting"."stg_properties"."company_relation_id",
"reporting"."stg_properties"."prop_name",
natural_sort(UNITS."UNIT_NAME"),
"reporting"."stg_tenants"."tenant_name"
