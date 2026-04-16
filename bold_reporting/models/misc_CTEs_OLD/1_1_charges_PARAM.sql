WITH CHARGE_CONTROL AS (
  	SELECT 
  			PROPS_."id" AS "PROP_ID",
  			PROPS_C."item_id" as "ITEM_ID",
  			CASE WHEN PROPS_C."base_rent" then 1 else 0 end as "BASE_RENT"
  		
  	FROM {{ var('properties_table') }} PROPS_
  	INNER JOIN {{ var('property_charge_controls_table') }} PROPS_C
  		ON PROPS_C."property_id" = PROPS_."id"
  	
  	WHERE PROPS_."name" IN (@Property_Name)
	AND CAST(PROPS_."company_relation_id" AS INT)  = CAST(@REAL_COMPANY_ID AS INT)
	),
CHARGES_TOT AS (
  SELECT 
		MAX("recurring_charge_id") AS "RCHARGE_ID",
  		LEASES_RC."lease_id" AS "LEASE_ID",
		CASE WHEN CHARGE_CONTROL. "BASE_RENT" = 1 THEN LEASES_RC_A."amount" ELSE 0 END AS "RENT_CHARGE",
  		CASE WHEN CHARGE_CONTROL. "BASE_RENT" = 0 THEN LEASES_RC_A."amount" ELSE 0 END AS "OTHER_CHARGE",
  		LEASES_RC_A."effective_date" AS "EFFECTIVE_DATE",
  		UNITS_."property_id" "PROP_ID",
  		LEASES_RC."unit_id" "UNIT_ID",
		LEASES_RC_A."frequency" "FREQUENCY"
  
	FROM {{ var('lease_recurring_charges_table') }} LEASES_RC
	LEFT OUTER JOIN {{ var('lease_recurring_charge_amounts_table') }} LEASES_RC_A
		ON LEASES_RC."id" = LEASES_RC_A."recurring_charge_id"
 	INNER JOIN {{ var('units_table') }} UNITS_
  		ON LEASES_RC."unit_id" =  UNITS_."id"
  	INNER JOIN CHARGE_CONTROL
  		ON CHARGE_CONTROL. "PROP_ID" = UNITS_."property_id"
  		AND CHARGE_CONTROL. "ITEM_ID" = LEASES_RC."order_entry_item_id"
  
  	WHERE LEASES_RC_A."effective_date" <= @AsOfDate
	AND (
		LEASES_RC_A."deleted_at" >= @AsOfDate 
		OR 
		LEASES_RC_A."deleted_at" IS NULL
		)
	AND (
		LEASES_RC."deleted_at" >= @AsOfDate
		OR
		LEASES_RC."deleted_at" IS NULL
		)
	AND (
		LEASES_RC_A."frequency" != 'One Time' --not a one time charge
		OR
		(
			LEASES_RC_A."frequency" = 'One Time'
			AND	 CAST(EXTRACT(DAY FROM (@AsOfDate - LEASES_RC_A."effective_date")) AS INTEGER) > 0
		  	AND CAST(EXTRACT(DAY FROM (@AsOfDate - LEASES_RC_A."effective_date")) AS INTEGER) < 31
		)--one time charge with less than a month differnce OJO: VER SI NO HAY QUE SACAR EL EXTRACT DAY. Ya que falla para los que son de un mes o un año exacto
		)
	AND (	
	  	LEASES_RC."terminate_date" >= @AsOfDate
		OR
		LEASES_RC."terminate_date" is NULL 
		)
		
	GROUP BY 
		LEASES_RC."lease_id",
		CASE WHEN CHARGE_CONTROL. "BASE_RENT" = 1 THEN LEASES_RC_A."amount" ELSE 0 END ,
		CASE WHEN CHARGE_CONTROL. "BASE_RENT" = 0 THEN LEASES_RC_A."amount" ELSE 0 END,
		LEASES_RC_A."effective_date",
		UNITS_."property_id",
		LEASES_RC."unit_id",
		LEASES_RC_A."frequency"
	),
MAX_CHARGES AS (
 	SELECT  "RCHARGE_ID" "RCHARGE_ID",
   	MAX("EFFECTIVE_DATE") "EFFECTIVE_DATE"
 	FROM CHARGES_TOT
	GROUP BY "RCHARGE_ID"
 ),
CHARGES AS ( 
 SELECT CHARGES_TOT.*
 FROM CHARGES_TOT
 INNER JOIN MAX_CHARGES
 	ON CHARGES_TOT."RCHARGE_ID" =  MAX_CHARGES."RCHARGE_ID" 
	AND CHARGES_TOT."EFFECTIVE_DATE" =  MAX_CHARGES."EFFECTIVE_DATE"
  GROUP BY 
  CHARGES_TOT."RCHARGE_ID",
  CHARGES_TOT."LEASE_ID",
  CHARGES_TOT."RENT_CHARGE",
  CHARGES_TOT."OTHER_CHARGE",
  CHARGES_TOT."EFFECTIVE_DATE",
  CHARGES_TOT."PROP_ID",
  CHARGES_TOT."UNIT_ID",
  CHARGES_TOT."FREQUENCY"
)

select *
from CHARGES
