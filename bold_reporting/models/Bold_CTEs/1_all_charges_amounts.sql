{{ config(materialized='table') }}

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
		UNITS_."property_id" as "PROP_ID",
  		LEASES_RC."unit_id" as "UNIT_ID",
		UNITS_."name" as "UNIT_NAME",
  		LEASES_RC."lease_id" AS "LEASE_ID",
		LEASES_RC."recurring_charge_id" AS "RCHARGE_ID",
		LEASES_RC_A."amount" as "AMOUNT",
  		LEASES_RC_A."effective_date" AS "EFFECTIVE_DATE",
		CHARGE_CONTROL."BASE_RENT" as "BASE_RENT",  		
		LEASES_RC_A."frequency" as "FREQUENCY"
  
	FROM {{ var('lease_recurring_charges_table') }} LEASES_RC
	LEFT OUTER JOIN {{ var('lease_recurring_charge_amounts_table') }} LEASES_RC_A
		ON LEASES_RC."id" = LEASES_RC_A."recurring_charge_id"
 	INNER JOIN {{ var('units_table') }} UNITS_
  		ON LEASES_RC."unit_id" =  UNITS_."id"
  	INNER JOIN CHARGE_CONTROL
  		ON CHARGE_CONTROL. "PROP_ID" = UNITS_."property_id"
  		AND CHARGE_CONTROL. "ITEM_ID" = LEASES_RC."order_entry_item_id"
  
  	WHERE (LEASES_RC_A."deleted_at" IS NULL)
	AND (LEASES_RC."deleted_at" IS NULL)
)

select *
from CHARGES_TOT