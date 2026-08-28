# dbt Production Runbook

This runbook is written as if a real Snowflake account existed for this project. **It does not.**
No command in this document has ever been executed against a live warehouse by this repository --
see `docs/engineering/dbt_production_engineering.md`'s "Operational Limitations" section. This is
a readiness runbook, not a record of production operations.

## Environments

Three logical environments, distinguished by target/schema naming, never by hardcoded credentials:

| Environment | `profiles.yml` target | Typical schema | Purpose |
| --- | --- | --- | --- |
| `dev` | `dev` (the only target `profiles.example.yml` defines) | `analytics_dev` (or a developer-specific schema via `SNOWFLAKE_SCHEMA`) | Local development, iterating on models before a PR. |
| `ci` | `dev` (CI reuses the same target with CI-specific env vars) | `analytics_ci` | `.github/workflows/ci.yml`'s `warehouse-assurance` job, when Snowflake secrets are configured. |
| `prod` | Not yet defined in `profiles.example.yml` | e.g. `analytics_prod` | A real production deployment -- reserved for a future milestone; no `prod` target exists in this repository today, and none should be added without a real, separately-secured Snowflake account. |

Every environment is driven entirely by environment variables (`SNOWFLAKE_ACCOUNT`,
`SNOWFLAKE_USER`, `SNOWFLAKE_ROLE`, `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_DATABASE`,
`SNOWFLAKE_SCHEMA`, `SNOWFLAKE_PRIVATE_KEY_PATH`) -- never a hardcoded value in `profiles.yml`
itself. `profiles.example.yml` is the only profile committed to the repository; a real
`profiles.yml` is gitignored and must be created locally (`cp profiles.example.yml profiles.yml`).

## Environment Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
dbt deps
```

For any command that touches a real warehouse (everything from "Build" onward in this runbook):

```bash
cp profiles.example.yml profiles.yml
export SNOWFLAKE_ACCOUNT="<account_identifier>"
export SNOWFLAKE_USER="<user>"
export SNOWFLAKE_ROLE="<role>"
export SNOWFLAKE_WAREHOUSE="<warehouse>"
export SNOWFLAKE_DATABASE="<database>"
export SNOWFLAKE_SCHEMA="<schema>"
export SNOWFLAKE_PRIVATE_KEY_PATH="<local_private_key_path>"
```

**Prerequisite this repository has never performed**: the `RAW_AIRLINE_*`/`RAW_AIRSTATS` schemas
these `profiles.yml`-configured sources point at must already contain data before any `dbt run`/
`dbt build` against them can succeed -- either the Milestone 9 synthetic CSVs
(`data/synthetic/**/*.csv`, produced by `python scripts/generate_airline_data.py`) loaded via
Snowflake's own bulk-load tooling (`COPY INTO`, Snowpipe, or equivalent -- not a dbt command), or a
real upstream ingestion pipeline's output. No command in this runbook performs that load.

## `dbt deps`

```bash
dbt deps
```

Installs `dbt-labs/dbt_utils`, `metaplane/dbt_expectations`, `godatadriven/dbt_date` into
`dbt_packages/` (pinned versions in `packages.yml`). Run this first, always -- every other command
below depends on it. If `dbt_packages/` ever ends up with duplicate `" 2"`/`" 3"`-suffixed
directories (a known artifact of concurrent tool invocations against this project during
development), the fix is `rm -rf dbt_packages && dbt deps`.

## `dbt parse`

```bash
dbt parse --profiles-dir .
```

Validates project/Jinja/ref structure without touching a warehouse (the placeholder env vars
`.github/workflows/ci.yml` uses for its `offline-assurance` job work for this locally too). This
is the command to run first when debugging "does my new model even parse" -- it is dramatically
faster than a real `run`/`build` and requires no credentials.

## `dbt build`

```bash
dbt build --profiles-dir .
```

Seeds, runs, snapshots, and tests the whole project in dependency order. Requires real Snowflake
credentials and the RAW schemas already loaded (see "Environment Setup" above). To scope a build
to only what changed, use `--select`:

```bash
dbt build --select fct_revenue+ --profiles-dir .          # a model and everything downstream of it
dbt build --select state:modified+ --defer --state <path> --profiles-dir .   # see "State/Defer Usage" below
```

## `dbt snapshot`

```bash
dbt snapshot --profiles-dir .
```

Included automatically inside `dbt build`; run standalone only when iterating on a snapshot
definition without re-running the whole project. The **first** invocation of any snapshot
(`snap_airports`, `snap_runways`, or the four Milestone 21 airline snapshots) materializes every
current row as its initial version (`dbt_valid_from` = that run's timestamp, `dbt_valid_to` =
null). Every subsequent invocation is where the `check`/`timestamp` strategy actually does its
work -- comparing current source state against the last known version and inserting a new row only
where `check_cols` differ (see `docs/engineering/dbt_production_engineering.md`'s "Snapshot
Strategy" for why every snapshot in this project uses `check`, never `timestamp`).

## `dbt test`

```bash
dbt test --profiles-dir .                       # every test
dbt test --select tag:business_rules --profiles-dir .   # by test-folder-derived tag/path selector
```

Included automatically inside `dbt build`. `dbt_project.yml` already configures
`+store_failures: true` for every test folder except the top-level default (`business_rules`,
`data_quality`, `incremental_integrity`, `referential_integrity`, `singular`,
`snapshot_integrity`, `source_quality` all store failing rows to the `DBT_TEST_FAILURES` schema on
a real warehouse run) -- inspect a failure's actual offending rows there rather than only reading
the pass/fail summary.

## `dbt docs generate`

```bash
dbt docs generate --profiles-dir .
dbt docs serve --profiles-dir .   # local browsing only; not how this would be published
```

Requires a warehouse connection (it queries `information_schema` for the catalog). Produces
`target/catalog.json` alongside the existing `target/manifest.json`. Every model/column in this
project already carries a `description` (a requirement since `docs/architecture/
development_standards.md`), every cross-model reference uses `ref()`/`source()` (real lineage,
not string literals), and the six Milestone 21 exposures give the generated docs site's lineage
graph explicit downstream consumption-surface nodes -- the project is ready for this command; it
has simply never been run against a real warehouse.

## Full Refresh

```bash
dbt run --select fct_payment_attempts fct_payments fct_refunds fct_revenue --full-refresh --profiles-dir .
```

Required for:

- **The first deployment run** of any of the four incremental models (there is no prior
  incremental table to merge into yet).
- **After any schema change** to one of the four (all four use `on_schema_change='fail'`, so a
  column add/drop/rename stops the incremental run rather than silently patching the table --
  the deliberate, conservative choice for financial-control facts; see the engineering doc).
- **After a change to upstream business logic** that would retroactively change already-
  materialized rows (e.g. a fix to `int_payment_attempt_classification`'s classification rule) --
  an incremental run would only apply the new logic to newly-filtered rows, leaving old rows
  computed under the old logic.

A `--full-refresh` on `fct_revenue` or `fct_payments` should be followed by a full-refresh of
anything downstream that also reads them incrementally or via `ref()` in an incremental filter
context (currently: `fct_refunds` reads `fct_payments`; no model reads `fct_revenue`
incrementally downstream).

## Failed Incremental Recovery

1. Read the failed run's `run_results.json` (or the CI `warehouse-assurance` job's uploaded
   artifact) for the specific model and error.
2. If the failure was a **transient warehouse issue** (timeout, connection drop): simply re-run
   `dbt build --select <model>+ --profiles-dir .`. The `merge` strategy is idempotent for a given
   source-data snapshot -- re-running with the same upstream data produces the same result.
3. If the failure was `on_schema_change='fail'` firing: this is not a bug, it is the guardrail
   working. Reconcile the model's YAML contract (if any) and column list with the actual intended
   schema change, then run `--full-refresh` for that model.
4. If the failure suggests the incremental table has **drifted from what a full rebuild would
   produce** (e.g. after fixing a bug in one of the four incremental models' own SQL): run
   `--full-refresh` for that model rather than trying to reason about what an incremental patch
   would need to do.
5. Re-run the model's own tests (`dbt test --select <model>`) after any recovery step, before
   trusting the table again.

## Snapshot Recovery Considerations

- Snapshots are **append-only by design** -- there is no `--full-refresh` flag for `dbt snapshot`.
  If a snapshot's history needs to be rebuilt from scratch (e.g. a `check_cols` list changed and
  the old history is no longer meaningful), the recovery is manual: drop the snapshot's target
  table in Snowflake, then re-run `dbt snapshot --select <snapshot_name>` to re-seed it as a fresh
  initial version. This discards all prior history -- confirm that is actually intended before
  doing it.
- `invalidate_hard_deletes=True` is set on every snapshot in this project (AirStats and Milestone
  21 airline snapshots alike). A source row that disappears entirely (not just changes) is
  detected and closes out that row's `dbt_valid_to` on the next snapshot run -- verify this is the
  desired behaviour before relying on it for an entity where a "disappearance" might actually mean
  "not yet loaded this run" rather than "genuinely deleted."

## State/Defer Usage

Not yet operable in this repository -- see `docs/engineering/dbt_production_engineering.md`'s
"State/Defer Strategy" section for why (no previous manifest is persisted anywhere yet). Once a
future milestone adds that persistence (e.g. downloading the prior `main`-branch run's
`dbt-manifest-<sha>` CI artifact), the commands would be:

```bash
dbt build --select state:modified+ --defer --state <path-to-downloaded-prior-manifest-dir> --profiles-dir .
```

`state:modified+` selects only models/tests changed since the compared manifest, plus everything
downstream of them; `--defer` lets unchanged upstream models resolve against the *previous* run's
already-built tables instead of requiring a full rebuild in the current environment.

## CI Artifact Review

- Every `offline-assurance` CI run uploads `manifest.json` (GitHub Actions artifact
  `dbt-manifest-<sha>`, 30-day retention) -- download it from the workflow run's "Artifacts"
  section to inspect the parsed project graph for that commit without re-running `dbt parse`
  locally.
- Every `warehouse-assurance` CI run (only when it actually ran -- see the engineering doc's
  "Offline vs. Warehouse CI") additionally uploads `manifest.json`, `catalog.json`, and
  `run_results.json` (artifact `dbt-warehouse-artifacts-<sha>`). `run_results.json` is the first
  place to look after any warehouse-assurance failure -- it carries the per-node status, timing,
  and (for a failed test) the compiled SQL that failed.

## Rollback/Recovery Principles

- **Tables** (`core`, `marts`, non-incremental facts): a `dbt build`/`dbt run` on a given commit
  is fully reproducible from that commit's SQL and the current source data -- "rollback" is
  `git checkout` to the prior commit and re-run, not a warehouse-side operation.
- **Incremental facts**: rollback is not simply re-running old SQL, because the *target table*
  already carries state from newer runs. Reverting an incremental model's logic requires a
  `--full-refresh` on that model after the code rollback, not just a re-run -- otherwise the table
  is left as a mix of old-logic and new-logic rows.
- **Snapshots**: never roll back by re-running old snapshot SQL against the live table -- that
  would corrupt the SCD history (see "Snapshot Recovery Considerations" above). A snapshot
  logic change is forward-only; historical rows already captured under the old logic remain as
  they are.
- **Never** use `dbt run --full-refresh` (whole-project) as a default troubleshooting step. It is
  the correct recovery for the specific incremental-model scenarios above, but applied
  project-wide it unnecessarily rebuilds every table-materialized model from scratch (snapshot
  history itself is unaffected either way -- `dbt snapshot` has no full-refresh flag at all).
  Prefer `--select <specific model>+` scoping instead of a whole-project full refresh.
