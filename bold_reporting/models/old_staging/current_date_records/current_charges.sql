WITH CHARGES AS (
	SELECT *
	FROM {{ ref('1_all_charges_amounts') }}
	WHERE CURRENT_DATE >= "_valid_from"
	AND CURRENT_DATE < "_valid_to"
)

select *
from CHARGES
