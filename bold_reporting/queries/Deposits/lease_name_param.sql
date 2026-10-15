SELECT 
	distinct "reporting"."stg_leases"."lease_name" as "LEASE_NAME"
  
  	FROM "reporting"."stg_leases"
	INNER JOIN "reporting"."stg_lease_deposits" 
	ON "reporting"."stg_leases"."lease_id"="reporting"."stg_lease_deposits"."lease_id"
 	INNER JOIN "reporting"."stg_units" 
	ON "reporting"."stg_units"."unit_id"="reporting"."stg_lease_deposits"."unit_id"
 	INNER JOIN "reporting"."stg_properties"
  		ON "reporting"."stg_properties"."property_id" =  "reporting"."stg_units"."property_id" 
  
  	WHERE 
  	"reporting"."stg_properties"."prop_name" IN (@Property_Name)
	AND CAST("reporting"."stg_properties"."company_relation_id" AS INT)  = CAST(@REAL_COMPANY_ID AS INT)
  	AND CAST("reporting"."stg_leases"."lease_raw_status" AS TEXT) IN (@Lease_Status)
	AND "reporting"."stg_units"."deleted_at" IS NULL
	AND "reporting"."stg_leases"."deleted_at" IS NULL
	AND "reporting"."stg_lease_deposits"."deleted_at" IS NULL
  	
order by 1 desc