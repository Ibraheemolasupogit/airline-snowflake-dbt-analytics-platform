"""Products, services, and pricing reference domain.

Grain:
    currencies: one row per currency code.
    exchange_rates: one row per currency, rate to USD as of AS_OF_DATE.
    fare_classes: one row per sellable fare class.
    fare_rules: one row per fare class rule set.
    products: one row per sellable fare bundle.
    services: one row per sellable ancillary/service catalog entry.
    airport_fees: one row per (airport, fee type).
    taxes: one row per (country, tax type).
    discounts: one row per discount code.
    ancillary_services: one row per ancillary service sold against a ticket
        (built in build_bookings.build_ancillary_services once tickets exist).
"""

from __future__ import annotations

from . import reference
from .config import AS_OF_DATE
from .utils import date_to_iso


def build_currencies() -> list[dict]:
    return [
        {"currency_code": code, "currency_name": name, "minor_unit_digits": digits}
        for code, name, digits in reference.CURRENCIES
    ]


def build_exchange_rates() -> list[dict]:
    return [
        {
            "currency_code": code,
            "rate_to_usd": reference.EXCHANGE_RATE_TO_USD[code],
            "as_of_date": date_to_iso(AS_OF_DATE),
        }
        for code, *_rest in reference.CURRENCIES
    ]


def build_fare_classes() -> list[dict]:
    return [
        {
            "fare_class_code": code,
            "cabin": cabin,
            "fare_basis_code": basis,
            "refundable": refundable,
            "change_fee_usd": change_fee,
            "base_fare_usd": base_fare,
            "per_km_usd": per_km,
            "description": description,
        }
        for code, cabin, basis, refundable, change_fee, base_fare, per_km, description in reference.FARE_CLASSES
    ]


def build_fare_rules() -> list[dict]:
    rows = []
    for code, cabin, _basis, refundable, change_fee, _base_fare, _per_km, _description in reference.FARE_CLASSES:
        rows.append(
            {
                "fare_rule_id": f"FRR-{code}",
                "fare_class_code": code,
                "refundable": refundable,
                "change_fee_usd": change_fee,
                "advance_purchase_days": 14 if cabin == "Y" else 0,
                "min_stay_nights": 1 if refundable is False else 0,
            }
        )
    return rows


def build_products() -> list[dict]:
    return [
        {
            "product_code": code,
            "product_name": name,
            "fare_class_code": fare_class_code,
            "included_service_codes": "|".join(included),
        }
        for code, name, fare_class_code, included in reference.PRODUCTS
    ]


def build_services() -> list[dict]:
    return [
        {
            "service_code": code,
            "service_name": name,
            "category": category,
            "base_price_usd": price,
        }
        for code, name, category, price in reference.SERVICES
    ]


def build_airport_fees() -> list[dict]:
    rows = []
    for ident, _icao, _iata, _name, _municipality, iso_country, _region, _continent, _lat, _lon, _offset in (
        reference.AIRPORT_FIXTURE
    ):
        currency = reference.COUNTRY_CURRENCY[iso_country]
        rate = reference.EXCHANGE_RATE_TO_USD[currency]
        for fee_code, fee_name, amount_usd in reference.AIRPORT_FEE_TYPES:
            rows.append(
                {
                    "airport_fee_id": f"FEE-{ident}-{fee_code}",
                    "airport_ident": ident,
                    "fee_code": fee_code,
                    "fee_name": fee_name,
                    "currency_code": currency,
                    "amount": round(amount_usd / rate, 2),
                }
            )
    return rows


def build_taxes() -> list[dict]:
    rows = []
    countries = sorted({row[5] for row in reference.AIRPORT_FIXTURE})
    for country in countries:
        currency = reference.COUNTRY_CURRENCY[country]
        for tax_code, tax_name, percentage_rate in reference.COUNTRY_TAX_TYPES:
            rows.append(
                {
                    "tax_id": f"TAX-{country}-{tax_code}",
                    "country_code": country,
                    "tax_code": tax_code,
                    "tax_name": tax_name,
                    "percentage_rate": percentage_rate,
                    "currency_code": currency,
                }
            )
    return rows


def build_discounts(corporate_accounts: list[dict]) -> list[dict]:
    rows = [
        {
            "discount_code": code,
            "discount_name": name,
            "discount_type": discount_type,
            "value": value,
            "corporate_account_id": "",
        }
        for code, name, discount_type, value in reference.GENERIC_DISCOUNTS
    ]
    for account in corporate_accounts:
        rows.append(
            {
                "discount_code": f"CORP-{account['corporate_account_id']}",
                "discount_name": f"Corporate rate: {account['company_name']}",
                "discount_type": "percentage",
                "value": account["negotiated_discount_pct"],
                "corporate_account_id": account["corporate_account_id"],
            }
        )
    return rows
