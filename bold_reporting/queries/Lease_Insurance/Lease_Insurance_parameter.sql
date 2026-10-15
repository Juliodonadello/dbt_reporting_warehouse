SELECT i.insurance_type
FROM "reporting"."stg_insurances" i
INNER JOIN "reporting"."stg_leases" l ON i.lease_id = l.lease_id
INNER JOIN "reporting"."stg_lease_units" lu ON l.lease_id = lu.lease_id
INNER JOIN "reporting"."stg_units" u ON lu.unit_id = u.unit_id
INNER JOIN "reporting"."stg_properties" p ON l.property_id = p.property_id
INNER JOIN "reporting"."stg_tenants" t ON t.tenant_id = l.primary_tenant_id
WHERE CAST(p.company_relation_id AS INT) = CAST(@REAL_COMPANY_ID AS INT)
  AND i.expiration_date >= @FromDate
  AND i.expiration_date <= @To_Date
  AND CAST(l.lease_raw_status AS TEXT) IN (@Lease_Status)
  AND p.prop_name IN (@Property_Name)
  AND i.deleted_at IS NULL
  AND l.deleted_at IS NULL
GROUP BY i.insurance_type
ORDER BY i.insurance_type ASC
