SELECT p.entity_id AS "ENTITY_ID"
FROM "reporting"."stg_properties" p
WHERE CAST(p.company_relation_id AS INT) = CAST(@REAL_COMPANY_ID AS INT)
  AND p.deleted_at IS NULL
GROUP BY p.entity_id
ORDER BY p.entity_id ASC
