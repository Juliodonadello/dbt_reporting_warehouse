SELECT 
"reporting"."stg_leases"."lease_name" as "lease_name",
"reporting"."stg_leases"."lease_id" as "leaseId",
"reporting"."stg_tenants"."external_tenant_id" AS "tenant_id",
"reporting"."stg_tenants"."tenant_name" as "tenant_name",
"reporting"."stg_units"."unit_location_id",
"reporting"."stg_units"."unit_name" as "unit_name",
"reporting"."stg_lease_deposits"."deposit_type" as "deposit_type",
CASE WHEN "reporting"."stg_lease_deposits"."refundable" IS TRUE THEN 'Yes' else 'No' END AS "refundable",
"reporting"."stg_lease_deposits"."invoice_number" as "invoiceNumber",
"reporting"."stg_properties"."prop_name" as "PROP_NAME"

FROM "reporting"."stg_lease_deposits" 
INNER JOIN "reporting"."stg_leases" 
	ON "reporting"."stg_leases"."lease_id"="reporting"."stg_lease_deposits"."lease_id"
INNER JOIN "reporting"."stg_units" 
	ON "reporting"."stg_units"."unit_id"="reporting"."stg_lease_deposits"."unit_id"
INNER JOIN "reporting"."stg_tenants" 
	ON "reporting"."stg_tenants"."tenant_id"="reporting"."stg_lease_deposits"."tenant_id"
INNER JOIN "reporting"."stg_properties" 
	ON "reporting"."stg_properties"."property_id"="reporting"."stg_leases"."property_id"
	
WHERE CAST("reporting"."stg_properties"."company_relation_id" AS INT) = CAST(@REAL_COMPANY_ID AS INT)
AND "reporting"."stg_properties"."prop_name" IN (@Property_Name)
AND  CAST("reporting"."stg_leases"."lease_raw_status" AS TEXT) IN (@Lease_Status)
AND "reporting"."stg_properties"."deleted_at" IS NULL
AND "reporting"."stg_units"."deleted_at" IS NULL
AND "reporting"."stg_leases"."deleted_at" IS NULL
AND "reporting"."stg_leases"."lease_raw_status" <> 'canceled'
AND "reporting"."stg_lease_deposits"."deleted_at" IS NULL
AND "reporting"."stg_lease_deposits"."invoice_number" IS NOT NULL
AND  CAST("reporting"."stg_leases"."lease_name" AS TEXT) IN (@Lease_Name)
AND  CAST("reporting"."stg_lease_deposits"."deposit_type" AS TEXT) IN (@Deposit_Type)
AND CASE WHEN "reporting"."stg_lease_deposits"."refundable" IS TRUE THEN 'YES' else 'NO' END IN (@Refundable)

ORDER BY "reporting"."stg_properties"."prop_name", NATURAL_SORT("reporting"."stg_units"."unit_name")