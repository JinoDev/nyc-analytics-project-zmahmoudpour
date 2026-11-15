-- Fact table for 311 traffic service requests
-- Grain: one row per service request (request_id)
-- No numeric measures: this is a factless fact table, analysed by counting requests
-- Each key is looked up in its dimension with ref(), so dbt builds every
-- dimension before this fact

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_311_traffic') }}
),

-- Clean the dimension columns the same way each dimension does,
-- so the keys below match
cleaned AS (
    SELECT
        *,
        NULLIF(TRIM(agency), '') AS agency_clean,
        NULLIF(TRIM(complaint_type), '') AS complaint_type_clean,
        NULLIF(TRIM(descriptor), '') AS descriptor_clean,
        NULLIF(TRIM(descriptor_2), '') AS descriptor_2_clean,
        NULLIF(TRIM(resolution_description), '') AS resolution_clean,
        NULLIF(TRIM(status), '') AS status_clean,
        NULLIF(TRIM(community_board), '') AS community_board_clean,
        NULLIF(TRIM(CAST(council_district AS STRING)), '') AS council_district_clean,
        NULLIF(TRIM(police_precinct), '') AS police_precinct_clean,
        NULLIF(TRIM(bridge_highway_name), '') AS bridge_name_clean,
        NULLIF(TRIM(bridge_highway_direction), '') AS bridge_direction_clean,
        NULLIF(TRIM(road_ramp), '') AS road_ramp_clean,
        NULLIF(TRIM(bridge_highway_segment), '') AS bridge_segment_clean
    FROM stg_311
),

-- Step 1: build each key from the source columns
keyed AS (
    SELECT
        request_id,

        CASE
            WHEN created_date IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['DATE(created_date)']) }}
        END AS created_date_key,

        CASE
            WHEN closed_date IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['DATE(closed_date)']) }}
        END AS closed_date_key,

        CASE
            WHEN borough IS NULL AND zip IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['borough', 'zip']) }}
        END AS location_key,

        CASE
            WHEN agency_clean IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['agency_clean']) }}
        END AS agency_key,

        CASE
            WHEN complaint_type_clean IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['complaint_type_clean', 'descriptor_clean', 'descriptor_2_clean']) }}
        END AS complaint_key,

        CASE
            WHEN resolution_clean IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['resolution_clean']) }}
        END AS resolution_key,

        CASE
            WHEN community_board_clean IS NULL
                AND council_district_clean IS NULL
                AND police_precinct_clean IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['community_board_clean', 'council_district_clean', 'police_precinct_clean']) }}
        END AS local_gov_key,

        CASE
            WHEN bridge_name_clean IS NULL
                AND bridge_direction_clean IS NULL
                AND road_ramp_clean IS NULL
                AND bridge_segment_clean IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['bridge_name_clean', 'bridge_direction_clean', 'road_ramp_clean', 'bridge_segment_clean']) }}
        END AS bridge_key,

        CASE
            WHEN status_clean IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['status_clean']) }}
        END AS status_key,

        -- Descriptive columns kept on the fact
        resolution_action_updated_date,
        location_type,
        incident_address,
        street_name,
        cross_street_1,
        cross_street_2,
        intersection_street_1,
        intersection_street_2,
        address_type,
        city,
        landmark,
        bbl,
        method_of_submission,
        latitude,
        longitude
    FROM cleaned
),

-- Step 2: look each key up in its dimension; a miss falls back to the Unknown row
fact_service_request AS (
    SELECT
        k.request_id,
        COALESCE(dc.date_key, '-1') AS created_date_key,
        COALESCE(dx.date_key, '-1') AS closed_date_key,
        COALESCE(loc.location_key, '-1') AS location_key,
        COALESCE(ag.agency_key, '-1') AS agency_key,
        COALESCE(cmp.complaint_key, '-1') AS complaint_key,
        COALESCE(res.resolution_key, '-1') AS resolution_key,
        COALESCE(gov.local_gov_key, '-1') AS local_gov_key,
        COALESCE(br.bridge_key, '-1') AS bridge_key,
        COALESCE(st.status_key, '-1') AS status_key,
        k.resolution_action_updated_date,
        k.location_type,
        k.incident_address,
        k.street_name,
        k.cross_street_1,
        k.cross_street_2,
        k.intersection_street_1,
        k.intersection_street_2,
        k.address_type,
        k.city,
        k.landmark,
        k.bbl,
        k.method_of_submission,
        k.latitude,
        k.longitude
    FROM keyed k
    LEFT JOIN {{ ref('dim_date') }} dc ON k.created_date_key = dc.date_key
    LEFT JOIN {{ ref('dim_date') }} dx ON k.closed_date_key = dx.date_key
    LEFT JOIN {{ ref('dim_location') }} loc ON k.location_key = loc.location_key
    LEFT JOIN {{ ref('dim_agency') }} ag ON k.agency_key = ag.agency_key
    LEFT JOIN {{ ref('dim_complaint') }} cmp ON k.complaint_key = cmp.complaint_key
    LEFT JOIN {{ ref('dim_resolution') }} res ON k.resolution_key = res.resolution_key
    LEFT JOIN {{ ref('dim_local_gov') }} gov ON k.local_gov_key = gov.local_gov_key
    LEFT JOIN {{ ref('dim_bridge') }} br ON k.bridge_key = br.bridge_key
    LEFT JOIN {{ ref('dim_status') }} st ON k.status_key = st.status_key
)

SELECT * FROM fact_service_request