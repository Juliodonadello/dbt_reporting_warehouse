SELECT DISTINCT "reporting"."stg_lease_recurring_charges"."item_id" AS "ITEM_ID"

FROM "reporting"."stg_lease_recurring_charges"
INNER JOIN "reporting"."stg_units" ON "reporting"."stg_lease_recurring_charges"."unit_id" =  "reporting"."stg_units"."unit_id"
INNER  JOIN "reporting"."stg_properties" ON "reporting"."stg_units"."property_id"="reporting"."stg_properties"."property_id"

WHERE
	"reporting"."stg_lease_recurring_charges"."deleted_at" IS NULL
	AND ("reporting"."stg_lease_recurring_charges"."terminate_date" >= @AsOfDate OR "reporting"."stg_lease_recurring_charges"."terminate_date" IS NULL)
	AND	"reporting"."stg_properties"."prop_name" IN (@Property_Name)
	AND CAST("reporting"."stg_properties"."company_relation_id" AS INT) = CAST(@REAL_COMPANY_ID AS INT)