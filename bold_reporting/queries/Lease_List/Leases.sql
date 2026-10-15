SELECT l.lease_id AS "id",
       l.lease_name AS "name",
       l.lease_raw_status AS "status",
       l.lease_start AS "start",
       l.lease_end AS "end",
       u.unit_name AS "units_name",
       u.city,
       u.base_unit_sq_ft AS "total_square_footage",
       t.tenant_name AS "tenants_name",
       p.prop_name AS "properties_name"
FROM "reporting"."stg_leases" l
INNER JOIN "reporting"."stg_lease_units" lu ON l.lease_id = lu.lease_id
INNER JOIN "reporting"."stg_units" u ON u.unit_id = lu.unit_id
INNER JOIN "reporting"."stg_tenants" t ON t.tenant_id = l.primary_tenant_id
INNER JOIN "reporting"."stg_properties" p ON u.property_id = p.property_id
WHERE CAST(p.company_relation_id AS INT) = CAST(@REAL_COMPANY_ID AS INT)
  AND p.prop_name IN (@Property_Name)
  AND CAST(l.lease_raw_status AS TEXT) IN (@Lease_Status)
  AND l.lease_raw_status <> 'canceled'
