WITH SQ_FT_TEMP AS
(
    SELECT p.property_id AS "PROP_ID",
           SUM(u.base_unit_sq_ft) AS "TOT_SQ_FT"
    FROM "reporting"."stg_units" u
    INNER JOIN "reporting"."stg_properties" p ON u.property_id = p.property_id
    WHERE u.deleted_at IS NULL
      AND p.deleted_at IS NULL
    GROUP BY p.property_id
)
SELECT l.lease_id AS "id",
       l.lease_name AS "name",
       l.lease_raw_status AS "status",
       l.lease_end AS "end",
       lu.lease_id,
       lu.unit_id,
       u.unit_id AS "units_id",
       u.unit_name AS "units_name",
       u.city,
       u.base_unit_sq_ft AS "total_square_footage",
       t.tenant_id AS "tenants_id",
       t.tenant_name AS "tenants_name",
       p.property_id AS "properties_id",
       p.prop_name AS "properties_name",
       DATE_PART('year', l.lease_end) AS "EndDate_YEAR",
       SQ_FT_TEMP."TOT_SQ_FT" AS "TOT_SQ_FT"
FROM "reporting"."stg_leases" l
INNER JOIN "reporting"."stg_lease_units" lu ON l.lease_id = lu.lease_id
INNER JOIN "reporting"."stg_units" u ON u.unit_id = lu.unit_id
INNER JOIN "reporting"."stg_tenants" t ON t.tenant_id = l.primary_tenant_id
INNER JOIN "reporting"."stg_properties" p ON u.property_id = p.property_id
INNER JOIN SQ_FT_TEMP ON p.property_id = SQ_FT_TEMP."PROP_ID"
WHERE l.lease_end IS NOT NULL
  AND l.lease_raw_status <> 'canceled'
  AND CAST(p.company_relation_id AS INT) = CAST(@REAL_COMPANY_ID AS INT)
  AND p.prop_name IN (@Property_Name)
