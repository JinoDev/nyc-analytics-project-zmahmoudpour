-- Status dimension for 311 service requests
-- Grain: one row per distinct request status

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_311_traffic') }}
),

distinct_status AS (
    SELECT DISTINCT TRIM(status) AS status
    FROM stg_311
    WHERE status IS NOT NULL
    AND TRIM(status) != ''
),

dim_status AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['status']) }} AS status_key,
        status
    FROM distinct_status
),

-- Null placeholder row: a request with no status points here
null_placeholder AS (
    SELECT
        '-1' AS status_key,
        'Unknown' AS status
)

SELECT * FROM dim_status
UNION ALL
SELECT * FROM null_placeholder