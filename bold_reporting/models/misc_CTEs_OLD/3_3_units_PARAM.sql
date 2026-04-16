{{ config(
  schema='reporting'
  ) }}

WITH UNITS AS (
  SELECT 
    PROPS_."id" AS "PROP_ID",
    PROPS_."name" AS "PROP_NAME",
    UNITS_."id" AS "UNIT_ID",
    UNITS_."name" AS "UNIT_NAME",
    MAX(COALESCE(uq."value", UNITS_."total_square_footage")) AS "UNIT_SQ_FT"
  
  FROM {{ var('units_table') }} UNITS_
  INNER JOIN {{ var('properties_table') }} PROPS_
    ON UNITS_."property_id" = PROPS_."id"
  
  LEFT JOIN (
    SELECT DISTINCT ON ("unit_id") 
      "unit_id",
      "value",
      "as_of_date"
    FROM {{ var('unit_square_footage_items_table') }}
    WHERE "square_footage_type" = 'Total'
      AND "as_of_date" <= @AsOfDate
    ORDER BY "unit_id", "as_of_date" DESC
  ) AS uq
    ON uq."unit_id" = UNITS_."id"
  
  WHERE PROPS_."deleted_at" IS NULL
    AND (UNITS_."deleted_at" >= @AsOfDate OR UNITS_."deleted_at" IS NULL)
    --AND PROPS_."name" IN (@Property_Name)
    --AND CAST(PROPS_."company_relation_id" AS INT) = CAST(@REAL_COMPANY_ID AS INT)
	AND UNITS_."status" = 'active'
  
  GROUP BY 
    PROPS_."id",
    PROPS_."name",
    UNITS_."id",
    UNITS_."name"
)

select *
from UNITS
