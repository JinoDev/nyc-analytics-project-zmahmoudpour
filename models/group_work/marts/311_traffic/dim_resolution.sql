-- Resolution dimension for 311 service requests
-- Grain: one row per distinct resolution description

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_311_traffic') }}
),

distinct_resolution AS (
    SELECT DISTINCT TRIM(resolution_description) AS resolution_description
    FROM stg_311
    WHERE resolution_description IS NOT NULL
    AND TRIM(resolution_description) != ''
),

dim_resolution AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['resolution_description']) }} AS resolution_key,
        resolution_description
    FROM distinct_resolution
),

-- Null placeholder row: a request with no resolution yet points here
null_placeholder AS (
    SELECT
        '-1' AS resolution_key,
        'Unknown' AS resolution_description
)

SELECT * FROM dim_resolution
UNION ALL
SELECT * FROM null_placeholder