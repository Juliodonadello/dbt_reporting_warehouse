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
        l.lease_name AS "LEASE_NAME",
        lu.unit_id AS "UNIT_ID",
        l.lease_created_at AS "lease_created_at",
        l.lease_start AS "start",
        l.lease_end AS "lease_end",
        CASE WHEN l.lease_raw_status = 'current' THEN 'OCCUPIED' ELSE 'VACANT' END AS "LEASE_STATUS",
        CASE WHEN ld.lease_deposit_id IS NULL THEN 'NO' ELSE 'YES' END AS "DEPOSIT",
        CASE
            WHEN COUNT(DISTINCT ld.refundable) > 1 THEN 'MANY'
            WHEN MAX(CASE WHEN CAST(ld.refundable AS TEXT) = 'true' THEN 1 ELSE 0 END) = 1 THEN 'YES'
            ELSE 'NO'
        END AS "REFUNDABLE",
        t.tenant_name AS "TENANT"
    FROM "reporting"."stg_leases" l
    INNER JOIN "reporting"."stg_lease_units" lu
        ON l.lease_id = lu.lease_id
    LEFT JOIN "reporting"."stg_lease_deposits" ld
        ON l.lease_id = ld.lease_id
    LEFT JOIN "reporting"."stg_tenants" t
        ON l.primary_tenant_id = t.tenant_id
    INNER JOIN "reporting"."stg_properties" p
        ON p.property_id = l.property_id
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
      AND p.prop_name IN (@Property_Name)
    GROUP BY
        l.lease_id,
        l.lease_name,
        lu.unit_id,
        l.lease_created_at,
        l.lease_start,
        l.lease_end,
        CASE WHEN l.lease_raw_status = 'current' THEN 'OCCUPIED' ELSE 'VACANT' END,
        CASE WHEN ld.lease_deposit_id IS NULL THEN 'NO' ELSE 'YES' END,
        t.tenant_name
),

LEASES_CHARGES AS (
    SELECT
        l."LEASE_ID",
        l."LEASE_NAME",
        l."UNIT_ID",
        MIN(l."lease_created_at") AS "lease_created_at",
        MIN(l."start") AS "start",
        MAX(l."lease_end") AS "lease_end",
        l."TENANT",
        COALESCE(MAX(CASE WHEN l."LEASE_STATUS" = 'OCCUPIED' THEN 'OCCUPIED' END), MAX(l."LEASE_STATUS")) AS "LEASE_STATUS",
        COALESCE(MAX(CASE WHEN l."DEPOSIT" = 'YES' THEN 'YES' END), MAX(l."DEPOSIT")) AS "DEPOSIT",
        COALESCE(MAX(CASE WHEN l."REFUNDABLE" = 'YES' THEN 'YES' END), MAX(l."REFUNDABLE")) AS "REFUNDABLE",
        SUM(c."RENT_CHARGE") AS "RENT_CHARGE",
        SUM(c."OTHER_CHARGE") AS "OTHER_CHARGE"
    FROM LEASES l
    LEFT JOIN CHARGES c
        ON l."LEASE_ID" = c."LEASE_ID"
       AND l."UNIT_ID" = c."UNIT_ID"
    GROUP BY
        l."LEASE_ID",
        l."LEASE_NAME",
        l."UNIT_ID",
        l."TENANT"
),

UNITS AS (
    SELECT
        p.property_id AS "PROP_ID",
        p.prop_name AS "PROP_NAME",
        p.company_relation_id AS "COMPANY_RELATION_ID",
        u.unit_id AS "UNIT_ID",
        u.unit_name AS "UNIT_NAME",
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
      AND u.floor_plan IN (@floorPlan)
    GROUP BY
        p.property_id,
        p.prop_name,
        p.company_relation_id,
        u.unit_id,
        u.unit_name
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
        "LEASE_NAME",
        "UNIT_ID",
        "lease_created_at",
        "start",
        "lease_end",
        "TENANT",
        "LEASE_STATUS",
        "DEPOSIT",
        "REFUNDABLE",
        "RENT_CHARGE",
        "OTHER_CHARGE"
    FROM LEASES_CHARGES
    GROUP BY
        "LEASE_ID",
        "LEASE_NAME",
        "UNIT_ID",
        "lease_created_at",
        "start",
        "lease_end",
        "TENANT",
        "LEASE_STATUS",
        "DEPOSIT",
        "REFUNDABLE",
        "RENT_CHARGE",
        "OTHER_CHARGE"
),

FINAL_AUX AS (
    SELECT
        COUNT(DISTINCT "LEASE_ID") AS "LEASES_COUNT",
        "UNIT_ID"
    FROM FINAL
    GROUP BY
        "UNIT_ID"
),

RENT_SCALATIONS AS (
    SELECT
        lrc.lease_id AS "LEASE_ID",
        CASE WHEN cc."BASE_RENT" = 1 THEN 1 ELSE 0 END AS "FLAG_RENT_SCAL",
        CASE WHEN cc."BASE_RENT" = 1 THEN lrca.amount ELSE 0 END AS "RENT_CHARGE_SCAL",
        lrca.effective_date AS "EFFECTIVE_DATE_SCAL",
        u.property_id AS "PROP_ID",
        lrc.unit_id AS "UNIT_ID"
    FROM "reporting"."stg_lease_recurring_charges" lrc
    INNER JOIN LEASES l
        ON lrc.lease_id = l."LEASE_ID"
    LEFT JOIN "reporting"."stg_lease_recurring_charge_amounts" lrca
        ON lrc.recurring_charge_id = lrca.recurring_charge_id
    INNER JOIN "reporting"."stg_units" u
        ON lrc.unit_id = u.unit_id
    INNER JOIN CHARGE_CONTROL cc
        ON cc."PROP_ID" = u.property_id
       AND cc."ITEM_ID" = lrc.item_id
    INNER JOIN "reporting"."stg_properties" p
        ON p.property_id = u.property_id
    WHERE lrca.effective_date > @AsOfDate
      AND lrca.frequency != 'One Time'
      AND (
          lrc.terminate_date > @AsOfDate
          OR lrc.terminate_date IS NULL
      )
      AND p.prop_name IN (@Property_Name)
      AND cc."BASE_RENT" = 1
    GROUP BY
        lrc.lease_id,
        CASE WHEN cc."BASE_RENT" = 1 THEN 1 ELSE 0 END,
        CASE WHEN cc."BASE_RENT" = 1 THEN lrca.amount ELSE 0 END,
        lrca.effective_date,
        u.property_id,
        lrc.unit_id
    ORDER BY
        u.property_id,
        lrc.unit_id,
        lrc.lease_id,
        lrca.effective_date ASC
),

RENT_SCALATIONS_AUX AS (
    SELECT
        rs."PROP_ID",
        rs."UNIT_ID",
        CASE WHEN SUM(rs."FLAG_RENT_SCAL") < 1 THEN 1 ELSE SUM(rs."FLAG_RENT_SCAL") END AS "COUNT_RENT_CHARGE_SCAL"
    FROM RENT_SCALATIONS rs
    GROUP BY
        rs."PROP_ID",
        rs."UNIT_ID",
        rs."LEASE_ID"
),

RENT_SCALATIONS_FINAL AS (
    SELECT
        rs."PROP_ID",
        rs."UNIT_ID",
        rs."LEASE_ID",
        rs."RENT_CHARGE_SCAL",
        rs."EFFECTIVE_DATE_SCAL",
        MAX(rsa."COUNT_RENT_CHARGE_SCAL") AS "COUNT_RENT_CHARGE_SCAL"
    FROM RENT_SCALATIONS rs
    LEFT JOIN RENT_SCALATIONS_AUX rsa
        ON rs."PROP_ID" = rsa."PROP_ID"
       AND rs."UNIT_ID" = rsa."UNIT_ID"
    GROUP BY
        1, 2, 3, 4, 5
)

SELECT
    u."PROP_ID",
    u."PROP_NAME",
    u."UNIT_ID",
    u."UNIT_NAME" AS "UNIT_NAME",
    f."LEASE_ID",
    f."LEASE_NAME",
    CASE WHEN f."lease_created_at" IS NOT NULL THEN 'OCCUPIED' ELSE 'VACANT' END AS "LEASE_STATUS",
    f."TENANT",
    f."start" AS "lease_start",
    f."lease_end",
    u."UNIT_SQ_FT" AS "UNIT_SQ_FT",
    fa."LEASES_COUNT",
    CASE
        WHEN rsf."COUNT_RENT_CHARGE_SCAL" > 1 THEN rsf."COUNT_RENT_CHARGE_SCAL"
        ELSE 1
    END AS "COUNT_RENT_CHARGE_SCAL",
    CASE
        WHEN (fa."LEASES_COUNT" < 2 AND rsf."COUNT_RENT_CHARGE_SCAL" < 2)
          OR (fa."LEASES_COUNT" IS NULL AND rsf."COUNT_RENT_CHARGE_SCAL" IS NULL) THEN u."UNIT_SQ_FT"
        WHEN fa."LEASES_COUNT" > 1 AND rsf."COUNT_RENT_CHARGE_SCAL" IS NULL THEN u."UNIT_SQ_FT" / fa."LEASES_COUNT"
        WHEN rsf."COUNT_RENT_CHARGE_SCAL" > 1 AND fa."LEASES_COUNT" IS NULL THEN u."UNIT_SQ_FT" / rsf."COUNT_RENT_CHARGE_SCAL"
        ELSE u."UNIT_SQ_FT" / (fa."LEASES_COUNT" * COALESCE(rsf."COUNT_RENT_CHARGE_SCAL", 1))
    END AS "UNIT_SQ_FT_fix",
    CASE
        WHEN s."TOT_SQ_FT" = 0 THEN 0
        ELSE u."UNIT_SQ_FT" / s."TOT_SQ_FT" * 100
    END AS "Pct of Property",
    CASE
        WHEN s."TOT_SQ_FT" = 0 THEN 0
        WHEN (fa."LEASES_COUNT" < 2 AND rsf."COUNT_RENT_CHARGE_SCAL" < 2)
          OR (fa."LEASES_COUNT" IS NULL AND rsf."COUNT_RENT_CHARGE_SCAL" IS NULL) THEN u."UNIT_SQ_FT" / s."TOT_SQ_FT" * 100
        WHEN fa."LEASES_COUNT" > 1 AND rsf."COUNT_RENT_CHARGE_SCAL" IS NULL THEN u."UNIT_SQ_FT" / fa."LEASES_COUNT" / s."TOT_SQ_FT" * 100
        WHEN rsf."COUNT_RENT_CHARGE_SCAL" > 1 AND fa."LEASES_COUNT" IS NULL THEN u."UNIT_SQ_FT" / rsf."COUNT_RENT_CHARGE_SCAL" / s."TOT_SQ_FT" * 100
        ELSE u."UNIT_SQ_FT" / (fa."LEASES_COUNT" * COALESCE(rsf."COUNT_RENT_CHARGE_SCAL", 1)) / s."TOT_SQ_FT" * 100
    END AS "Pct of Property_fix",
    f."DEPOSIT",
    f."REFUNDABLE",
    f."RENT_CHARGE" AS "RENT_AMOUNT",
    f."OTHER_CHARGE" AS "OTHER_AMOUNT",
    CASE
        WHEN rsf."COUNT_RENT_CHARGE_SCAL" IS NULL THEN f."RENT_CHARGE"
        ELSE f."RENT_CHARGE" / COALESCE(rsf."COUNT_RENT_CHARGE_SCAL", 1)
    END AS "RENT_AMOUNT_fix",
    CASE
        WHEN rsf."COUNT_RENT_CHARGE_SCAL" IS NULL THEN f."OTHER_CHARGE"
        ELSE f."OTHER_CHARGE" / COALESCE(rsf."COUNT_RENT_CHARGE_SCAL", 1)
    END AS "OTHER_AMOUNT_fix",
    CASE WHEN u."UNIT_SQ_FT" = 0 THEN 0 ELSE f."RENT_CHARGE" * 12 / u."UNIT_SQ_FT" END AS "Annual Rent/Sq Ft",
    CASE WHEN u."UNIT_SQ_FT" = 0 THEN 0 ELSE f."OTHER_CHARGE" * 12 / u."UNIT_SQ_FT" END AS "Annual Other/Sq Ft",
    CASE
        WHEN u."UNIT_SQ_FT" = 0 THEN 0
        ELSE f."RENT_CHARGE" * 12 / u."UNIT_SQ_FT" / COALESCE(rsf."COUNT_RENT_CHARGE_SCAL", 1)
    END AS "Annual Rent/Sq Ft_fix",
    CASE
        WHEN u."UNIT_SQ_FT" = 0 THEN 0
        ELSE f."OTHER_CHARGE" * 12 / u."UNIT_SQ_FT" / COALESCE(rsf."COUNT_RENT_CHARGE_SCAL", 1)
    END AS "Annual Other/Sq Ft_fix",
    rsf."RENT_CHARGE_SCAL",
    rsf."EFFECTIVE_DATE_SCAL"
FROM UNITS u
LEFT JOIN SQ_FT_TEMP s
    ON u."PROP_ID" = s."PROP_ID"
LEFT JOIN FINAL f
    ON u."UNIT_ID" = f."UNIT_ID"
LEFT JOIN FINAL_AUX fa
    ON f."UNIT_ID" = fa."UNIT_ID"
LEFT JOIN RENT_SCALATIONS_FINAL rsf
    ON rsf."PROP_ID" = u."PROP_ID"
   AND rsf."UNIT_ID" = u."UNIT_ID"
   AND rsf."LEASE_ID" = f."LEASE_ID"
LEFT JOIN "reporting"."stg_leases" l
    ON f."LEASE_ID" = l.lease_id
WHERE u."PROP_NAME" IN (@Property_Name)
  AND u."COMPANY_RELATION_ID" = CAST(@REAL_COMPANY_ID AS INT)
  AND CASE WHEN CAST(l.month_to_month_flag AS TEXT) = 'true' THEN 'True' ELSE 'False' END IN (@month_to_month)
ORDER BY
    u."PROP_NAME",
    natural_sort(u."UNIT_NAME"),
    rsf."EFFECTIVE_DATE_SCAL" ASC;
