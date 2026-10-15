SELECT i.insurance_id AS "id",
       i.deleted_at,
       i.insurance_type,
       i.company,
       i.policy_number,
       i.email_to,
       i.effective_date,
       i.expiration_date,
       i.insurance_value,
       i.lease_id,
       i.property_id,
       i.notification_date,
       i.email_cc,
       l.lease_name AS "name",
       l.lease_raw_status AS "status",
       lu.lease_id,
       lu.unit_id,
       u.unit_name AS "units_name",
       p.prop_name AS "property_name",
       t.tenant_name AS "primary_tenant_name"
FROM "reporting"."stg_insurances" i
INNER JOIN "reporting"."stg_leases" l ON i.lease_id = l.lease_id
INNER JOIN "reporting"."stg_lease_units" lu ON l.lease_id = lu.lease_id
INNER JOIN "reporting"."stg_units" u ON lu.unit_id = u.unit_id
INNER JOIN "reporting"."stg_properties" p ON l.property_id = p.property_id
INNER JOIN "reporting"."stg_tenants" t ON t.tenant_id = l.primary_tenant_id
WHERE CAST(p.company_relation_id AS INT) = CAST(@REAL_COMPANY_ID AS INT)
  AND (
      @ignore_end_date = true
      OR (
          @ignore_end_date = false
          AND i.expiration_date >= @FromDate
          AND i.expiration_date <= @To_Date
      )
  )
  AND CAST(l.lease_raw_status AS TEXT) IN (@Lease_Status)
  AND p.prop_name IN (@Property_Name)
  AND CAST(i.insurance_type AS TEXT) IN (@Insurance_Type)
  AND i.deleted_at IS NULL
  AND l.deleted_at IS NULL
