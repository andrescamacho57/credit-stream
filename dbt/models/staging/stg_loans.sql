with source as (

    select * from {{ source('raw', 'accepted_loans') }}

),

loans_only as (

    -- Lending Club's quarterly CSVs end with summary footer rows like
    -- "Total amount funded in policy code 2: 81866225". Concatenating the
    -- quarterly files carried 33 of them into the data. They land with the
    -- footer text in id and every other column null.
    --
    -- Filtering on numeric id rather than on null amount, because the grain
    -- is "one row per loan keyed by numeric id" - that catches any future
    -- junk row regardless of its wording.
    select *
    from source
    where try_cast(id as number) is not null

),

cleaned as (

    select
        -- Identifier stays text. You never do arithmetic on a key.
        id                                                 as loan_id,

        -- Amounts
        try_cast(loan_amnt as number(12,2))                as loan_amount,
        try_cast(funded_amnt as number(12,2))              as funded_amount,

        -- Required monthly obligation. This is the column the anomaly
        -- detection depends on: payments summing to less than the
        -- installment is the signal, and it is unavailable from the
        -- stream alone.
        try_cast(installment as number(10,2))              as installment_amount,

        try_cast(int_rate as number(6,4))                  as interest_rate_pct,

        -- " 36 months" -> 36
        try_cast(regexp_substr(term, '[0-9]+') as integer) as term_months,

        -- Dimension key sources
        trim(grade)                                        as grade,
        trim(sub_grade)                                    as sub_grade,
        trim(purpose)                                      as purpose,
        trim(addr_state)                                   as state_code,

               -- Source packs two independent facts into one string:
        -- "Does not meet the credit policy. Status:Charged Off" is a status
        -- PLUS a policy exception. Split here so downstream filters on
        -- loan_status catch every loan of that status.
        case
            when loan_status like 'Does not meet the credit policy.%'
                then trim(split_part(loan_status, 'Status:', 2))
            else trim(loan_status)
        end                                                as loan_status,

        loan_status not like 'Does not meet the credit policy.%'
                                                           as meets_credit_policy,
                                                           
        -- Borrower attributes: NOT properties of a person. member_id is
        -- 100% null in this dataset, so there is no borrower entity. These
        -- are values captured on one application form at one moment.
        -- "10+ years" -> 10, "< 1 year" -> 0
        -- Both are bucket boundaries, not measurements. '< 1 year' maps to 0
        -- for analytical use; display as '< 1 year' in marts, not here.
        -- Note: averaging tenure is biased slightly low as a result.
        case
            when emp_length = '< 1 year'  then 0
            when emp_length = '10+ years' then 10
            else try_cast(regexp_substr(emp_length, '[0-9]+') as integer)
        end                                                as employment_length_years,

        try_cast(annual_inc as number(14,2))               as annual_income,
        try_cast(dti as number(8,2))                       as debt_to_income_pct,

        -- FICO was published as a ~5-point band, not a point score.
        -- Taking the low end as the conservative convention; averaging would
        -- invent precision the source never had.
        try_cast(fico_range_low as integer)                as fico_at_origination,

        -- Most recent credit pull. Enables score migration analysis:
        -- deterioration visible before a payment is missed.
        -- CAUTION: for charged-off loans this pull happened after the
        -- default, so it leaks the label. Valid for monitoring, not for
        -- predictive modeling.
        try_cast(last_fico_range_low as integer)           as fico_at_last_pull,
        try_to_date(last_credit_pull_d, 'MON-YYYY')        as last_credit_pull_at,

        -- Degenerate attributes: kept on the fact, no dimension table.
        -- 3-6 distinct values each with no derivable attributes - a lookup
        -- table would be a join to retrieve a string we already have.
        trim(home_ownership)                               as home_ownership,
        trim(verification_status)                          as verification_status,
        trim(application_type)                             as application_type,

        -- Portfolio monitoring measures
        try_cast(total_pymnt as number(14,2))              as total_paid_to_date,
        try_cast(out_prncp as number(14,2))                as outstanding_principal,
        try_to_date(last_pymnt_d, 'MON-YYYY')              as last_payment_at,
        try_cast(last_pymnt_amnt as number(12,2))          as last_payment_amount,

        -- "Dec-2018" -> 2018-12-01
        try_to_date(issue_d, 'MON-YYYY')                   as issued_at

    from loans_only

)

select * from cleaned
