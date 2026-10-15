WITH OPTIONS AS (
  SELECT "reporting"."stg_lease_options"."lease_category",
"reporting"."stg_lease_options"."notification_date",
"reporting"."stg_lease_options"."expiration_date",
"reporting"."stg_lease_options"."property_manager_email",
"reporting"."stg_lease_options"."description",
"reporting"."stg_lease_options"."lease_id" as "D_lease_id",
"reporting"."stg_lease_options"."property_id",
"reporting"."stg_units"."unit_name" as "unit_name",
"reporting"."stg_lease_options"."note" 

FROM "reporting"."stg_lease_options"
INNER JOIN "reporting"."stg_units"
    ON "reporting"."stg_lease_options"."unit_id" =  "reporting"."stg_units"."unit_id"
INNER JOIN "reporting"."stg_properties"
    ON "reporting"."stg_properties"."property_id" =  "reporting"."stg_units"."property_id"
  
  WHERE
	"reporting"."stg_properties"."prop_name" IN (@Property_Name)
	AND CAST("reporting"."stg_properties"."company_relation_id" AS INT)  = CAST(@REAL_COMPANY_ID AS INT)
	
	AND "reporting"."stg_lease_options"."deleted_at" IS NULL
)

SELECT OPTIONS.*

FROM OPTIONS 
order by OPTIONS."D_lease_id"
