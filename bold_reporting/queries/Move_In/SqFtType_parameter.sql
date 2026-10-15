WITH UNITS AS 
(
  SELECT 
		"reporting"."stg_properties"."property_id" AS "PROP_ID",
		"reporting"."stg_properties"."prop_name" AS "PROP_NAME",
		"reporting"."stg_units"."unit_id" AS "UNIT_ID",
  		"reporting"."stg_units"."unit_name" AS "UNIT_NAME",
  		"reporting"."stg_unit_square_footage_items"."square_footage_type" AS "SQ_FT_TYPE",
  		"reporting"."stg_units"."unit_class" AS "UNIT_CLASS"
  		
	FROM   "reporting"."stg_units"
	INNER JOIN "reporting"."stg_properties"
		ON "reporting"."stg_units"."property_id" = "reporting"."stg_properties"."property_id"
  	LEFT JOIN "reporting"."stg_unit_square_footage_items"
		ON "reporting"."stg_unit_square_footage_items"."unit_id" = "reporting"."stg_units"."unit_id"
	
  	WHERE "reporting"."stg_units"."deleted_at" IS NULL
  	and "reporting"."stg_properties"."deleted_at" IS NULL
	AND CAST("reporting"."stg_properties"."company_relation_id" AS INT) = CAST(@REAL_COMPANY_ID AS INT)
  
	GROUP BY 
		"reporting"."stg_properties"."property_id",
		"reporting"."stg_properties"."prop_name",
		"reporting"."stg_units"."unit_id",
  		"reporting"."stg_units"."unit_name",
        "reporting"."stg_units"."unit_class",
  		"reporting"."stg_unit_square_footage_items"."square_footage_type" 
)
select UNITS."SQ_FT_TYPE"
	
from UNITS

where  UNITS."PROP_NAME" IN (@Property_Name)

GROUP BY UNITS."SQ_FT_TYPE"
