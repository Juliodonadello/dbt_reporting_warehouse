WITH LEASES AS (
	SELECT *
	FROM {{ ref('int_mixed_leases_units_all') }}
),
CHARGES AS (
	SELECT
		CHARGES_."recurring_charge_id" AS "RCHARGE_ID",
		CHARGES_."lease_id" AS "LEASE_ID",
		CHARGES_."unit_id" AS "UNIT_ID",
		CHARGES_."property_id" AS "PROP_ID",
		CHARGES_."item_id" AS "ITEM_ID",
		CHARGES_."frequency" AS "FREQUENCY",
		CHARGES_."charge_valid_from" AS "EFFECTIVE_DATE",
		CHARGES_."rent_charge" AS "RENT_CHARGE",
		CHARGES_."other_charge" AS "OTHER_CHARGE",
		CASE
			WHEN CHARGES_."frequency" = 'One Time'
				THEN CHARGES_."charge_valid_from" + 1
			ELSE CHARGES_."charge_valid_from"
		END AS "_valid_from",
		LEAST(
			CHARGES_."charge_valid_to",
			COALESCE(CHARGES_."terminate_date" + 1, date '9999-12-31'),
			COALESCE(CAST(CHARGES_."one_time_window_end" AS date), date '9999-12-31')
		) AS "_valid_to"
	FROM {{ ref('int_charges_effective_ranges') }} CHARGES_
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
		"PROP_ID",
		"PROP_NAME",
		"UNIT_ID",
		"UNIT_NAME",
		"UNIT_SQ_FT",
		"LEASE_ID",
		"LEASE_NAME",
		"lease_created_at",
		"lease_start",
		"unit_move_in",
		"lease_end",
		"LEASE_TERMINATION",
		"LEASE_RAW_STATUS",
		"LEASE_STATUS",
		"UNIT_STATUS",
		"DEPOSIT",
		"REFUNDABLE",
		"TENANT_NAME",
		"company_relation_id",
		"month_to_month",
		"month_to_month_label",
		"boundary_date" AS "_valid_from",
		LEAD("boundary_date") OVER (
			PARTITION BY "LEASE_ID", "UNIT_ID", "LEASE_VALID_FROM", "LEASE_VALID_TO"
			ORDER BY "boundary_date"
		) AS "_valid_to"
	FROM (
		SELECT DISTINCT
			"PROP_ID",
			"PROP_NAME",
			"UNIT_ID",
			"UNIT_NAME",
			"UNIT_SQ_FT",
			"LEASE_ID",
			"LEASE_NAME",
			"lease_created_at",
			"lease_start",
			"unit_move_in",
			"lease_end",
			"LEASE_TERMINATION",
			"LEASE_RAW_STATUS",
			"LEASE_STATUS",
			"UNIT_STATUS",
			"DEPOSIT",
			"REFUNDABLE",
			"TENANT_NAME",
			"company_relation_id",
			"month_to_month",
			"month_to_month_label",
			"_valid_from" AS "LEASE_VALID_FROM",
			"_valid_to" AS "LEASE_VALID_TO",
			"boundary_date"
		FROM BOUNDARIES
	) AS BOUNDARIES_DISTINCT
),
LEASES_CHARGES AS (
	SELECT
		PERIODS."PROP_ID" AS "PROP_ID",
		PERIODS."PROP_NAME" AS "PROP_NAME",
		PERIODS."UNIT_ID" AS "UNIT_ID",
		PERIODS."UNIT_NAME" AS "UNIT_NAME",
		PERIODS."UNIT_SQ_FT" AS "UNIT_SQ_FT",
		PERIODS."LEASE_ID" AS "LEASE_ID",
		PERIODS."LEASE_NAME" AS "LEASE_NAME",
		PERIODS."lease_created_at" AS "lease_created_at",
		PERIODS."lease_start" AS "lease_start",
		PERIODS."unit_move_in" AS "unit_move_in",
		PERIODS."lease_end" AS "lease_end",
		PERIODS."LEASE_TERMINATION" AS "LEASE_TERMINATION",
		PERIODS."LEASE_RAW_STATUS" AS "LEASE_RAW_STATUS",
		PERIODS."LEASE_STATUS" AS "LEASE_STATUS",
		PERIODS."UNIT_STATUS" AS "UNIT_STATUS",
		PERIODS."DEPOSIT" AS "DEPOSIT",
		PERIODS."REFUNDABLE" AS "REFUNDABLE",
		PERIODS."TENANT_NAME" AS "TENANT_NAME",
		PERIODS."company_relation_id" AS "company_relation_id",
		PERIODS."month_to_month" AS "month_to_month",
		PERIODS."month_to_month_label" AS "month_to_month_label",
		COALESCE(SUM(CASE WHEN CHARGES."FREQUENCY" = 'Annually' THEN CHARGES."RENT_CHARGE" / 12 ELSE CHARGES."RENT_CHARGE" END), 0) AS "RENT_AMOUNT",
		COALESCE(SUM(CASE WHEN CHARGES."FREQUENCY" = 'Annually' THEN CHARGES."OTHER_CHARGE" / 12 ELSE CHARGES."OTHER_CHARGE" END), 0) AS "OTHER_AMOUNT",
		COALESCE(SUM(CASE WHEN CHARGES."FREQUENCY" = 'Annually' THEN CHARGES."RENT_CHARGE" ELSE CHARGES."RENT_CHARGE" * 12 END), 0) AS "ANNUAL_RENT_AMOUNT",
		COALESCE(SUM(CASE WHEN CHARGES."FREQUENCY" = 'Annually' THEN CHARGES."OTHER_CHARGE" ELSE CHARGES."OTHER_CHARGE" * 12 END), 0) AS "ANNUAL_OTHER_AMOUNT",
		PERIODS."_valid_from" AS "_valid_from",
		PERIODS."_valid_to" AS "_valid_to"
	FROM PERIODS
	LEFT OUTER JOIN CHARGES
		ON PERIODS."LEASE_ID" = CHARGES."LEASE_ID"
		AND PERIODS."UNIT_ID" = CHARGES."UNIT_ID"
		AND PERIODS."_valid_from" < CHARGES."_valid_to"
		AND PERIODS."_valid_to" > CHARGES."_valid_from"
	WHERE PERIODS."_valid_to" IS NOT NULL
	AND PERIODS."_valid_from" < PERIODS."_valid_to"
	GROUP BY
		PERIODS."PROP_ID",
		PERIODS."PROP_NAME",
		PERIODS."UNIT_ID",
		PERIODS."UNIT_NAME",
		PERIODS."UNIT_SQ_FT",
		PERIODS."LEASE_ID",
		PERIODS."LEASE_NAME",
		PERIODS."lease_created_at",
		PERIODS."lease_start",
		PERIODS."unit_move_in",
		PERIODS."lease_end",
		PERIODS."LEASE_TERMINATION",
		PERIODS."LEASE_RAW_STATUS",
		PERIODS."LEASE_STATUS",
		PERIODS."UNIT_STATUS",
		PERIODS."DEPOSIT",
		PERIODS."REFUNDABLE",
		PERIODS."TENANT_NAME",
		PERIODS."company_relation_id",
		PERIODS."month_to_month",
		PERIODS."month_to_month_label",
		PERIODS."_valid_from",
		PERIODS."_valid_to"
)

select *
from LEASES_CHARGES
