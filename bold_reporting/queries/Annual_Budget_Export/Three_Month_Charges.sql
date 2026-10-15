WITH RECURSIVE date_series AS (
    SELECT @AsOfDate::DATE as month
    UNION ALL
    SELECT (month + INTERVAL '1 month')::DATE
    FROM date_series
    WHERE month + INTERVAL '1 month' < (@AsOfDate + INTERVAL '12 month')::DATE
),
CHARGES_TOT AS (
    SELECT 
        "stg_lease_recurring_charges"."lease_id" AS "LEASE_ID",
  		"reporting"."stg_leases"."lease_name" AS "LEASE_NAME",
        "stg_lease_recurring_charge_amounts"."effective_date" AS "EFFECTIVE_DATE",
        "stg_lease_recurring_charge_amounts"."amount" AS "AMOUNT",
        "stg_lease_recurring_charges"."item_id" AS "ITEM_ID",
        "stg_units"."property_id" AS "PROP_ID",
  		"reporting"."stg_properties"."location_id" as "LOCATION_ID",
        "stg_lease_recurring_charges"."unit_id" AS "UNIT_ID",
  		"reporting"."stg_leases"."lease_end" AS "LEASE_END",
  		"stg_lease_recurring_charge_amounts"."frequency" AS "FREQUENCY",
  		"stg_lease_recurring_charges"."terminate_date" AS "RCHARGE_END",
  		"reporting"."stg_leases"."month_to_month_flag" AS "month_to_month" 
  
    FROM "reporting"."stg_lease_recurring_charges"
    INNER JOIN "reporting"."stg_lease_recurring_charge_amounts"
        ON "stg_lease_recurring_charges"."recurring_charge_id" = "stg_lease_recurring_charge_amounts"."recurring_charge_id"
    INNER JOIN "reporting"."stg_units"
        ON "stg_lease_recurring_charges"."unit_id" =  "stg_units"."unit_id"
    INNER JOIN "reporting"."stg_properties"
        ON "stg_units"."property_id" =  "stg_properties"."property_id"
  	INNER JOIN "reporting"."stg_leases" 
  		ON "stg_lease_recurring_charges"."lease_id" = "reporting"."stg_leases"."lease_id"
  
    WHERE "stg_lease_recurring_charge_amounts"."effective_date" <= (@AsOfDate + INTERVAL '12 month')
  		--AND "stg_lease_recurring_charge_amounts"."effective_date" >= (@AsOfDate)
        AND "stg_lease_recurring_charge_amounts"."deleted_at" IS NULL
        AND "stg_lease_recurring_charges"."deleted_at" IS NULL
        --AND ("stg_lease_recurring_charges"."terminate_date" >= (@AsOfDate + INTERVAL '12 month') OR "stg_lease_recurring_charges"."terminate_date" IS NULL)
  		AND ("stg_lease_recurring_charges"."terminate_date" >= @AsOfDate OR "stg_lease_recurring_charges"."terminate_date" IS NULL)
        AND "stg_lease_recurring_charges"."item_id" in (@Item_Id)
        AND "reporting"."stg_properties"."prop_name" IN (@Property_Name)
        AND CAST("reporting"."stg_properties"."company_relation_id" AS INT) = CAST(@REAL_COMPANY_ID AS INT)
  		AND ("stg_lease_recurring_charge_amounts"."effective_date" <= "reporting"."stg_leases"."lease_end"
			OR "reporting"."stg_leases"."lease_end" is NULL)
),
charged_amounts AS (
    SELECT
        ds."month",
        ct."LEASE_ID",
  		ct."LEASE_NAME",
        ct."EFFECTIVE_DATE",
        ct."AMOUNT" AS "AMOUNT_OLD",
  		-- proration in lease end calculation
  		CASE 
  				WHEN ct."FREQUENCY" = 'Annually' THEN ct."AMOUNT" / 12
  				WHEN ( EXTRACT(MONTH FROM ds."month") = EXTRACT(MONTH FROM ct."LEASE_END") 
				   			 AND EXTRACT(YEAR FROM ds."month") = EXTRACT(YEAR FROM ct."LEASE_END")  
					 		 AND 31 = EXTRACT(DAY FROM ct."LEASE_END") ) then ct."AMOUNT"
  				WHEN ( EXTRACT(MONTH FROM ds."month") = EXTRACT(MONTH FROM ct."LEASE_END") 
				   			 AND EXTRACT(YEAR FROM ds."month") = EXTRACT(YEAR FROM ct."LEASE_END") 
  							AND EXTRACT(MONTH FROM ct."LEASE_END") IN (4, 6, 9, 11) ) then ct."AMOUNT" * EXTRACT(DAY FROM ct."LEASE_END") / 30
  				WHEN ( EXTRACT(MONTH FROM ds."month") = EXTRACT(MONTH FROM ct."LEASE_END") 
				   			 AND EXTRACT(YEAR FROM ds."month") = EXTRACT(YEAR FROM ct."LEASE_END") 
  							AND EXTRACT(MONTH FROM ct."LEASE_END") IN (1, 3, 5, 7, 8, 10, 12) ) then ct."AMOUNT" * EXTRACT(DAY FROM ct."LEASE_END") / 31
  				WHEN ( EXTRACT(MONTH FROM ds."month") = EXTRACT(MONTH FROM ct."RCHARGE_END") 
				   			 AND EXTRACT(YEAR FROM ds."month") = EXTRACT(YEAR FROM ct."RCHARGE_END")
					 		 AND EXTRACT(MONTH FROM ct."RCHARGE_END") IN (4, 6, 9, 11) ) then ct."AMOUNT" * EXTRACT(DAY FROM ct."RCHARGE_END") / 30
  				WHEN ( EXTRACT(MONTH FROM ds."month") = EXTRACT(MONTH FROM ct."RCHARGE_END") 
				   			 AND EXTRACT(YEAR FROM ds."month") = EXTRACT(YEAR FROM ct."RCHARGE_END")
					 		 AND EXTRACT(MONTH FROM ct."RCHARGE_END") IN (1, 3, 5, 7, 8, 10, 12) ) then ct."AMOUNT" * EXTRACT(DAY FROM ct."RCHARGE_END") / 31
  				WHEN ( EXTRACT(MONTH FROM ds."month") = EXTRACT(MONTH FROM ct."EFFECTIVE_DATE") 
				   			 AND EXTRACT(YEAR FROM ds."month") = EXTRACT(YEAR FROM ct."EFFECTIVE_DATE")  
					 		 AND 1 = EXTRACT(DAY FROM ct."EFFECTIVE_DATE") ) then ct."AMOUNT"
				WHEN ( EXTRACT(MONTH FROM ds."month") = EXTRACT(MONTH FROM ct."EFFECTIVE_DATE") 
							AND EXTRACT(YEAR FROM ds."month") = EXTRACT(YEAR FROM ct."EFFECTIVE_DATE") 
					 		AND EXTRACT(MONTH FROM ct."EFFECTIVE_DATE") IN (1, 3, 5, 7, 8, 10, 12) ) then ct."AMOUNT" * (31-EXTRACT(DAY FROM ct."EFFECTIVE_DATE")+1) / 31	 --FALTA RELLENAR CON LOS DIAS CON EL EFFECTIVE DATE ANTERIOR  
  				WHEN ( EXTRACT(MONTH FROM ds."month") = EXTRACT(MONTH FROM ct."EFFECTIVE_DATE") 
							AND EXTRACT(YEAR FROM ds."month") = EXTRACT(YEAR FROM ct."EFFECTIVE_DATE") 
					 		AND EXTRACT(MONTH FROM ct."EFFECTIVE_DATE") IN (4, 6, 9, 11)  ) then ct."AMOUNT" * (30-EXTRACT(DAY FROM ct."EFFECTIVE_DATE")+1) / 30	 --FALTA RELLENAR CON LOS DIAS CON EL EFFECTIVE DATE ANTERIOR  
  				ELSE ct."AMOUNT"
  		END AS "AMOUNT",
  		--end proration in lease end
        ct."ITEM_ID",
        ct."PROP_ID",
  		ct."LOCATION_ID",
        ct."UNIT_ID",
        ROW_NUMBER() OVER (PARTITION BY ct."LEASE_ID", ct."ITEM_ID", ds."month" ORDER BY ct."EFFECTIVE_DATE" DESC) AS rn,
  		ct."LEASE_END" 
    FROM
        date_series ds
    CROSS JOIN CHARGES_TOT ct
    WHERE ds."month" >= ct."EFFECTIVE_DATE"
  		AND (ct."LEASE_END" >= ds."month" 
			 		OR ct."LEASE_END" IS NULL
			 		OR CAST(ct."month_to_month" AS TEXT) IN (@month_to_month)
			)
  		--AND (ct."RCHARGE_END" >= ds."month" or ct."RCHARGE_END" IS NULL)
  		AND (DATE_TRUNC('month', TO_DATE(TO_CHAR(ct."RCHARGE_END", 'MM/DD/YYYY'), 'MM/DD/YYYY')) >= DATE_TRUNC('month', TO_DATE(TO_CHAR(ds."month", 'MM/DD/YYYY'), 'MM/DD/YYYY'))  or ct."RCHARGE_END" IS NULL)
  
),
FINAL_TO_PIVOT AS (
    SELECT
        ds."month" as "TIME_STAMP",
        EXTRACT(MONTH FROM ds."month") AS "MONTH",
        EXTRACT(YEAR FROM ds."month") AS "YEAR",
        ca."LEASE_ID",
  		ca."LEASE_NAME",
        COALESCE(ca."AMOUNT", 0) AS "AMOUNT",
        ca."ITEM_ID",
        ca."PROP_ID",
  		ca."LOCATION_ID",
        ca."UNIT_ID"
    FROM
        date_series ds
    LEFT JOIN charged_amounts ca ON ds."month" = ca."month" AND ca.rn = 1
    ORDER BY ca."PROP_ID", ca."LEASE_ID", ca."ITEM_ID", ds."month"
)
 
SELECT
	'' AS "DONOTIMPORT",
	MIN("TIME_STAMP") AS "BUDGET_ID",
    fp."ITEM_ID" AS "order_entry_item_id",
	"reporting"."stg_properties"."department_id" AS "department_id",
	"reporting"."stg_properties"."property_id" AS "property_id",
	fp."LOCATION_ID" as "LOCATION_ID",
	"reporting"."stg_leases"."lease_id" AS "lease_id",
	"reporting"."stg_leases"."lease_name" AS "lease_name",
	"reporting"."stg_tenants"."external_tenant_id" AS "tenants_id",
	"reporting"."stg_tenants"."vendor_id" AS "vendor_id",
	fp."ITEM_ID" AS "item_id",
	"reporting"."stg_properties"."class_id" AS "class_id",
	ROUND(SUM(CASE WHEN DATE_TRUNC('month', @AsOfDate + INTERVAL '0 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END)::numeric, 2) AS "Month 1",
    TO_CHAR(@AsOfDate + INTERVAL '0 month', '"Month Ended "FMMonth YYYY') AS "month_1_full_name",
    ROUND(SUM(CASE WHEN DATE_TRUNC('month', @AsOfDate + INTERVAL '1 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END)::numeric, 2) AS "Month 2",
    TO_CHAR(@AsOfDate + INTERVAL '1 month', '"Month Ended "FMMonth YYYY') AS "month_2_full_name",
    ROUND(SUM(CASE WHEN DATE_TRUNC('month', @AsOfDate + INTERVAL '2 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END)::numeric, 2) AS "Month 3",
    TO_CHAR(@AsOfDate + INTERVAL '2 month', '"Month Ended "FMMonth YYYY') AS "month_3_full_name",
    ROUND(SUM(CASE WHEN DATE_TRUNC('month', @AsOfDate + INTERVAL '3 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END)::numeric, 2) AS "Month 4",
    TO_CHAR(@AsOfDate + INTERVAL '3 month', '"Month Ended "FMMonth YYYY') AS "month_4_full_name",
    ROUND(SUM(CASE WHEN DATE_TRUNC('month', @AsOfDate + INTERVAL '4 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END)::numeric, 2) AS "Month 5",
    TO_CHAR(@AsOfDate + INTERVAL '4 month', '"Month Ended "FMMonth YYYY') AS "month_5_full_name",
    ROUND(SUM(CASE WHEN DATE_TRUNC('month', @AsOfDate + INTERVAL '5 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END)::numeric, 2) AS "Month 6",
    TO_CHAR(@AsOfDate + INTERVAL '5 month', '"Month Ended "FMMonth YYYY') AS "month_6_full_name",
    ROUND(SUM(CASE WHEN DATE_TRUNC('month', @AsOfDate + INTERVAL '6 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END)::numeric, 2) AS "Month 7",
    TO_CHAR(@AsOfDate + INTERVAL '6 month', '"Month Ended "FMMonth YYYY') AS "month_7_full_name",
    ROUND(SUM(CASE WHEN DATE_TRUNC('month', @AsOfDate + INTERVAL '7 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END)::numeric, 2) AS "Month 8",
    TO_CHAR(@AsOfDate + INTERVAL '7 month', '"Month Ended "FMMonth YYYY') AS "month_8_full_name",
    ROUND(SUM(CASE WHEN DATE_TRUNC('month', @AsOfDate + INTERVAL '8 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END)::numeric, 2) AS "Month 9",
    TO_CHAR(@AsOfDate + INTERVAL '8 month', '"Month Ended "FMMonth YYYY') AS "month_9_full_name",
    ROUND(SUM(CASE WHEN DATE_TRUNC('month', @AsOfDate + INTERVAL '9 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END)::numeric, 2) AS "Month 10",
    TO_CHAR(@AsOfDate + INTERVAL '9 month', '"Month Ended "FMMonth YYYY') AS "month_10_full_name",
    ROUND(SUM(CASE WHEN DATE_TRUNC('month', @AsOfDate + INTERVAL '10 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END)::numeric, 2) AS "Month 11",
    TO_CHAR(@AsOfDate + INTERVAL '10 month', '"Month Ended "FMMonth YYYY') AS "month_11_full_name",
    ROUND(SUM(CASE WHEN DATE_TRUNC('month', @AsOfDate + INTERVAL '11 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END)::numeric, 2) AS "Month 12",
    TO_CHAR(@AsOfDate + INTERVAL '11 month', '"Month Ended "FMMonth YYYY') AS "month_12_full_name"
 	
FROM
    FINAL_TO_PIVOT as fp
INNER JOIN "reporting"."stg_leases" ON fp."LEASE_ID" = "reporting"."stg_leases"."lease_id"
INNER JOIN "reporting"."stg_tenants" ON "reporting"."stg_tenants"."tenant_id" = "reporting"."stg_leases"."primary_tenant_id"
INNER JOIN "reporting"."stg_properties" ON fp."PROP_ID" = "reporting"."stg_properties"."property_id"

WHERE CAST("reporting"."stg_leases"."month_to_month_flag" AS TEXT) IN (@month_to_month)
AND CAST("reporting"."stg_leases"."lease_raw_status" AS TEXT) IN (@Lease_Status)
	
GROUP BY 1,3,4,5,6,7,8,9,10,11,12
