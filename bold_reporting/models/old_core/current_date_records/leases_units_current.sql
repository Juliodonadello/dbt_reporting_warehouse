WITH LEASES_UNITS AS (
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
	LEASES."LEASE_STATUS" AS "LEASE_STATUS",
	CASE WHEN LEASES."LEASE_STATUS" = 'current' THEN 'OCCUPIED' ELSE 'VACANT' END AS "UNIT_STATUS",
	LEASES."DEPOSIT" AS "DEPOSIT",
	LEASES."REFUNDABLE" AS "REFUNDABLE",
	LEASES."TENANT_NAME" AS "TENANT_NAME",
	LEASES."company_relation_id" as "company_relation_id",
	GREATEST(
		LEASES."_valid_from",
		COALESCE(UNITS."_valid_from", LEASES."_valid_from")
	) AS "_valid_from",
	LEAST(
		LEASES."_valid_to",
		COALESCE(UNITS."_valid_to", LEASES."_valid_to")
	) AS "_valid_to"

	FROM  {{ ref('current_leases') }} as LEASES
	LEFT JOIN  {{ ref('current_units') }} as UNITS
		ON  UNITS."UNIT_ID" = LEASES."UNIT_ID"
		AND UNITS."PROP_ID" = LEASES."PROP_ID"
		AND UNITS."_valid_from" < LEASES."_valid_to"
		AND UNITS."_valid_to" > LEASES."_valid_from"

	)

select *
from LEASES_UNITS AS A
where "_valid_from" < "_valid_to"
--WHERE A.company_relation_id = (SELECT COMPANY_ACCOUNTS.id
--                      FROM {{ var('company_accounts') }} AS COMPANY_ACCOUNTS
--                      WHERE (COMPANY_ACCOUNTS.db_user = (CURRENT_USER)::text))
