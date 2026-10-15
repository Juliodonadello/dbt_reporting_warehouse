WITH CHARGE_CONTROL AS (
    SELECT
        p.property_id AS "PROP_ID",
        pcc.item_id AS "ITEM_ID",
        CASE WHEN pcc.base_rent THEN 1 ELSE 0 END AS "BASE_RENT"
    FROM "reporting"."stg_properties" p
    INNER JOIN "reporting"."stg_property_charge_controls" pcc
        ON pcc.property_id = p.property_id
    WHERE p.prop_name IN (@Property_Name)
      AND p.company_relation_id = CAST(@REAL_COMPANY_ID AS INT)
),

CHARGES_TOT AS (
    SELECT
        lrc.recurring_charge_id AS "RCHARGE_ID",
        lrc.lease_id AS "LEASE_ID",
        CASE WHEN cc."BASE_RENT" = 1 THEN lrca.amount ELSE 0 END AS "RENT_CHARGE",
        CASE WHEN cc."BASE_RENT" = 0 THEN lrca.amount ELSE 0 END AS "OTHER_CHARGE",
        lrca.effective_date AS "EFFECTIVE_DATE",
        u.property_id AS "PROP_ID",
        lrc.unit_id AS "UNIT_ID"
    FROM "reporting"."stg_lease_recurring_charges" lrc
    LEFT JOIN "reporting"."stg_lease_recurring_charge_amounts" lrca
        ON lrc.recurring_charge_id = lrca.recurring_charge_id
    INNER JOIN "reporting"."stg_units" u
        ON lrc.unit_id = u.unit_id
    INNER JOIN CHARGE_CONTROL cc
        ON cc."PROP_ID" = u.property_id
       AND cc."ITEM_ID" = lrc.item_id
    WHERE lrca.effective_date <= @AsOfDate
      AND (
          lrca.frequency != 'One Time'
          OR (
              lrca.frequency = 'One Time'
              AND CAST(EXTRACT(DAY FROM (@AsOfDate - lrca.effective_date)) AS INTEGER) > 0
              AND CAST(EXTRACT(DAY FROM (@AsOfDate - lrca.effective_date)) AS INTEGER) < 31
          )
      )
      AND (
          lrc.terminate_date >= @AsOfDate
          OR lrc.terminate_date IS NULL
      )
    GROUP BY
        lrc.recurring_charge_id,
        lrc.lease_id,
        CASE WHEN cc."BASE_RENT" = 1 THEN lrca.amount ELSE 0 END,
        CASE WHEN cc."BASE_RENT" = 0 THEN lrca.amount ELSE 0 END,
        lrca.effective_date,
        u.property_id,
        lrc.unit_id
),

MAX_CHARGES AS (
    SELECT
        "RCHARGE_ID",
        MAX("EFFECTIVE_DATE") AS "EFFECTIVE_DATE"
    FROM CHARGES_TOT
    GROUP BY
        "RCHARGE_ID"
),

CHARGES AS (
    SELECT
        ct.*
    FROM CHARGES_TOT ct
    INNER JOIN MAX_CHARGES mc
        ON ct."RCHARGE_ID" = mc."RCHARGE_ID"
       AND ct."EFFECTIVE_DATE" = mc."EFFECTIVE_DATE"
    GROUP BY
        ct."RCHARGE_ID",
        ct."LEASE_ID",
        ct."RENT_CHARGE",
        ct."OTHER_CHARGE",
        ct."EFFECTIVE_DATE",
        ct."PROP_ID",
        ct."UNIT_ID"
),

LEASES AS (
    SELECT
        l.lease_id AS "LEASE_ID",
        lu.unit_id AS "UNIT_ID",
        l.lease_created_at AS "lease_created_at",
        l.lease_start AS "start",
        l.lease_end AS "lease_end",
        CASE WHEN l.lease_raw_status = 'current' THEN 'OCCUPIED' ELSE 'VACANT' END AS "LEASE_STATUS",
        CASE WHEN ld.lease_deposit_id IS NULL THEN 'NO' ELSE 'YES' END AS "DEPOSIT",
        CASE WHEN CAST(ld.refundable AS TEXT) = 'true' THEN 'YES' ELSE 'NO' END AS "REFUNDABLE",
        t.tenant_name AS "TENANT",
        l.lease_name AS "LEASE_NAME"
    FROM "reporting"."stg_leases" l
    INNER JOIN "reporting"."stg_lease_units" lu
        ON l.lease_id = lu.lease_id
    LEFT JOIN "reporting"."stg_lease_deposits" ld
        ON l.lease_id = ld.lease_id
    LEFT JOIN "reporting"."stg_tenants" t
        ON l.primary_tenant_id = t.tenant_id
    WHERE (
            (
                @ignore_end_date = true
                AND l.lease_raw_status = 'current'
                AND COALESCE(lu.move_in, l.lease_start) <= @AsOfDate
            )
            OR
            (
                @ignore_end_date = false
                AND COALESCE(lu.move_in, l.lease_start) <= @AsOfDate
                AND (
                    (
                        CAST(l.month_to_month_flag AS TEXT) = 'true'
                        AND (
                            l.lease_termination IS NULL
                            OR l.lease_termination > @AsOfDate
                        )
                    )
                    OR l.lease_end IS NULL
                    OR l.lease_end > @AsOfDate
                )
            )
        )
      AND l.lease_raw_status <> 'canceled'
      AND CASE WHEN CAST(l.month_to_month_flag AS TEXT) = 'true' THEN 'True' ELSE 'False' END IN (@month_to_month)
    GROUP BY
        l.lease_id,
        lu.unit_id,
        l.lease_created_at,
        l.lease_start,
        l.lease_end,
        CASE WHEN l.lease_raw_status = 'current' THEN 'OCCUPIED' ELSE 'VACANT' END,
        CASE WHEN ld.lease_deposit_id IS NULL THEN 'NO' ELSE 'YES' END,
        CASE WHEN CAST(ld.refundable AS TEXT) = 'true' THEN 'YES' ELSE 'NO' END,
        t.tenant_name,
        l.lease_name
),

LEASES_CHARGES AS (
    SELECT
        l."LEASE_ID",
        l."UNIT_ID",
        MIN(l."lease_created_at") AS "lease_created_at",
        MIN(l."start") AS "start",
        MAX(l."lease_end") AS "lease_end",
        l."TENANT",
        COALESCE(MAX(CASE WHEN l."LEASE_STATUS" = 'OCCUPIED' THEN 'OCCUPIED' END), MAX(l."LEASE_STATUS")) AS "LEASE_STATUS",
        COALESCE(MAX(CASE WHEN l."DEPOSIT" = 'YES' THEN 'YES' END), MAX(l."DEPOSIT")) AS "DEPOSIT",
        COALESCE(MAX(CASE WHEN l."REFUNDABLE" = 'YES' THEN 'YES' END), MAX(l."REFUNDABLE")) AS "REFUNDABLE",
        SUM(c."RENT_CHARGE") AS "RENT_CHARGE",
        SUM(c."OTHER_CHARGE") AS "OTHER_CHARGE",
        l."LEASE_NAME" AS "LEASE_NAME"
    FROM LEASES l
    LEFT JOIN CHARGES c
        ON l."LEASE_ID" = c."LEASE_ID"
       AND l."UNIT_ID" = c."UNIT_ID"
    GROUP BY
        l."LEASE_ID",
        l."UNIT_ID",
        l."TENANT",
        l."LEASE_NAME"
),

UNITS AS (
    SELECT
        p.property_id AS "PROP_ID",
        p.prop_name AS "PROP_NAME",
        p.company_relation_id AS "COMPANY_RELATION_ID",
        u.unit_id AS "UNIT_ID",
        u.unit_name AS "UNIT_NAME",
        'Total' AS "SQ_FT_TYPE",
        u.unit_class AS "UNIT_CLASS",
        MAX(COALESCE(uq.unit_sq_ft_value, u.base_unit_sq_ft)) AS "UNIT_SQ_FT"
    FROM "reporting"."stg_units" u
    INNER JOIN "reporting"."stg_properties" p
        ON u.property_id = p.property_id
    LEFT JOIN (
        SELECT DISTINCT ON (unit_id)
            unit_id,
            unit_sq_ft_value,
            as_of_date
        FROM "reporting"."stg_unit_square_footage_items"
        WHERE square_footage_type = 'Total'
          AND as_of_date <= @AsOfDate
        ORDER BY
            unit_id,
            as_of_date DESC
    ) uq
        ON uq.unit_id = u.unit_id
    WHERE p.prop_name IN (@Property_Name)
      AND p.company_relation_id = CAST(@REAL_COMPANY_ID AS INT)
    GROUP BY
        p.property_id,
        p.prop_name,
        p.company_relation_id,
        u.unit_id,
        u.unit_name,
        u.unit_class
),

SQ_FT_TEMP AS (
    SELECT
        "PROP_ID",
        SUM("UNIT_SQ_FT") AS "TOT_SQ_FT"
    FROM UNITS
    GROUP BY
        "PROP_ID"
),

FINAL AS (
    SELECT
        "LEASE_ID",
        "UNIT_ID",
        "lease_created_at",
        "start",
        "lease_end",
        "TENANT",
        "LEASE_STATUS",
        "DEPOSIT",
        "REFUNDABLE",
        "RENT_CHARGE",
        "OTHER_CHARGE",
        "LEASE_NAME"
    FROM LEASES_CHARGES
    GROUP BY
        "LEASE_ID",
        "UNIT_ID",
        "lease_created_at",
        "start",
        "lease_end",
        "TENANT",
        "LEASE_STATUS",
        "DEPOSIT",
        "REFUNDABLE",
        "RENT_CHARGE",
        "OTHER_CHARGE",
        "LEASE_NAME"
),

FINAL_AUX AS (
    SELECT
        COUNT(DISTINCT "LEASE_ID") AS "LEASES_COUNT",
        "UNIT_ID"
    FROM FINAL
    GROUP BY
        "UNIT_ID"
)

SELECT
    u."PROP_ID",
    u."PROP_NAME",
    u."UNIT_ID",
    u."UNIT_NAME" AS "UNIT_NAME",
    CASE WHEN f."lease_created_at" IS NOT NULL THEN 'OCCUPIED' ELSE 'VACANT' END AS "LEASE_STATUS",
    f."TENANT",
    f."lease_created_at" AS "lease_created_at",
    f."start" AS "lease_start",
    f."lease_end",
    u."UNIT_SQ_FT" AS "UNIT_SQ_FT",
    CASE WHEN fa."LEASES_COUNT" > 0 THEN u."UNIT_SQ_FT" / fa."LEASES_COUNT" ELSE u."UNIT_SQ_FT" END AS "UNIT_SQ_FT_fix",
    CASE WHEN f."lease_created_at" IS NOT NULL THEN u."UNIT_SQ_FT" ELSE NULL END AS "OCCUPIED_UNIT_SQ_FT",
    CASE
        WHEN f."lease_created_at" IS NOT NULL AND fa."LEASES_COUNT" > 0 THEN u."UNIT_SQ_FT" / fa."LEASES_COUNT"
        WHEN f."lease_created_at" IS NOT NULL THEN u."UNIT_SQ_FT"
        ELSE NULL
    END AS "OCCUPIED_UNIT_SQ_FT_fix",
    CASE WHEN f."lease_created_at" IS NULL THEN u."UNIT_SQ_FT" ELSE NULL END AS "VACCANT_UNIT_SQ_FT",
    CASE
        WHEN f."lease_created_at" IS NULL AND fa."LEASES_COUNT" > 0 THEN u."UNIT_SQ_FT" / fa."LEASES_COUNT"
        WHEN f."lease_created_at" IS NULL THEN u."UNIT_SQ_FT"
        ELSE NULL
    END AS "VACCANT_UNIT_SQ_FT_fix",
    CASE
        WHEN s."TOT_SQ_FT" = 0 THEN 0
        ELSE u."UNIT_SQ_FT" / s."TOT_SQ_FT" * 100
    END AS "Pct of Property",
    CASE
        WHEN s."TOT_SQ_FT" = 0 OR s."TOT_SQ_FT" IS NULL THEN 0
        WHEN fa."LEASES_COUNT" > 0 THEN (u."UNIT_SQ_FT" / fa."LEASES_COUNT") / s."TOT_SQ_FT" * 100
        WHEN fa."LEASES_COUNT" <= 0 OR fa."LEASES_COUNT" IS NULL THEN u."UNIT_SQ_FT" / s."TOT_SQ_FT" * 100
        ELSE NULL
    END AS "Pct of Property_fix",
    CASE
        WHEN s."TOT_SQ_FT" = 0 THEN 0
        WHEN f."lease_created_at" IS NULL THEN 0
        ELSE u."UNIT_SQ_FT" / s."TOT_SQ_FT" * 100
    END AS "OCC Pct of Property",
    CASE
        WHEN s."TOT_SQ_FT" = 0 OR s."TOT_SQ_FT" IS NULL THEN 0
        WHEN f."lease_created_at" IS NULL OR fa."LEASES_COUNT" = 0 THEN 0
        WHEN fa."LEASES_COUNT" > 0 THEN (u."UNIT_SQ_FT" / fa."LEASES_COUNT") / s."TOT_SQ_FT" * 100
        ELSE NULL
    END AS "OCC Pct of Property_fix",
    CASE
        WHEN s."TOT_SQ_FT" = 0 OR f."lease_created_at" IS NOT NULL THEN 0
        ELSE u."UNIT_SQ_FT" / s."TOT_SQ_FT" * 100
    END AS "VAC Pct of Property",
    CASE
        WHEN s."TOT_SQ_FT" = 0 OR s."TOT_SQ_FT" IS NULL THEN 0
        WHEN fa."LEASES_COUNT" > 0 OR f."lease_created_at" IS NOT NULL THEN 0
        WHEN f."lease_created_at" IS NULL OR fa."LEASES_COUNT" = 0 THEN u."UNIT_SQ_FT" / s."TOT_SQ_FT" * 100
        ELSE NULL
    END AS "VAC Pct of Property_fix",
    f."DEPOSIT",
    f."REFUNDABLE",
    f."RENT_CHARGE" AS "RENT_AMOUNT",
    f."OTHER_CHARGE" AS "OTHER_AMOUNT",
    CASE WHEN u."UNIT_SQ_FT" = 0 THEN 0 ELSE f."RENT_CHARGE" * 12 / u."UNIT_SQ_FT" END AS "Annual Rent/Sq Ft",
    CASE WHEN u."UNIT_SQ_FT" = 0 THEN 0 ELSE f."OTHER_CHARGE" * 12 / u."UNIT_SQ_FT" END AS "Annual Other/Sq Ft",
    f."LEASE_NAME",
    u."SQ_FT_TYPE",
    u."UNIT_CLASS" AS "UNIT_CLASS"
FROM UNITS u
LEFT JOIN SQ_FT_TEMP s
    ON u."PROP_ID" = s."PROP_ID"
LEFT JOIN FINAL f
    ON u."UNIT_ID" = f."UNIT_ID"
LEFT JOIN FINAL_AUX fa
    ON f."UNIT_ID" = fa."UNIT_ID"
WHERE u."PROP_NAME" IN (@Property_Name)
  AND u."UNIT_CLASS" IN (@Unit_Class)
  AND u."COMPANY_RELATION_ID" = CAST(@REAL_COMPANY_ID AS INT)
ORDER BY
    u."PROP_NAME",
    natural_sort(u."UNIT_NAME");
