WITH REPORT_BASE AS (

    SELECT
        RPT."prop_id",
        RPT."prop_name",
        RPT."company_relation_id",
        RPT."unit_id",
        RPT."unit_name",
        RPT."unit_sq_ft",
        RPT."property_total_sq_ft",
        RPT."lease_id",
        RPT."lease_name",
        RPT."lease_status",
        RPT."tenant",
        RPT."lease_created_at",
        RPT."lease_start",
        RPT."lease_end",
        RPT."deposit",
        RPT."refundable",
        RPT."month_to_month_label",
        RPT."recurring_charge_id",
        RPT."frequency",
        RPT."one_time_window_end",
        RPT."charge_terminate_date",
        RPT."charge_valid_from",
        RPT."rent_amount",
        RPT."other_amount",
        RPT."annual_rent_amount",
        RPT."annual_other_amount"
    FROM "reporting"."rpt_rent_roll_increases" AS RPT
    WHERE RPT."prop_name" IN (@Property_Name)
      AND RPT."company_relation_id" = CAST(@REAL_COMPANY_ID AS INT)
      AND RPT."unit_status_raw" = 'active'
      AND RPT."report_valid_from" <= @AsOfDate
      AND RPT."report_valid_to" > @AsOfDate

),

UNIT_BASE AS (

    SELECT DISTINCT
        RPT."prop_id"              AS "PROP_ID",
        RPT."prop_name"            AS "PROP_NAME",
        RPT."company_relation_id"  AS "company_relation_id",
        RPT."unit_id"              AS "UNIT_ID",
        RPT."unit_name"            AS "UNIT_NAME",
        RPT."unit_sq_ft"           AS "UNIT_SQ_FT",
        RPT."property_total_sq_ft" AS "PROPERTY_TOTAL_SQ_FT"
    FROM REPORT_BASE RPT

),

ACTIVE_REPORT_BASE AS (

    SELECT *
    FROM REPORT_BASE RPT
    WHERE RPT."lease_id" IS NOT NULL
      AND RPT."lease_status" = 'OCCUPIED'
      AND RPT."month_to_month_label" IN (@month_to_month)

),

LEASE_BASE AS (

    SELECT
        RPT."prop_id" AS "PROP_ID",
        RPT."unit_id" AS "UNIT_ID",
        RPT."lease_id" AS "LEASE_ID",
        MAX(RPT."lease_name") AS "LEASE_NAME",
        MAX(RPT."tenant") AS "TENANT",
        MIN(RPT."lease_created_at") AS "lease_created_at",
        MIN(RPT."lease_start") AS "lease_start",
        MAX(RPT."lease_end") AS "lease_end",
        MAX(RPT."month_to_month_label") AS "month_to_month_label",

        COALESCE(
            MAX(CASE WHEN RPT."deposit" = 'YES' THEN 'YES' END),
            MAX(RPT."deposit")
        ) AS "DEPOSIT",

        COALESCE(
            MAX(CASE WHEN RPT."refundable" = 'YES' THEN 'YES' END),
            MAX(RPT."refundable")
        ) AS "REFUNDABLE"

    FROM ACTIVE_REPORT_BASE RPT
    GROUP BY
        RPT."prop_id",
        RPT."unit_id",
        RPT."lease_id"

),

CHARGE_BASE AS (

    SELECT *
    FROM ACTIVE_REPORT_BASE RPT
    WHERE (
            RPT."recurring_charge_id" IS NULL
            OR RPT."frequency" <> 'One Time'
            OR (
                RPT."frequency" = 'One Time'
                AND RPT."one_time_window_end" > @AsOfDate
            )
          )
      AND (
            RPT."charge_terminate_date" IS NULL
            OR RPT."charge_terminate_date" >= @AsOfDate
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
    FROM CHARGE_BASE RPT
    GROUP BY
        RPT."prop_id",
        RPT."unit_id",
        RPT."lease_id"

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

        L."LEASE_ID",
        L."LEASE_NAME",

        CASE
            WHEN L."LEASE_ID" IS NOT NULL THEN 'OCCUPIED'
            ELSE 'VACANT'
        END AS "LEASE_STATUS",

        L."TENANT",
        L."lease_created_at",
        L."lease_start",
        L."lease_end",
        COALESCE(L."month_to_month_label", 'False') AS "month_to_month_label",
        L."DEPOSIT",
        L."REFUNDABLE",

        COALESCE(C."RENT_AMOUNT", 0) AS "RENT_AMOUNT",
        COALESCE(C."OTHER_AMOUNT", 0) AS "OTHER_AMOUNT",
        COALESCE(C."ANNUAL_RENT_AMOUNT", 0) AS "ANNUAL_RENT_AMOUNT",
        COALESCE(C."ANNUAL_OTHER_AMOUNT", 0) AS "ANNUAL_OTHER_AMOUNT"

    FROM UNIT_BASE U

    LEFT JOIN LEASE_BASE L
        ON U."PROP_ID" = L."PROP_ID"
       AND U."UNIT_ID" = L."UNIT_ID"

    LEFT JOIN CHARGE_AGG C
        ON L."PROP_ID" = C."PROP_ID"
       AND L."UNIT_ID" = C."UNIT_ID"
       AND L."LEASE_ID" = C."LEASE_ID"

),

LEASES_PER_UNIT AS (

    SELECT
        UL."PROP_ID",
        UL."UNIT_ID",
        COUNT(DISTINCT UL."LEASE_ID")
            FILTER (WHERE UL."LEASE_ID" IS NOT NULL) AS "LEASES_COUNT"
    FROM UNIT_LEASES UL
    GROUP BY
        UL."PROP_ID",
        UL."UNIT_ID"

),

RENT_ESCALATIONS AS (

    SELECT DISTINCT
        RPT."prop_id" AS "PROP_ID",
        RPT."unit_id" AS "UNIT_ID",
        RPT."lease_id" AS "LEASE_ID",
        RPT."rent_amount" AS "RENT_CHARGE_SCAL",
        RPT."charge_valid_from" AS "EFFECTIVE_DATE_SCAL"
    FROM "reporting"."rpt_rent_roll_increases" AS RPT
    INNER JOIN LEASE_BASE LB
        ON RPT."prop_id" = LB."PROP_ID"
       AND RPT."unit_id" = LB."UNIT_ID"
       AND RPT."lease_id" = LB."LEASE_ID"
    WHERE RPT."prop_name" IN (@Property_Name)
      AND RPT."company_relation_id" = CAST(@REAL_COMPANY_ID AS INT)
      AND RPT."unit_status_raw" = 'active'
      AND RPT."charge_valid_from" > @AsOfDate
      AND RPT."frequency" <> 'One Time'
      AND (
            RPT."charge_terminate_date" IS NULL
            OR RPT."charge_terminate_date" > @AsOfDate
          )
      AND COALESCE(RPT."rent_amount", 0) <> 0

),

RENT_ESCALATION_COUNTS AS (

    SELECT
        RE."PROP_ID",
        RE."UNIT_ID",
        RE."LEASE_ID",
        COUNT(*) AS "COUNT_RENT_CHARGE_SCAL"
    FROM RENT_ESCALATIONS RE
    GROUP BY
        RE."PROP_ID",
        RE."UNIT_ID",
        RE."LEASE_ID"

)

SELECT
    UL."PROP_ID",
    UL."PROP_NAME",
    UL."UNIT_ID",
    UL."UNIT_NAME",
    UL."LEASE_ID",
    UL."LEASE_NAME",
    UL."LEASE_STATUS",
    UL."TENANT",
    UL."lease_start",
    UL."lease_end",
    UL."UNIT_SQ_FT",
    LPU."LEASES_COUNT",

    CASE
        WHEN REC."COUNT_RENT_CHARGE_SCAL" > 1 THEN REC."COUNT_RENT_CHARGE_SCAL"
        ELSE 1
    END AS "COUNT_RENT_CHARGE_SCAL",

    CASE
        WHEN COALESCE(LPU."LEASES_COUNT", 0) < 2
         AND COALESCE(REC."COUNT_RENT_CHARGE_SCAL", 0) < 2
            THEN UL."UNIT_SQ_FT"
        WHEN COALESCE(LPU."LEASES_COUNT", 0) > 1
         AND REC."COUNT_RENT_CHARGE_SCAL" IS NULL
            THEN UL."UNIT_SQ_FT" / LPU."LEASES_COUNT"
        WHEN COALESCE(REC."COUNT_RENT_CHARGE_SCAL", 0) > 1
         AND COALESCE(LPU."LEASES_COUNT", 0) = 0
            THEN UL."UNIT_SQ_FT" / REC."COUNT_RENT_CHARGE_SCAL"
        ELSE UL."UNIT_SQ_FT" / (
            NULLIF(LPU."LEASES_COUNT", 0) * COALESCE(REC."COUNT_RENT_CHARGE_SCAL", 1)
        )
    END AS "UNIT_SQ_FT_fix",

    CASE
        WHEN COALESCE(UL."PROPERTY_TOTAL_SQ_FT", 0) = 0
            THEN 0
        ELSE UL."UNIT_SQ_FT" / UL."PROPERTY_TOTAL_SQ_FT" * 100
    END AS "Pct of Property",

    CASE
        WHEN COALESCE(UL."PROPERTY_TOTAL_SQ_FT", 0) = 0
            THEN 0
        WHEN COALESCE(LPU."LEASES_COUNT", 0) < 2
         AND COALESCE(REC."COUNT_RENT_CHARGE_SCAL", 0) < 2
            THEN UL."UNIT_SQ_FT" / UL."PROPERTY_TOTAL_SQ_FT" * 100
        WHEN COALESCE(LPU."LEASES_COUNT", 0) > 1
         AND REC."COUNT_RENT_CHARGE_SCAL" IS NULL
            THEN UL."UNIT_SQ_FT" / LPU."LEASES_COUNT" / UL."PROPERTY_TOTAL_SQ_FT" * 100
        WHEN COALESCE(REC."COUNT_RENT_CHARGE_SCAL", 0) > 1
         AND COALESCE(LPU."LEASES_COUNT", 0) = 0
            THEN UL."UNIT_SQ_FT" / REC."COUNT_RENT_CHARGE_SCAL" / UL."PROPERTY_TOTAL_SQ_FT" * 100
        ELSE UL."UNIT_SQ_FT" / (
            NULLIF(LPU."LEASES_COUNT", 0) * COALESCE(REC."COUNT_RENT_CHARGE_SCAL", 1)
        ) / UL."PROPERTY_TOTAL_SQ_FT" * 100
    END AS "Pct of Property_fix",

    UL."DEPOSIT",
    UL."REFUNDABLE",

    UL."RENT_AMOUNT",
    UL."OTHER_AMOUNT",

    CASE
        WHEN REC."COUNT_RENT_CHARGE_SCAL" IS NULL THEN UL."RENT_AMOUNT"
        ELSE UL."RENT_AMOUNT" / COALESCE(REC."COUNT_RENT_CHARGE_SCAL", 1)
    END AS "RENT_AMOUNT_fix",

    CASE
        WHEN REC."COUNT_RENT_CHARGE_SCAL" IS NULL THEN UL."OTHER_AMOUNT"
        ELSE UL."OTHER_AMOUNT" / COALESCE(REC."COUNT_RENT_CHARGE_SCAL", 1)
    END AS "OTHER_AMOUNT_fix",

    CASE
        WHEN COALESCE(UL."UNIT_SQ_FT", 0) = 0
            THEN 0
        ELSE UL."ANNUAL_RENT_AMOUNT" / UL."UNIT_SQ_FT"
    END AS "Annual Rent/Sq Ft",

    CASE
        WHEN COALESCE(UL."UNIT_SQ_FT", 0) = 0
            THEN 0
        ELSE UL."ANNUAL_OTHER_AMOUNT" / UL."UNIT_SQ_FT"
    END AS "Annual Other/Sq Ft",

    CASE
        WHEN COALESCE(UL."UNIT_SQ_FT", 0) = 0
            THEN 0
        ELSE UL."ANNUAL_RENT_AMOUNT" / UL."UNIT_SQ_FT"
             / COALESCE(REC."COUNT_RENT_CHARGE_SCAL", 1)
    END AS "Annual Rent/Sq Ft_fix",

    CASE
        WHEN COALESCE(UL."UNIT_SQ_FT", 0) = 0
            THEN 0
        ELSE UL."ANNUAL_OTHER_AMOUNT" / UL."UNIT_SQ_FT"
             / COALESCE(REC."COUNT_RENT_CHARGE_SCAL", 1)
    END AS "Annual Other/Sq Ft_fix",

    RE."RENT_CHARGE_SCAL",
    RE."EFFECTIVE_DATE_SCAL"

FROM UNIT_LEASES UL

LEFT JOIN LEASES_PER_UNIT LPU
    ON UL."PROP_ID" = LPU."PROP_ID"
   AND UL."UNIT_ID" = LPU."UNIT_ID"

LEFT JOIN RENT_ESCALATIONS RE
    ON UL."PROP_ID" = RE."PROP_ID"
   AND UL."UNIT_ID" = RE."UNIT_ID"
   AND UL."LEASE_ID" = RE."LEASE_ID"

LEFT JOIN RENT_ESCALATION_COUNTS REC
    ON UL."PROP_ID" = REC."PROP_ID"
   AND UL."UNIT_ID" = REC."UNIT_ID"
   AND UL."LEASE_ID" = REC."LEASE_ID"

WHERE UL."month_to_month_label" IN (@month_to_month)

ORDER BY
    UL."PROP_NAME",
    UL."UNIT_NAME",
    RE."EFFECTIVE_DATE_SCAL" ASC
