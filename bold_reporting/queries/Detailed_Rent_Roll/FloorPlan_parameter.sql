SELECT CASE WHEN "reporting"."stg_units"."floor_plan" IS NULL THEN ' ' else "reporting"."stg_units"."floor_plan" end as  "floorPlan"
FROM "reporting"."stg_units"
INNER  JOIN "reporting"."stg_properties" ON "reporting"."stg_units"."property_id"="reporting"."stg_properties"."property_id"

WHERE  CAST("reporting"."stg_properties"."company_relation_id" AS INT) = CAST(@REAL_COMPANY_ID AS INT)
    AND "reporting"."stg_properties"."prop_name" IN (@Property_Name)
	AND  "reporting"."stg_units"."deleted_at"  IS NULL
	
group by 1
