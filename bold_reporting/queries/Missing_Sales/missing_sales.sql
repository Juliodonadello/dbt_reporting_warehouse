WITH LEASES_SALES AS (
  SELECT 
    "reporting"."stg_leases"."lease_id" AS "LEASE_ID",
    "reporting"."stg_leases"."lease_name" AS "LEASE_NAME",
    "reporting"."stg_leases"."lease_start" AS "start",
    "reporting"."stg_leases"."lease_end" AS "lease_end",
    "reporting"."stg_rent_percentages"."overage_start_date" AS "overage_start_date",
    "reporting"."stg_rent_percentages"."overage_end_date" AS "overage_end_date",
    "reporting"."stg_rent_percentages"."months_frequency" AS "MONTHS_FRECUENCY",
    "reporting"."stg_rent_percentages"."item_id" AS "ITEM_ID",
    "reporting"."stg_rent_percentages"."sale_type" AS "TYPE_REQUIRED",
    "reporting"."stg_sales_entry"."transaction_date" AS "transaction_date",
    SUBSTRING(TO_CHAR("reporting"."stg_sales_entry"."transaction_date", 'Month'), 1, 3) AS "transaction_month",
    EXTRACT(YEAR FROM "reporting"."stg_sales_entry"."transaction_date") AS "transaction_year",
    "reporting"."stg_sales_entry"."sales_volume" AS "sales_volume",
    "reporting"."stg_lease_units"."unit_id" AS "UNIT_ID",  		
    "reporting"."stg_tenants"."tenant_name" AS "TENANT",
    "reporting"."stg_units"."unit_name" AS "UNIT_NAME",
    "reporting"."stg_units"."base_unit_sq_ft" AS "UNIT_SQ_FT",
    "reporting"."stg_properties"."prop_name" AS "PROP_NAME"

  FROM "reporting"."stg_leases"
  INNER JOIN "reporting"."stg_lease_units"
    ON "reporting"."stg_leases"."lease_id" = "reporting"."stg_lease_units"."lease_id"
  INNER JOIN "reporting"."stg_units"
    ON "reporting"."stg_units"."unit_id" = "reporting"."stg_lease_units"."unit_id"
  INNER JOIN "reporting"."stg_properties"
    ON "reporting"."stg_properties"."property_id" = "reporting"."stg_leases"."property_id"
  INNER JOIN "reporting"."stg_sales_entry"
    ON "reporting"."stg_leases"."lease_id" = "reporting"."stg_sales_entry"."lease_id"
  LEFT JOIN "reporting"."stg_rent_percentages"
    ON "reporting"."stg_leases"."lease_id" = "reporting"."stg_rent_percentages"."lease_id"
  LEFT OUTER JOIN "reporting"."stg_tenants"
    ON "reporting"."stg_leases"."primary_tenant_id" = "reporting"."stg_tenants"."tenant_id"
  WHERE  "reporting"."stg_properties"."prop_name" IN (@Property_Name)
    AND "reporting"."stg_leases"."lease_name" IN (@Lease_Name)
    AND CAST("reporting"."stg_properties"."company_relation_id" AS TEXT) = CAST(@REAL_COMPANY_ID AS TEXT)
    AND "reporting"."stg_leases"."deleted_at" IS NULL
    AND "reporting"."stg_sales_entry"."deleted_at" IS NULL
    AND "reporting"."stg_sales_entry"."transaction_date" >= (CAST(@asofdate AS DATE) - INTERVAL '12 months')
    AND "reporting"."stg_sales_entry"."transaction_date" < CAST(@asofdate AS DATE) + INTERVAL '1 day'
),
MONTH_SALES AS (
  SELECT 
    "LEASE_ID",
    "LEASE_NAME",
    "start",
    "lease_end",
    "overage_start_date",
    "overage_end_date",
    "MONTHS_FRECUENCY",
    "ITEM_ID",
    "TYPE_REQUIRED",
    "PROP_NAME",
    STRING_AGG(DISTINCT "UNIT_NAME"::TEXT, '/') AS "UNIT_NAME",
    MAX("UNIT_SQ_FT") AS "UNIT_SQ_FT",
    STRING_AGG(DISTINCT "TENANT", '/') AS "TENANT",
    SUM(CASE WHEN TO_CHAR("transaction_date", 'YYYY-MM') = TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '0 month', 'YYYY-MM') THEN "sales_volume" ELSE 0 END) AS "current_month",
    SUM(CASE WHEN TO_CHAR("transaction_date", 'YYYY-MM') = TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '1 month', 'YYYY-MM') THEN "sales_volume" ELSE 0 END) AS "previous_month_1",
    SUM(CASE WHEN TO_CHAR("transaction_date", 'YYYY-MM') = TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '2 months', 'YYYY-MM') THEN "sales_volume" ELSE 0 END) AS "previous_month_2",
    SUM(CASE WHEN TO_CHAR("transaction_date", 'YYYY-MM') = TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '3 months', 'YYYY-MM') THEN "sales_volume" ELSE 0 END) AS "previous_month_3",
    SUM(CASE WHEN TO_CHAR("transaction_date", 'YYYY-MM') = TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '4 months', 'YYYY-MM') THEN "sales_volume" ELSE 0 END) AS "previous_month_4",
    SUM(CASE WHEN TO_CHAR("transaction_date", 'YYYY-MM') = TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '5 months', 'YYYY-MM') THEN "sales_volume" ELSE 0 END) AS "previous_month_5",
    SUM(CASE WHEN TO_CHAR("transaction_date", 'YYYY-MM') = TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '6 months', 'YYYY-MM') THEN "sales_volume" ELSE 0 END) AS "previous_month_6",
    SUM(CASE WHEN TO_CHAR("transaction_date", 'YYYY-MM') = TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '7 months', 'YYYY-MM') THEN "sales_volume" ELSE 0 END) AS "previous_month_7",
    SUM(CASE WHEN TO_CHAR("transaction_date", 'YYYY-MM') = TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '8 months', 'YYYY-MM') THEN "sales_volume" ELSE 0 END) AS "previous_month_8",
    SUM(CASE WHEN TO_CHAR("transaction_date", 'YYYY-MM') = TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '9 months', 'YYYY-MM') THEN "sales_volume" ELSE 0 END) AS "previous_month_9",
    SUM(CASE WHEN TO_CHAR("transaction_date", 'YYYY-MM') = TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '10 months', 'YYYY-MM') THEN "sales_volume" ELSE 0 END) AS "previous_month_10",
    SUM(CASE WHEN TO_CHAR("transaction_date", 'YYYY-MM') = TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '11 months', 'YYYY-MM') THEN "sales_volume" ELSE 0 END) AS "previous_month_11",
    SUM(CASE WHEN TO_CHAR("transaction_date", 'YYYY-MM') = TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '12 months', 'YYYY-MM') THEN "sales_volume" ELSE 0 END) AS "previous_month_12",
    SUBSTRING(TO_CHAR(CAST(@asofdate AS DATE), 'Month'), 1, 3) AS "current_month_name",
    SUBSTRING(TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '1 month', 'Month'), 1, 3) AS "previous_month_1_name",
    SUBSTRING(TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '2 months', 'Month'), 1, 3) AS "previous_month_2_name",
    SUBSTRING(TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '3 months', 'Month'), 1, 3) AS "previous_month_3_name",
    SUBSTRING(TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '4 months', 'Month'), 1, 3) AS "previous_month_4_name",
    SUBSTRING(TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '5 months', 'Month'), 1, 3) AS "previous_month_5_name",
    SUBSTRING(TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '6 months', 'Month'), 1, 3) AS "previous_month_6_name",
    SUBSTRING(TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '7 months', 'Month'), 1, 3) AS "previous_month_7_name",
    SUBSTRING(TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '8 months', 'Month'), 1, 3) AS "previous_month_8_name",
    SUBSTRING(TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '9 months', 'Month'), 1, 3) AS "previous_month_9_name",
    SUBSTRING(TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '10 months', 'Month'), 1, 3) AS "previous_month_10_name",
    SUBSTRING(TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '11 months', 'Month'), 1, 3) AS "previous_month_11_name",
    SUBSTRING(TO_CHAR(CAST(@asofdate AS DATE) - INTERVAL '12 months', 'Month'), 1, 3) AS "previous_month_12_name",
    
    CAST(@asofdate AS DATE) AS "current_month_date",
    CAST(@asofdate AS DATE) - INTERVAL '1 month' AS "previous_month_1_date",
    CAST(@asofdate AS DATE) - INTERVAL '2 months' AS "previous_month_2_date",
    CAST(@asofdate AS DATE) - INTERVAL '3 months' AS "previous_month_3_date",
    CAST(@asofdate AS DATE) - INTERVAL '4 months' AS "previous_month_4_date",
    CAST(@asofdate AS DATE) - INTERVAL '5 months' AS "previous_month_5_date",
    CAST(@asofdate AS DATE) - INTERVAL '6 months' AS "previous_month_6_date",
    CAST(@asofdate AS DATE) - INTERVAL '7 months' AS "previous_month_7_date",
    CAST(@asofdate AS DATE) - INTERVAL '8 months' AS "previous_month_8_date",
    CAST(@asofdate AS DATE) - INTERVAL '9 months' AS "previous_month_9_date",
    CAST(@asofdate AS DATE) - INTERVAL '10 months' AS "previous_month_10_date",
    CAST(@asofdate AS DATE) - INTERVAL '11 months' AS "previous_month_11_date",
    CAST(@asofdate AS DATE) - INTERVAL '12 months' AS "previous_month_12_date"


  FROM LEASES_SALES
  GROUP BY 
    "LEASE_ID",
    "LEASE_NAME",
    "start",
    "lease_end",
    "overage_start_date",
    "overage_end_date",
    "MONTHS_FRECUENCY",
    "ITEM_ID",
    "TYPE_REQUIRED",
    "PROP_NAME"
)
SELECT 
"LEASE_ID",
"LEASE_NAME",
"start",
"lease_end",
"overage_start_date",
"overage_end_date",
"MONTHS_FRECUENCY",
"ITEM_ID",
"TYPE_REQUIRED",
"PROP_NAME",
"UNIT_NAME",
"UNIT_SQ_FT",
"TENANT",
"current_month_name","previous_month_1_name","previous_month_2_name","previous_month_3_name","previous_month_4_name","previous_month_5_name","previous_month_6_name",
"previous_month_7_name","previous_month_8_name", "previous_month_9_name","previous_month_10_name","previous_month_11_name","previous_month_12_name",
CASE WHEN "current_month_date" < ("overage_start_date" + INTERVAL '1 day') OR "current_month_date" > "overage_end_date" THEN '   ' --Not Required
      WHEN "current_month_date" >= "overage_start_date" AND "current_month_date" <= "overage_end_date" AND "current_month" > 0 THEN 'CER' -- Sales Registered
      WHEN "current_month_date" >= "overage_start_date" AND "current_month_date" <= "overage_end_date" AND ("current_month" = 0 or "current_month" is null) THEN ' * ' -- Sales missing
      ELSE 'Not_end' --Not configured
END AS "status_current_month",
CASE WHEN "previous_month_1_date" < ("overage_start_date" + INTERVAL '1 day') OR "previous_month_1_date" > "overage_end_date" THEN '   ' --Not Required
      WHEN "previous_month_1_date" >= "overage_start_date" AND "previous_month_1_date" <= "overage_end_date" AND "previous_month_1" > 0 THEN 'CER' -- Sales Registered
      WHEN "previous_month_1_date" >= "overage_start_date" AND "previous_month_1_date" <= "overage_end_date" AND ("previous_month_1" = 0 or "previous_month_1" is null) THEN ' * ' -- Sales missing
      ELSE 'Not_end' --Not configured
END AS "status_previous_month_1",
CASE WHEN "previous_month_2_date" < ("overage_start_date" + INTERVAL '1 day') OR "previous_month_2_date" > "overage_end_date" THEN '   ' --Not Required
      WHEN "previous_month_2_date" >= "overage_start_date" AND "previous_month_2_date" <= "overage_end_date" AND "previous_month_2" > 0 THEN 'CER' -- Sales Registered
      WHEN "previous_month_2_date" >= "overage_start_date" AND "previous_month_2_date" <= "overage_end_date" AND ("previous_month_2" = 0 or "previous_month_2" is null) THEN ' * ' -- Sales missing
      ELSE 'Not_end' --Not configured
END AS "status_previous_month_2",
CASE WHEN "previous_month_3_date" < ("overage_start_date" + INTERVAL '1 day') OR "previous_month_3_date" > "overage_end_date" THEN '   ' --Not Required
      WHEN "previous_month_3_date" >= "overage_start_date" AND "previous_month_3_date" <= "overage_end_date" AND "previous_month_3" > 0 THEN 'CER' -- Sales Registered
      WHEN "previous_month_3_date" >= "overage_start_date" AND "previous_month_3_date" <= "overage_end_date" AND ("previous_month_3" = 0 or "previous_month_3" is null) THEN ' * ' -- Sales missing
      ELSE 'Not_end' --Not configured
END AS "status_previous_month_3",
CASE WHEN "previous_month_4_date" < ("overage_start_date" + INTERVAL '1 day') OR "previous_month_4_date" > "overage_end_date" THEN '   ' --Not Required
      WHEN "previous_month_4_date" >= "overage_start_date" AND "previous_month_4_date" <= "overage_end_date" AND "previous_month_4" > 0 THEN 'CER' -- Sales Registered
      WHEN "previous_month_4_date" >= "overage_start_date" AND "previous_month_4_date" <= "overage_end_date" AND ("previous_month_4" = 0 or "previous_month_4" is null) THEN ' * ' -- Sales missing
      ELSE 'Not_end' --Not configured
END AS "status_previous_month_4",
CASE WHEN "previous_month_5_date" < ("overage_start_date" + INTERVAL '1 day') OR "previous_month_5_date" > "overage_end_date" THEN '   ' --Not Required
      WHEN "previous_month_5_date" >= "overage_start_date" AND "previous_month_5_date" <= "overage_end_date" AND "previous_month_5" > 0 THEN 'CER' -- Sales Registered
      WHEN "previous_month_5_date" >= "overage_start_date" AND "previous_month_5_date" <= "overage_end_date" AND ("previous_month_5" = 0 or "previous_month_5" is null) THEN ' * ' -- Sales missing
      ELSE 'Not_end' --Not configured
END AS "status_previous_month_5",
CASE WHEN "previous_month_6_date" < ("overage_start_date" + INTERVAL '1 day') OR "previous_month_6_date" > "overage_end_date" THEN '   ' --Not Required
      WHEN "previous_month_6_date" >= "overage_start_date" AND "previous_month_6_date" <= "overage_end_date" AND "previous_month_6" > 0 THEN 'CER' -- Sales Registered
      WHEN "previous_month_6_date" >= "overage_start_date" AND "previous_month_6_date" <= "overage_end_date" AND ("previous_month_6" = 0 or "previous_month_6" is null) THEN ' * ' -- Sales missing
      ELSE 'Not_end' --Not configured
END AS "status_previous_month_6",
CASE WHEN "previous_month_7_date" < ("overage_start_date" + INTERVAL '1 day') OR "previous_month_7_date" > "overage_end_date" THEN '   ' --Not Required
      WHEN "previous_month_7_date" >= "overage_start_date" AND "previous_month_7_date" <= "overage_end_date" AND "previous_month_7" > 0 THEN 'CER' -- Sales Registered
      WHEN "previous_month_7_date" >= "overage_start_date" AND "previous_month_7_date" <= "overage_end_date" AND ("previous_month_7" = 0 or "previous_month_7" is null) THEN ' * ' -- Sales missing
      ELSE 'Not_end' --Not configured
END AS "status_previous_month_7",
CASE WHEN "previous_month_8_date" < ("overage_start_date" + INTERVAL '1 day') OR "previous_month_8_date" > "overage_end_date" THEN '   ' --Not Required
      WHEN "previous_month_8_date" >= "overage_start_date" AND "previous_month_8_date" <= "overage_end_date" AND "previous_month_8" > 0 THEN 'CER' -- Sales Registered
      WHEN "previous_month_8_date" >= "overage_start_date" AND "previous_month_8_date" <= "overage_end_date" AND ("previous_month_8" = 0 or "previous_month_8" is null) THEN ' * ' -- Sales missing
      ELSE 'Not_end' --Not configured
END AS "status_previous_month_8",
CASE WHEN "previous_month_9_date" < ("overage_start_date" + INTERVAL '1 day') OR "previous_month_9_date" > "overage_end_date" THEN '   ' --Not Required
      WHEN "previous_month_9_date" >= "overage_start_date" AND "previous_month_9_date" <= "overage_end_date" AND "previous_month_9" > 0 THEN 'CER' -- Sales Registered
      WHEN "previous_month_9_date" >= "overage_start_date" AND "previous_month_9_date" <= "overage_end_date" AND ("previous_month_9" = 0 or "previous_month_9" is null) THEN ' * ' -- Sales missing
      ELSE 'Not_end' --Not configured
END AS "status_previous_month_9",
CASE WHEN "previous_month_10_date" < ("overage_start_date" + INTERVAL '1 day') OR "previous_month_10_date" > "overage_end_date" THEN '   ' --Not Required
      WHEN "previous_month_10_date" >= "overage_start_date" AND "previous_month_10_date" <= "overage_end_date" AND "previous_month_10" > 0 THEN 'CER' -- Sales Registered
      WHEN "previous_month_10_date" >= "overage_start_date" AND "previous_month_10_date" <= "overage_end_date" AND ("previous_month_10" = 0 or "previous_month_10" is null) THEN ' * ' -- Sales missing
      ELSE 'Not_end' --Not configured
END AS "status_previous_month_10",
CASE WHEN "previous_month_11_date" < ("overage_start_date" + INTERVAL '1 day') OR "previous_month_11_date" > "overage_end_date" THEN '   ' --Not Required
      WHEN "previous_month_11_date" >= "overage_start_date" AND "previous_month_11_date" <= "overage_end_date" AND "previous_month_11" > 0 THEN 'CER' -- Sales Registered
      WHEN "previous_month_11_date" >= "overage_start_date" AND "previous_month_11_date" <= "overage_end_date" AND ("previous_month_11" = 0 or "previous_month_11" is null) THEN ' * ' -- Sales missing
      ELSE 'Not_end' --Not configured
END AS "status_previous_month_11",
CASE WHEN "previous_month_12_date" < ("overage_start_date" + INTERVAL '1 day') OR "previous_month_12_date" > "overage_end_date" THEN '   ' --Not Required
      WHEN "previous_month_12_date" >= "overage_start_date" AND "previous_month_12_date" <= "overage_end_date" AND "previous_month_12" > 0 THEN 'CER' -- Sales Registered
      WHEN "previous_month_12_date" >= "overage_start_date" AND "previous_month_12_date" <= "overage_end_date" AND ("previous_month_12" = 0 or "previous_month_12" is null) THEN ' * ' -- Sales missing
      ELSE 'Not_end' --Not configured
END AS "status_previous_month_12",

"current_month",
"previous_month_1",
"previous_month_2",
"previous_month_3",
"previous_month_4",
"previous_month_5",
"previous_month_6",
"previous_month_7",
"previous_month_8",
"previous_month_9",
"previous_month_10",
"previous_month_11",
"previous_month_12"




FROM MONTH_SALES

