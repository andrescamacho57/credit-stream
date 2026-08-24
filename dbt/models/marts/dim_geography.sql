-- Grain: one row per US state (51, including DC).
--
-- Built on the state_regions seed rather than derived from the loan data,
-- because a dimension should describe the full domain - not just the values
-- that happen to appear in one fact table. A state with zero loans still
-- belongs here, or "loans by region" silently omits it from the denominator.
--
-- Regions and divisions follow the official US Census classification, so
-- aggregates here are comparable to published statistics.

with states as (

    select * from {{ ref('state_regions') }}

),

final as (

    select
        -- Natural key. Two-letter code is already unique, stable, and
        -- meaningful - no surrogate key needed. A surrogate would add a
        -- lookup step and hide the value.
        state_code                as state_key,

        state_name,
        census_region,
        census_division

    from states

)

select * from final

-- dim_geography.sql defines how to build the model/table.
-- _dim_geography.yml documents it and defines tests (quality checks).