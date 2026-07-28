with source as (

    select * from {{ source('raw', 'accepted_loans') }}

),

loans_only as (

    -- Lending Club's quarterly CSVs end with summary footer rows like
    -- "Total amount funded in policy code 2: 81866225". Concatenating the
    -- quarterly files carried ~33 of them into the data. They land with the
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

        try_cast(loan_amnt as number(12,2))                as loan_amount,
        try_cast(int_rate as number(6,4))                  as interest_rate_pct,

        -- " 36 months" -> 36
        try_cast(regexp_substr(term, '[0-9]+') as integer) as term_months,

        -- "10+ years" -> 10, "< 1 year" -> 0
        -- Both are bucket boundaries, not measurements. '< 1 year' maps to 0
        -- for analytical use; display as '< 1 year' in marts, not here.
        -- Note: averaging tenure is biased slightly low as a result.
        case
            when emp_length = '< 1 year'  then 0
            when emp_length = '10+ years' then 10
            else try_cast(regexp_substr(emp_length, '[0-9]+') as integer)
        end                                                as employment_length_years,

        -- "Dec-2018" -> 2018-12-01
        try_to_date(issue_d, 'MON-YYYY')                   as issued_at,

        trim(grade)                                        as grade,
        trim(sub_grade)                                    as sub_grade,
        trim(loan_status)                                  as loan_status,
        trim(purpose)                                      as purpose

    from loans_only

)

select * from cleaned

