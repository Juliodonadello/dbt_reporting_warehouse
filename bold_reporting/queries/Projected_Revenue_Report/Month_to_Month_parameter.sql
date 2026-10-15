SELECT "reporting"."stg_leases"."month_to_month_flag" "M_t_M"

FROM "reporting"."stg_leases"
INNER  JOIN "reporting"."stg_lease_units" ON "reporting"."stg_leases"."lease_id"="reporting"."stg_lease_units"."lease_id"
INNER  JOIN "reporting"."stg_units" ON "reporting"."stg_units"."unit_id"="reporting"."stg_lease_units"."unit_id"
INNER  JOIN "reporting"."stg_properties" ON "reporting"."stg_units"."property_id"="reporting"."stg_properties"."property_id"

WHERE  CAST("reporting"."stg_properties"."company_relation_id" AS INT) = CAST(@REAL_COMPANY_ID AS INT)
    AND "reporting"."stg_properties"."prop_name" IN (@Property_Name)
    
GROUP BY "reporting"."stg_leases"."month_to_month_flag" 