-- Property_Name keeps its existing name but now receives property IDs from Bold.
-- Available values: Value = property_id, Label = prop_name; multi-value Integer.
WITH UNIT_BASE AS (

    SELECT DISTINCT
        U.property_id AS "PROP_ID",
        U.prop_name AS "PROP_NAME",
        U.company_relation_id AS "company_relation_id",
        U.unit_id AS "UNIT_ID",
        U.unit_name AS "UNIT_NAME",
        U.floor_plan AS "floorPlan",
        FUS.unit_sq_ft AS "UNIT_SQ_FT"
    FROM "reporting"."dim_unit" U
    INNER JOIN "reporting"."fct_unit_sqft" FUS
        ON U.property_id = FUS.property_id
       AND U.unit_id = FUS.unit_id
       AND FUS.unit_sqft_valid_from <= @AsOfDate
       AND FUS.unit_sqft_valid_to > @AsOfDate
    WHERE U.property_id = ANY(
        CAST(ARRAY[@Property_Name] AS integer[])
    )
      AND U.company_relation_id = CAST(@REAL_COMPANY_ID AS INT)
      AND U.floor_plan IN (@floorPlan)

),

FILTERED_RENT_ROLL AS (

    SELECT
        RPT."prop_id",
        RPT."prop_name",
        RPT."company_relation_id",
        RPT."unit_id",
        RPT."unit_name",
        RPT."floor_plan",
        RPT."unit_sq_ft",
        RPT."property_total_sq_ft",
        RPT."lease_id",
        RPT."lease_created_at",
        RPT."lease_start",
        RPT."unit_move_in",
        RPT."lease_end",
        RPT."lease_raw_status",
        RPT."lease_termination",
        RPT."tenant",
        RPT."deposit",
        RPT."refundable",
        RPT."month_to_month_label",
        RPT."recurring_charge_id",
        RPT."frequency",
        RPT."one_time_window_end",
        RPT."charge_terminate_date",
        RPT."rent_amount",
        RPT."other_amount",
        RPT."annual_rent_amount",
        RPT."annual_other_amount",
        RPT."rent_charge",
        RPT."other_charge",
        RPT."report_valid_from"
    FROM "reporting"."rpt_summarized_rent_roll" AS RPT
    WHERE RPT."prop_id" = ANY(
        CAST(ARRAY[@Property_Name] AS integer[])
    )
      AND RPT."company_relation_id" = CAST(@REAL_COMPANY_ID AS INT)
      AND RPT."floor_plan" IN (@floorPlan)
      AND RPT."report_valid_from" <= @AsOfDate
      AND RPT."report_valid_to" > @AsOfDate

),
LEASE_BASE AS (

    SELECT
        DL.property_id AS "PROP_ID",
        DL.company_relation_id AS "company_relation_id",
        DL.unit_id AS "UNIT_ID",
        DL.lease_id AS "LEASE_ID",
        DL.lease_created_at AS "lease_created_at",
        DL.lease_start AS "start",
        DL.lease_end AS "lease_end",
        DL.tenant AS "TENANT",
        'OCCUPIED' AS "LEASE_STATUS",
        DL.deposit AS "DEPOSIT",
        DL.refundable AS "REFUNDABLE"
    FROM "reporting"."dim_lease" DL
    INNER JOIN UNIT_BASE U
        ON DL.property_id = U."PROP_ID"
       AND DL.company_relation_id = U."company_relation_id"
       AND DL.unit_id = U."UNIT_ID"
    WHERE DL.lease_raw_status <> 'canceled'
      AND DL.company_relation_id = CAST(@REAL_COMPANY_ID AS INT)
      AND DL.property_id = ANY(
          CAST(ARRAY[@Property_Name] AS integer[])
      )
      AND DL.month_to_month_label IN (@month_to_month)
      AND (
            (
                @ignore_end_date = true
                AND DL.lease_raw_status = 'current'
                AND DL.unit_move_in <= @AsOfDate
            )
            OR
            (
                @ignore_end_date = false
                AND DL.unit_move_in <= @AsOfDate
                AND (
                    (
                        DL.month_to_month_label = 'True'
                        AND (
                            DL.lease_termination IS NULL
                            OR DL.lease_termination > @AsOfDate
                        )
                    )
                    OR DL.lease_end IS NULL
                    OR DL.lease_end > @AsOfDate
                )
            )
          )

),

CHARGE_AGG AS (

    SELECT
        RPT."prop_id" AS "PROP_ID",
        RPT."unit_id" AS "UNIT_ID",
        RPT."lease_id" AS "LEASE_ID",
        SUM(COALESCE(RPT."rent_amount", 0)) AS "RENT_AMOUNT",
        SUM(COALESCE(RPT."other_amount", 0)) AS "OTHER_AMOUNT",
        SUM(COALESCE(RPT."annual_rent_amount", 0)) AS "ANNUAL_RENT_AMOUNT",
        SUM(COALESCE(RPT."annual_other_amount", 0)) AS "ANNUAL_OTHER_AMOUNT",
        SUM(
            CASE
                WHEN RPT."frequency" = 'Monthly'
                    THEN COALESCE(RPT."rent_charge", 0)
                       + COALESCE(RPT."other_charge", 0)
                ELSE 0
            END
        ) AS "TOTAL_MONTHLY_CHARGES",
        SUM(
            CASE
                WHEN RPT."frequency" = 'Annually'
                    THEN COALESCE(RPT."rent_charge", 0)
                       + COALESCE(RPT."other_charge", 0)
                ELSE 0
            END
        ) AS "TOTAL_ANNUALLY_CHARGES",
        SUM(
            CASE
                WHEN RPT."frequency" = 'Quarterly'
                    THEN COALESCE(RPT."rent_charge", 0)
                       + COALESCE(RPT."other_charge", 0)
                ELSE 0
            END
        ) AS "TOTAL_QUARTERLY_CHARGES"
    FROM FILTERED_RENT_ROLL AS RPT
    INNER JOIN LEASE_BASE AS L
        ON RPT."prop_id" = L."PROP_ID"
       AND RPT."unit_id" = L."UNIT_ID"
       AND RPT."lease_id" = L."LEASE_ID"
    GROUP BY RPT."prop_id", RPT."unit_id", RPT."lease_id"

),

FINAL AS (

    SELECT
        L."PROP_ID",
        L."company_relation_id",
        L."LEASE_ID",
        L."UNIT_ID",
        L."lease_created_at",
        L."start",
        L."lease_end",
        L."TENANT",
        L."LEASE_STATUS",
        L."DEPOSIT",
        L."REFUNDABLE",
        COALESCE(C."RENT_AMOUNT", 0) AS "RENT_AMOUNT",
        COALESCE(C."OTHER_AMOUNT", 0) AS "OTHER_AMOUNT",
        COALESCE(C."ANNUAL_RENT_AMOUNT", 0) AS "ANNUAL_RENT_AMOUNT",
        COALESCE(C."ANNUAL_OTHER_AMOUNT", 0) AS "ANNUAL_OTHER_AMOUNT",
        COALESCE(C."TOTAL_MONTHLY_CHARGES", 0) AS "TOTAL_MONTHLY_CHARGES",
        COALESCE(C."TOTAL_ANNUALLY_CHARGES", 0) AS "TOTAL_ANNUALLY_CHARGES",
        COALESCE(C."TOTAL_QUARTERLY_CHARGES", 0) AS "TOTAL_QUARTERLY_CHARGES"
    FROM LEASE_BASE AS L
    LEFT JOIN CHARGE_AGG AS C
        ON L."PROP_ID" = C."PROP_ID"
       AND L."UNIT_ID" = C."UNIT_ID"
       AND L."LEASE_ID" = C."LEASE_ID"

),

FINAL_AUX AS (

    SELECT
        "PROP_ID",
        "company_relation_id",
        "UNIT_ID",
        COUNT(DISTINCT "LEASE_ID") AS "LEASES_COUNT"
    FROM FINAL
    GROUP BY "company_relation_id", "PROP_ID", "UNIT_ID"

)

SELECT
    UNITS."PROP_ID",
    UNITS."PROP_NAME",
    UNITS."UNIT_NAME",
    UNITS."floorPlan",
    COUNT(DISTINCT UNITS."UNIT_ID") AS "UNIT_TOT",
    SUM(
        CASE
            WHEN COALESCE(FINAL_AUX."LEASES_COUNT", 0) = 0
                THEN UNITS."UNIT_SQ_FT"
            ELSE UNITS."UNIT_SQ_FT" / FINAL_AUX."LEASES_COUNT"
        END
    ) AS "PROP_SQ_FT",
    SUM(
        CASE
            WHEN FINAL."LEASE_STATUS" = 'OCCUPIED'
                THEN UNITS."UNIT_SQ_FT" / FINAL_AUX."LEASES_COUNT"
            ELSE 0
        END
    ) AS "OCCUPIED_UNIT_SQ_FT",
    SUM(COALESCE(FINAL."RENT_AMOUNT", 0)) AS "RENT_AMOUNT_TOT",
    SUM(COALESCE(FINAL."OTHER_AMOUNT", 0)) AS "OTHER_AMOUNT_TOT",
    SUM(COALESCE(FINAL."TOTAL_MONTHLY_CHARGES", 0)) AS "TOTAL_MONTHLY_CHARGES",
    SUM(COALESCE(FINAL."TOTAL_ANNUALLY_CHARGES", 0)) AS "TOTAL_ANNUALLY_CHARGES",
    SUM(COALESCE(FINAL."TOTAL_QUARTERLY_CHARGES", 0)) AS "TOTAL_QUARTERLY_CHARGES"
FROM UNIT_BASE AS UNITS
LEFT JOIN FINAL
    ON UNITS."PROP_ID" = FINAL."PROP_ID"
   AND UNITS."company_relation_id" = FINAL."company_relation_id"
   AND UNITS."UNIT_ID" = FINAL."UNIT_ID"
LEFT JOIN FINAL_AUX
    ON UNITS."PROP_ID" = FINAL_AUX."PROP_ID"
   AND UNITS."company_relation_id" = FINAL_AUX."company_relation_id"
   AND UNITS."UNIT_ID" = FINAL_AUX."UNIT_ID"
GROUP BY
    UNITS."PROP_ID",
    UNITS."PROP_NAME",
    UNITS."UNIT_NAME",
    UNITS."floorPlan"
ORDER BY "PROP_NAME"
