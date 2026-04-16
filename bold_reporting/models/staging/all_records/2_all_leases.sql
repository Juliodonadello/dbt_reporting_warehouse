WITH LEASES AS (
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
		CASE WHEN LEASES_D."id" IS NULL THEN 'NO' ELSE 'YES' END AS "DEPOSIT",
		CASE
			WHEN COUNT(DISTINCT LEASES_D."refundable") > 1 THEN 'MANY'
			WHEN MAX(CASE WHEN LEASES_D."refundable" = 'true' THEN 1 ELSE 0 END) = 1 THEN 'YES'
			ELSE 'NO'
		END AS "REFUNDABLE",
		TENANTS_."name"  as "TENANT_NAME"
  
FROM {{ var('leases_table') }} as LEASES_
INNER JOIN {{ var('lease_units_table') }} LEASES_U
	ON LEASES_."id" = LEASES_U."lease_id"
INNER OUTER JOIN {{ var('tenants_table') }} TENANTS_
	ON LEASES_."primaryTenantId" = TENANTS_."id" 
LEFT OUTER JOIN {{ var('lease_deposits_table') }} LEASES_D
		ON LEASES_."id" = LEASES_D."lease_id"
		AND (LEASES_D."deleted_at" IS  NULL)
  
	WHERE (LEASES_."deleted_at" IS NULL)
		AND (LEASES_D."deleted_at" IS NULL)
		AND (TENANTS_."deleted_at" IS NULL)
		--AND CASE WHEN CAST(LEASES_."month_to_month" AS TEXT) ='true' THEN 'True' ELSE 'False' END IN (@month_to_month) 
  	
  GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,
		CASE WHEN LEASES_D."id" IS NULL THEN 'NO' ELSE 'YES' END ,
		TENANTS_."name"
	)

select *
from LEASES
