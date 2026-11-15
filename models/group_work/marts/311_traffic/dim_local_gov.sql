-- Local government dimension for 311 service requests
-- Grain: one row per distinct community_board + council_district + police_precinct

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_311_traffic') }}
),

distinct_local_gov AS (
    SELECT DISTINCT
        NULLIF(TRIM(community_board), '') AS community_board,
        NULLIF(TRIM(CAST(council_district AS STRING)), '') AS council_district,
        NULLIF(TRIM(police_precinct), '') AS police_precinct
    FROM stg_311
),

dim_local_gov AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['community_board', 'council_district', 'police_precinct']) }} AS local_gov_key,
        community_board,
        council_district,
        police_precinct
    FROM distinct_local_gov
    WHERE community_board IS NOT NULL
        OR council_district IS NOT NULL
        OR police_precinct IS NOT NULL
),

-- Null placeholder row: a request with none of the three points here
null_placeholder AS (
    SELECT
        '-1' AS local_gov_key,
        'Unknown' AS community_board,
        'Unknown' AS council_district,
        'Unknown' AS police_precinct
)

SELECT * FROM dim_local_gov
UNION ALL
SELECT * FROM null_placeholder