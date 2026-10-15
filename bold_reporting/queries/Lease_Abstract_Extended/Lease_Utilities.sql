SELECT "reporting"."stg_leases"."lease_id" as "LEASE_ID",
"reporting"."stg_leases"."lease_name" as "LEASE_NAME",
"reporting"."stg_properties"."prop_name" as "PROP_NAME",
"reporting"."stg_units"."unit_name" as "UNIT_NAME",
"reporting"."stg_units"."unit_id" as "UNIT_ID",
"reporting"."stg_unit_utilities"."utility_name" as "UTILITY_NAME",
"reporting"."stg_unit_utilities"."utility_description" as "UTILITY_DESCRIPTION"

FROM "reporting"."stg_leases"
INNER JOIN "reporting"."stg_properties"
  		ON "reporting"."stg_properties"."property_id" =  "reporting"."stg_leases"."property_id"
INNER JOIN "reporting"."stg_lease_units"
  		ON "reporting"."stg_lease_units"."lease_id" =  "reporting"."stg_leases"."lease_id"
INNER JOIN "reporting"."stg_units"
  		ON "reporting"."stg_lease_units"."unit_id" =  "reporting"."stg_units"."unit_id"
INNER JOIN "reporting"."stg_unit_utilities"
  		ON "reporting"."stg_lease_units"."unit_id" =  "reporting"."stg_unit_utilities"."unit_id"

WHERE  	"reporting"."stg_properties"."prop_name" IN (@Property_Name)
		AND "reporting"."stg_properties"."deleted_at" IS NULL
		AND "reporting"."stg_lease_units"."deleted_at" IS NULL
		AND "reporting"."stg_unit_utilities"."deleted_at" IS NULL
		AND CAST("reporting"."stg_properties"."company_relation_id" AS INT)  = CAST(@REAL_COMPANY_ID AS INT)
		AND (
					
					"reporting"."stg_leases"."deleted_at" IS NULL
					)
		AND (CASE WHEN "reporting"."stg_leases"."month_to_month_flag" = 'False' THEN 'NO'
							WHEN "reporting"."stg_leases"."month_to_month_flag" = 'True' THEN 'YES'
				END) IN (@month_to_month)
				