SELECT
    p.prop_name AS "PROP_NAME"
FROM "reporting"."stg_properties" p
WHERE p.company_relation_id = CAST(@REAL_COMPANY_ID AS INT)
  AND p.entity_id IN (@Entity_Id)
GROUP BY
    p.prop_name
ORDER BY
    p.prop_name ASC;
