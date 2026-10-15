WITH LEATE_CHARGES AS (
  SELECT "reporting"."stg_lease_late_charges"."lease_late_charge_id" AS "id",
  "reporting"."stg_lease_late_charges"."description",
  "reporting"."stg_lease_late_charges"."minimum_lease_balance",
  "reporting"."stg_lease_late_charges"."suppress_charge_under",
  "reporting"."stg_lease_late_charges"."lease_id",
  CAST("reporting"."stg_lease_late_charges"."process_by" AS text) "process_by"
  

  FROM "reporting"."stg_lease_late_charges"
	INNER JOIN "reporting"."stg_leases"
	  ON "reporting"."stg_lease_late_charges"."lease_id" = "reporting"."stg_leases"."lease_id"
	INNER JOIN "reporting"."stg_properties"
	  ON "reporting"."stg_properties"."property_id" = "reporting"."stg_leases"."property_id"

  where  CAST("reporting"."stg_properties"."company_relation_id" AS INT)  = CAST(@REAL_COMPANY_ID AS INT)
	  AND "reporting"."stg_properties"."prop_name" IN (@Property_Name)
	  
	  AND
	  "reporting"."stg_lease_late_charges"."deleted_at" IS NULL
),
LEATE_CHARGES_STEPS AS (
  SELECT 
  "reporting"."stg_lease_late_charge_steps"."lease_late_charge_step_id" AS "lease_late_charge_steps_id",
  "reporting"."stg_lease_late_charge_steps"."late_charge_type",
  "reporting"."stg_lease_late_charge_steps"."grace_days",
  "reporting"."stg_lease_late_charge_steps"."frequency" || ': ' || "reporting"."stg_lease_late_charge_steps"."repeat_factor" as "Frecuency",
  "reporting"."stg_lease_late_charge_steps"."calculation_type",
  COALESCE("reporting"."stg_lease_late_charge_steps"."flat_amount","reporting"."stg_lease_late_charge_steps"."percentage") as "Amount",
  "reporting"."stg_lease_late_charge_steps"."lease_late_charge_id" 

  FROM "reporting"."stg_lease_late_charge_steps" 

  WHERE 
	  "reporting"."stg_lease_late_charge_steps"."deleted_at" IS NULL
   ORDER BY "reporting"."stg_lease_late_charge_steps"."lease_late_charge_id",
	"reporting"."stg_lease_late_charge_steps"."lease_late_charge_step_id", 
	"reporting"."stg_lease_late_charge_steps"."grace_days"
)
SELECT LEATE_CHARGES."id",
  LEATE_CHARGES."description",
  LEATE_CHARGES."minimum_lease_balance",
  LEATE_CHARGES."suppress_charge_under",
  LEATE_CHARGES."lease_id",
  LEATE_CHARGES."process_by",
  LEATE_CHARGES_STEPS."lease_late_charge_steps_id" as "steps_id",
  LEATE_CHARGES_STEPS."late_charge_type",
  LEATE_CHARGES_STEPS."grace_days",
  LEATE_CHARGES_STEPS."Frecuency",
  LEATE_CHARGES_STEPS."calculation_type",
  LEATE_CHARGES_STEPS."Amount"

FROM LEATE_CHARGES
LEFT JOIN LEATE_CHARGES_STEPS
	ON LEATE_CHARGES."id" = LEATE_CHARGES_STEPS."lease_late_charge_id"

ORDER BY LEATE_CHARGES."lease_id", LEATE_CHARGES."id", LEATE_CHARGES_STEPS."grace_days"
