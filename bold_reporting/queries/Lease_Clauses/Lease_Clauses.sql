SELECT 
  "reporting"."stg_lease_options"."lease_option_id" AS "Clause_id",
  "reporting"."stg_lease_options"."lease_category" AS "clause_category",
  "reporting"."stg_lease_options"."notification_date",
  "reporting"."stg_lease_options"."expiration_date",
  --"reporting"."stg_lease_options"."tenant_email",
  "reporting"."stg_lease_options"."property_manager_email",
  "reporting"."stg_lease_options"."description",
  "reporting"."stg_lease_options"."sent",
  "reporting"."stg_lease_options"."lease_id",
  "reporting"."stg_lease_options"."property_id",
  "reporting"."stg_lease_options"."unit_id",
  "reporting"."stg_properties"."prop_name",
  "reporting"."stg_tenants"."tenant_name" as "TENANT_NAME",
  MIN("reporting"."stg_units"."unit_name") as "UNIT_NAME",
  "reporting"."stg_leases"."lease_raw_status"  as "LEASE_STATUS"
	  
FROM "reporting"."stg_lease_options"
  INNER JOIN "reporting"."stg_leases" ON "reporting"."stg_lease_options"."lease_id" = "reporting"."stg_leases"."lease_id"
  inner join "reporting"."stg_properties" on "reporting"."stg_properties"."property_id" = "reporting"."stg_leases"."property_id"
  LEFT JOIN "reporting"."stg_tenants" on "reporting"."stg_leases"."primary_tenant_id" = "reporting"."stg_tenants"."tenant_id"
  INNER JOIN "reporting"."stg_lease_units" on "reporting"."stg_leases"."lease_id" = "reporting"."stg_lease_units"."lease_id"
  INNER JOIN "reporting"."stg_units" on "reporting"."stg_lease_units"."unit_id" = "reporting"."stg_units"."unit_id"
		 
WHERE CAST("reporting"."stg_properties"."company_relation_id" AS INT)  = CAST(@REAL_COMPANY_ID AS INT)
  AND "reporting"."stg_properties"."prop_name" IN (@Property_Name)
  AND ("reporting"."stg_lease_options"."expiration_date" > @FromDate and "reporting"."stg_lease_options"."expiration_date" < @ToDate)
  --AND "reporting"."stg_leases"."lease_raw_status" = 'current'
  --AND "reporting"."stg_leases"."lease_raw_status" IN (@Lease_Status) --Reatrieving operator error. Fix: Implementing a filter over the table layout using the parameter values
  AND "reporting"."stg_lease_options"."deleted_at" IS NULL
  AND "reporting"."stg_leases"."deleted_at" IS NULL
  AND "reporting"."stg_properties"."deleted_at" IS NULL
  AND "reporting"."stg_units"."deleted_at" IS NULL
  
 GROUP BY 
  "reporting"."stg_lease_options"."lease_option_id",
  "reporting"."stg_lease_options"."lease_category",
  "reporting"."stg_lease_options"."notification_date",
  "reporting"."stg_lease_options"."expiration_date",
  "reporting"."stg_lease_options"."property_manager_email",
  "reporting"."stg_lease_options"."description",
  "reporting"."stg_lease_options"."sent",
  "reporting"."stg_lease_options"."lease_id",
  "reporting"."stg_lease_options"."property_id",
  "reporting"."stg_lease_options"."unit_id",
  "reporting"."stg_properties"."prop_name",
  "reporting"."stg_properties"."company_relation_id",
  "reporting"."stg_tenants"."tenant_name",
  "reporting"."stg_leases"."lease_raw_status"
  
ORDER BY "reporting"."stg_lease_options"."lease_category"
