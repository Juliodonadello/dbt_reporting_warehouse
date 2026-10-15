SELECT
    CASE WHEN CAST(l.month_to_month_flag AS TEXT) = 'true' THEN 'True' ELSE 'False' END AS "M_t_M"
FROM "reporting"."stg_leases" l
INNER JOIN "reporting"."stg_lease_units" lu
    ON l.lease_id = lu.lease_id
INNER JOIN "reporting"."stg_units" u
    ON u.unit_id = lu.unit_id
INNER JOIN "reporting"."stg_properties" p
    ON u.property_id = p.property_id
WHERE p.company_relation_id = CAST(@REAL_COMPANY_ID AS INT)
  AND p.prop_name IN (@Property_Name)
GROUP BY
    l.month_to_month_flag;
