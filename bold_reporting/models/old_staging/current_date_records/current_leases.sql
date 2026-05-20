WITH LEASES AS (
	SELECT *
	FROM {{ ref('2_all_leases') }}
	WHERE CURRENT_DATE >= "_valid_from"
	AND CURRENT_DATE < "_valid_to"
)

select *
from LEASES AS A
--WHERE A.company_relation_id = (SELECT COMPANY_ACCOUNTS.id
--                      FROM {{ var('company_accounts') }} AS COMPANY_ACCOUNTS
--                      WHERE (COMPANY_ACCOUNTS.db_user = (CURRENT_USER)::text))
