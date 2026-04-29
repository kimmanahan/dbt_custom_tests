/*
 * Generic test to validate that all expected records exist in a final model. Uses Snowflake as data source so may need to tweak to_varchar()depending on db.
 *
 * Purpose
 * - Ensures completeness by verifying that every key (or composite key) from a
 *   comparison dataset exists in the target (final) model.
 * - Supports simple model-to-model comparison as well as complex, business logic-driven
 *   reconciliation across multiple joined source tables.
 * - Provides flexible filtering and configurable failure thresholds.
 *
 * Key capabilities
 * - Single or composite key comparison
 * - Compare against a single model or custom SQL (multi-table joins)
 * - Optional business logic on both compare and final datasets
 * - Supports mismatched key column names between datasets
 * - Side-specific and shared filters
 * - Configurable failure threshold using fail_if_gte
 *
 * Notes
 * - Keys are normalized to varchar before comparison to avoid Snowflake implicit
 *   casting errors when comparing numeric ids to varchar ids such as UUIDs.
 */

{% test all_records_exist_in_final(
    model,
    compare_model=None,
    compare_sql=None,
    final_sql=None,
    key_columns=None,
    compare_key_columns=None,
    final_key_columns=None,
    where_clause=None,
    model_where=None,
    compare_where=None,
    fail_if_gte=1
) %}

{{ config(severity='warn') }}


{%- if key_columns is none and (compare_key_columns is none or final_key_columns is none) -%}
    {{ exceptions.raise_compiler_error(
        "all_records_exist_in_final: provide either key_columns or both compare_key_columns and final_key_columns"
    ) }}
{%- endif -%}

{%- if compare_model is none and compare_sql is none -%}
    {{ exceptions.raise_compiler_error(
        "all_records_exist_in_final: provide either compare_model or compare_sql"
    ) }}
{%- endif -%}

{%- if compare_model is not none and compare_sql is not none -%}
    {{ exceptions.raise_compiler_error(
        "all_records_exist_in_final: provide only one of compare_model or compare_sql"
    ) }}
{%- endif -%}

{%- set compare_keys = compare_key_columns if compare_key_columns is not none else key_columns -%}
{%- set final_keys_list = final_key_columns if final_key_columns is not none else key_columns -%}

{%- if compare_keys | length != final_keys_list | length -%}
    {{ exceptions.raise_compiler_error(
        "all_records_exist_in_final: compare_key_columns and final_key_columns must have the same number of columns"
    ) }}
{%- endif -%}

with raw_src as (

    {% if compare_sql is not none %}
        select *
        from (
            {{ compare_sql }}
        ) as compare_subquery
        where 1 = 1
        {% if where_clause is not none %}
          and {{ where_clause }}
        {% endif %}
        {% if compare_where is not none %}
          and {{ compare_where }}
        {% endif %}
    {% else %}
        select *
        from {{ compare_model }}
        where 1 = 1
        {% if where_clause is not none %}
          and {{ where_clause }}
        {% endif %}
        {% if compare_where is not none %}
          and {{ compare_where }}
        {% endif %}
    {% endif %}

),

raw_final as (

    {% if final_sql is not none %}
        select *
        from (
            {{ final_sql }}
        ) as final_subquery
        where 1 = 1
        {% if where_clause is not none %}
          and {{ where_clause }}
        {% endif %}
        {% if model_where is not none %}
          and {{ model_where }}
        {% endif %}
    {% else %}
        select *
        from {{ model }}
        where 1 = 1
        {% if where_clause is not none %}
          and {{ where_clause }}
        {% endif %}
        {% if model_where is not none %}
          and {{ model_where }}
        {% endif %}
    {% endif %}

),

src_keys as (

    select distinct
        {% for col in compare_keys %}
            to_varchar({{ col }}) as key_{{ loop.index0 }}{% if not loop.last %}, {% endif %}
        {% endfor %}
    from raw_src

),

final_keys as (

    select distinct
        {% for col in final_keys_list %}
            to_varchar({{ col }}) as key_{{ loop.index0 }}{% if not loop.last %}, {% endif %}
        {% endfor %}
    from raw_final

),

missing as (

    select
        src_keys.*
    from src_keys
    left join final_keys
      on
      {% for i in range(compare_keys | length) %}
        src_keys.key_{{ i }} = final_keys.key_{{ i }}{% if not loop.last %} and {% endif %}
      {% endfor %}
    where
      {% for i in range(compare_keys | length) %}
        final_keys.key_{{ i }} is null{% if not loop.last %} and {% endif %}
      {% endfor %}

),

missing_count as (

    select count(*) as missing_record_count
    from missing

),

failing_rows as (

    select
        missing.*
    from missing
    cross join missing_count
    where missing_count.missing_record_count >= {{ fail_if_gte }}

)

select *
from failing_rows

{% endtest %}
