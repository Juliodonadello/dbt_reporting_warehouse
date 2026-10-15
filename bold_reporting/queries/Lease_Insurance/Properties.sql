SELECT p.prop_name AS "PROP_NAME"
FROM "reporting"."stg_properties" p
WHERE CAST(p.company_relation_id AS INT) = CAST(@REAL_COMPANY_ID AS INT)
  AND p.entity_id IN (@Entity_Id)
  AND p.property_status = 'Active'
GROUP BY p.prop_name
ORDER BY p.prop_name ASC
