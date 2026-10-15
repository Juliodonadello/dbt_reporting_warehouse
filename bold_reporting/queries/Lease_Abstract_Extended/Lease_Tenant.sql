SELECT "reporting"."stg_leases"."lease_id" AS "id",
"reporting"."stg_leases"."lease_name" AS "name",
"reporting"."stg_leases"."lease_raw_status" AS "status",
"reporting"."stg_leases"."lease_start" AS "start",
"reporting"."stg_leases"."lease_end" AS "end",
"reporting"."stg_leases"."move_in",
"reporting"."stg_leases"."intended_move_out",
"reporting"."stg_leases"."actual_move_out",
"reporting"."stg_tenants"."tenant_name" AS "tenants_name",
"reporting"."stg_tenants"."email",
"reporting"."stg_tenants"."balance" 

FROM "reporting"."stg_leases" 
INNER JOIN "reporting"."stg_tenants"
	ON "reporting"."stg_leases"."primary_tenant_id"="reporting"."stg_tenants"."tenant_id"
INNER JOIN "reporting"."stg_properties"
	ON "reporting"."stg_leases"."property_id"="reporting"."stg_properties"."property_id"
	
WHERE CAST("reporting"."stg_properties"."company_relation_id" AS INT)  = CAST(@REAL_COMPANY_ID AS INT)
	
	
	
	AND "reporting"."stg_properties"."prop_name" IN (@Property_Name)
