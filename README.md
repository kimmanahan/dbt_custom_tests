Custom Generic dbt Tests
A collection of generic, reusable dbt tests for data validation, reconciliation, and quality monitoring. Each test is parameterized and project-agnostic — drop them into any dbt project and configure via test arguments.
Tests
all_records_exist_in_final
Validates completeness by ensuring every key (or composite key) from a comparison dataset exists in a target model. Useful for verifying that no records were dropped during transformation, or for reconciling a final mart against upstream sources.
Capabilities

Single or composite key comparison
Compare against another model or against custom SQL (multi-table joins)
Optional business logic on either side via where-clauses
Mismatched key column names between datasets
Side-specific and shared filters
Configurable failure threshold (fail_if_gte)

Example
yamlversion: 2

models:
  - name: dim_customer
    tests:
      - all_records_exist_in_final:
          compare_model: ref('stg_customer')
          key_columns: ['customer_id']
          fail_if_gte: 1
        
Conventions

All tests default to severity: warn unless overridden in your dbt config
Keys are normalized to varchar before comparison to avoid implicit-cast issues (especially in Snowflake)
Tests accept either compare_model or compare_sql, never both
Where-clauses can be applied per-side (compare_where, model_where) or to both sides (where_clause)

Installation
Drop the .sql file into your project's tests/generic/ directory. dbt will register the test automatically on the next compile.
Compatibility
Built and tested against dbt-core with Snowflake as the warehouse. Most tests are warehouse-agnostic; any warehouse-specific functions (e.g. to_varchar) are noted in test headers.
