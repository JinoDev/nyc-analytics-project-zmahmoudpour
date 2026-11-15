WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_311_traffic') }}
),

stg_mv AS (
    SELECT * FROM {{ ref('stg_mv_collisions') }}
),

all_locations AS (

    SELECT DISTINCT
        CAST(borough AS STRING) AS borough,
        CAST(zip AS STRING) AS zip
    FROM stg_311
    WHERE borough IS NOT NULL
       OR zip IS NOT NULL

    UNION DISTINCT

    SELECT DISTINCT
        CAST(borough AS STRING) AS borough,
        CAST(zip AS STRING) AS zip
    FROM stg_mv
    WHERE borough IS NOT NULL
       OR zip IS NOT NULL

),

location_dimension AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'borough', 'zip'
        ]) }} AS location_key,

        borough,
        zip

    FROM all_locations

),

-- Null placeholder row to handle NULL values.

null_placeholder AS (

    SELECT
        '-1' AS location_key,
        CAST(NULL AS STRING) AS borough,
        CAST(NULL AS STRING) AS zip

)

SELECT * FROM location_dimension
UNION ALL
SELECT * FROM null_placeholder