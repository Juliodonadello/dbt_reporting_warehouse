SELECT "reporting"."stg_leases"."lease_id" as "LEASE_ID",
"reporting"."stg_leases"."lease_name" as "LEASE_NAME",
"reporting"."stg_properties"."prop_name" as "PROP_NAME",
"reporting"."stg_properties"."company_relation_id",
CASE 	WHEN "reporting"."stg_leases"."month_to_month_flag" = 'False' THEN 'NO'
					WHEN "reporting"."stg_leases"."month_to_month_flag" = 'True' THEN 'YES'
		END AS "M_t_M",
"reporting"."stg_lease_recurring_charges"."item_id" AS "order_entry_item_id",
"reporting"."stg_lease_recurring_charges"."recovery_control_id",
"reporting"."stg_lease_recovery_control"."recovery_control_name" AS "lease_recovery_control_name",
CASE WHEN "reporting"."stg_lease_recovery_control"."calculation_control_base_year" IS NULL THEN '  ' ELSE "reporting"."stg_lease_recovery_control"."calculation_control_base_year"
	END AS "calculation_control_base_year",
CASE WHEN "reporting"."stg_lease_recovery_control"."calculation_control_base_amount" IS NULL THEN ' ' 
	ELSE to_char("reporting"."stg_lease_recovery_control"."calculation_control_base_amount", '$FM999,999,999,990.00')
	END AS "calculation_control_base_amount",
"reporting"."stg_recovery_control_expense_category"."manual_percent" 

FROM "reporting"."stg_leases"
INNER JOIN "reporting"."stg_properties"
  		ON "reporting"."stg_properties"."property_id" =  "reporting"."stg_leases"."property_id"
INNER JOIN "reporting"."stg_lease_recurring_charges" 
	ON "reporting"."stg_leases"."lease_id"="reporting"."stg_lease_recurring_charges"."lease_id" 
INNER JOIN "reporting"."stg_lease_recovery_control" 
	ON "reporting"."stg_lease_recurring_charges"."recovery_control_id"="reporting"."stg_lease_recovery_control"."lease_recovery_control_id" 
LEFT OUTER JOIN "reporting"."stg_recovery_control_expense_category" 
	ON "reporting"."stg_lease_recovery_control"."lease_recovery_control_id"="reporting"."stg_recovery_control_expense_category"."lease_recovery_control_id"

WHERE  	(("reporting"."stg_lease_recovery_control"."calculation_control_base_year" IS NOT NULL)
	   			OR 
		 		("reporting"."stg_lease_recovery_control"."calculation_control_base_amount" IS NOT NULL)
		 		OR 
		 		("reporting"."stg_recovery_control_expense_category"."manual_percent" IS NOT NULL)
	   			)
		AND "reporting"."stg_properties"."prop_name" IN (@Property_Name)
		AND CAST("reporting"."stg_properties"."company_relation_id" AS INT)  = CAST(@REAL_COMPANY_ID AS INT)
		AND "reporting"."stg_lease_recurring_charges"."deleted_at" IS NULL
		AND "reporting"."stg_leases"."deleted_at" IS NULL
		AND "reporting"."stg_lease_recovery_control"."deleted_at" IS NULL
		AND "reporting"."stg_recovery_control_expense_category"."deleted_at" IS NULL
		AND (CASE WHEN "reporting"."stg_leases"."month_to_month_flag" = 'False' THEN 'NO'
							WHEN "reporting"."stg_leases"."month_to_month_flag" = 'True' THEN 'YES'
				END) IN (@month_to_month)