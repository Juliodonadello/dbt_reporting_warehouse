WITH UNITS AS (
    SELECT
        p.property_id AS "PROP_ID",
        p.prop_name AS "PROP_NAME",
        u.unit_id AS "UNIT_ID",
        u.unit_name AS "UNIT_NAME",
        usq.square_footage_type AS "SQ_FT_TYPE",
        u.unit_class AS "UNIT_CLASS"
    FROM "reporting"."stg_units" u
    INNER JOIN "reporting"."stg_properties" p
        ON u.property_id = p.property_id
    LEFT JOIN "reporting"."stg_unit_square_footage_items" usq
        ON usq.unit_id = u.unit_id
    WHERE p.company_relation_id = CAST(@REAL_COMPANY_ID AS INT)
      AND p.prop_name IN (@Property_Name)
    GROUP BY
        p.property_id,
        p.prop_name,
        u.unit_id,
        u.unit_name,
        usq.square_footage_type,
        u.unit_class
)

SELECT
    "SQ_FT_TYPE",
    "UNIT_CLASS"
FROM UNITS
GROUP BY
    "SQ_FT_TYPE",
    "UNIT_CLASS";
