-- Grain: one row per loan purpose (14).
--
-- Earns a table for two reasons that dim_loan_grade did not:
--
-- 1. Category rollup. debt_consolidation (56.5%) and credit_card (22.9%) are
--    economically the same behavior - refinancing existing revolving debt -
--    split across two labels. Together they are 79.4% of the book. Grouping
--    them turns an unusable 14-way breakdown into a real segmentation.
--
-- 2. is_small_business flag. 24,689 loans (1.09%). Small as a share, large
--    enough in absolute terms to segment and compute default rates on.
--    Commercial credit behaves differently from consumer credit, so this is
--    a cut worth making cheap.
--
-- Derived from stg_loans rather than a seed: like loan_status, the purpose
-- domain is whatever the source system emits, not an external standard.

with source_purposes as (

    select distinct purpose
    from {{ ref('stg_loans') }}

),

final as (

    select
        -- Natural key. Already unique and readable - no surrogate needed,
        -- unlike dim_loan_status where the natural key was two columns.
        purpose as purpose_key,

        -- Display label. Source values are snake_case machine strings.
        initcap(replace(purpose, '_', ' ')) as purpose_name,

        case purpose
            when 'debt_consolidation' then 'Debt Refinancing'
            when 'credit_card'        then 'Debt Refinancing'
            when 'home_improvement'   then 'Home'
            when 'house'              then 'Home'
            when 'major_purchase'     then 'Major Purchase'
            when 'car'                then 'Major Purchase'
            when 'small_business'     then 'Business'
            when 'medical'            then 'Life Event'
            when 'wedding'            then 'Life Event'
            when 'moving'             then 'Life Event'
            when 'vacation'           then 'Discretionary'
            when 'renewable_energy'   then 'Home'
            when 'educational'        then 'Life Event'
            when 'other'              then 'Other'
        end as purpose_category,

        purpose = 'small_business' as is_small_business

    from source_purposes

)

select * from final