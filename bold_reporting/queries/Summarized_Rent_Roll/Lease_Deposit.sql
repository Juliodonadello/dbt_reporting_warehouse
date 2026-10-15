WITH DEPOSITS AS (
    SELECT
        ld.deposit_type AS "D_type",
        CASE WHEN ld.refundable IS TRUE THEN 'YES' ELSE 'NO' END AS "D_refundable",
        ld.invoice_number AS "D_invoice_number",
        u.unit_name AS "D_unit_name",
        ld.lease_id AS "D_lease_id",
        ld.lease_deposit_id AS "deposit_id"
    FROM "reporting"."stg_lease_deposits" ld
    INNER JOIN "reporting"."stg_units" u
        ON ld.unit_id = u.unit_id
    INNER JOIN "reporting"."stg_properties" p
        ON p.property_id = u.property_id
    WHERE p.prop_name IN (@Property_Name)
      AND p.company_relation_id = CAST(@REAL_COMPANY_ID AS INT)
),

DEPOSITS_REFUNDS AS (
    SELECT
        ldr.lease_deposit_id,
        SUM(ldr.amount) AS "REFUNDED_AMOUNT"
    FROM "reporting"."stg_lease_deposit_refunds" ldr
    INNER JOIN DEPOSITS d
        ON ldr.lease_deposit_id = d."deposit_id"
    GROUP BY
        ldr.lease_deposit_id
)

SELECT
    d.*,
    dr."REFUNDED_AMOUNT"
FROM DEPOSITS d
LEFT JOIN DEPOSITS_REFUNDS dr
    ON dr.lease_deposit_id = d."deposit_id"
ORDER BY
    d."D_lease_id";
