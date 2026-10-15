SELECT 
	distinct "reporting"."stg_leases"."lease_name" as "LEASE_NAME"
  
  	FROM "reporting"."stg_leases"
	LEFT JOIN "reporting"."stg_lease_recurring_charges"
  		ON "reporting"."stg_leases"."lease_id"  = "reporting"."stg_lease_recurring_charges"."lease_id"
	LEFT JOIN "reporting"."stg_lease_recurring_charge_amounts"
		ON "reporting"."stg_lease_recurring_charges"."recurring_charge_id" = "reporting"."stg_lease_recurring_charge_amounts"."recurring_charge_id"
 	INNER JOIN "reporting"."stg_units"
  		ON "reporting"."stg_lease_recurring_charges"."unit_id" =  "reporting"."stg_units"."unit_id"
 	INNER JOIN "reporting"."stg_properties"
  		ON "reporting"."stg_properties"."property_id" =  "reporting"."stg_units"."property_id" 
  
  	WHERE 
  	"reporting"."stg_properties"."prop_name" IN (@Property_Name)
	AND CAST("reporting"."stg_properties"."company_relation_id" AS INT)  = CAST(@REAL_COMPANY_ID AS INT)
  	AND CASE 
  					WHEN "reporting"."stg_leases"."lease_raw_status" = 'current' THEN 'Current'
					WHEN "reporting"."stg_leases"."lease_raw_status" = 'canceled' THEN 'Canceled'
					WHEN "reporting"."stg_leases"."lease_raw_status" = 'terminated' THEN 'Terminated'
					WHEN "reporting"."stg_leases"."lease_raw_status" = 'future' THEN 'Future'
					ELSE 'null' 
			END  IN (@Lease_Status)
			
  	
order by 1 desc