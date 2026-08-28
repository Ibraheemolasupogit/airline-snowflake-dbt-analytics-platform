"""Deterministic synthetic airline source-data generation package.

This package builds a small, relationally coherent synthetic airline dataset
that sits downstream of the AirStats airport-reference foundation. It writes
plain CSV files under ``data/synthetic/`` and never queries or writes to
Snowflake. See ``docs/data_models/airline_synthetic_source_data.md`` for the
full design.
"""
