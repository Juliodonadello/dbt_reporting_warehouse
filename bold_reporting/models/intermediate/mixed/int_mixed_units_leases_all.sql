WITH UNITS_BASE AS (
	SELECT
		PROPS_."property_id" AS "PROP_ID",
		PROPS_."prop_name" AS "PROP_NAME",
		UNITS_."unit_id" AS "UNIT_ID",
		UNITS_."unit_name" AS "UNIT_NAME",
		UNIT_SQFT."unit_sq_ft" AS "UNIT_SQ_FT",
		PROPS_."company_relation_id" AS "company_relation_id",
		UNIT_SQFT."valid_from" AS "_valid_from",
		UNIT_SQFT."valid_to" AS "_valid_to"
	FROM {{ ref('stg_units') }} UNITS_
	INNER JOIN {{ ref('stg_properties') }} PROPS_
		ON UNITS_."property_id" = PROPS_."property_id"
	INNER JOIN {{ ref('int_unit_sqft_ranges') }} UNIT_SQFT
		ON UNITS_."unit_id" = UNIT_SQFT."unit_id"
		AND UNITS_."property_id" = UNIT_SQFT."property_id"
	WHERE UNITS_."deleted_at" IS NULL
	AND PROPS_."deleted_at" IS NULL
),
UNITS_LEASES AS (
	SELECT
		UNITS."PROP_ID" AS "PROP_ID",
		UNITS."PROP_NAME" AS "PROP_NAME",
		UNITS."UNIT_ID" AS "UNIT_ID",
		UNITS."UNIT_NAME" AS "UNIT_NAME",
		UNITS."UNIT_SQ_FT" AS "UNIT_SQ_FT",
		LEASES."lease_id" AS "LEASE_ID",
		LEASES."lease_name" AS "LEASE_NAME",
		LEASES."lease_created_at" AS "lease_created_at",
		LEASES."lease_start" AS "lease_start",
		LEASES."unit_move_in" AS "unit_move_in",
		LEASES."lease_end" AS "lease_end",
		LEASES."lease_termination" AS "LEASE_TERMINATION",
		LEASES."lease_raw_status" AS "LEASE_RAW_STATUS",
		LEASES."lease_status" AS "LEASE_STATUS",
		CASE
			WHEN LEASES."lease_id" IS NOT NULL THEN LEASES."lease_status"
			ELSE 'VACANT'
		END AS "UNIT_STATUS",
		LEASES."deposit" AS "DEPOSIT",
		LEASES."refundable" AS "REFUNDABLE",
		LEASES."tenant" AS "TENANT_NAME",
		UNITS."company_relation_id" AS "company_relation_id",
		LEASES."month_to_month_flag" AS "month_to_month",
		LEASES."month_to_month_label" AS "month_to_month_label",
		GREATEST(
			UNITS."_valid_from",
			COALESCE(LEASES."lease_valid_from", UNITS."_valid_from")
		) AS "_valid_from",
		LEAST(
			UNITS."_valid_to",
			COALESCE(LEASES."lease_valid_to", UNITS."_valid_to")
		) AS "_valid_to"
	FROM UNITS_BASE UNITS
	LEFT OUTER JOIN {{ ref('int_leases_enriched') }} LEASES
		ON UNITS."UNIT_ID" = LEASES."unit_id"
		AND UNITS."PROP_ID" = LEASES."property_id"
		AND UNITS."_valid_from" < LEASES."lease_valid_to"
		AND UNITS."_valid_to" > LEASES."lease_valid_from"
)

select *
from UNITS_LEASES
where "_valid_from" < "_valid_to"
