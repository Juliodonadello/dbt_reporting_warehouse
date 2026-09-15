-- Property_Name keeps its existing name but now receives property IDs from Bold.
-- Available values: Value = property_id, Label = prop_name; multi-value Integer.
WITH UNIT_BASE AS (

    SELECT DISTINCT
        U.property_id AS "PROP_ID",
        U.prop_name AS "PROP_NAME",
        U.company_relation_id AS "company_relation_id",
        U.unit_id AS "UNIT_ID",
        U.unit_name AS "UNIT_NAME",
        FUS.unit_sq_ft AS "UNIT_SQ_FT",
        COALESCE(FPS.property_total_sq_ft, 0) AS "PROPERTY_TOTAL_SQ_FT",
        U.floor_plan AS "floorPlan"
    FROM "reporting"."dim_unit" U
    INNER JOIN "reporting"."fct_unit_sqft" FUS
        ON U.property_id = FUS.property_id
       AND U.unit_id = FUS.unit_id
       AND FUS.unit_sqft_valid_from <= @AsOfDate
       AND FUS.unit_sqft_valid_to > @AsOfDate
    LEFT JOIN "reporting"."fct_property_sqft" FPS
        ON U.property_id = FPS.property_id
       AND U.company_relation_id = FPS.company_relation_id
       AND FPS.property_sqft_valid_from <= @AsOfDate
       AND FPS.property_sqft_valid_to > @AsOfDate
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
        RPT."tenant",
        RPT."lease_created_at",
        RPT."lease_start",
        RPT."unit_move_in",
        RPT."lease_end",
        RPT."lease_raw_status",
        RPT."lease_termination",
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
        RPT."annual_other_amount"
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
        DL.tenant AS "TENANT",
        DL.lease_created_at AS "lease_created_at",
        DL.lease_start AS "lease_start",
        DL.lease_end AS "lease_end",
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
        SUM(COALESCE(RPT."annual_other_amount", 0)) AS "ANNUAL_OTHER_AMOUNT"
    FROM FILTERED_RENT_ROLL RPT
    INNER JOIN LEASE_BASE L
        ON RPT."prop_id" = L."PROP_ID"
       AND RPT."unit_id" = L."UNIT_ID"
       AND RPT."lease_id" = L."LEASE_ID"
    GROUP BY RPT."prop_id", RPT."unit_id", RPT."lease_id"

),

UNIT_LEASES AS (

    SELECT
        U."PROP_ID",
        U."PROP_NAME",
        U."company_relation_id",
        U."UNIT_ID",
        U."UNIT_NAME",
        U."UNIT_SQ_FT",
        U."PROPERTY_TOTAL_SQ_FT",
        U."floorPlan",
        L."LEASE_ID",
        CASE
            WHEN L."LEASE_ID" IS NOT NULL THEN 'OCCUPIED'
            ELSE 'VACANT'
        END AS "LEASE_STATUS",
        L."TENANT",
        L."lease_created_at",
        L."lease_start",
        L."lease_end",
        L."DEPOSIT",
        L."REFUNDABLE",
        COALESCE(C."RENT_AMOUNT", 0) AS "RENT_AMOUNT",
        COALESCE(C."OTHER_AMOUNT", 0) AS "OTHER_AMOUNT",
        COALESCE(C."ANNUAL_RENT_AMOUNT", 0) AS "ANNUAL_RENT_AMOUNT",
        COALESCE(C."ANNUAL_OTHER_AMOUNT", 0) AS "ANNUAL_OTHER_AMOUNT"
    FROM UNIT_BASE U
    LEFT JOIN LEASE_BASE L
        ON U."PROP_ID" = L."PROP_ID"
       AND U."company_relation_id" = L."company_relation_id"
       AND U."UNIT_ID" = L."UNIT_ID"
    LEFT JOIN CHARGE_AGG C
        ON L."PROP_ID" = C."PROP_ID"
       AND L."UNIT_ID" = C."UNIT_ID"
       AND L."LEASE_ID" = C."LEASE_ID"

),

LEASES_PER_UNIT AS (

    SELECT
        UL."PROP_ID",
        UL."company_relation_id",
        UL."UNIT_ID",
        COUNT(DISTINCT UL."LEASE_ID")
            FILTER (WHERE UL."LEASE_ID" IS NOT NULL) AS "LEASES_COUNT"
    FROM UNIT_LEASES UL
    GROUP BY UL."company_relation_id", UL."PROP_ID", UL."UNIT_ID"

)

SELECT
    UL."PROP_ID",
    UL."PROP_NAME",
    UL."UNIT_ID",
    UL."UNIT_NAME",
    UL."LEASE_ID",
    UL."LEASE_STATUS",
    UL."TENANT",
    UL."lease_created_at",
    UL."lease_start",
    UL."lease_end",
    UL."UNIT_SQ_FT",
    UL."floorPlan",
    CASE
        WHEN COALESCE(LPU."LEASES_COUNT", 0) = 0 THEN UL."UNIT_SQ_FT"
        ELSE UL."UNIT_SQ_FT" / LPU."LEASES_COUNT"
    END AS "UNIT_SQ_FT_fix",
    CASE
        WHEN COALESCE(UL."PROPERTY_TOTAL_SQ_FT", 0) = 0 THEN 0
        ELSE UL."UNIT_SQ_FT" / UL."PROPERTY_TOTAL_SQ_FT" * 100
    END AS "Pct of Property",
    CASE
        WHEN COALESCE(UL."PROPERTY_TOTAL_SQ_FT", 0) = 0 THEN 0
        WHEN COALESCE(LPU."LEASES_COUNT", 0) = 0
            THEN UL."UNIT_SQ_FT" / UL."PROPERTY_TOTAL_SQ_FT" * 100
        ELSE (UL."UNIT_SQ_FT" / LPU."LEASES_COUNT")
            / UL."PROPERTY_TOTAL_SQ_FT" * 100
    END AS "Pct of Property_fix",
    UL."DEPOSIT",
    UL."REFUNDABLE",
    UL."RENT_AMOUNT",
    UL."OTHER_AMOUNT",
    UL."ANNUAL_RENT_AMOUNT",
    UL."ANNUAL_OTHER_AMOUNT",
    CASE
        WHEN COALESCE(UL."UNIT_SQ_FT", 0) = 0 THEN 0
        ELSE UL."ANNUAL_RENT_AMOUNT" / UL."UNIT_SQ_FT"
    END AS "Annual Rent/Sq Ft",
    CASE
        WHEN COALESCE(UL."UNIT_SQ_FT", 0) = 0 THEN 0
        ELSE UL."ANNUAL_OTHER_AMOUNT" / UL."UNIT_SQ_FT"
    END AS "Annual Other/Sq Ft"
FROM UNIT_LEASES UL
LEFT JOIN LEASES_PER_UNIT LPU
    ON UL."PROP_ID" = LPU."PROP_ID"
   AND UL."company_relation_id" = LPU."company_relation_id"
   AND UL."UNIT_ID" = LPU."UNIT_ID"
ORDER BY UL."PROP_NAME", UL."UNIT_NAME"
