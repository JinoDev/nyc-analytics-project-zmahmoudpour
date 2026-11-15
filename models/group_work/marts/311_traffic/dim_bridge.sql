-- Bridge / highway dimension for 311 service requests
-- Grain: one row per distinct bridge_highway_name + direction + segment + road_ramp
-- Only about 1.2% of requests have these values; the rest point to the -1 row

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_311_traffic') }}
),

distinct_bridges AS (
    SELECT DISTINCT
        NULLIF(TRIM(bridge_highway_name), '') AS bridge_highway_name,
        NULLIF(TRIM(bridge_highway_direction), '') AS bridge_highway_direction,
        NULLIF(TRIM(road_ramp), '') AS road_ramp,
        NULLIF(TRIM(bridge_highway_segment), '') AS bridge_highway_segment
    FROM stg_311
),

dim_bridge AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['bridge_highway_name', 'bridge_highway_direction', 'road_ramp', 'bridge_highway_segment']) }} AS bridge_key,
        bridge_highway_name,
        bridge_highway_direction,
        road_ramp,
        bridge_highway_segment
    FROM distinct_bridges
    WHERE bridge_highway_name IS NOT NULL
        OR bridge_highway_direction IS NOT NULL
        OR road_ramp IS NOT NULL
        OR bridge_highway_segment IS NOT NULL
),

-- Null placeholder row: a request with no bridge or highway info points here
null_placeholder AS (
    SELECT
        '-1' AS bridge_key,
        'Unknown' AS bridge_highway_name,
        'Unknown' AS bridge_highway_direction,
        'Unknown' AS road_ramp,
        'Unknown' AS bridge_highway_segment
)

SELECT * FROM dim_bridge
UNION ALL
SELECT * FROM null_placeholder