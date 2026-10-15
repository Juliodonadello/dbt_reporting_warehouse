SELECT
    p.entity_id AS "ENTITY_ID"
FROM "reporting"."stg_properties" p
WHERE p.company_relation_id = CAST(@REAL_COMPANY_ID AS INT)
GROUP BY
    p.entity_id
ORDER BY
    p.entity_id ASC;
