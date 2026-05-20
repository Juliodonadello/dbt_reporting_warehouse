WITH LEASES_UNITS AS (
	SELECT
		COALESCE(UNITS_."property_id", LEASES."property_id") AS "PROP_ID",
		PROPS_."prop_name" AS "PROP_NAME",
		LEASES."unit_id" AS "UNIT_ID",
		UNITS_."unit_name" AS "UNIT_NAME",
		UNIT_SQFT."unit_sq_ft" AS "UNIT_SQ_FT",
		LEASES."lease_id" AS "LEASE_ID",
		LEASES."lease_name" AS "LEASE_NAME",
		LEASES."lease_created_at" AS "lease_created_at",
		LEASES."lease_start" AS "lease_start",
		LEASES."unit_move_in" AS "unit_move_in",
		LEASES."lease_end" AS "lease_end",
		LEASES."lease_termination" AS "LEASE_TERMINATION",
		LEASES."lease_raw_status" AS "LEASE_RAW_STATUS",
		LEASES."lease_status" AS "LEASE_STATUS",
		LEASES."lease_status" AS "UNIT_STATUS",
		LEASES."deposit" AS "DEPOSIT",
		LEASES."refundable" AS "REFUNDABLE",
		LEASES."tenant" AS "TENANT_NAME",
		PROPS_."company_relation_id" AS "company_relation_id",
		LEASES."month_to_month_flag" AS "month_to_month",
		LEASES."month_to_month_label" AS "month_to_month_label",
		GREATEST(
			LEASES."lease_valid_from",
			COALESCE(UNIT_SQFT."valid_from", LEASES."lease_valid_from")
		) AS "_valid_from",
		LEAST(
			LEASES."lease_valid_to",
			COALESCE(UNIT_SQFT."valid_to", LEASES."lease_valid_to")
		) AS "_valid_to"
	FROM {{ ref('int_leases_enriched') }} LEASES
	LEFT OUTER JOIN {{ ref('stg_units') }} UNITS_
		ON LEASES."unit_id" = UNITS_."unit_id"
	LEFT OUTER JOIN {{ ref('stg_properties') }} PROPS_
		ON COALESCE(UNITS_."property_id", LEASES."property_id") = PROPS_."property_id"
	LEFT OUTER JOIN {{ ref('int_unit_sqft_ranges') }} UNIT_SQFT
		ON LEASES."unit_id" = UNIT_SQFT."unit_id"
		AND COALESCE(UNITS_."property_id", LEASES."property_id") = UNIT_SQFT."property_id"
		AND LEASES."lease_valid_from" < UNIT_SQFT."valid_to"
		AND LEASES."lease_valid_to" > UNIT_SQFT."valid_from"
)

select *
from LEASES_UNITS
where "_valid_from" < "_valid_to"
