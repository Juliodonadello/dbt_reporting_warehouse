WITH LEASES AS (
	SELECT *
	FROM {{ ref('2_all_leases') }}
),
CHARGES AS (
	SELECT
		"LEASE_ID",
		"UNIT_ID",
		"FREQUENCY",
		CASE WHEN "BASE_RENT" = 1 THEN "AMOUNT" ELSE 0 END AS "RENT_CHARGE",
		CASE WHEN "BASE_RENT" = 0 THEN "AMOUNT" ELSE 0 END AS "OTHER_CHARGE",
		"_valid_from",
		"_valid_to"
	FROM {{ ref('1_all_charges_amounts') }}
),
BOUNDARIES AS (
	SELECT
		LEASES.*,
		LEASES."_valid_from" AS "boundary_date"
	FROM LEASES

	UNION ALL

	SELECT
		LEASES.*,
		LEASES."_valid_to" AS "boundary_date"
	FROM LEASES

	UNION ALL

	SELECT
		LEASES.*,
		GREATEST(LEASES."_valid_from", CHARGES."_valid_from") AS "boundary_date"
	FROM LEASES
	INNER JOIN CHARGES
		ON LEASES."LEASE_ID" = CHARGES."LEASE_ID"
  		AND LEASES."UNIT_ID" = CHARGES."UNIT_ID"
		AND LEASES."_valid_from" < CHARGES."_valid_to"
		AND LEASES."_valid_to" > CHARGES."_valid_from"

	UNION ALL

	SELECT
		LEASES.*,
		LEAST(LEASES."_valid_to", CHARGES."_valid_to") AS "boundary_date"
	FROM LEASES
	INNER JOIN CHARGES
		ON LEASES."LEASE_ID" = CHARGES."LEASE_ID"
  		AND LEASES."UNIT_ID" = CHARGES."UNIT_ID"
		AND LEASES."_valid_from" < CHARGES."_valid_to"
		AND LEASES."_valid_to" > CHARGES."_valid_from"
),
PERIODS AS (
	SELECT
		"LEASE_ID",
		"LEASE_NAME",
		"UNIT_ID",
		"lease_created_at",
		"lease_start",
		"lease_end",
		"ACTUAL_MOVE_OUT",
		"INTENDED_MOVE_OUT",
		"REASON_FOR_TERMINATION",
		"company_relation_id",
		"PROP_ID",
		"LEASE_STATUS",
		"DEPOSIT",
		"REFUNDABLE",
		"TENANT_NAME",
		"month_to_month",
		"boundary_date" AS "_valid_from",
		LEAD("boundary_date") OVER (
			PARTITION BY "LEASE_ID", "UNIT_ID", LEASES_VALID_FROM, LEASES_VALID_TO
			ORDER BY "boundary_date"
		) AS "_valid_to"
	FROM (
		SELECT DISTINCT
			"LEASE_ID",
			"LEASE_NAME",
			"UNIT_ID",
			"lease_created_at",
			"lease_start",
			"lease_end",
			"ACTUAL_MOVE_OUT",
			"INTENDED_MOVE_OUT",
			"REASON_FOR_TERMINATION",
			"company_relation_id",
			"PROP_ID",
			"LEASE_STATUS",
			"DEPOSIT",
			"REFUNDABLE",
			"TENANT_NAME",
			"month_to_month",
			"_valid_from" AS LEASES_VALID_FROM,
			"_valid_to" AS LEASES_VALID_TO,
			"boundary_date"
		FROM BOUNDARIES
	) AS BOUNDARIES_DISTINCT
),
LEASES_CHARGES AS (
	SELECT
  		PERIODS."LEASE_ID",
		PERIODS."UNIT_ID",
		MIN(PERIODS."lease_created_at") "lease_created_at", --because of difference in seconds, can't be grouped
  		MIN(PERIODS."lease_start") "start",
		MAX(PERIODS."lease_end") "lease_end", --because of difference in seconds, can't be grouped
  		PERIODS."TENANT_NAME" AS "TENANT",
  		COALESCE(MAX(CASE WHEN PERIODS."LEASE_STATUS" = 'current' THEN 'OCCUPIED' END), MAX(PERIODS."LEASE_STATUS")) AS "LEASE_STATUS",
  		COALESCE(MAX(CASE WHEN PERIODS."DEPOSIT" = 'YES' THEN 'YES' END), MAX(PERIODS."DEPOSIT")) AS "DEPOSIT",
  		COALESCE(MAX(CASE WHEN PERIODS."REFUNDABLE" = 'YES' THEN 'YES' END), MAX(PERIODS."REFUNDABLE")) AS "REFUNDABLE",
  		COALESCE(SUM(CASE WHEN CHARGES."FREQUENCY" = 'Annually' THEN CHARGES."RENT_CHARGE" / 12 ELSE CHARGES."RENT_CHARGE" END), 0) AS "RENT_AMOUNT",
  		COALESCE(SUM(CASE WHEN CHARGES."FREQUENCY" = 'Annually' THEN CHARGES."OTHER_CHARGE" / 12 ELSE CHARGES."OTHER_CHARGE" END), 0) AS "OTHER_AMOUNT",
		COALESCE(SUM(CASE WHEN CHARGES."FREQUENCY" = 'Annually' THEN CHARGES."RENT_CHARGE" ELSE CHARGES."RENT_CHARGE" * 12 END), 0) AS "ANNUAL_RENT_AMOUNT",
  		COALESCE(SUM(CASE WHEN CHARGES."FREQUENCY" = 'Annually' THEN CHARGES."OTHER_CHARGE" ELSE CHARGES."OTHER_CHARGE" * 12 END), 0) AS "ANNUAL_OTHER_AMOUNT",
		PERIODS."_valid_from",
		PERIODS."_valid_to"

	FROM PERIODS
	LEFT JOIN CHARGES
		ON PERIODS."LEASE_ID" = CHARGES."LEASE_ID"
  		AND PERIODS."UNIT_ID" = CHARGES."UNIT_ID"
		AND PERIODS."_valid_from" < CHARGES."_valid_to"
		AND PERIODS."_valid_to" > CHARGES."_valid_from"
	WHERE PERIODS."_valid_to" IS NOT NULL
	AND PERIODS."_valid_from" < PERIODS."_valid_to"
	GROUP BY PERIODS."LEASE_ID",
		PERIODS."UNIT_ID",
		PERIODS."TENANT_NAME",
		PERIODS."_valid_from",
		PERIODS."_valid_to"
)

select *
from LEASES_CHARGES
