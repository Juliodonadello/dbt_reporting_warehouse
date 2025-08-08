WITH SQ_FT_TEMP AS (
	SELECT
		UNITS."PROP_ID" as "PROP_ID",
		SUM(UNITS."UNIT_SQ_FT") AS "TOT_SQ_FT"
	 
	FROM  {{ ref('units') }} as UNITS

	GROUP BY  UNITS."PROP_ID"
	),
FINAL AS (
	select 
		"LEASE_ID",
		"UNIT_ID",
		"lease_created_at", 
		"start",
		"lease_end",
		"TENANT",
		"LEASE_STATUS",
		"DEPOSIT",
		"REFUNDABLE",
		"RENT_AMOUNT",
		"OTHER_AMOUNT",
		"ANNUAL_RENT_AMOUNT",
		"ANNUAL_OTHER_AMOUNT"
	from {{ ref('leases_charges') }} as LEASES_CHARGES
	group by 
		"LEASE_ID",
		"UNIT_ID",
		"lease_created_at", 
		"start",
		"lease_end",
		"TENANT",
		"LEASE_STATUS",
		"DEPOSIT",
		"REFUNDABLE",
		"RENT_AMOUNT",
		"OTHER_AMOUNT",
		"ANNUAL_RENT_AMOUNT",
		"ANNUAL_OTHER_AMOUNT"
	ORDER BY LEASES_CHARGES."LEASE_ID"
	),
FINAL_AUX AS (
    SELECT COUNT(DISTINCT "LEASE_ID") "LEASES_COUNT",
    "UNIT_ID"
    FROM FINAL
    GROUP BY "UNIT_ID"
	),
RENT_SCALATIONS AS (
  SELECT 
  		"public"."lease_recurring_charges"."lease_id" AS "LEASE_ID",
  		CASE WHEN CHARGE_CONTROL."BASE_RENT" = 1 THEN 1 ELSE 0 END AS "FLAG_RENT_SCAL",
		CASE WHEN CHARGE_CONTROL."BASE_RENT" = 1 THEN "public"."lease_recurring_charge_amounts"."amount" ELSE 0 END AS "RENT_CHARGE_SCAL",
  		--CASE WHEN CHARGE_CONTROL. "BASE_RENT" = 0 THEN "public"."lease_recurring_charge_amounts"."amount" ELSE 0 END AS "OTHER_CHARGE",
  		"public"."lease_recurring_charge_amounts"."effective_date" AS "EFFECTIVE_DATE_SCAL",
  		"public"."units"."property_id" "PROP_ID",
  		"public"."lease_recurring_charges"."unit_id" "UNIT_ID"
  
	FROM "public"."lease_recurring_charges"
	LEFT OUTER JOIN "public"."lease_recurring_charge_amounts"
		ON "public"."lease_recurring_charges"."id" = "public"."lease_recurring_charge_amounts"."recurring_charge_id"
 	INNER JOIN "public"."units"
  		ON "public"."lease_recurring_charges"."unit_id" =  "public"."units"."id"
  	INNER JOIN CHARGE_CONTROL
  		ON CHARGE_CONTROL. "PROP_ID" = "public"."units"."property_id"
  		AND CHARGE_CONTROL. "ITEM_ID" = "public"."lease_recurring_charges"."order_entry_item_id"
	INNER JOIN "public"."properties"
		ON "public"."properties"."id" = "public"."units"."property_id"
  
  	WHERE "public"."lease_recurring_charge_amounts"."effective_date" > @AsOfDate
	AND (
		"public"."lease_recurring_charge_amounts"."deleted_at" > @AsOfDate 
		OR 
		"public"."lease_recurring_charge_amounts"."deleted_at" IS NULL
		)
	AND (
		"public"."lease_recurring_charges"."deleted_at" > @AsOfDate
		OR
		"public"."lease_recurring_charges"."deleted_at" IS NULL
		)
	AND (
		"public"."lease_recurring_charge_amounts"."frequency" != 'One Time' --not a one time charge 
		--OR
		/*(
			"public"."lease_recurring_charge_amounts"."frequency" = 'One Time'
			AND	 CAST(EXTRACT(DAY FROM (@AsOfDate - "public"."lease_recurring_charge_amounts"."effective_date")) AS INTEGER) > 0
		  	AND CAST(EXTRACT(DAY FROM (@AsOfDate - "public"."lease_recurring_charge_amounts"."effective_date")) AS INTEGER) < 31
		)--one time charge with less than a month differnce
		-- COMMENTED BECAUSE ONE TIME ARE NOT CONSIDER SCALATIONS
		*/
		)
	AND (	
	  	"public"."lease_recurring_charges"."terminate_date" > @AsOfDate
		OR
		"public"."lease_recurring_charges"."terminate_date" is NULL 
		)
	AND (	
	  	"public"."lease_recurring_charges"."deleted_at" > @AsOfDate
		OR
		"public"."lease_recurring_charges"."deleted_at" is NULL 
		)
	AND "public"."properties"."name" IN (@Property_Name)
  	AND CHARGE_CONTROL. "BASE_RENT" = 1
  	AND "public"."units"."status" = 'active'
		
	GROUP BY 
		"public"."lease_recurring_charges"."lease_id",
  		CASE WHEN CHARGE_CONTROL."BASE_RENT" = 1 THEN 1 ELSE 0 END,
		CASE WHEN CHARGE_CONTROL."BASE_RENT" = 1 THEN "public"."lease_recurring_charge_amounts"."amount" ELSE 0 END,
		"public"."lease_recurring_charge_amounts"."effective_date",
		"public"."units"."property_id",
		"public"."lease_recurring_charges"."unit_id"
	ORDER BY 
			"public"."units"."property_id",
			"public"."lease_recurring_charges"."unit_id",
			"public"."lease_recurring_charges"."lease_id",
			"public"."lease_recurring_charge_amounts"."effective_date" ASC
	),
RENT_SCALATIONS_AUX AS (
	SELECT 
  			RENT_SCALATIONS."PROP_ID",
			RENT_SCALATIONS."UNIT_ID",
			--SUM(RENT_SCALATIONS."FLAG_RENT_SCAL") AS "COUNT_RENT_CHARGE_SCAL"
			CASE WHEN SUM(RENT_SCALATIONS."FLAG_RENT_SCAL") < 1 THEN 1 ELSE SUM(RENT_SCALATIONS."FLAG_RENT_SCAL") END AS "COUNT_RENT_CHARGE_SCAL"


	FROM RENT_SCALATIONS
  	--INNER JOIN CHARGE_CONTROL ON RENT_SCALATIONS."PROP_ID" = CHARGE_CONTROL."PROP_ID"

	GROUP BY RENT_SCALATIONS."PROP_ID",
			RENT_SCALATIONS."UNIT_ID",
  			RENT_SCALATIONS."LEASE_ID"
	ORDER BY RENT_SCALATIONS."PROP_ID",
			RENT_SCALATIONS."UNIT_ID"
),
RENT_SCALATIONS_FINAL AS (
	SELECT 
  			RENT_SCALATIONS."PROP_ID",
			RENT_SCALATIONS."UNIT_ID",
			RENT_SCALATIONS."LEASE_ID",
  			RENT_SCALATIONS."RENT_CHARGE_SCAL",
			RENT_SCALATIONS."EFFECTIVE_DATE_SCAL",
			MAX(RENT_SCALATIONS_AUX."COUNT_RENT_CHARGE_SCAL") "COUNT_RENT_CHARGE_SCAL"

	FROM RENT_SCALATIONS
  	LEFT JOIN RENT_SCALATIONS_AUX
  		ON RENT_SCALATIONS."PROP_ID" = RENT_SCALATIONS_AUX."PROP_ID"
  		AND RENT_SCALATIONS."UNIT_ID" = RENT_SCALATIONS_AUX."UNIT_ID"

	GROUP BY 1,2,3,4,5
	ORDER BY RENT_SCALATIONS."PROP_ID",
			RENT_SCALATIONS."UNIT_ID",
			RENT_SCALATIONS."LEASE_ID",
			RENT_SCALATIONS."EFFECTIVE_DATE_SCAL" ASC
)

SELECT 
UNITS."PROP_ID",
UNITS."PROP_NAME",
UNITS."UNIT_ID",
UNITS."UNIT_NAME" "UNIT_NAME" ,
FINAL."LEASE_ID",
FINAL."LEASE_NAME",
--CASE WHEN FINAL."LEASE_STATUS" = 'OCCUPIED' THEN 'OCCUPIED' ELSE 'VACANT' END AS  "LEASE_STATUS",
CASE WHEN FINAL."lease_created_at" IS NOT NULL THEN 'OCCUPIED' ELSE 'VACANT' END AS  "LEASE_STATUS", -- esto se hizo porque los status future se deben ver como Occupied si el asofdate coincide
FINAL."TENANT",
--FINAL."lease_created_at" "lease_created_at",
FINAL."start" "lease_start",
FINAL."lease_end",	
UNITS."UNIT_SQ_FT" "UNIT_SQ_FT",
FINAL_AUX."LEASES_COUNT",
CASE WHEN RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL">1 THEN RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL"
		ELSE 1
		END AS "COUNT_RENT_CHARGE_SCAL",
CASE 	WHEN ( FINAL_AUX."LEASES_COUNT" <2 AND RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL" < 2)
						OR (FINAL_AUX."LEASES_COUNT" is null AND RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL" is null) THEN UNITS."UNIT_SQ_FT"
			WHEN (FINAL_AUX."LEASES_COUNT" > 1 AND RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL" is null) THEN UNITS."UNIT_SQ_FT"/FINAL_AUX."LEASES_COUNT"
			WHEN (RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL" > 1 AND FINAL_AUX."LEASES_COUNT" is null) THEN UNITS."UNIT_SQ_FT"/RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL"
			ELSE  UNITS."UNIT_SQ_FT"/(FINAL_AUX."LEASES_COUNT" *  COALESCE(RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL", 1) )
	END AS "UNIT_SQ_FT_fix",
CASE 	WHEN SQ_FT_TEMP."TOT_SQ_FT" = 0 THEN 0 
			ELSE UNITS."UNIT_SQ_FT" / SQ_FT_TEMP."TOT_SQ_FT" * 100 
	END AS "Pct of Property",
CASE 	WHEN SQ_FT_TEMP."TOT_SQ_FT" = 0 THEN 0
			WHEN (FINAL_AUX."LEASES_COUNT"<2 AND RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL" < 2)
						OR (FINAL_AUX."LEASES_COUNT" is null AND RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL" is null) THEN UNITS."UNIT_SQ_FT" / SQ_FT_TEMP."TOT_SQ_FT" * 100
			WHEN (FINAL_AUX."LEASES_COUNT" > 1 AND RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL" is null) THEN UNITS."UNIT_SQ_FT" / FINAL_AUX."LEASES_COUNT" / SQ_FT_TEMP."TOT_SQ_FT" * 100
			WHEN (RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL" > 1 AND FINAL_AUX."LEASES_COUNT" is null) THEN UNITS."UNIT_SQ_FT" /RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL" / SQ_FT_TEMP."TOT_SQ_FT" * 100
			ELSE UNITS."UNIT_SQ_FT"/(FINAL_AUX."LEASES_COUNT" *  COALESCE(RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL", 1)) / SQ_FT_TEMP."TOT_SQ_FT" * 100
	END AS "Pct of Property_fix",
FINAL."DEPOSIT",
FINAL."REFUNDABLE",
--LEASES."RCHARGE_ID",
FINAL."RENT_CHARGE" "RENT_AMOUNT",
FINAL."OTHER_CHARGE" "OTHER_AMOUNT",
CASE 
    WHEN RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL" IS NULL THEN FINAL."RENT_CHARGE"
    ELSE FINAL."RENT_CHARGE" / COALESCE(RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL", 1)
END AS "RENT_AMOUNT_fix",
CASE 
    WHEN RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL" IS NULL THEN FINAL."OTHER_CHARGE"
    ELSE FINAL."OTHER_CHARGE" / COALESCE(RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL", 1)
END AS "OTHER_AMOUNT_fix",
CASE WHEN UNITS."UNIT_SQ_FT" = 0 THEN 0 ELSE FINAL."RENT_CHARGE" *12 /UNITS."UNIT_SQ_FT" END AS "Annual Rent/Sq Ft",
CASE WHEN UNITS."UNIT_SQ_FT" = 0 THEN 0 ELSE FINAL."OTHER_CHARGE" *12 /UNITS."UNIT_SQ_FT" END AS "Annual Other/Sq Ft",
CASE 
    WHEN UNITS."UNIT_SQ_FT" = 0 THEN 0
    ELSE FINAL."RENT_CHARGE" * 12 / UNITS."UNIT_SQ_FT" / COALESCE(RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL", 1)
END AS "Annual Rent/Sq Ft_fix",
CASE 
    WHEN UNITS."UNIT_SQ_FT" = 0 THEN 0
    ELSE FINAL."OTHER_CHARGE" * 12 / UNITS."UNIT_SQ_FT" / COALESCE(RENT_SCALATIONS_FINAL."COUNT_RENT_CHARGE_SCAL", 1)
END AS "Annual Other/Sq Ft_fix",
RENT_SCALATIONS_FINAL."RENT_CHARGE_SCAL",
RENT_SCALATIONS_FINAL."EFFECTIVE_DATE_SCAL"

FROM UNITS
LEFT JOIN SQ_FT_TEMP
	ON UNITS."PROP_ID" = SQ_FT_TEMP."PROP_ID"
LEFT JOIN FINAL
	ON UNITS."UNIT_ID" = FINAL."UNIT_ID"
LEFT JOIN FINAL_AUX
	ON FINAL."UNIT_ID" = FINAL_AUX."UNIT_ID"
INNER JOIN "public"."properties"
	ON UNITS."PROP_ID" = "public"."properties"."id"
LEFT JOIN RENT_SCALATIONS_FINAL
	ON RENT_SCALATIONS_FINAL."PROP_ID" = UNITS."PROP_ID"
	AND RENT_SCALATIONS_FINAL."UNIT_ID" = UNITS."UNIT_ID"
	AND RENT_SCALATIONS_FINAL."LEASE_ID" = FINAL."LEASE_ID"

where  "PROP_NAME" IN (@Property_Name)
	AND CAST("public"."properties"."company_relation_id" AS INT) = CAST(@REAL_COMPANY_ID AS INT)

--group by 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28

order by "PROP_NAME", UNITS."UNIT_NAME",
			RENT_SCALATIONS_FINAL."EFFECTIVE_DATE_SCAL" ASC
