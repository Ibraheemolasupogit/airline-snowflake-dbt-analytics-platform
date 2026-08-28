# Metric Definitions (Governed Metric Convention)

## Why this is a document, not a dbt Semantic Layer

Milestone 21 assessed whether a proper dbt Semantic Layer (`semantic_models:`/`metrics:` YAML,
queried via `dbt sl query`/MetricFlow) could be added cleanly. It could not, without adding an
unsupported dependency: `dbt-semantic-interfaces` is present only as a transitive dependency of
`dbt-core` 1.9 itself (used for internal manifest parsing), but the actual query engine package,
`dbt-metricflow`, is **not** listed in `requirements.txt` and has never been installed or
exercised in this repository. Declaring `semantic_models:`/`metrics:` YAML that has never been
queried end-to-end would be decorative -- present in the repo but unverified -- which this
milestone's own instructions explicitly reject ("prefer a stable portfolio repository over a
decorative broken semantic layer").

Instead, this document is the **governed metric-definition convention**: every metric a consumer
might reasonably ask for is defined once, precisely, with its exact source column and any
currency/grain caveat, so a future Milestone can wire it into a real semantic layer (or a BI tool's
own metric layer) without re-deriving the definition from scratch or guessing at semantics.

## Convention

Each metric below states:

- **Definition** -- what it means in one sentence.
- **Source** -- the exact governed model/column it reads (never re-derived here).
- **Grain** -- the level at which it is meaningful.
- **Currency** -- whether it is currency-safe as-is or requires grouping by currency.

No metric here recomputes business logic already implemented in a core fact or mart; each is a
direct pointer to an existing, tested column.

## Metrics

### total_bookings

- **Definition**: Count of bookings.
- **Source**: `count(*)` from `fct_bookings`, or `sum(booking_count)` from
  `mart_booking_performance` / `mart_booking_channel_performance`.
- **Grain**: Company-wide, or sliced by any of `fct_bookings`'s dimensions (status, trip type,
  channel, route).
- **Currency**: Not currency-denominated; safe to sum at any grain.

### completed_flights

- **Definition**: Count of flight instances with `status = 'completed'`.
- **Source**: `fct_flight_operations.status = 'completed'`, or `completed_flight_count` from
  `mart_daily_flight_operations` / `mart_route_operational_performance` /
  `mart_airline_on_time_performance`.
- **Grain**: Company-wide, daily, per route, or per airline.
- **Currency**: Not currency-denominated.

### passengers_carried

- **Definition**: Count of ticket segments actually flown (`journey_completion_status =
  'completed'`), never a raw ticket or booking count.
- **Source**: `fct_flight_operations.passengers_carried`, or `total_passengers_carried` from any
  airline_operations/revenue mart that reuses it.
- **Grain**: Per flight instance, or any aggregation of it (daily, route, airline, airport).
- **Currency**: Not currency-denominated.

### load_factor

- **Definition**: `passengers_carried / seats_available`, guarded to compute only when
  `seats_available > 0`.
- **Source**: `fct_flight_operations.load_factor` (the single generation point; every mart that
  reports a load factor either passes this through or re-aggregates it, never re-derives the
  formula independently).
- **Grain**: Per flight instance at source; averaged for daily/route/airline aggregates (an
  average of per-flight load factors, not a re-derived ratio of aggregate sums).
- **Currency**: Not currency-denominated. Bounded `[0, 1]`.

### recognised_revenue

- **Definition**: Earned revenue per Milestone 17's fulfilment-driven recognition policy --
  **never** an invoice total, and never revenue before the underlying service was fulfilled.
- **Source**: `fct_revenue.gross_recognised_amount` / `net_recognised_amount`, or any
  `recognised_ticket_revenue` / `recognised_ancillary_revenue` / `total_recognised_revenue` /
  `net_recognised_revenue` column across the `revenue` mart domain.
- **Grain**: Per revenue event at source; any aggregation of it must group by `currency`.
- **Currency**: **Critical** -- never sum across currencies. Every source column above is a
  `transaction_currency_amount`; there is no `reporting_currency_amount` anywhere in this
  repository (see `docs/data_models/airline_commercial_marts.md`).

### amount_collected

- **Definition**: Cash actually collected against invoices -- a billing/cash-flow measure, not
  recognised revenue.
- **Source**: `fct_invoices.amount_collected`, or `amount_collected_total` from
  `mart_daily_billing`.
- **Grain**: Per invoice at source; any aggregation must group by `currency`.
- **Currency**: Group by `currency`; never sum across currencies.

### refund_amount

- **Definition**: Refund amount, unmodified from source (including the deliberately injected
  `refund_greater_than_collected_amount` controlled exception's inflated value -- never capped).
- **Source**: `fct_refunds.refund_amount`, or `refund_amount_total` from `mart_refund_performance`
  / `mart_daily_billing`.
- **Grain**: Per refund at source; any aggregation must group by `currency`.
- **Currency**: Group by `currency`; never sum across currencies.

### outstanding_balance

- **Definition**: `source_invoice_total - amount_collected + refund_amount +
  net_adjustment_amount`. Positive = still due; zero = settled; negative = over-settled. Never
  clamped to zero.
- **Source**: `fct_outstanding_balances.outstanding_balance`, or `outstanding_balance_total` from
  `mart_outstanding_balances` / `mart_executive_billing_assurance`.
- **Grain**: Per invoice at source; any aggregation must group by `currency`.
- **Currency**: Group by `currency`; never sum across currencies.

### billing_exception_count

- **Definition**: Count of detected billing/revenue exceptions (fourteen rule-based types; see
  `docs/data_models/airline_outstanding_balances_exceptions.md`).
- **Source**: `count(*)` from `fct_billing_exceptions`, or `exception_count` from
  `mart_billing_exceptions` / `mart_executive_billing_assurance`.
- **Grain**: Company-wide, or sliced by exception type, severity, status, currency, route, or
  corporate account.
- **Currency**: Not itself currency-denominated (it is a count); the exception rows it counts
  may carry a `currency`-scoped `financial_value_at_risk_amount` separately (see below).

### financial_value_at_risk

- **Definition**: Non-negative absolute monetary exposure per detected exception; always `0` for
  the `late_arriving_payment` timing anomaly (a genuinely zero-exposure exception type).
- **Source**: `fct_billing_exceptions.financial_value_at_risk_amount`, or
  `financial_value_at_risk_total` from `mart_billing_exceptions` / `mart_executive_billing_
  assurance`.
- **Grain**: Per exception at source; any aggregation must group by `currency`.
- **Currency**: Group by `currency`; never sum across currencies.

## Explicitly not defined here

RASK, CASK, profit margin, contribution margin, and route profitability are deliberately absent:
no seat-kilometre cost basis or route/flight cost data exists anywhere in the Milestone 9
specification, so none of these can be defensibly computed. See `docs/data_models/
airline_commercial_marts.md`'s "Route Commercial Performance and the Profitability Exclusion"
section for the full rationale -- unchanged in Milestone 21.

## Future semantic-layer path

If `dbt-metricflow` is added to `requirements.txt` in a later milestone, every metric above can be
translated directly into a `semantic_models:`/`metrics:` YAML node: the **Source** column is
already the exact `measure`/`agg` target, and the **Currency** note is already the required
`dimension` to group by. No metric definition would need to change; only its representation would.
