{{ config(
  schema='reporting'
  ) }}

WITH UNIT_SQ_FT_ITEMS AS (
  SELECT
    UNITS_SF."unit_id",
    UNITS_SF."square_footage_type",
    UNITS_SF."value",
    UNITS_SF."as_of_date",
    UNITS_SF."as_of_date" as "_valid_from",
    COALESCE(
      LEAD(UNITS_SF."as_of_date") OVER (
        PARTITION BY UNITS_SF."unit_id", UNITS_SF."square_footage_type"
        ORDER BY UNITS_SF."as_of_date"
      ),
      date '9999-12-31'
    ) as "_valid_to"
  FROM {{ source('app', 'unit_square_footage_items') }} UNITS_SF
  WHERE UNITS_SF."deleted_at" IS NULL
    AND UNITS_SF."as_of_date" IS NOT NULL
),
FIRST_TOTAL_SQ_FT AS (
  SELECT
    UNIT_SQ_FT_ITEMS."unit_id",
    MIN(UNIT_SQ_FT_ITEMS."as_of_date") AS "FIRST_AS_OF_DATE"
  FROM UNIT_SQ_FT_ITEMS
  WHERE UNIT_SQ_FT_ITEMS."square_footage_type" = 'Total'
  GROUP BY UNIT_SQ_FT_ITEMS."unit_id"
),
BASE_UNIT_SQ_FT AS (
  SELECT
    UNITS_."id" AS "unit_id",
    'Total' AS "square_footage_type",
    UNITS_."total_square_footage" AS "value",
    CAST(NULL AS date) AS "as_of_date",
    date '1900-01-01' as "_valid_from",
    COALESCE(FIRST_TOTAL_SQ_FT."FIRST_AS_OF_DATE", date '9999-12-31') as "_valid_to"
  FROM {{ source('app', 'units') }} UNITS_
  LEFT JOIN FIRST_TOTAL_SQ_FT
    ON FIRST_TOTAL_SQ_FT."unit_id" = UNITS_."id"
  WHERE UNITS_."deleted_at" IS NULL
),
ALL_UNIT_SQ_FT AS (
  SELECT *
  FROM BASE_UNIT_SQ_FT
  WHERE "_valid_from" < "_valid_to"

  UNION ALL

  SELECT *
  FROM UNIT_SQ_FT_ITEMS
  WHERE "_valid_from" < "_valid_to"
),
UNITS AS (
  SELECT 
    PROPS_."id" AS "PROP_ID",
    PROPS_."name" AS "PROP_NAME",
    PROPS_."company_relation_id" AS "company_relation_id",
    UNITS_."id" AS "UNIT_ID",
    UNITS_."name" AS "UNIT_NAME",
    UNITS_."total_square_footage" AS "UNIT_TOTAL_SQ_FT",
    UNITS_SF."square_footage_type" AS "UNIT_SF_TYPE",
    UNITS_SF."value" AS "UNIT_SF_VALUE",
    UNITS_SF."as_of_date" AS "UNIT_SF_ASOFDATE",
    GREATEST(
      UNITS_SF."_valid_from",
      date '1900-01-01'
    ) as "_valid_from",
    LEAST(
      UNITS_SF."_valid_to",
      COALESCE(CAST(UNITS_."deleted_at" AS date), date '9999-12-31'),
      COALESCE(CAST(PROPS_."deleted_at" AS date), date '9999-12-31')
    ) as "_valid_to"
  
  FROM {{ source('app', 'units') }} UNITS_
  INNER JOIN {{ source('app', 'properties') }} PROPS_
    ON UNITS_."property_id" = PROPS_."id"
  LEFT JOIN ALL_UNIT_SQ_FT UNITS_SF
    ON UNITS_SF."unit_id" = UNITS_."id"

  WHERE UNITS_SF."unit_id" IS NOT NULL
	  --AND UNITS_."status" = 'active'
)

select *
from UNITS
where "_valid_from" < "_valid_to"
