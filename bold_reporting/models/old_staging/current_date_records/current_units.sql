WITH UNITS AS (
  SELECT
    UNITS_SF."PROP_ID" AS "PROP_ID",
    UNITS_SF."PROP_NAME" AS "PROP_NAME",
    UNITS_SF."UNIT_ID" AS "UNIT_ID",
    UNITS_SF."UNIT_NAME" AS "UNIT_NAME",
    UNITS_SF."company_relation_id" AS "company_relation_id",
    MAX(COALESCE(UNITS_SF."UNIT_SF_VALUE", UNITS_SF."UNIT_TOTAL_SQ_FT")) AS "UNIT_SQ_FT",
    MIN(UNITS_SF."_valid_from") AS "_valid_from",
    MAX(UNITS_SF."_valid_to") AS "_valid_to"

  FROM {{ ref('3_all_units_sqft') }} UNITS_SF

  WHERE CURRENT_DATE >= UNITS_SF."_valid_from"
    AND CURRENT_DATE < UNITS_SF."_valid_to"
    AND UNITS_SF."UNIT_SF_TYPE" = 'Total'
    --AND PROPS_."name" IN (@Property_Name)
    --AND CAST(PROPS_."company_relation_id" AS INT) = CAST(@REAL_COMPANY_ID AS INT)
	  --AND UNITS_."status" = 'active'

  GROUP BY
    UNITS_SF."PROP_ID",
    UNITS_SF."PROP_NAME",
    UNITS_SF."UNIT_ID",
    UNITS_SF."UNIT_NAME",
    UNITS_SF."company_relation_id"
)

select *
from UNITS AS A

--WHERE A."company_relation_id" = (SELECT COMPANY_ACCOUNTS.id
--                      FROM {{ var('company_accounts') }} AS COMPANY_ACCOUNTS
--                      WHERE (COMPANY_ACCOUNTS.db_user = (CURRENT_USER)::text))
