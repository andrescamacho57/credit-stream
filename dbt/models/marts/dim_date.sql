-- Grain: one row per calendar day.
--
-- Generated as a full daily calendar rather than derived from loan issue
-- dates. Loans were issued monthly (139 distinct months), but payment events
-- land on arbitrary days - so a dimension built only from issue dates would
-- give the payment fact nothing to join to. A conformed dimension has to
-- serve every fact table that needs it.
--
-- Range covers 2007 (earliest loan) through 2028 (past the maturity of the
-- last 60-month loan, and forward far enough for simulated payment events).

with date_spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2007-01-01' as date)",
        end_date="cast('2028-01-01' as date)"
    ) }}

),

enriched as (

    select
        -- Integer surrogate key, YYYYMMDD. Dimensional modeling convention:
        -- recognizable to anyone reading the schema, and readable inside the
        -- fact table without a join. Arithmetic requires the date_day column.
        cast(to_char(date_day, 'YYYYMMDD') as integer) as date_key,

        date_day                                       as calendar_date,

        year(date_day)                                 as calendar_year,
        quarter(date_day)                              as calendar_quarter,
        month(date_day)                                as month_number,
        monthname(date_day)                            as month_name,
        day(date_day)                                  as day_of_month,
        dayofweek(date_day)                            as day_of_week_number,
        dayname(date_day)                              as day_name,
        weekofyear(date_day)                           as week_of_year,

        -- Display and grouping helpers. Cheap to store, saves repeating
        -- the same formatting logic in every downstream query.
        to_char(date_day, 'YYYY-MM')                   as year_month,
        'Q' || quarter(date_day) || ' ' || year(date_day) as quarter_label,

        date_trunc('month', date_day)                  as month_start_date,
        last_day(date_day, 'month')                    as month_end_date,

        dayofweek(date_day) in (0, 6)                  as is_weekend

    from date_spine

)

select * from enriched
