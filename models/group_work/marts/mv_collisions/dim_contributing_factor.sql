-- Contributing factor dimension for motor vehicle collisions
-- Grain: one row per distinct contributing factor value
-- contributing_factor_vehicle_1 to _5 are unpivoted into one list of values

WITH stg_mv AS (
    SELECT * FROM {{ ref('stg_mv_collisions') }}
),

all_factors AS (
    SELECT contributing_factor_vehicle_1 AS contributing_factor FROM stg_mv
    UNION DISTINCT
    SELECT contributing_factor_vehicle_2 FROM stg_mv
    UNION DISTINCT
    SELECT contributing_factor_vehicle_3 FROM stg_mv
    UNION DISTINCT
    SELECT contributing_factor_vehicle_4 FROM stg_mv
    UNION DISTINCT
    SELECT contributing_factor_vehicle_5 FROM stg_mv
),

distinct_factors AS (
    SELECT DISTINCT TRIM(contributing_factor) AS contributing_factor
    FROM all_factors
    WHERE contributing_factor IS NOT NULL
    AND TRIM(contributing_factor) != ''
),

-- Derived fields: our own groupings, not in the source data
enriched AS (
    SELECT
        contributing_factor,
        CASE
            WHEN contributing_factor = 'Unsafe Speed' THEN 'Speed'
            WHEN contributing_factor IN (
                'Traffic Control Disregarded',
                'Traffic Control Device Improper/Non-Working',
                'Failure to Yield Right-of-Way'
            ) THEN 'Traffic Control'
            WHEN contributing_factor IN (
                'Driver Inattention/Distraction', 'Passenger Distraction',
                'Outside Car Distraction', 'Cell Phone (hand-Held)',
                'Fell Asleep', 'Fatigued/Drowsy', 'Lost Consciousness',
                'Illnes', 'Physical Disability', 'Alcohol Involvement',
                'Drugs (illegal)', 'Prescription Medication',
                'Cell Phone (hands-free)', 'Eating or Drinking',
                'Listening/Using Headphones', 'Other Electronic Device',
                'Texting', 'Using On Board Navigation Device'
            ) THEN 'Driver Attention'
            WHEN contributing_factor IN (
                'Following Too Closely', 'Passing or Lane Usage Improper',
                'Passing Too Closely', 'Backing Unsafely', 'Turning Improperly',
                'Unsafe Lane Changing', 'Failure to Keep Right',
                'Aggressive Driving/Road Rage', 'Driver Inexperience',
                'Reaction to Uninvolved Vehicle',
                'Pedestrian/Bicyclist/Other Pedestrian Error/Confusion'
            ) THEN 'Driving Maneuver'
            WHEN contributing_factor IN (
                'Brakes Defective', 'Steering Failure', 'Tire Failure/Inadequate',
                'Accelerator Defective', 'Tow Hitch Defective', 'Headlights Defective',
                'Other Lighting Defects', 'Tinted Windows', 'Oversized Vehicle',
                'Driverless/Runaway Vehicle', 'Other Vehicular', 'Vehicle Vandalism',
                'Windshield Inadequate'
            ) THEN 'Vehicle Condition'
            WHEN contributing_factor IN (
                'Pavement Slippery', 'Pavement Defective', 'View Obstructed/Limited',
                'Glare', 'Obstruction/Debris', 'Animals Action',
                'Lane Marking Improper/Inadequate',
                'Shoulders Defective/Improper'
            ) THEN 'Environment'
            WHEN contributing_factor = 'Unspecified'
                OR REGEXP_CONTAINS(contributing_factor, r'^[0-9]+$') THEN 'Unknown'
            ELSE 'Other'
        END AS factor_category,
        -- Link to the 311 request types, used for the optional concordance metric
        CASE
            WHEN contributing_factor = 'Unsafe Speed' THEN 'Chronic Speeding'
            WHEN contributing_factor = 'Traffic Control Disregarded'
                THEN 'Chronic Stoplight Violation / Traffic Signal Condition'
            ELSE 'No 311 match'
        END AS maps_to_311_category
    FROM distinct_factors
),

dim_contributing_factor AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['contributing_factor']) }} AS contributing_factor_key,
        contributing_factor,
        factor_category,
        maps_to_311_category
    FROM enriched
),

-- Null placeholder row: a crash with no vehicle in that position points here
null_placeholder AS (
    SELECT
        '-1' AS contributing_factor_key,
        'Unknown' AS contributing_factor,
        'Unknown' AS factor_category,
        'No 311 match' AS maps_to_311_category
)

SELECT * FROM dim_contributing_factor
UNION ALL
SELECT * FROM null_placeholder