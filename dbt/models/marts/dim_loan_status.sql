-- Grain: The grain is one row per (status, policy flag) combination (9 after normalization).
--
-- Derived from stg_loans rather than a seed, unlike dim_geography. The state
-- domain is externally defined - 51 states exist whether or not we have loans
-- in them. Loan status has no external authority: the domain IS whatever the
-- source system emits. A seed here would silently drift from reality.
--
-- Two source values pack two independent facts into one string:
--   "Does not meet the credit policy. Status:Fully Paid"
--   "Does not meet the credit policy. Status:Charged Off"
-- These are normal statuses PLUS a policy exception flag. Splitting them into
-- loan_status + meets_credit_policy means "where loan_status = 'Charged Off'"
-- catches every charge-off, instead of silently missing 761 of them.

with source_statuses as (

    select distinct loan_status as raw_status
    from {{ ref('stg_loans') }}

),

normalized as (

    select
        raw_status,

        case
            when raw_status like 'Does not meet the credit policy.%'
                then trim(split_part(raw_status, 'Status:', 2))
            else raw_status
        end as loan_status,

        raw_status not like 'Does not meet the credit policy.%'
            as meets_credit_policy

    from source_statuses

),

final as (

    select distinct
        {{ dbt_utils.generate_surrogate_key(['loan_status', 'meets_credit_policy']) }} as loan_status_key,

        loan_status,
        meets_credit_policy,

        -- Ordinal severity. Enables roll-rate analysis (movement between
        -- stages over time) and clean range filters: delinquency_stage >= 2
        -- is "seriously delinquent" without listing every status string.
        --
        -- Fully Paid and Current are both 0: neither is delinquent. The
        -- ordinal measures HOW delinquent, not whether the loan is finished.
        -- is_terminal carries that distinction instead.
        case loan_status
            when 'Fully Paid'          then 0
            when 'Current'             then 0
            when 'In Grace Period'     then 1
            when 'Late (16-30 days)'   then 2
            when 'Late (31-120 days)'  then 3
            when 'Default'             then 4
            when 'Charged Off'         then 5
        end as delinquency_stage,

        -- Currently meeting obligations
        case loan_status
            when 'Fully Paid'          then true
            when 'Current'             then true
            when 'In Grace Period'     then true
            else false
        end as is_performing,

        -- No further state changes expected
        case loan_status
            when 'Fully Paid'          then true
            when 'Charged Off'         then true
            else false
        end as is_terminal

    from normalized

)

select * from final