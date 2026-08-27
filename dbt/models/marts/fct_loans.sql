-- Grain: one row per loan. 2,260,668 rows.
--
-- No borrower dimension exists: member_id is 100% null in this dataset, so
-- there is no way to link two loans to the same person. The loan is the
-- atomic entity. Borrower attributes here (income, employment, home
-- ownership) are a snapshot from one application form, not properties of a
-- person that could be tracked over time.
--
-- dim_date is a role-playing dimension: three date keys point at the same
-- physical table for different purposes. Join with aliases downstream.

with loans as (

    select * from {{ ref('stg_loans') }}

),

status_lookup as (

    select * from {{ ref('dim_loan_status') }}

),

final as (

    select
        -- Degenerate dimension: the loan's own identifier. No dim_loan table
        -- exists because a loan has no attributes beyond what is already here.
        l.loan_id,

        -- Foreign keys
        l.state_code                                        as state_key,
        l.purpose                                           as purpose_key,
        s.loan_status_key,

        -- Role-playing date keys. YYYYMMDD integers matching dim_date.
        cast(to_char(l.issued_at, 'YYYYMMDD') as integer)   as issued_date_key,
        cast(to_char(l.last_payment_at, 'YYYYMMDD') as integer)
                                                            as last_payment_date_key,
        cast(to_char(l.last_credit_pull_at, 'YYYYMMDD') as integer)
                                                            as last_credit_pull_date_key,

        -- Loan terms
        l.loan_amount,
        l.funded_amount,
        l.installment_amount,
        l.interest_rate_pct,
        l.term_months,

        -- Borrower snapshot at application. NOT properties of a person -
        -- see the grain note above.
        l.annual_income,
        l.debt_to_income_pct,
        l.employment_length_years,
        l.fico_at_origination,

        -- Portfolio monitoring
        l.fico_at_last_pull,
        l.fico_at_last_pull - l.fico_at_origination         as fico_migration,
        l.total_paid_to_date,
        l.outstanding_principal,
        l.last_payment_amount,

        -- Degenerate attributes. 3-6 distinct values each with nothing to
        -- add - a lookup table would be a join to retrieve a string we
        -- already have. dim_loan_grade was considered and dropped for the
        -- same reason: left(sub_grade, 1) is not a dimension.
        l.grade,
        l.sub_grade,
        l.home_ownership,
        l.verification_status,
        l.application_type

    from loans l
    left join status_lookup s
        on l.loan_status = case
                when s.meets_credit_policy then s.loan_status
                else 'Does not meet the credit policy. Status:' || s.loan_status
           end
       and l.loan_status like case
                when s.meets_credit_policy then '%'
                else 'Does not meet the credit policy.%'
           end

)

select * from final