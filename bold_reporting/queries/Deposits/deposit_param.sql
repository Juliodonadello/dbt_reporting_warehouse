SELECT "reporting"."stg_lease_deposits"."deposit_type" AS "type",
CASE WHEN "reporting"."stg_lease_deposits"."refundable" IS TRUE THEN 'YES' ELSE 'NO' END AS "REFUNDABLE"

FROM "reporting"."stg_lease_deposits"

WHERE CAST("reporting"."stg_lease_deposits"."company_relation_id" AS INT) = @REAL_COMPANY_ID

AND EXISTS (
    SELECT 1
    FROM "reporting"."stg_leases" l
    INNER JOIN "reporting"."stg_properties" p ON p.property_id = l.property_id
    WHERE l.lease_id = "reporting"."stg_lease_deposits"."lease_id"
      AND p.prop_name IN (@Property_Name)
      AND CAST(p.company_relation_id AS INT) = CAST(@REAL_COMPANY_ID AS INT)
)

group by 1,2