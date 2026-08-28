"""Lightweight tests for the deterministic synthetic airline data generator.

These are plain pytest/Python tests -- they do not invoke dbt or Snowflake.
They exercise ``scripts/generate_airline_data.py``, ``scripts/generate_control_totals.py``,
and ``scripts/validate_source_data.py`` directly against temporary output
directories so they never depend on (or mutate) the committed
``data/synthetic/`` fixtures.
"""

from __future__ import annotations

import filecmp
from pathlib import Path

import pytest

import generate_airline_data as gen
import generate_control_totals as totals_mod
import validate_source_data as validator
from airline_synth.config import GeneratorConfig

SMALL_CONFIG_KWARGS = {"num_bookings": 60, "num_passengers": 60}


@pytest.fixture(scope="module")
def generated_tables():
    config = GeneratorConfig(**SMALL_CONFIG_KWARGS)
    return gen.generate(config)


@pytest.fixture(scope="module")
def generated_dir(tmp_path_factory) -> Path:
    output_dir = tmp_path_factory.mktemp("synthetic_a")
    config = GeneratorConfig(output_dir=str(output_dir), **SMALL_CONFIG_KWARGS)
    tables = gen.generate(config)
    gen.write_tables(tables, output_dir)
    return output_dir


def test_generate_is_deterministic_in_memory():
    config = GeneratorConfig(**SMALL_CONFIG_KWARGS)
    tables_a = gen.generate(config)
    tables_b = gen.generate(config)
    assert tables_a.keys() == tables_b.keys()
    for name in tables_a:
        assert tables_a[name] == tables_b[name], f"table '{name}' differs between identical-seed runs"


def test_generate_is_deterministic_on_disk(tmp_path_factory):
    config = GeneratorConfig(**SMALL_CONFIG_KWARGS)

    dir_a = tmp_path_factory.mktemp("det_a")
    dir_b = tmp_path_factory.mktemp("det_b")
    gen.write_tables(gen.generate(config), dir_a)
    gen.write_tables(gen.generate(config), dir_b)

    for name, path in gen.OUTPUT_PATHS.items():
        assert filecmp.cmp(dir_a / path, dir_b / path, shallow=False), f"{name} differs across runs"


def test_different_seed_changes_output():
    tables_default = gen.generate(GeneratorConfig(**SMALL_CONFIG_KWARGS))
    tables_other = gen.generate(GeneratorConfig(seed=999, **SMALL_CONFIG_KWARGS))
    assert tables_default["bookings"] != tables_other["bookings"]


@pytest.mark.parametrize("table,pk", list(validator.PRIMARY_KEYS.items()))
def test_primary_keys_are_unique_and_non_null(generated_tables, table, pk):
    values = [row[pk] for row in generated_tables[table]]
    assert all(values), f"{table}.{pk} has a null/blank value"
    assert len(values) == len(set(values)), f"{table}.{pk} has duplicate values"


def test_foreign_keys_resolve_or_are_documented_exceptions(generated_tables):
    report = validator.Report()
    validator.check_foreign_keys(generated_tables, generated_tables["exception_manifest"], report)
    assert report.is_clean(), report.unexpected


def test_exception_manifest_has_the_fourteen_expected_types(generated_tables):
    manifest = generated_tables["exception_manifest"]
    assert len(manifest) == 14
    types = {row["exception_type"] for row in manifest}
    assert types == validator.EXPECTED_EXCEPTION_TYPES


def test_exception_fingerprints_are_present(generated_tables):
    report = validator.Report()
    validator.verify_exception_fingerprints(
        generated_tables, generated_tables["exception_manifest"], report
    )
    assert report.is_clean(), report.unexpected


def test_currencies_are_all_supported(generated_tables):
    report = validator.Report()
    validator.check_currencies(generated_tables, report)
    assert report.is_clean(), report.unexpected


def test_control_totals_are_stable_for_identical_input(generated_dir):
    first = totals_mod.compute_control_totals(generated_dir)
    second = totals_mod.compute_control_totals(generated_dir)
    assert first == second


def test_control_totals_reflect_row_counts(generated_dir, generated_tables):
    result = totals_mod.compute_control_totals(generated_dir)
    control = result["control_totals"]
    assert control["booking_count"] == len(generated_tables["bookings"])
    assert control["invoice_count"] == len(generated_tables["invoices"])
    assert control["flight_instance_count"] == len(generated_tables["flight_instances"])
    assert control["ticket_count"] == len(generated_tables["tickets"])
    assert control["successful_payment_count"] == len(generated_tables["payments"])
    assert control["refund_count"] == len(generated_tables["refunds"])


def test_validator_passes_on_freshly_generated_data(generated_dir):
    exit_code = validator.main(["--data-dir", str(generated_dir), "--skip-determinism-check"])
    assert exit_code == 0


def test_airports_reference_only_documented_fixture_idents(generated_tables):
    from airline_synth import reference

    fixture_idents = {row[0] for row in reference.AIRPORT_FIXTURE}
    airport_idents = {row["ident"] for row in generated_tables["airports"]}
    assert airport_idents == fixture_idents
    for route in generated_tables["routes"]:
        assert route["origin_ident"] in fixture_idents
        assert route["destination_ident"] in fixture_idents
