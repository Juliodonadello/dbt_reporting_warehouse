WITH DEPOSITS AS (
  SELECT "reporting"."stg_lease_deposits"."deposit_type" as "D_type",
  CASE WHEN "reporting"."stg_lease_deposits"."refundable" IS TRUE THEN 'YES' ELSE 'NO' END as "D_refundable",
  "reporting"."stg_lease_deposits"."invoice_number" as "D_invoice_number",
  "reporting"."stg_units"."unit_name" as "D_unit_name",
  "reporting"."stg_lease_deposits"."lease_id" as "D_lease_id",
  "reporting"."stg_lease_deposits"."lease_deposit_id" as "deposit_id"

  FROM "reporting"."stg_lease_deposits"
  INNER JOIN "reporting"."stg_units"
  		ON "reporting"."stg_lease_deposits"."unit_id" =  "reporting"."stg_units"."unit_id"
 	INNER JOIN "reporting"."stg_properties"
  		ON "reporting"."stg_properties"."property_id" =  "reporting"."stg_units"."property_id"
  
  WHERE
	"reporting"."stg_properties"."prop_name" IN (@Property_Name)
	AND CAST("reporting"."stg_properties"."company_relation_id" AS INT)  = CAST(@REAL_COMPANY_ID AS INT)
	
	AND "reporting"."stg_lease_deposits"."deleted_at" IS NULL
),
DEPOSITS_REFUNDS AS (
    SELECT "reporting"."stg_lease_deposit_refunds"."lease_deposit_id",
		SUM ("reporting"."stg_lease_deposit_refunds"."amount") "REFUNDED_AMOUNT"
  
  FROM "reporting"."stg_lease_deposit_refunds"
  INNER JOIN DEPOSITS ON "reporting"."stg_lease_deposit_refunds"."lease_deposit_id" = DEPOSITS."deposit_id"
  
  WHERE  "reporting"."stg_lease_deposit_refunds"."deleted_at" IS NULL
  
  GROUP BY "reporting"."stg_lease_deposit_refunds"."lease_deposit_id"
)

SELECT DEPOSITS.*,
	DEPOSITS_REFUNDS."REFUNDED_AMOUNT"
	
FROM DEPOSITS
LEFT JOIN DEPOSITS_REFUNDS
	ON DEPOSITS_REFUNDS."lease_deposit_id" = DEPOSITS."deposit_id"

order by DEPOSITS."D_lease_id"

