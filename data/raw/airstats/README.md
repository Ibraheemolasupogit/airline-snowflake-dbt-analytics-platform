# AirStats Raw Data Convention

## Purpose

`data/raw/airstats/` is the local landing convention for airport-reference files that will
back the Snowflake `RAW_AIRSTATS` source schema in later load automation. Milestone 2 defines
the convention and dbt source metadata only; it does not load Snowflake tables.

## Source Provenance

The initial AirStats source specification maps to the public-domain OurAirports CSV downloads:

- `airports.csv`
- `runways.csv`
- `airport-comments.csv`
- `countries.csv`
- `regions.csv`

OurAirports documents the files as CSV with UTF-8 encoding and publishes nightly generated
downloads through the OurAirports site and the `davidmegginson/ourairports-data` GitHub mirror.
The files are public domain and carry no warranty of accuracy or fitness for use.

## Filename Convention

Raw exports should be stored locally with a dated suffix when used for development or load
testing:

- `airports_YYYYMMDD.csv`
- `runways_YYYYMMDD.csv`
- `airport_comments_YYYYMMDD.csv`
- `countries_YYYYMMDD.csv`
- `regions_YYYYMMDD.csv`

The source file `airport-comments.csv` is renamed to `airport_comments_YYYYMMDD.csv` locally so
that file names align with Snowflake table names and dbt source names.

## Commit Policy

Large raw CSV downloads are intentionally excluded from git by `.gitignore`. This README is
tracked so the raw-data contract is visible without committing external datasets. Small fixtures
may be added in a future milestone only when they are deterministic, clearly labelled as samples,
and useful for automated validation.

## Snowflake Raw Mapping

Future ingestion should load these files into the configured analytics database under schema
`RAW_AIRSTATS`:

| Local file pattern | Snowflake table | dbt source |
| --- | --- | --- |
| `airports_YYYYMMDD.csv` | `RAW_AIRSTATS.AIRPORTS` | `source('airstats', 'airports')` |
| `runways_YYYYMMDD.csv` | `RAW_AIRSTATS.RUNWAYS` | `source('airstats', 'runways')` |
| `airport_comments_YYYYMMDD.csv` | `RAW_AIRSTATS.AIRPORT_COMMENTS` | `source('airstats', 'airport_comments')` |
| `countries_YYYYMMDD.csv` | `RAW_AIRSTATS.COUNTRIES` | `source('airstats', 'countries')` |
| `regions_YYYYMMDD.csv` | `RAW_AIRSTATS.REGIONS` | `source('airstats', 'regions')` |

The raw-table design uses snake_case column names. For `airport-comments.csv`, ingestion should
map source headers `threadRef`, `airportRef`, `airportIdent`, `date`, and `memberNickname` to
`thread_ref`, `airport_ref`, `airport_ident`, `comment_date`, and `member_nickname`.

## Ingestion Assumptions

- Files are UTF-8 CSV with a header row.
- Source records are loaded without business filtering.
- Provider identifiers and relationship fields are preserved.
- No reliable raw ingestion timestamp is available in this milestone.
- dbt source freshness is therefore not configured for these static/reference-style datasets.

Separate raw `airport_types` and `runway_surfaces` datasets are not included because the public
source specification exposes those values as attributes rather than standalone CSV downloads.
