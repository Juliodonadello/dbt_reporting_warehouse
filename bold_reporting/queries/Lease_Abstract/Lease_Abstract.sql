WITH CHARGES_TOT AS (
  SELECT 
		"reporting"."stg_units"."property_id" AS "PROP_ID",
  		"reporting"."stg_properties"."prop_name" AS "PROP_NAME",
  		"reporting"."stg_units"."unit_name" AS "UNIT_NAME",
		"reporting"."stg_units"."base_unit_sq_ft" AS "UNIT_SQ_FT",
  		"reporting"."stg_lease_recurring_charges"."unit_id" AS "UNIT_ID",
 		"reporting"."stg_leases"."lease_id" AS "LEASE_ID",
  		
  		"reporting"."stg_lease_recurring_charges"."recurring_charge_id" AS "RCHARGE_ID",
  		"reporting"."stg_lease_recurring_charges"."item_id" AS "ITEM_ID" ,
  		"reporting"."stg_lease_recurring_charge_amounts"."effective_date" AS "EFFECTIVE_DATE",
  		"reporting"."stg_lease_recurring_charges"."terminate_date" AS "TERMINATE_DATE",
  		"reporting"."stg_lease_recurring_charge_amounts"."amount" AS "AMOUNT",
  		"reporting"."stg_lease_recurring_charge_amounts"."frequency" AS "FREQUENCY",
		("reporting"."stg_lease_recurring_charge_amounts"."amount"
				*
				CASE 
				WHEN "reporting"."stg_lease_recurring_charge_amounts"."frequency" = 'Monthly' THEN 12
				WHEN "reporting"."stg_lease_recurring_charge_amounts"."frequency" = 'Annually' THEN 1
				WHEN "reporting"."stg_lease_recurring_charge_amounts"."frequency" = 'One Time' THEN 1
				WHEN "reporting"."stg_lease_recurring_charge_amounts"."frequency" = 'Weekly' THEN 52
				WHEN "reporting"."stg_lease_recurring_charge_amounts"."frequency" = 'Bi-weekly' THEN 26
				WHEN "reporting"."stg_lease_recurring_charge_amounts"."frequency" = 'Quarterly' THEN 4
				WHEN "reporting"."stg_lease_recurring_charge_amounts"."frequency" = 'Semi-annually' THEN 2
				ELSE 1
				END
			  ) / COALESCE(NULLIF(CAST("reporting"."stg_units"."base_unit_sq_ft" AS INT), 0), 1)
		AS "Am/SqFt",
  		("reporting"."stg_lease_recurring_charge_amounts"."amount"
			  *
			  CASE 
				  WHEN "reporting"."stg_lease_recurring_charge_amounts"."frequency" = 'Monthly' THEN 1
				  WHEN "reporting"."stg_lease_recurring_charge_amounts"."frequency" = 'Annually' THEN 1.0 / 12
				  WHEN "reporting"."stg_lease_recurring_charge_amounts"."frequency" = 'One Time' THEN 1
				  WHEN "reporting"."stg_lease_recurring_charge_amounts"."frequency" = 'Weekly' THEN 52.0 / 12
				  WHEN "reporting"."stg_lease_recurring_charge_amounts"."frequency" = 'Bi-weekly' THEN 26.0 / 12
				  WHEN "reporting"."stg_lease_recurring_charge_amounts"."frequency" = 'Quarterly' THEN 1.0 / 3
				  WHEN "reporting"."stg_lease_recurring_charge_amounts"."frequency" = 'Semi-annually' THEN 1.0 / 6
        ELSE 1
			  END
		)  / COALESCE(NULLIF(CAST("reporting"."stg_units"."base_unit_sq_ft" AS INT), 0), 1)
		AS "Mo/SqFt",
  		CASE 	WHEN "reporting"."stg_leases"."month_to_month_flag" = 'False' THEN 'NO'
					WHEN "reporting"."stg_leases"."month_to_month_flag" = 'True' THEN 'YES'
		END AS "M_t_M",
  		CASE WHEN "reporting"."stg_leases"."lease_raw_status" = 'current' THEN 'Current'
		  WHEN "reporting"."stg_leases"."lease_raw_status" = 'canceled' THEN 'Canceled'
		  WHEN "reporting"."stg_leases"."lease_raw_status" = 'terminated' THEN 'Terminated'
		  WHEN "reporting"."stg_leases"."lease_raw_status" = 'future' THEN 'Future'
		  ELSE 'null' 
		END AS "LEASE_STATUS"
  
  	FROM "reporting"."stg_leases"
  	INNER JOIN "reporting"."stg_lease_units"
  		ON "reporting"."stg_leases"."lease_id"  = "reporting"."stg_lease_units"."lease_id"
 	INNER JOIN "reporting"."stg_units"
  		ON "reporting"."stg_units"."unit_id"  = "reporting"."stg_lease_units"."unit_id"
 	INNER JOIN "reporting"."stg_properties"
  		ON "reporting"."stg_properties"."property_id" =  "reporting"."stg_units"."property_id"
  
	LEFT JOIN "reporting"."stg_lease_recurring_charges"
		ON "reporting"."stg_leases"."lease_id"  = "reporting"."stg_lease_recurring_charges"."lease_id"
		AND "reporting"."stg_lease_recurring_charges"."unit_id" =  "reporting"."stg_units"."unit_id"  
		AND "reporting"."stg_lease_recurring_charges"."deleted_at" IS NULL
	LEFT JOIN "reporting"."stg_lease_recurring_charge_amounts"
		ON "reporting"."stg_lease_recurring_charges"."recurring_charge_id" = "reporting"."stg_lease_recurring_charge_amounts"."recurring_charge_id"
  		AND "reporting"."stg_lease_recurring_charge_amounts"."deleted_at" IS NULL
  
  	WHERE 
  	"reporting"."stg_properties"."prop_name" IN (@Property_Name)
	AND CAST("reporting"."stg_properties"."company_relation_id" AS INT)  = CAST(@REAL_COMPANY_ID AS INT)
	AND
	(
		(
			@ignore_end_date = true
			AND "reporting"."stg_leases"."lease_raw_status" = 'current'
			AND COALESCE(
				"reporting"."stg_lease_units"."move_in",
				"reporting"."stg_leases"."lease_start"
			) <= @AsOfDate
		)
		OR
		(
			@ignore_end_date = false
			AND COALESCE(
				"reporting"."stg_lease_units"."move_in",
				"reporting"."stg_leases"."lease_start"
			) <= @AsOfDate
			AND
			(
				(
					CAST("reporting"."stg_leases"."month_to_month_flag" AS TEXT) = 'true'
					AND
					(
						"reporting"."stg_leases"."lease_termination" IS NULL
						OR "reporting"."stg_leases"."lease_termination" > @AsOfDate
					)
				)
				OR "reporting"."stg_leases"."lease_end" IS NULL
				OR "reporting"."stg_leases"."lease_end" > @AsOfDate
			)
		)
	)
	AND "reporting"."stg_leases"."deleted_at" IS NULL
  	AND CASE 
  					WHEN "reporting"."stg_leases"."lease_raw_status" = 'current' THEN 'Current'
					WHEN "reporting"."stg_leases"."lease_raw_status" = 'canceled' THEN 'Canceled'
					WHEN "reporting"."stg_leases"."lease_raw_status" = 'terminated' THEN 'Terminated'
					WHEN "reporting"."stg_leases"."lease_raw_status" = 'future' THEN 'Future'
					ELSE 'null' 
			END  IN (@Lease_Status)
  	AND "reporting"."stg_leases"."lease_raw_status" <> 'canceled'
  	AND "reporting"."stg_leases"."lease_name" IN (@Lease_Name)
),
MAX_CHARGES AS (
 	SELECT  "RCHARGE_ID" "RCHARGE_ID",
   	MAX("EFFECTIVE_DATE") "EFFECTIVE_DATE",
  	MAX('Current') as "STATUS"
 	FROM CHARGES_TOT
  	WHERE "EFFECTIVE_DATE" <= @AsOfDate 
	GROUP BY "RCHARGE_ID"
 ), 
CHARGES AS (
   select CHARGES_TOT.*,
   CASE 	WHEN MAX_CHARGES."STATUS" IS NULL AND CHARGES_TOT."EFFECTIVE_DATE" >= @AsOfDate  THEN 'Future'
			  WHEN MAX_CHARGES."STATUS" IS NULL AND CHARGES_TOT."EFFECTIVE_DATE" < @AsOfDate THEN 'Historical'
			  ELSE MAX_CHARGES."STATUS"
	  END AS "RCHARGE_STATUS"

   from CHARGES_TOT
   LEFT JOIN MAX_CHARGES 
	  ON CHARGES_TOT."RCHARGE_ID" =  MAX_CHARGES."RCHARGE_ID" 
	  AND CHARGES_TOT."EFFECTIVE_DATE" =  MAX_CHARGES."EFFECTIVE_DATE"
	
  WHERE CHARGES_TOT."M_t_M" IN (@month_to_month)
  ORDER BY CHARGES_TOT."RCHARGE_ID", CHARGES_TOT."EFFECTIVE_DATE" ASC
 )
 
 SELECT * 
 FROM CHARGES
 
