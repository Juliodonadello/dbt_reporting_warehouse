{{ config(
  materialized='table',
  schema='reporting'
  ) }}

WITH UNITS AS (
  SELECT 
    PROPS_."id" AS "PROP_ID",
    PROPS_."name" AS "PROP_NAME",
    UNITS_."id" AS "UNIT_ID",
    UNITS_."name" AS "UNIT_NAME",
    UNITS_."total_square_footage" AS "UNIT_TOTAL_SQ_FT",
    UNITS_SF."square_footage_type" AS "UNIT_SF_TYPE",
    UNITS_SF."value" AS "UNIT_SF_VALUE",
    UNITS_SF."as_of_date" AS "UNIT_SF_ASOFDATE"
  
  FROM {{ var('units_table') }} UNITS_
  INNER JOIN {{ var('properties_table') }} PROPS_
    ON UNITS_."property_id" = PROPS_."id"
  LEFT JOIN {{ var('unit_square_footage_items_table') }} UNITS_SF
    ON UNITS_SF."unit_id" = UNITS_."id"

  WHERE PROPS_."deleted_at" IS NULL
    AND (UNITS_."deleted_at" IS NULL)
    AND (UNITS_SF."deleted_at" IS NULL)
	  --AND UNITS_."status" = 'active'
)

select *
from UNITS