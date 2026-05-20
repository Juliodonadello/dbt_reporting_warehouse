WITH LEASE_DEPOSITS AS (
	SELECT
		LEASES_D."lease_id" AS "LEASE_ID",
		CASE WHEN COUNT(LEASES_D."id") = 0 THEN 'NO' ELSE 'YES' END AS "DEPOSIT",
		CASE
			WHEN COUNT(DISTINCT LEASES_D."refundable") > 1 THEN 'MANY'
			WHEN MAX(CASE WHEN LEASES_D."refundable" = 'true' THEN 1 ELSE 0 END) = 1 THEN 'YES'
			ELSE 'NO'
		END AS "REFUNDABLE"
	FROM {{ source('app', 'lease_deposits') }} LEASES_D
	WHERE LEASES_D."deleted_at" IS NULL
	GROUP BY LEASES_D."lease_id"
),
LEASES AS (
  SELECT LEASES_."id" AS "LEASE_ID",
		LEASES_."name" AS "LEASE_NAME",
		LEASES_U."unit_id" AS "UNIT_ID",
		LEASES_."created_at" AS "lease_created_at",
  		LEASES_."start" AS "lease_start",
		LEASES_."end" AS "lease_end",
  		LEASES_."actual_move_out" AS "ACTUAL_MOVE_OUT",
		LEASES_."intended_move_out" AS "INTENDED_MOVE_OUT",
  		LEASES_."reason_for_termination" AS "REASON_FOR_TERMINATION",
		LEASES_."company_relation_id" AS "company_relation_id",
		LEASES_."property_id" AS "PROP_ID",
		LEASES_."status" AS "LEASE_STATUS",
		COALESCE(LEASE_DEPOSITS."DEPOSIT", 'NO') AS "DEPOSIT",
		COALESCE(LEASE_DEPOSITS."REFUNDABLE", 'NO') AS "REFUNDABLE",
		TENANTS_."name"  as "TENANT_NAME",
		LEASES_."month_to_month" as "month_to_month",
		COALESCE(LEASES_."start", LEASES_U."move_in", date '1900-01-01') as "_valid_from",
		LEAST(
			COALESCE(LEASES_."end", date '9999-12-31'),
			COALESCE(LEASES_."actual_move_out", date '9999-12-31'),
			COALESCE(LEASES_."intended_move_out", date '9999-12-31'),
			COALESCE(CAST(LEASES_."deleted_at" AS date), date '9999-12-31'),
			COALESCE(CAST(LEASES_U."deleted_at" AS date), date '9999-12-31')
		) as "_valid_to"
  
FROM {{ source('app', 'leases') }} as LEASES_
INNER JOIN {{ source('app', 'lease_units') }} LEASES_U
	ON LEASES_."id" = LEASES_U."lease_id"
LEFT OUTER JOIN {{ source('app', 'tenants') }} TENANTS_
	ON LEASES_."primaryTenantId" = TENANTS_."id" 
LEFT OUTER JOIN LEASE_DEPOSITS
	ON LEASES_."id" = LEASE_DEPOSITS."LEASE_ID"
  
	WHERE (TENANTS_."deleted_at" IS NULL OR TENANTS_."id" IS NULL)
		--AND CASE WHEN CAST(LEASES_."month_to_month" AS TEXT) ='true' THEN 'True' ELSE 'False' END IN (@month_to_month) 
	)

select *
from LEASES
where "_valid_from" < "_valid_to"
