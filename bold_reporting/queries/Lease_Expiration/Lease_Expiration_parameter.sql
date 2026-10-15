SELECT l.lease_raw_status AS "LEASE_STATUS"
FROM "reporting"."stg_leases" l
INNER JOIN "reporting"."stg_lease_units" lu ON l.lease_id = lu.lease_id
INNER JOIN "reporting"."stg_units" u ON u.unit_id = lu.unit_id
INNER JOIN "reporting"."stg_properties" p ON u.property_id = p.property_id
WHERE l.lease_end IS NOT NULL
  AND CAST(p.company_relation_id AS INT) = CAST(@REAL_COMPANY_ID AS INT)
  AND p.prop_name IN (@Property_Name)
GROUP BY l.lease_raw_status
