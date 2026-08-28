{% macro convert_currency(amount, from_rate_to_usd, to_rate_to_usd, scale=2) -%}
    cast(round((({{ amount }}) * ({{ from_rate_to_usd }})) / ({{ to_rate_to_usd }}), {{ scale }}) as decimal(18, {{ scale }}))
{%- endmacro %}
