WITH CHARGES_CPI_TOT AS (
  SELECT 
		"reporting"."stg_lease_recurring_charges"."recurring_charge_id" AS "RCHARGE_ID",
  		"reporting"."stg_lease_recurring_charges"."lease_id" AS "LEASE_ID",
  		"reporting"."stg_lease_recurring_charges"."item_id" "ITEM_ID",
  		"reporting"."stg_units"."property_id" "PROP_ID",
  		"reporting"."stg_lease_recurring_charges"."unit_id" "UNIT_ID",
  		
  		"reporting"."stg_cpi_history"."cpi_history_created_at" "cpi_history_created_at",
  		("reporting"."stg_cpi_history"."charges_detail" ->> 'newChargeAmount')::NUMERIC(10,2)  AS "newChargeAmount",
  		("reporting"."stg_cpi_history"."charges_detail" ->> 'previousChargeAmount')::NUMERIC(10,2)  AS "previousChargeAmount",
  		"reporting"."stg_cpi_history"."charges_detail" ->> 'finalAdjustmentAmount' AS "finalAdjustmentAmount",
    	("reporting"."stg_cpi_history"."calculation_details" ->> 'currentCPIDate')::timestamptz AS "current_cpi_date",
  		("reporting"."stg_cpi_history"."calculation_details" ->> 'previousCPIDate')::timestamptz AS "previous_cpi_date",
  		
  		"reporting"."stg_lease_recurring_charge_cpi_controls"."next_adjustment_date" AS "next_cpi_date",
  		"reporting"."stg_lease_recurring_charge_cpi_controls"."index_1" AS "index_1",
  		"reporting"."stg_lease_recurring_charge_cpi_controls"."area_1" AS "area_1",
  		"reporting"."stg_lease_recurring_charge_cpi_controls"."floor_percent" AS "floor_percent",
		
  		"reporting"."stg_properties"."prop_name" as "PROP_NAME",
  		"reporting"."stg_units"."unit_name" as "UNIT_NAME",
  		"reporting"."stg_leases"."lease_name" as "LEASE_NAME",
  		"reporting"."stg_tenants"."tenant_name" as "TENANT_NAME"
  
	FROM "reporting"."stg_lease_recurring_charges"
 	 INNER JOIN "reporting"."stg_units" ON "reporting"."stg_lease_recurring_charges"."unit_id" =  "reporting"."stg_units"."unit_id"
  	INNER JOIN "reporting"."stg_properties" ON "reporting"."stg_properties"."property_id" = "reporting"."stg_units"."property_id"
  	INNER JOIN "reporting"."stg_leases" ON "reporting"."stg_lease_recurring_charges"."lease_id"  = "reporting"."stg_leases"."lease_id"
  	INNER JOIN "reporting"."stg_tenants" ON "reporting"."stg_tenants"."tenant_id"  = "reporting"."stg_leases"."primary_tenant_id"
  	INNER JOIN "reporting"."stg_lease_recurring_charge_cpi_controls" ON "reporting"."stg_lease_recurring_charge_cpi_controls"."lease_recurring_charge_id"  = "reporting"."stg_lease_recurring_charges"."recurring_charge_id"
  	LEFT JOIN "reporting"."stg_cpi_history" ON "reporting"."stg_cpi_history"."recurring_charge_id" = "reporting"."stg_lease_recurring_charges"."recurring_charge_id"
  
  	WHERE "reporting"."stg_tenants"."deleted_at" IS NULL
  	AND "reporting"."stg_properties"."deleted_at" IS NULL
  	AND "reporting"."stg_leases"."deleted_at" IS NULL
	AND	"reporting"."stg_lease_recurring_charges"."deleted_at" IS NULL
  	AND "reporting"."stg_lease_recurring_charge_cpi_controls"."deleted_at" is NULL 
  	AND "reporting"."stg_cpi_history"."deleted_at" is NULL 
	AND ("reporting"."stg_lease_recurring_charges"."terminate_date" >= (@AsOfDate) or "reporting"."stg_lease_recurring_charges"."terminate_date" IS NULL
		OR  CASE WHEN CAST("reporting"."stg_leases"."month_to_month_flag" AS TEXT) ='true' THEN 'True' ELSE 'False' END IN (@month_to_month) 
		)
  	AND CAST("reporting"."stg_properties"."company_relation_id" AS INT) = CAST(@REAL_COMPANY_ID AS INT)
  	AND "reporting"."stg_properties"."prop_name" IN (@Property_Name)
  	AND CAST("reporting"."stg_leases"."lease_raw_status" AS TEXT) IN (@Lease_Status)
  	AND "reporting"."stg_lease_recurring_charges"."item_id" in (@Item_Id)
	),
MAX_CHARGES_CPI_TOT AS (
 	SELECT  "RCHARGE_ID" "RCHARGE_ID",
   	MAX("cpi_history_created_at") "cpi_history_created_at"
 	FROM CHARGES_CPI_TOT
	GROUP BY "RCHARGE_ID"
 ),
 CHARGES_CPI AS ( 
 SELECT CHARGES_CPI_TOT.*
 FROM CHARGES_CPI_TOT
 INNER JOIN MAX_CHARGES_CPI_TOT
 	ON CHARGES_CPI_TOT."RCHARGE_ID" =  MAX_CHARGES_CPI_TOT."RCHARGE_ID" 
	AND CHARGES_CPI_TOT."cpi_history_created_at" =  MAX_CHARGES_CPI_TOT."cpi_history_created_at"
)
SELECT *
FROM CHARGES_CPI
