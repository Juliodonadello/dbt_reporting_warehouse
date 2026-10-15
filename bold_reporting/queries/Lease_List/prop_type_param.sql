SELECT DISTINCT p.property_type AS "PROP_TYPE"
FROM "reporting"."stg_properties" p
WHERE CAST(p.company_relation_id AS INT) = CAST(@REAL_COMPANY_ID AS INT)
  AND p.deleted_at IS NULL
  AND p.entity_id IN (@Entity_Id)
  AND p.property_status = 'Active'
ORDER BY p.property_type ASC
