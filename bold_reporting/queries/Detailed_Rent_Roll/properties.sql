SELECT  "reporting"."stg_properties"."prop_name" AS "PROP_NAME" 

FROM  "reporting"."stg_properties"

WHERE CAST("reporting"."stg_properties"."company_relation_id" AS INT)  = CAST(@REAL_COMPANY_ID AS INT)
 and "reporting"."stg_properties"."deleted_at" IS NULL
 AND "reporting"."stg_properties"."entity_id" IN (@Entity_Id)

GROUP BY  "reporting"."stg_properties"."prop_name"

ORDER BY "reporting"."stg_properties"."prop_name" asc
