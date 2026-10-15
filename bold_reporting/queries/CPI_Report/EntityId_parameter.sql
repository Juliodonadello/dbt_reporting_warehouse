SELECT  "reporting"."stg_properties"."entity_id" AS "ENTITY_ID" 

FROM  "reporting"."stg_properties"

WHERE CAST("reporting"."stg_properties"."company_relation_id" AS INT)  = CAST(@REAL_COMPANY_ID AS INT)
 and "reporting"."stg_properties"."deleted_at" IS NULL

GROUP BY  "reporting"."stg_properties"."entity_id"

ORDER BY "reporting"."stg_properties"."entity_id" asc
