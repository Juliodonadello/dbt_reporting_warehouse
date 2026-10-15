SELECT DISTINCT
  "reporting"."stg_leases"."lease_name" AS "LEASE_NAME"

FROM "reporting"."stg_leases"
INNER JOIN "reporting"."stg_properties"
  ON "reporting"."stg_properties"."property_id" = "reporting"."stg_leases"."property_id"
LEFT JOIN "reporting"."stg_rent_percentages"
  ON "reporting"."stg_leases"."lease_id" = "reporting"."stg_rent_percentages"."lease_id"

WHERE "reporting"."stg_properties"."prop_name" IN (@Property_Name)
  AND CAST("reporting"."stg_properties"."company_relation_id" AS TEXT) = CAST(@REAL_COMPANY_ID AS TEXT)
  AND "reporting"."stg_leases"."deleted_at" IS NULL
  AND "reporting"."stg_rent_percentages"."deleted_at" IS NULL
  --AND (("reporting"."stg_rent_percentages"."overage_start_date" < CAST(@asofdate AS DATE) AND "reporting"."stg_rent_percentages"."overage_end_date" > CAST(@asofdate AS DATE))
  --  OR ("reporting"."stg_rent_percentages"."overage_start_date" < CAST(@asofdate AS DATE) AND "reporting"."stg_rent_percentages"."overage_end_date" IS NULL))

ORDER BY "reporting"."stg_leases"."lease_name" ASC