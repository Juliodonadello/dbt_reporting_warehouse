select
    id as lease_deposit_id,
    lease_id,
    unit_id,
    tenant_id,
    cast(company_relation_id as integer) as company_relation_id,
    "type" as deposit_type,
    refundable,
    invoice_number,
    letter_of_credit_amount,
    letter_of_credit_attachment,
    letter_of_credit_bank,
    letter_of_credit_expiration_date,
    deleted_at
from {{ source('app', 'lease_deposits') }}
where deleted_at is null
