WITH SQ_FT_TEMP AS
(
    SELECT p.property_id AS "PROP_ID",
           SUM(u.base_unit_sq_ft) AS "TOT_SQ_FT"
    FROM "reporting"."stg_units" u
    INNER JOIN "reporting"."stg_properties" p ON u.property_id = p.property_id
    WHERE u.deleted_at IS NULL
      AND p.deleted_at IS NULL
      AND p.property_status = 'Active'
    GROUP BY p.property_id
)
SELECT p.prop_name AS "PROP_NAME",
       MAX(SQ_FT_TEMP."TOT_SQ_FT") AS "TOT_SQ_FT"
FROM "reporting"."stg_properties" p
INNER JOIN SQ_FT_TEMP ON p.property_id = SQ_FT_TEMP."PROP_ID"
WHERE CAST(p.company_relation_id AS INT) = CAST(@REAL_COMPANY_ID AS INT)
  AND p.deleted_at IS NULL
  AND p.entity_id IN (@Entity_Id)
GROUP BY p.prop_name
ORDER BY p.prop_name ASC
