WITH UNITS AS (
	SELECT
		"PROP_ID",
		"PROP_NAME",
		"UNIT_ID",
		"UNIT_NAME",
		"company_relation_id",
		COALESCE("UNIT_SF_VALUE", "UNIT_TOTAL_SQ_FT") AS "UNIT_SQ_FT",
		"_valid_from",
		"_valid_to"
	FROM {{ ref('3_all_units_sqft') }}
	WHERE "UNIT_SF_TYPE" = 'Total'
),
UNITS_LEASES AS (
	SELECT
	UNITS."PROP_ID" AS "PROP_ID",
    UNITS."PROP_NAME" AS "PROP_NAME",
    UNITS."UNIT_ID" AS "UNIT_ID",
    UNITS."UNIT_NAME" AS "UNIT_NAME",
    UNITS."UNIT_SQ_FT" AS "UNIT_SQ_FT",
	LEASES."LEASE_ID" AS "LEASE_ID",
	LEASES."LEASE_NAME" AS "LEASE_NAME",
	LEASES."lease_created_at" AS "lease_created_at",
	LEASES."lease_start" AS "lease_start",
	LEASES."lease_end" AS "lease_end",
	LEASES."ACTUAL_MOVE_OUT" AS "ACTUAL_MOVE_OUT",
	LEASES."INTENDED_MOVE_OUT" AS "INTENDED_MOVE_OUT",
	LEASES."REASON_FOR_TERMINATION" AS "REASON_FOR_TERMINATION",
	COALESCE(LEASES."company_relation_id", UNITS."company_relation_id") AS "company_relation_id",
	LEASES."LEASE_STATUS" AS "LEASE_STATUS",
	CASE
		WHEN LEASES."LEASE_ID" IS NOT NULL AND LEASES."LEASE_STATUS" = 'current' THEN 'OCCUPIED'
		ELSE 'VACANT'
	END AS "UNIT_STATUS",
	LEASES."DEPOSIT" AS "DEPOSIT",
	LEASES."REFUNDABLE" AS "REFUNDABLE",
	LEASES."TENANT_NAME" AS "TENANT_NAME",
	GREATEST(
		UNITS."_valid_from",
		COALESCE(LEASES."_valid_from", UNITS."_valid_from")
	) AS "_valid_from",
	LEAST(
		UNITS."_valid_to",
		COALESCE(LEASES."_valid_to", UNITS."_valid_to")
	) AS "_valid_to"

	FROM  UNITS
	LEFT JOIN  {{ ref('2_all_leases') }} as LEASES
		ON  UNITS."UNIT_ID" = LEASES."UNIT_ID"
		AND UNITS."PROP_ID" = LEASES."PROP_ID"
		AND UNITS."_valid_from" < LEASES."_valid_to"
		AND UNITS."_valid_to" > LEASES."_valid_from"

	--WHERE LEASES."LEASE_STATUS" = 'current'

	--GROUP BY LEASES."LEASE_ID",
	--	LEASES."UNIT_ID",
	--	LEASES."TENANT_NAME"
	)

select *
from UNITS_LEASES
where "_valid_from" < "_valid_to"
