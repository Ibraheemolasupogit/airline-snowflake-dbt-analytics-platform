"""Static reference/fixture data for the synthetic airline generator.

AIRPORT_FIXTURE is a small, hand-picked, deterministic list of real-world
airport identifiers styled the way AirStats/OurAirports represents them
(``ident``, ``icao_code``, ``iata_code``, ``iso_country``, ``iso_region``,
``continent_code``). It is NOT queried from Snowflake or from the AirStats
staging layer at run time -- no live warehouse connection exists for this
generator. It exists so that routes, flight schedules, flight instances,
ticket segments, and airport fees reference airport identifiers that are
consistent with the AirStats domain instead of arbitrary made-up codes. See
``docs/data_models/airline_synthetic_source_data.md`` for the full rationale.
"""

from __future__ import annotations

# ident, icao_code, iata_code, airport_name, municipality, iso_country,
# iso_region, continent_code, latitude_deg, longitude_deg, utc_offset_hours
AIRPORT_FIXTURE = [
    ("KJFK", "KJFK", "JFK", "John F Kennedy International Airport", "New York", "US", "US-NY", "NA", 40.6398, -73.7789, -5.0),
    ("KLAX", "KLAX", "LAX", "Los Angeles International Airport", "Los Angeles", "US", "US-CA", "NA", 33.9425, -118.4081, -8.0),
    ("KORD", "KORD", "ORD", "Chicago O'Hare International Airport", "Chicago", "US", "US-IL", "NA", 41.9786, -87.9048, -6.0),
    ("KATL", "KATL", "ATL", "Hartsfield Jackson Atlanta International Airport", "Atlanta", "US", "US-GA", "NA", 33.6407, -84.4277, -5.0),
    ("KDFW", "KDFW", "DFW", "Dallas Fort Worth International Airport", "Dallas-Fort Worth", "US", "US-TX", "NA", 32.8968, -97.0380, -6.0),
    ("KSFO", "KSFO", "SFO", "San Francisco International Airport", "San Francisco", "US", "US-CA", "NA", 37.6188, -122.3750, -8.0),
    ("CYYZ", "CYYZ", "YYZ", "Toronto Pearson International Airport", "Mississauga", "CA", "CA-ON", "NA", 43.6772, -79.6306, -5.0),
    ("EGLL", "EGLL", "LHR", "London Heathrow Airport", "London", "GB", "GB-ENG", "EU", 51.4700, -0.4543, 0.0),
    ("EGKK", "EGKK", "LGW", "London Gatwick Airport", "London", "GB", "GB-ENG", "EU", 51.1481, -0.1903, 0.0),
    ("LFPG", "LFPG", "CDG", "Charles de Gaulle International Airport", "Paris", "FR", "FR-J", "EU", 49.0097, 2.5479, 1.0),
    ("EDDF", "EDDF", "FRA", "Frankfurt am Main Airport", "Frankfurt", "DE", "DE-HE", "EU", 50.0333, 8.5706, 1.0),
    ("EHAM", "EHAM", "AMS", "Amsterdam Airport Schiphol", "Amsterdam", "NL", "NL-NH", "EU", 52.3086, 4.7639, 1.0),
    ("LEMD", "LEMD", "MAD", "Adolfo Suarez Madrid-Barajas Airport", "Madrid", "ES", "ES-M", "EU", 40.4936, -3.5668, 1.0),
    ("LIRF", "LIRF", "FCO", "Leonardo da Vinci International Airport", "Rome", "IT", "IT-62", "EU", 41.8003, 12.2389, 1.0),
    ("OMDB", "OMDB", "DXB", "Dubai International Airport", "Dubai", "AE", "AE-DU", "AS", 25.2528, 55.3644, 4.0),
    ("VHHH", "VHHH", "HKG", "Hong Kong International Airport", "Hong Kong", "HK", "HK-U-A", "AS", 22.3080, 113.9185, 8.0),
    ("WSSS", "WSSS", "SIN", "Singapore Changi Airport", "Singapore", "SG", "SG-04", "AS", 1.3644, 103.9915, 8.0),
    ("RJTT", "RJTT", "HND", "Tokyo Haneda Airport", "Tokyo", "JP", "JP-13", "AS", 35.5494, 139.7798, 9.0),
    ("RJAA", "RJAA", "NRT", "Narita International Airport", "Narita", "JP", "JP-12", "AS", 35.7647, 140.3864, 9.0),
    ("ZBAA", "ZBAA", "PEK", "Beijing Capital International Airport", "Beijing", "CN", "CN-11", "AS", 40.0801, 116.5846, 8.0),
    ("YSSY", "YSSY", "SYD", "Sydney Kingsford Smith Airport", "Sydney", "AU", "AU-NSW", "OC", -33.9461, 151.1772, 10.0),
    ("FAOR", "FAOR", "JNB", "OR Tambo International Airport", "Johannesburg", "ZA", "ZA-GT", "AF", -26.1392, 28.2460, 2.0),
    ("SBGR", "SBGR", "GRU", "Sao Paulo-Guarulhos International Airport", "Sao Paulo", "BR", "BR-SP", "SA", -23.4356, -46.4731, -3.0),
    ("LTFM", "LTFM", "IST", "Istanbul Airport", "Istanbul", "TR", "TR-34", "EU", 41.2753, 28.7519, 3.0),
]

AIRPORT_FIELDS = (
    "ident",
    "icao_code",
    "iata_code",
    "airport_name",
    "municipality",
    "iso_country",
    "iso_region",
    "continent_code",
    "latitude_deg",
    "longitude_deg",
    "utc_offset_hours",
)

COUNTRY_CURRENCY = {
    "US": "USD",
    "CA": "CAD",
    "GB": "GBP",
    "FR": "EUR",
    "DE": "EUR",
    "NL": "EUR",
    "ES": "EUR",
    "IT": "EUR",
    "AE": "AED",
    "HK": "HKD",
    "SG": "SGD",
    "JP": "JPY",
    "CN": "CNY",
    "AU": "AUD",
    "ZA": "ZAR",
    "BR": "BRL",
    "TR": "TRY",
}

# currency_code, currency_name, minor_unit_digits
CURRENCIES = [
    ("USD", "US Dollar", 2),
    ("CAD", "Canadian Dollar", 2),
    ("GBP", "British Pound Sterling", 2),
    ("EUR", "Euro", 2),
    ("AED", "UAE Dirham", 2),
    ("HKD", "Hong Kong Dollar", 2),
    ("SGD", "Singapore Dollar", 2),
    ("JPY", "Japanese Yen", 0),
    ("CNY", "Chinese Yuan Renminbi", 2),
    ("AUD", "Australian Dollar", 2),
    ("ZAR", "South African Rand", 2),
    ("BRL", "Brazilian Real", 2),
    ("TRY", "Turkish Lira", 2),
]

# currency_code -> illustrative fixed rate to USD, as of the synthetic AS_OF_DATE.
# These are deterministic fixture values for relational realism only; they are
# not live market exchange rates.
EXCHANGE_RATE_TO_USD = {
    "USD": 1.0,
    "CAD": 0.74,
    "GBP": 1.27,
    "EUR": 1.09,
    "AED": 0.2723,
    "HKD": 0.1282,
    "SGD": 0.7450,
    "JPY": 0.0067,
    "CNY": 0.1390,
    "AUD": 0.6600,
    "ZAR": 0.0540,
    "BRL": 0.1700,
    "TRY": 0.0300,
}

# code, name, home_country, hub_ident
AIRLINES = [
    ("NB", "Northbridge Airways", "US", "KJFK"),
    ("ZM", "Meridian Skyways", "GB", "EGLL"),
    ("SL", "Solara Air", "FR", "LFPG"),
    ("PC", "Pacific Crown Airlines", "SG", "WSSS"),
    ("DF", "Desert Falcon Airways", "AE", "OMDB"),
    ("SX", "Southern Cross Air", "AU", "YSSY"),
]

# code, name, body_type, typical_seats, cabins (ordered), cruise_speed_kmh
AIRCRAFT_TYPES = [
    ("A320", "Airbus A320-200", "narrowbody", 180, ("Y", "C"), 830),
    ("A321", "Airbus A321-200", "narrowbody", 220, ("Y", "C"), 830),
    ("A359", "Airbus A350-900", "widebody", 325, ("Y", "W", "C", "F"), 900),
    ("B738", "Boeing 737-800", "narrowbody", 189, ("Y", "C"), 840),
    ("B77W", "Boeing 777-300ER", "widebody", 396, ("Y", "W", "C", "F"), 900),
    ("E190", "Embraer E190", "regional", 100, ("Y", "C"), 800),
]

CABIN_NAMES = {
    "Y": "Economy",
    "W": "Premium Economy",
    "C": "Business",
    "F": "First",
}

# fare_class_code, cabin, fare_basis_code, refundable, change_fee_usd,
# base_fare_usd, per_km_usd, description
FARE_CLASSES = [
    ("ECOSV", "Y", "QOWECO", False, 75.0, 90.0, 0.045, "Economy Saver"),
    ("ECOFL", "Y", "YFLECO", True, 0.0, 140.0, 0.055, "Economy Flex"),
    ("PREMY", "W", "WFLPEY", True, 0.0, 260.0, 0.085, "Premium Economy"),
    ("BIZSV", "C", "CNRBIZ", False, 150.0, 520.0, 0.16, "Business Saver"),
    ("BIZFL", "C", "CFLBIZ", True, 0.0, 780.0, 0.20, "Business Flex"),
    ("FIRST", "F", "FFLFST", True, 0.0, 1450.0, 0.34, "First"),
]

# product_code, product_name, fare_class_code, included_service_codes (tuple)
PRODUCTS = [
    ("PRD-ECOSV", "Economy Basic", "ECOSV", ()),
    ("PRD-ECOFL", "Economy Standard", "ECOFL", ("BAG20",)),
    ("PRD-PREMY", "Premium Economy", "PREMY", ("BAG20", "SEATPR")),
    ("PRD-BIZSV", "Business Saver", "BIZSV", ("BAG20", "SEATPR", "MEALSP")),
    ("PRD-BIZFL", "Business Flex", "BIZFL", ("BAG20", "SEATPR", "MEALSP", "LOUNGE")),
    ("PRD-FIRST", "First", "FIRST", ("BAG20", "SEATPR", "MEALSP", "LOUNGE")),
]

# service_code, service_name, category, base_price_usd
SERVICES = [
    ("BAG20", "Extra Checked Bag 20kg", "baggage", 45.0),
    ("SEATPR", "Preferred Seat Selection", "seating", 25.0),
    ("SEATXL", "Extra Legroom Seat", "seating", 60.0),
    ("MEALSP", "Special Meal", "catering", 20.0),
    ("LOUNGE", "Airport Lounge Access", "lounge", 55.0),
    ("UPGCB", "Upgrade to Business", "upgrade", 220.0),
    ("WIFI", "Inflight Wi-Fi", "connectivity", 15.0),
]

# fee_code, fee_name, amount_usd (flat, applied per departing passenger)
AIRPORT_FEE_TYPES = [
    ("PSC", "Passenger Service Charge", 35.0),
    ("SEC", "Security Fee", 12.0),
]

# tax_code, tax_name, percentage_rate (of base fare)
COUNTRY_TAX_TYPES = [
    ("GVT", "Government Passenger Tax", 0.07),
]

BOOKING_CHANNELS = ("direct_website", "mobile_app", "call_center", "travel_agent", "corporate_portal")

PAYMENT_METHODS = ("card", "bank_transfer", "voucher")

# discount_code, discount_name, discount_type (percentage|fixed_amount), value
GENERIC_DISCOUNTS = [
    ("WELCOME10", "Welcome 10 Percent", "percentage", 0.10),
    ("SUMMER25", "Summer Fixed Discount", "fixed_amount", 25.0),
    ("LOYALTY5", "Loyalty 5 Percent", "percentage", 0.05),
]

FIRST_NAMES = [
    "James", "Mary", "Robert", "Patricia", "John", "Jennifer", "Michael", "Linda",
    "David", "Elizabeth", "William", "Barbara", "Richard", "Susan", "Joseph", "Jessica",
    "Thomas", "Sarah", "Charles", "Karen", "Daniel", "Nancy", "Matthew", "Lisa",
    "Anthony", "Betty", "Mark", "Margaret", "Paul", "Sandra", "Steven", "Ashley",
    "Kenji", "Yuki", "Wei", "Mei", "Fatima", "Ahmed", "Priya", "Arjun",
]

LAST_NAMES = [
    "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
    "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez", "Wilson", "Anderson", "Thomas",
    "Taylor", "Moore", "Jackson", "Martin", "Lee", "Perez", "Thompson", "White",
    "Harris", "Sanchez", "Clark", "Ramirez", "Lewis", "Robinson", "Walker", "Young",
    "Tanaka", "Wong", "Khan", "Ali", "Dubois", "Muller", "Rossi", "Silva",
]

NATIONALITIES = ["US", "GB", "FR", "DE", "NL", "ES", "IT", "AE", "SG", "AU", "CA", "JP", "CN", "ZA", "BR", "TR"]

# company_name, country, negotiated_discount_pct
CORPORATE_ACCOUNTS = [
    ("Vantage Consulting Group", "US", 0.12),
    ("Northfield Industrial Holdings", "GB", 0.10),
    ("Solenne Cosmetiques", "FR", 0.08),
    ("Meridian Bank Group", "SG", 0.15),
    ("Falcon Logistics International", "AE", 0.10),
]

# agency_name, country, commission_pct
TRAVEL_AGENTS = [
    ("Compass Point Travel", "US", 0.07),
    ("Blue Horizon Journeys", "GB", 0.06),
    ("Voyage Elegante", "FR", 0.065),
    ("Pacific Rim Travel Partners", "SG", 0.07),
    ("Oasis Business Travel", "AE", 0.06),
    ("Southern Skies Travel Co", "AU", 0.065),
    ("Harborview Corporate Travel", "CA", 0.06),
    ("Golden Gate Getaways", "US", 0.05),
]
