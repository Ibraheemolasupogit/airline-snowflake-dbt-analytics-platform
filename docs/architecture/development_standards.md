# Development Standards

## Naming Conventions

- dbt models use lower snake case.
- Staging models use `stg_<source>__<entity>`.
- Intermediate models use `int_<business_process>__<entity_or_step>`.
- Core dimensions use `dim_<entity>`.
- Core facts use `fct_<business_process_or_event>`.
- Marts use descriptive business-facing names scoped to their domain.

## Layer Responsibilities

- `staging`: one model per source entity where practical; rename, cast, deduplicate only when source-specific and documented.
- `intermediate`: reusable transformations and business logic that should not be exposed directly to reporting users.
- `core`: governed facts and dimensions with stable contracts, documented grain, and high-value tests.
- `marts`: consumption-ready reporting models for operational and commercial analytics.

## Model Grain

Every core and mart model must document its grain before or alongside implementation. Models that mix grains must be redesigned or explicitly justified.

## Testing Expectations

Use dbt generic and singular tests for primary keys, foreign keys, accepted values, not-null constraints, source quality, reconciliation, and business rules. Financial outputs require reconciliation tests that compare movements, balances, and exception handling.

## Documentation Requirements

Every source, model, and important column introduced in later milestones should have dbt documentation. Business-facing models must include ownership context, grain, refresh expectation, and known limitations.

## Source Lineage

Transformations must preserve source lineage through stable identifiers, load metadata, and documented joins. Do not remove source keys merely because a later model has a surrogate key.

## No-Secrets Rule

Do not commit passwords, tokens, private keys, account secrets, real profiles, or local environment files. Use environment variables and private local configuration.

## Incremental Models

Incremental materialisation should be applied model-by-model only when source volume, refresh pattern, and merge keys justify it. Incremental filters must be testable and documented.

## Financial Controls

Billing, revenue, payments, refunds, adjustments, balances, and reconciliation models must be auditable. Required controls include explicit grain, source-to-target tie-outs, exception classification, and tests for duplicate or missing financial events.
