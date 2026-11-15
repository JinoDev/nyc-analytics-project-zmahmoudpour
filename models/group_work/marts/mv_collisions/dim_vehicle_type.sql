-- Vehicle type dimension for motor vehicle collisions
-- Grain: one row per distinct vehicle type value (trimmed, upper-cased)
-- vehicle_type_code1 to _5 are unpivoted into one list of values

WITH stg_mv AS (
    SELECT * FROM {{ ref('stg_mv_collisions') }}
),

all_types AS (
    SELECT vehicle_type_code1 AS vehicle_type FROM stg_mv
    UNION DISTINCT
    SELECT vehicle_type_code2 FROM stg_mv
    UNION DISTINCT
    SELECT vehicle_type_code_3 FROM stg_mv
    UNION DISTINCT
    SELECT vehicle_type_code_4 FROM stg_mv
    UNION DISTINCT
    SELECT vehicle_type_code_5 FROM stg_mv
),

-- Upper-casing merges spelling variants such as Van / van and Ambulance / AMBULANCE
distinct_types AS (
    SELECT DISTINCT UPPER(TRIM(vehicle_type)) AS vehicle_type_raw
    FROM all_types
    WHERE vehicle_type IS NOT NULL
    AND TRIM(vehicle_type) != ''
),

-- Derived field: our own grouping of a near-free-text source column
-- Order matters: the first matching WHEN wins
enriched AS (
    SELECT
        vehicle_type_raw,
                CASE
            WHEN vehicle_type_raw IN ('UNKNOWN', 'UNK', 'UN/C', 'UN/T') THEN 'Unknown'
            WHEN vehicle_type_raw LIKE '%AMBU%'
                OR vehicle_type_raw LIKE 'FDNY%'
                OR vehicle_type_raw LIKE 'FIRE%'
                OR vehicle_type_raw LIKE 'POLI%' THEN 'Emergency'
            WHEN vehicle_type_raw LIKE 'TAXI%'
                OR vehicle_type_raw LIKE 'LIMO%' THEN 'Taxi / Limo'
            WHEN vehicle_type_raw LIKE '%BUS%' THEN 'Bus'
            WHEN vehicle_type_raw LIKE '%SEDAN%'
                OR vehicle_type_raw IN ('CONVERTIBLE', '3-DOOR', '4-DOOR', '2-DOOR') THEN 'Sedan'
            WHEN vehicle_type_raw LIKE '%STATION WAGON%'
                OR vehicle_type_raw LIKE '%SPORT UTIL%'
                OR vehicle_type_raw IN ('SUBN', 'SUV', 'UTIL', 'CARRY ALL') THEN 'SUV'
            WHEN vehicle_type_raw IN ('BIKE', 'BICY', 'BICYCLE', 'PEDICAB') THEN 'Bicycle'
            WHEN vehicle_type_raw IN ('E-BIKE', 'E-SCOOTER', 'EBIK', 'ESST', 'SCOOTER',
                'STANDING S', 'ELECTRIC S') THEN 'E-Bike / E-Scooter'
            WHEN vehicle_type_raw LIKE '%MOTORCYCLE%'
                OR vehicle_type_raw IN ('MOTORBIKE', 'MOPED', 'MOPD', 'MOTORSCOOTER',
                    'MINIBIKE', 'DIRT BIKE') THEN 'Motorcycle / Moped'
            WHEN vehicle_type_raw IN ('VAN', 'REFRIGERATED VAN') THEN 'Van'
            WHEN vehicle_type_raw IN ('LIFT BOOM', 'SNOW PLOW', 'FORKLIFT', 'FORK LIFT',
                'PALLET', 'BULK AGRICULTURE', 'MULTI-WHEELED VEHICLE') THEN 'Work Vehicle'
            WHEN vehicle_type_raw LIKE '%TRUCK%'
                OR vehicle_type_raw LIKE 'PICK UP%'
                OR vehicle_type_raw LIKE 'TRAC%'
                OR vehicle_type_raw LIKE 'GARBAGE%'
                OR vehicle_type_raw LIKE 'DELIVERY%'
                OR vehicle_type_raw LIKE 'SANITATION%'
                OR vehicle_type_raw IN ('PICK-UP TRUCK', 'PK', 'DUMP', 'FLAT BED', 'FLAT',
                    'CHASSIS CAB', 'TANKER', 'CONCRETE MIXER', 'FLAT RACK', 'STAKE OR RACK',
                    'DELV', 'COMMERCIAL', 'COM', 'OPEN BODY', 'TRAILER') THEN 'Truck'
            ELSE 'Other'
        END AS vehicle_type_clean
    FROM distinct_types
),

dim_vehicle_type AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['vehicle_type_raw']) }} AS vehicle_type_key,
        vehicle_type_raw,
        vehicle_type_clean,
        -- Derived: trucks and buses, for the truck-route angle
        vehicle_type_clean IN ('Truck', 'Bus') AS is_large_vehicle
    FROM enriched
),

-- Null placeholder row: a crash with no vehicle in that position points here
null_placeholder AS (
    SELECT
        '-1' AS vehicle_type_key,
        'UNKNOWN / NONE' AS vehicle_type_raw,
        'Unknown' AS vehicle_type_clean,
        CAST(FALSE AS BOOLEAN) AS is_large_vehicle
)

SELECT * FROM dim_vehicle_type
UNION ALL
SELECT * FROM null_placeholder