SELECT
    u.floor_plan AS "floorPlan"
FROM "reporting"."stg_units" u
INNER JOIN "reporting"."stg_properties" p
    ON u.property_id = p.property_id
WHERE p.company_relation_id = CAST(@REAL_COMPANY_ID AS INT)
  AND p.prop_name IN (@Property_Name)
GROUP BY
    1;
