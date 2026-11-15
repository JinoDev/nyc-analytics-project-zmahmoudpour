-- Fact table for motor vehicle collisions
-- Grain: one row per collision (collision_id)
-- Each crash points to the PRIMARY factor and vehicle type (position 1)
-- Each key is looked up in its dimension with ref(), so dbt builds every
-- dimension before this fact

WITH stg_mv AS (
    SELECT * FROM {{ ref('stg_mv_collisions') }}
),

-- Step 1: build each key from the source columns
keyed AS (
    SELECT
        collision_id,

        CASE
            WHEN crash_date IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['crash_date']) }}
        END AS date_key,

        CASE
            WHEN borough IS NULL AND zip IS NULL THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['borough', 'zip']) }}
        END AS location_key,

        CASE
            WHEN contributing_factor_vehicle_1 IS NULL
                OR TRIM(contributing_factor_vehicle_1) = '' THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['TRIM(contributing_factor_vehicle_1)']) }}
        END AS contri_factor_key,

        CASE
            WHEN vehicle_type_code1 IS NULL
                OR TRIM(vehicle_type_code1) = '' THEN '-1'
            ELSE {{ dbt_utils.generate_surrogate_key(['UPPER(TRIM(vehicle_type_code1))']) }}
        END AS vehicle_type_key,

        -- Descriptive columns kept on the fact
        crash_time,
        latitude,
        longitude,
        on_street_name,
        off_street_name,
        cross_street_name,

        -- Measures
        COALESCE(number_of_persons_injured, 0) AS number_of_persons_injured,
        COALESCE(number_of_persons_killed, 0) AS number_of_persons_killed,
        COALESCE(number_of_pedestrians_injured, 0) AS number_of_pedestrians_injured,
        COALESCE(number_of_pedestrians_killed, 0) AS number_of_pedestrians_killed,
        COALESCE(number_of_cyclist_injured, 0) AS number_of_cyclist_injured,
        COALESCE(number_of_cyclist_killed, 0) AS number_of_cyclist_killed,
        COALESCE(number_of_motorist_injured, 0) AS number_of_motorist_injured,
        COALESCE(number_of_motorist_killed, 0) AS number_of_motorist_killed
    FROM stg_mv
),

-- Step 2: look each key up in its dimension; a miss falls back to the Unknown row
fact_collision AS (
    SELECT
        k.collision_id,
        COALESCE(d.date_key, '-1') AS date_key,
        COALESCE(loc.location_key, '-1') AS location_key,
        COALESCE(cf.contributing_factor_key, '-1') AS contri_factor_key,
        COALESCE(vt.vehicle_type_key, '-1') AS vehicle_type_key,
        k.crash_time,
        k.latitude,
        k.longitude,
        k.on_street_name,
        k.off_street_name,
        k.cross_street_name,
        k.number_of_persons_injured,
        k.number_of_persons_killed,
        k.number_of_pedestrians_injured,
        k.number_of_pedestrians_killed,
        k.number_of_cyclist_injured,
        k.number_of_cyclist_killed,
        k.number_of_motorist_injured,
        k.number_of_motorist_killed
    FROM keyed k
    LEFT JOIN {{ ref('dim_date') }} d ON k.date_key = d.date_key
    LEFT JOIN {{ ref('dim_location') }} loc ON k.location_key = loc.location_key
    LEFT JOIN {{ ref('dim_contributing_factor') }} cf ON k.contri_factor_key = cf.contributing_factor_key
    LEFT JOIN {{ ref('dim_vehicle_type') }} vt ON k.vehicle_type_key = vt.vehicle_type_key
)

SELECT * FROM fact_collision