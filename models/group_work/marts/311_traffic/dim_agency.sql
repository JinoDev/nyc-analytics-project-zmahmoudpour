-- Agency dimension for 311 service requests
-- Grain: one row per agency
-- agency_category is derived: our own grouping, not in the source data

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_311_traffic') }}
),

distinct_agencies AS (
    SELECT DISTINCT
        TRIM(agency) AS agency,
        TRIM(agency_name) AS agency_name
    FROM stg_311
    WHERE agency IS NOT NULL
),

dim_agency AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['agency']) }} AS agency_key,
        agency,
        agency_name,
        CASE
            WHEN agency = 'NYPD' THEN 'Enforcement'
            WHEN agency = 'DOT' THEN 'Infrastructure'
            ELSE 'Other'
        END AS agency_category
    FROM distinct_agencies
),

-- Null placeholder row: a request with no agency points here
null_placeholder AS (
    SELECT
        '-1' AS agency_key,
        'Unknown' AS agency,
        'Unknown' AS agency_name,
        'Unknown' AS agency_category
)

SELECT * FROM dim_agency
UNION ALL
SELECT * FROM null_placeholder