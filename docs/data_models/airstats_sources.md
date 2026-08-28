# AirStats Source Quality Notes

## Dataset Purpose

AirStats is the authoritative airport-reference source foundation for this platform. It provides
airport, runway, country, region, and comment context that later milestones can conform for route
and flight modelling, then downstream operational and commercial analytics.

Milestone 3 adds dbt staging views on top of the Milestone 2 source definitions:

```text
RAW_AIRSTATS
-> source()
-> AirStats staging views
-> intermediate airport intelligence
```

The staging views perform explicit column selection, Snowflake-safe typing, source-aligned
renaming, blank-string-to-null handling, simple boolean normalization, and lineage preservation.
They do not implement intermediate transformations, conformed dimensions, marts, route modelling,
flight modelling, or commercial analytics.

## Entities

- `airports`: one row per airport-like facility. Natural key: `ident`.
- `runways`: one row per landing surface. Natural key: source `id`; airport relationship key:
  `airport_ident`.
- `airport_comments`: one row per airport comment. Natural key: source `id`; airport relationship
  key: `airport_ident`.
- `countries`: one row per country or country-like entity. Natural key: `code`.
- `regions`: one row per high-level administrative subdivision. Natural key: `code`.

Separate `airport_types` and `runway_surfaces` source tables are not configured in Milestone 2
because the available raw source design provides those as attributes on `airports` and `runways`,
not as standalone datasets.

## Relationships

The source-level relationships expected by this milestone are:

```text
airports.ident
-> runways.airport_ident

airports.ident
-> airport_comments.airport_ident

countries.code
-> regions.iso_country

regions.code
-> airports.iso_region

countries.code
-> airports.iso_country
```

Milestone 2 tests the first three relationships where they are directly configured in dbt source
metadata. Additional country and region joins are documented for later staging and conformance.

## Expected Cardinalities

- One `airports.ident` value can have zero, one, or many `runways` rows.
- One `airports.ident` value can have zero, one, or many `airport_comments` rows.
- One `countries.code` value can have zero, one, or many `regions` rows.
- One `regions.code` value can have zero, one, or many `airports` rows.

## Known Source-Quality Risks

- Airport type is a source classification and may not match downstream commercial airport
  segmentation.
- Runway `surface` values are not represented by a separate controlled raw lookup table.
- Airport comments are user-generated text and may be incomplete, duplicated in meaning, stale, or
  unsuitable for governed reporting without curation.
- Airport identifiers can change in operational reality; both source `id` and public `ident`
  should be retained through staging for lineage review.
- Latitude, longitude, runway dimensions, links, and keyword fields may be null.

## Null Handling Expectations

- Natural keys used for source relationships should be non-null.
- Optional descriptive fields should remain nullable in the raw source layer.
- Numeric quality tests should allow nulls where the source specification treats the attribute as
  optional, then enforce valid ranges only when populated.

## Freshness

No dbt source freshness is configured in Milestone 2. These files are static/reference-style CSV
extracts and the raw-table design does not yet include a reliable ingestion timestamp. A future
load process may add metadata such as `loaded_at`, `source_file_name`, and `source_file_date`;
freshness should only be enabled after those fields exist in Snowflake.

## Future Snowflake Load Pattern

Future load automation should stage dated CSV files from `data/raw/airstats/` or an external
object store, load them into `RAW_AIRSTATS`, preserve provider keys, and normalize only mechanical
header naming differences such as camelCase to snake_case. Business cleaning belongs in Milestone
3 staging models, not in the raw/source definition.

## Staging Views

- `stg_airstats__airports`: one row per source airport-like facility. Natural key: `ident`.
- `stg_airstats__runways`: one row per source landing surface. Natural key:
  `runway_source_id`; airport relationship key: `airport_ident`.
- `stg_airstats__airport_comments`: one row per source comment. Natural key:
  `airport_comment_source_id`; airport relationship key: `airport_ident`.
- `stg_airstats__countries`: one row per source country or country-like entity. Natural key:
  `country_code`.
- `stg_airstats__regions`: one row per source administrative subdivision. Natural key:
  `region_code`; country relationship key: `country_code`.

## Intermediate Airport Intelligence

Milestone 4 adds reusable intermediate AirStats transformations upstream of future dimensions,
facts, and marts:

- `int_airport_geography`: one row per airport identifier; joins staged airports to staged
  countries and regions while preserving airports with missing geography references.
- `int_airport_runway_profile`: one row per airport identifier; aggregates source runway counts,
  open/closed/lighted counts, length and width summaries, and distinct surface count.
- `int_airport_operational_status`: one row per airport identifier; creates transparent
  source-derived analytical status categories from airport type, scheduled-service flag, and
  runway records.
- `int_airport_comment_activity`: one row per airport identifier; aggregates comment counts,
  first/latest timestamps, distinct threads, distinct members, and comments with text.
- `int_airport_comment_quality`: one row per airport identifier; measures structural comment
  completeness for comments that can be linked to an airport.
- `int_runway_capability`: one row per runway source identifier; categorizes runway length,
  width, surface, endpoint completeness, and source closed/open usability.

The operational-status and runway-capability fields are source-derived analytical attributes.
They are not live operational status, NOTAM interpretation, regulatory approval, runway
certification, landing approval, aircraft compatibility, or commercial route coverage.
