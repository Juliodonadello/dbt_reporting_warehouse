WITH REPORT_BASE AS (

    SELECT *
    FROM "reporting"."rpt_occupied_square_footage" AS RPT
    WHERE RPT."prop_name" IN (@Property_Name)
      AND RPT."company_relation_id" = CAST(@REAL_COMPANY_ID AS INT)
      AND RPT."unit_valid_from" <= @AsOfDate
      AND RPT."unit_valid_to" > @AsOfDate

),

UNIT_BASE AS (

    SELECT DISTINCT
        RPT."prop_id" AS "PROP_ID",
        RPT."prop_name" AS "PROP_NAME",
        RPT."company_relation_id" AS "company_relation_id",
        RPT."unit_id" AS "UNIT_ID",
        RPT."unit_name" AS "UNIT_NAME",
        RPT."sq_ft_type" AS "SQ_FT_TYPE",
        RPT."unit_class" AS "UNIT_CLASS",
        RPT."unit_sq_ft" AS "UNIT_SQ_FT",
        RPT."property_total_sq_ft" AS "TOT_SQ_FT"
    FROM REPORT_BASE RPT
    WHERE RPT."unit_class" IN (@Unit_Class)

),

LEASE_BASE AS (

    SELECT
        RPT."lease_id" AS "LEASE_ID",
        RPT."unit_id" AS "UNIT_ID",
        MIN(RPT."lease_created_at") AS "lease_created_at",
        MIN(RPT."lease_start") AS "lease_start",
        MAX(RPT."lease_end") AS "lease_end",
        MAX(RPT."tenant") AS "TENANT",
        'OCCUPIED' AS "LEASE_STATUS",
        COALESCE(
            MAX(CASE WHEN RPT."deposit" = 'YES' THEN 'YES' END),
            MAX(RPT."deposit")
        ) AS "DEPOSIT",
        COALESCE(
            MAX(CASE WHEN RPT."refundable" = 'YES' THEN 'YES' END),
            MAX(RPT."refundable")
        ) AS "REFUNDABLE",
        MAX(RPT."lease_name") AS "LEASE_NAME"
    FROM REPORT_BASE RPT
    WHERE RPT."lease_id" IS NOT NULL
      AND RPT."lease_raw_status" = 'current'
      AND RPT."lease_valid_from" <= @AsOfDate
      AND RPT."lease_valid_to" > @AsOfDate
      AND RPT."month_to_month_label" IN (@month_to_month)
    GROUP BY
        RPT."lease_id",
        RPT."unit_id"

),

CHARGE_BASE AS (

    SELECT DISTINCT
        RPT."recurring_charge_id" AS "RCHARGE_ID",
        RPT."lease_id" AS "LEASE_ID",
        RPT."unit_id" AS "UNIT_ID",
        RPT."rent_charge" AS "RENT_CHARGE",
        RPT."other_charge" AS "OTHER_CHARGE"
    FROM REPORT_BASE RPT
    INNER JOIN LEASE_BASE LB
        ON RPT."lease_id" = LB."LEASE_ID"
       AND RPT."unit_id" = LB."UNIT_ID"
    WHERE RPT."recurring_charge_id" IS NOT NULL
      AND RPT."charge_valid_from" <= @AsOfDate
      AND RPT."charge_valid_to" > @AsOfDate
      AND (
            RPT."frequency" <> 'One Time'
            OR (
                RPT."frequency" = 'One Time'
                AND @AsOfDate > RPT."charge_valid_from"
                AND @AsOfDate < RPT."one_time_window_end"
            )
          )
      AND (
            RPT."charge_terminate_date" IS NULL
            OR RPT."charge_terminate_date" >= @AsOfDate
          )

),

CHARGES AS (

    SELECT
        CB."LEASE_ID",
        CB."UNIT_ID",
        SUM(CB."RENT_CHARGE") AS "RENT_CHARGE",
        SUM(CB."OTHER_CHARGE") AS "OTHER_CHARGE"
    FROM CHARGE_BASE CB
    GROUP BY
        CB."LEASE_ID",
        CB."UNIT_ID"

),

FINAL AS (

    SELECT
        LB."LEASE_ID",
        LB."UNIT_ID",
        LB."lease_created_at",
        LB."lease_start",
        LB."lease_end",
        LB."TENANT",
        LB."LEASE_STATUS",
        LB."DEPOSIT",
        LB."REFUNDABLE",
        CH."RENT_CHARGE",
        CH."OTHER_CHARGE",
        LB."LEASE_NAME"
    FROM LEASE_BASE LB
    LEFT JOIN CHARGES CH
        ON LB."LEASE_ID" = CH."LEASE_ID"
       AND LB."UNIT_ID" = CH."UNIT_ID"

),

FINAL_AUX AS (

    SELECT
        COUNT(DISTINCT "LEASE_ID") AS "LEASES_COUNT",
        "UNIT_ID"
    FROM FINAL
    GROUP BY "UNIT_ID"

)

SELECT
    UNITS."PROP_ID",
    UNITS."PROP_NAME",
    UNITS."UNIT_ID",
    UNITS."UNIT_NAME",
    CASE
        WHEN FINAL."lease_created_at" IS NOT NULL THEN 'OCCUPIED'
        ELSE 'VACANT'
    END AS "LEASE_STATUS",
    FINAL."TENANT",
    FINAL."lease_created_at" AS "lease_created_at",
    FINAL."lease_start" AS "lease_start",
    FINAL."lease_end",
    UNITS."UNIT_SQ_FT" AS "UNIT_SQ_FT",
    CASE
        WHEN FINAL_AUX."LEASES_COUNT" > 0 THEN UNITS."UNIT_SQ_FT" / FINAL_AUX."LEASES_COUNT"
        ELSE UNITS."UNIT_SQ_FT"
    END AS "UNIT_SQ_FT_fix",
    CASE
        WHEN FINAL."lease_created_at" IS NOT NULL THEN UNITS."UNIT_SQ_FT"
        ELSE NULL
    END AS "OCCUPIED_UNIT_SQ_FT",
    CASE
        WHEN FINAL."lease_created_at" IS NOT NULL AND FINAL_AUX."LEASES_COUNT" > 0
            THEN UNITS."UNIT_SQ_FT" / FINAL_AUX."LEASES_COUNT"
        WHEN FINAL."lease_created_at" IS NOT NULL THEN UNITS."UNIT_SQ_FT"
        ELSE NULL
    END AS "OCCUPIED_UNIT_SQ_FT_fix",
    CASE
        WHEN FINAL."lease_created_at" IS NULL THEN UNITS."UNIT_SQ_FT"
        ELSE NULL
    END AS "VACCANT_UNIT_SQ_FT",
    CASE
        WHEN FINAL."lease_created_at" IS NULL AND FINAL_AUX."LEASES_COUNT" > 0
            THEN UNITS."UNIT_SQ_FT" / FINAL_AUX."LEASES_COUNT"
        WHEN FINAL."lease_created_at" IS NULL THEN UNITS."UNIT_SQ_FT"
        ELSE NULL
    END AS "VACCANT_UNIT_SQ_FT_fix",
    CASE
        WHEN UNITS."TOT_SQ_FT" = 0 THEN 0
        ELSE UNITS."UNIT_SQ_FT" / UNITS."TOT_SQ_FT" * 100
    END AS "Pct of Property",
    CASE
        WHEN UNITS."TOT_SQ_FT" = 0 OR UNITS."TOT_SQ_FT" IS NULL THEN 0
        WHEN FINAL_AUX."LEASES_COUNT" > 0
            THEN (UNITS."UNIT_SQ_FT" / FINAL_AUX."LEASES_COUNT") / UNITS."TOT_SQ_FT" * 100
        WHEN FINAL_AUX."LEASES_COUNT" <= 0 OR FINAL_AUX."LEASES_COUNT" IS NULL
            THEN UNITS."UNIT_SQ_FT" / UNITS."TOT_SQ_FT" * 100
        ELSE NULL
    END AS "Pct of Property_fix",
    CASE
        WHEN UNITS."TOT_SQ_FT" = 0 THEN 0
        WHEN FINAL."lease_created_at" IS NULL THEN 0
        ELSE UNITS."UNIT_SQ_FT" / UNITS."TOT_SQ_FT" * 100
    END AS "OCC Pct of Property",
    CASE
        WHEN UNITS."TOT_SQ_FT" = 0 OR UNITS."TOT_SQ_FT" IS NULL THEN 0
        WHEN FINAL."lease_created_at" IS NULL OR FINAL_AUX."LEASES_COUNT" = 0 THEN 0
        WHEN FINAL_AUX."LEASES_COUNT" > 0
            THEN (UNITS."UNIT_SQ_FT" / FINAL_AUX."LEASES_COUNT") / UNITS."TOT_SQ_FT" * 100
        ELSE NULL
    END AS "OCC Pct of Property_fix",
    CASE
        WHEN UNITS."TOT_SQ_FT" = 0 OR FINAL."lease_created_at" IS NOT NULL THEN 0
        ELSE UNITS."UNIT_SQ_FT" / UNITS."TOT_SQ_FT" * 100
    END AS "VAC Pct of Property",
    CASE
        WHEN UNITS."TOT_SQ_FT" = 0 OR UNITS."TOT_SQ_FT" IS NULL THEN 0
        WHEN FINAL_AUX."LEASES_COUNT" > 0 OR FINAL."lease_created_at" IS NOT NULL THEN 0
        WHEN FINAL."lease_created_at" IS NULL OR FINAL_AUX."LEASES_COUNT" = 0
            THEN UNITS."UNIT_SQ_FT" / UNITS."TOT_SQ_FT" * 100
        ELSE NULL
    END AS "VAC Pct of Property_fix",
    FINAL."DEPOSIT",
    FINAL."REFUNDABLE",
    FINAL."RENT_CHARGE" AS "RENT_AMOUNT",
    FINAL."OTHER_CHARGE" AS "OTHER_AMOUNT",
    CASE
        WHEN UNITS."UNIT_SQ_FT" = 0 THEN 0
        ELSE FINAL."RENT_CHARGE" * 12 / UNITS."UNIT_SQ_FT"
    END AS "Annual Rent/Sq Ft",
    CASE
        WHEN UNITS."UNIT_SQ_FT" = 0 THEN 0
        ELSE FINAL."OTHER_CHARGE" * 12 / UNITS."UNIT_SQ_FT"
    END AS "Annual Other/Sq Ft",
    FINAL."LEASE_NAME",
    UNITS."SQ_FT_TYPE",
    UNITS."UNIT_CLASS"
FROM UNIT_BASE UNITS
LEFT JOIN FINAL
    ON UNITS."UNIT_ID" = FINAL."UNIT_ID"
LEFT JOIN FINAL_AUX
    ON FINAL."UNIT_ID" = FINAL_AUX."UNIT_ID"
ORDER BY
    "PROP_NAME",
    natural_sort("UNIT_NAME")
