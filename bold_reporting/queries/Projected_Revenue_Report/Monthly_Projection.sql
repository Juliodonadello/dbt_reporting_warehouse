WITH date_series AS (
    SELECT generate_series(
                   @From_Date::DATE - INTERVAL '1 month',
                   @To_Date::DATE,
                   INTERVAL '1 month'
           )::DATE AS month
),
CHARGES_TOT AS MATERIALIZED (
    SELECT 
        "reporting"."stg_lease_recurring_charges"."lease_id" AS "LEASE_ID",
        "reporting"."stg_lease_recurring_charge_amounts"."effective_date" AS "EFFECTIVE_DATE",
        "reporting"."stg_lease_recurring_charge_amounts"."amount" AS "AMOUNT",
        "reporting"."stg_lease_recurring_charges"."item_id" AS "ITEM_ID",
		"reporting"."stg_units"."property_id" AS "PROP_ID",
        "reporting"."stg_lease_recurring_charges"."unit_id" AS "UNIT_ID",
		COALESCE("reporting"."stg_lease_units"."move_in", "reporting"."stg_leases"."lease_start") AS "LEASE_MOVE_IN",
  		"reporting"."stg_leases"."lease_end" AS "LEASE_END",
		"reporting"."stg_leases"."lease_termination" AS "LEASE_TERMINATION",
		"reporting"."stg_leases"."lease_raw_status" AS "LEASE_STATUS",
		"reporting"."stg_leases"."month_to_month_flag" AS "MONTH_TO_MONTH",
  		"reporting"."stg_lease_recurring_charge_amounts"."frequency" AS "FREQUENCY", 
  		"reporting"."stg_lease_recurring_charges"."terminate_date" AS "RCHARGE_END"
  
    FROM "reporting"."stg_lease_recurring_charges"
    INNER JOIN "reporting"."stg_lease_recurring_charge_amounts"
        ON "reporting"."stg_lease_recurring_charges"."recurring_charge_id" = "reporting"."stg_lease_recurring_charge_amounts"."recurring_charge_id"
    INNER JOIN "reporting"."stg_units"
        ON "reporting"."stg_lease_recurring_charges"."unit_id" =  "reporting"."stg_units"."unit_id"
    INNER JOIN "reporting"."stg_properties"
        ON "reporting"."stg_units"."property_id" =  "reporting"."stg_properties"."property_id"
  	INNER JOIN "reporting"."stg_leases" 
  		ON "reporting"."stg_lease_recurring_charges"."lease_id" = "reporting"."stg_leases"."lease_id"
	INNER JOIN "reporting"."stg_lease_units"
		ON "reporting"."stg_leases"."lease_id" = "reporting"."stg_lease_units"."lease_id"
		AND "reporting"."stg_lease_recurring_charges"."unit_id" = "reporting"."stg_lease_units"."unit_id"
  
    WHERE "reporting"."stg_lease_recurring_charge_amounts"."effective_date" <= @To_Date
        AND "reporting"."stg_lease_recurring_charge_amounts"."deleted_at" IS NULL
        AND "reporting"."stg_lease_recurring_charges"."deleted_at" IS NULL
        AND "reporting"."stg_lease_recurring_charges"."item_id" in (@Item_Id)
        AND "reporting"."stg_properties"."prop_name" IN (@Property_Name)
        AND CAST("reporting"."stg_properties"."company_relation_id" AS INT) = CAST(@REAL_COMPANY_ID AS INT)
  		AND ("reporting"."stg_lease_recurring_charge_amounts"."effective_date" <= "reporting"."stg_leases"."lease_end" OR "reporting"."stg_leases"."lease_end" is NULL)
),
charged_amounts AS (
    SELECT
        ds."month",
        ct."LEASE_ID",
        ct."EFFECTIVE_DATE",
  		-- Full monthly rate, before proration, for the next month's calculation.
        CASE WHEN ct."FREQUENCY" = 'Annually' THEN ct."AMOUNT" / 12
             ELSE ct."AMOUNT"
        END AS "AMOUNT_OLD",
  		-- proration in lease end calculation
  		CASE 
  				WHEN ct."FREQUENCY" = 'Annually' THEN ct."AMOUNT" / 12
				-- Use the actual number of days in the lease-end month, including February and leap years.
				WHEN DATE_TRUNC('month', ds."month") = DATE_TRUNC('month', ct."LEASE_END")
					THEN ct."AMOUNT" * EXTRACT(DAY FROM ct."LEASE_END")
						/ EXTRACT(DAY FROM (DATE_TRUNC('month', ct."LEASE_END") + INTERVAL '1 month - 1 day'))
				-- Apply the same dynamic month length when the recurring charge terminates.
				WHEN DATE_TRUNC('month', ds."month") = DATE_TRUNC('month', ct."RCHARGE_END")
					THEN ct."AMOUNT" * EXTRACT(DAY FROM ct."RCHARGE_END")
						/ EXTRACT(DAY FROM (DATE_TRUNC('month', ct."RCHARGE_END") + INTERVAL '1 month - 1 day'))
                  -- Use actual days in the projected month, including leap-year February.
                WHEN DATE_TRUNC('month', ds."month") = DATE_TRUNC('month', ct."EFFECTIVE_DATE")
                    THEN ct."AMOUNT"
                        * (EXTRACT(DAY FROM (DATE_TRUNC('month', ds."month") + INTERVAL '1 month - 1 day'))
                           - EXTRACT(DAY FROM ct."EFFECTIVE_DATE") + 1)
                        / EXTRACT(DAY FROM (DATE_TRUNC('month', ds."month") + INTERVAL '1 month - 1 day'))
  				ELSE ct."AMOUNT"
  		END AS "AMOUNT",
  		--end proration in lease end
        ct."ITEM_ID",
        ct."PROP_ID",
        ct."UNIT_ID",
        ROW_NUMBER() OVER (
            PARTITION BY ct."LEASE_ID", ct."ITEM_ID", ct."UNIT_ID", ds."month"
            ORDER BY ct."EFFECTIVE_DATE" DESC
        ) AS "rn",
  		ct."LEASE_END" 
    FROM
        date_series ds
    CROSS JOIN CHARGES_TOT ct
    WHERE 
  		(
  		(ct."FREQUENCY" <> 'One Time' AND EXTRACT(YEAR FROM ds."month")*100+EXTRACT(MONTH FROM ds."month") >= EXTRACT(YEAR FROM ct."EFFECTIVE_DATE")*100+EXTRACT(MONTH FROM ct."EFFECTIVE_DATE"))
		  OR
		(ct."FREQUENCY" = 'One Time' AND EXTRACT(YEAR FROM ds."month")*100+EXTRACT(MONTH FROM ds."month") = EXTRACT(YEAR FROM ct."EFFECTIVE_DATE")*100+EXTRACT(MONTH FROM ct."EFFECTIVE_DATE"))
		 )
		AND
		(
			(
				@ignore_end_date = true
				AND ct."LEASE_STATUS" = 'current'
				AND ct."LEASE_MOVE_IN" <= ds."month"
			)
			OR
			(
				@ignore_end_date = false
				AND ct."LEASE_MOVE_IN" <= ds."month"
				AND
				(
					(
						CAST(ct."MONTH_TO_MONTH" AS TEXT) = 'true'
						AND
						(
							ct."LEASE_TERMINATION" IS NULL
							OR ct."LEASE_TERMINATION" > ds."month"
						)
					)
					OR ct."LEASE_END" IS NULL
					OR ct."LEASE_END" > ds."month"
				)
			)
		)
  		AND (ct."RCHARGE_END" >= ds."month" or ct."RCHARGE_END" is null)
),
latest_charge_per_unit AS (
    SELECT
        ca."month",
        ca."LEASE_ID",
        ca."EFFECTIVE_DATE",
        ca."ITEM_ID",
        ca."PROP_ID",
        ca."UNIT_ID",
		ca."LEASE_END",
		ca."rn",
		ca."AMOUNT_OLD",
		ca."AMOUNT"
  		
	FROM charged_amounts AS ca
	WHERE ca."rn" = 1
	
), 
charged_amounts_with_prev AS (
    SELECT
        ca."month",
        ca."LEASE_ID",
        ca."EFFECTIVE_DATE",
        ca."ITEM_ID",
        ca."PROP_ID",
        ca."UNIT_ID",
        ca."LEASE_END",
  		ca."rn",
        ca."AMOUNT",
        LAG(ca."AMOUNT_OLD") OVER (
            PARTITION BY ca."LEASE_ID", ca."ITEM_ID", ca."UNIT_ID"
            ORDER BY ca."month"
        ) AS "AMOUNT_OLD"
    FROM latest_charge_per_unit ca
),
final_ca as (
select charged_amounts_with_prev.*,
CASE WHEN ( EXTRACT(MONTH FROM "month") = EXTRACT(MONTH FROM "EFFECTIVE_DATE") 
						AND EXTRACT(YEAR FROM "month") = EXTRACT(YEAR FROM "EFFECTIVE_DATE") 
                        AND '1' != EXTRACT(DAY FROM "EFFECTIVE_DATE")
  						AND ("AMOUNT_OLD" IS NULL) ) 
			then  "AMOUNT" 								-- proration for first effective date in the charge 
  		 WHEN ( EXTRACT(MONTH FROM "month") = EXTRACT(MONTH FROM "EFFECTIVE_DATE") 
						AND EXTRACT(YEAR FROM "month") = EXTRACT(YEAR FROM "EFFECTIVE_DATE") 
                        AND '1' != EXTRACT(DAY FROM "EFFECTIVE_DATE") ) 
			then "AMOUNT" + (
                "AMOUNT_OLD" * (EXTRACT(DAY FROM "EFFECTIVE_DATE") - 1)
                / EXTRACT(DAY FROM (DATE_TRUNC('month', "month") + INTERVAL '1 month - 1 day'))
            ) -- Both portions use the same month's day count.
			ELSE "AMOUNT"
			END AS "PRORATED_AMOUNT"
from charged_amounts_with_prev
where charged_amounts_with_prev."rn" = 1 and "month" >= @From_Date
),
charged_amounts_2 AS (
	SELECT  charged_amounts."month",
        charged_amounts."LEASE_ID",
        charged_amounts."EFFECTIVE_DATE",
        charged_amounts."ITEM_ID",
        charged_amounts."PROP_ID",
  		charged_amounts."LEASE_END",
  		SUM(charged_amounts."AMOUNT") "AMOUNT_OLD",
  		SUM(charged_amounts."PRORATED_AMOUNT") "AMOUNT"
		
	FROM final_ca as charged_amounts
  	GROUP BY 1,2,3,4,5,6
  	ORDER BY 1
),
FINAL_TO_PIVOT AS (
    SELECT
        ds."month" as "TIME_STAMP",
        EXTRACT(MONTH FROM ds."month") AS "MONTH",
        EXTRACT(YEAR FROM ds."month") AS "YEAR",
        ca."LEASE_ID",
        COALESCE(ca."AMOUNT", 0) AS "AMOUNT",
        ca."ITEM_ID",
        ca."PROP_ID"
        --        ca."UNIT_ID"
    FROM date_series ds
    LEFT JOIN charged_amounts_2 ca 
  		ON ds."month" = ca."month" --AND ca."rn" = 1
    ORDER BY ca."PROP_ID", ca."LEASE_ID", ca."ITEM_ID", ds."month"
)
SELECT
    fp."ITEM_ID",
    "reporting"."stg_leases"."lease_name" AS "name",
    "reporting"."stg_leases"."lease_start" AS "start",
    "reporting"."stg_leases"."lease_end" AS "end",
    "reporting"."stg_tenants"."tenant_name" AS "tenants_name",
    "reporting"."stg_properties"."prop_name" AS "property_name",
    SUM(CASE WHEN DATE_TRUNC('month', @From_Date + INTERVAL '0 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END) AS "Month 1",
    TO_CHAR(@From_Date + INTERVAL '0 month', 'Mon, YY') AS "month_1_name",
    SUM(CASE WHEN DATE_TRUNC('month', @From_Date + INTERVAL '1 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END) AS "Month 2",
    TO_CHAR(@From_Date + INTERVAL '1 month', 'Mon, YY') AS "month_2_name",
    SUM(CASE WHEN DATE_TRUNC('month', @From_Date + INTERVAL '2 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END) AS "Month 3",
    TO_CHAR(@From_Date + INTERVAL '2 month', 'Mon, YY') AS "month_3_name",
    SUM(CASE WHEN DATE_TRUNC('month', @From_Date + INTERVAL '3 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END) AS "Month 4",
    TO_CHAR(@From_Date + INTERVAL '3 month', 'Mon, YY') AS "month_4_name",
    SUM(CASE WHEN DATE_TRUNC('month', @From_Date + INTERVAL '4 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END) AS "Month 5",
    TO_CHAR(@From_Date + INTERVAL '4 month', 'Mon, YY') AS "month_5_name",
    SUM(CASE WHEN DATE_TRUNC('month', @From_Date + INTERVAL '5 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END) AS "Month 6",
    TO_CHAR(@From_Date + INTERVAL '5 month', 'Mon, YY') AS "month_6_name",
    SUM(CASE WHEN DATE_TRUNC('month', @From_Date + INTERVAL '6 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END) AS "Month 7",
    TO_CHAR(@From_Date + INTERVAL '6 month', 'Mon, YY') AS "month_7_name",
    SUM(CASE WHEN DATE_TRUNC('month', @From_Date + INTERVAL '7 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END) AS "Month 8",
    TO_CHAR(@From_Date + INTERVAL '7 month', 'Mon, YY') AS "month_8_name",
    SUM(CASE WHEN DATE_TRUNC('month', @From_Date + INTERVAL '8 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END) AS "Month 9",
    TO_CHAR(@From_Date + INTERVAL '8 month', 'Mon, YY') AS "month_9_name",
    SUM(CASE WHEN DATE_TRUNC('month', @From_Date + INTERVAL '9 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END) AS "Month 10",
    TO_CHAR(@From_Date + INTERVAL '9 month', 'Mon, YY') AS "month_10_name",
    SUM(CASE WHEN DATE_TRUNC('month', @From_Date + INTERVAL '10 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END) AS "Month 11",
    TO_CHAR(@From_Date + INTERVAL '10 month', 'Mon, YY') AS "month_11_name",
    SUM(CASE WHEN DATE_TRUNC('month', @From_Date + INTERVAL '11 month') = DATE_TRUNC('month', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END) AS "Month 12",
    TO_CHAR(@From_Date + INTERVAL '11 month', 'Mon, YY') AS "month_12_name",
    SUM(CASE WHEN DATE_TRUNC('year', @From_Date) = DATE_TRUNC('year', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END) AS "YEAR 1",
    EXTRACT(YEAR FROM @From_Date) AS "year_1_name",
    SUM(CASE WHEN DATE_TRUNC('year', @From_Date + INTERVAL '1 year') = DATE_TRUNC('year', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END) AS "YEAR 2",
    EXTRACT(YEAR FROM @From_Date + INTERVAL '1 year') AS "year_2_name",
    SUM(CASE WHEN DATE_TRUNC('year', @From_Date + INTERVAL '2 year') = DATE_TRUNC('year', fp."TIME_STAMP") THEN fp."AMOUNT" ELSE 0 END) AS "YEAR 3",
    EXTRACT(YEAR FROM @From_Date + INTERVAL '2 year') AS "year_3_name"
FROM
    FINAL_TO_PIVOT as fp
INNER JOIN "reporting"."stg_leases" ON fp."LEASE_ID" = "reporting"."stg_leases"."lease_id"
INNER JOIN "reporting"."stg_tenants" ON "reporting"."stg_tenants"."tenant_id" = "reporting"."stg_leases"."primary_tenant_id"
INNER JOIN "reporting"."stg_properties" ON fp."PROP_ID" = "reporting"."stg_properties"."property_id"

WHERE  CAST("reporting"."stg_leases"."lease_raw_status" AS TEXT) IN (@Lease_Status)
	AND "reporting"."stg_leases"."deleted_at" IS NULL
	AND "reporting"."stg_leases"."lease_raw_status" <> 'canceled'
	AND CASE WHEN CAST("reporting"."stg_leases"."month_to_month_flag" AS TEXT) ='true' THEN 'True' ELSE 'False' END IN (@month_to_month) 
	AND "reporting"."stg_tenants"."deleted_at" IS NULL
	
GROUP BY
    1, 2, 3, 4, 5, 6
ORDER BY
    1, 2, 4
