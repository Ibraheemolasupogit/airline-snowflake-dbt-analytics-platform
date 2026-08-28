"""Offline jinja-only lint shim for the one dbt_utils macro used in model SQL.

CI and local ``sqlfluff lint --templater jinja`` runs (see .github/workflows/ci.yml) render
models with plain Jinja, not the dbt templater, because the dbt templater requires a live
Snowflake connection. Plain Jinja has no notion of installed dbt packages, so
``dbt_utils.generate_surrogate_key(...)`` -- used by every model under models/core/dimensions/ --
would otherwise fail to parse. This module is loaded via [sqlfluff:templater:jinja]
library_path = sqlfluff_libs (see .sqlfluff) and exposed in templates as ``dbt_utils``. It only
needs to produce syntactically valid Snowflake SQL for linting; it is never executed against a
warehouse, so it does not need to match dbt_utils' real hashing semantics exactly.
"""


def generate_surrogate_key(field_list):
    coalesced = [
        f"coalesce(cast({field} as varchar), '_dbt_utils_surrogate_key_null_')"
        for field in field_list
    ]
    return "md5(cast(" + " || '-' || ".join(coalesced) + " as varchar))"
