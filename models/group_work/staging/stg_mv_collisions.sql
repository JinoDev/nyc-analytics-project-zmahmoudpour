WITH source AS (
   SELECT * FROM {{ source('raw', 'source_mv_collisions') }}
), 

cleaned AS (
   SELECT
       -- Explicitly calling for all the columns that are not being manually cleaned
       * EXCEPT (
           collision_id,
           crash_date,
           number_of_persons_injured,
           number_of_persons_killed,
           number_of_pedestrians_injured,
           number_of_pedestrians_killed,
           number_of_cyclist_injured,
           number_of_cyclist_killed,
           number_of_motorist_injured,
           number_of_motorist_killed,
           zip_code,
           borough,
           latitude,
           longitude
       ),

       -- Identifiers
       CAST(collision_id AS STRING) AS collision_id,

       -- Date/Time
       CAST(crash_date AS DATE) AS crash_date,

       -- casualty details
       CAST(number_of_persons_injured AS INT) AS number_of_persons_injured,
       CAST(number_of_persons_killed AS INT) AS number_of_persons_killed,
       CAST(number_of_pedestrians_injured AS INT) AS number_of_pedestrians_injured,
       CAST(number_of_pedestrians_killed AS INT) AS number_of_pedestrians_killed,
       CAST(number_of_cyclist_injured AS INT) AS number_of_cyclist_injured,
       CAST(number_of_cyclist_killed AS INT) AS number_of_cyclist_killed,
       CAST(number_of_motorist_injured AS INT) AS number_of_motorist_injured,
       CAST(number_of_motorist_killed AS INT) AS number_of_motorist_killed,

       -- Location - clean zip code, handling several common zip code data problems
       CASE
           WHEN UPPER(TRIM(CAST(zip_code AS STRING))) IN ('N/A', 'NA') THEN NULL
           WHEN UPPER(TRIM(CAST(zip_code AS STRING))) = 'ANONYMOUS' THEN 'Anonymous'
           WHEN LENGTH(CAST(zip_code AS STRING)) = 5 THEN CAST(zip_code AS STRING)
           WHEN LENGTH(CAST(zip_code AS STRING)) = 9 THEN CAST(zip_code AS STRING)
           WHEN LENGTH(CAST(zip_code AS STRING)) = 10
               AND REGEXP_CONTAINS(CAST(zip_code AS STRING), r'^\d{5}-\d{4}')
           THEN CAST(zip_code AS STRING)
           ELSE NULL
       END AS zip,

       -- Location - standardized borough, just in case
       CASE
           WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
           WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
           WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
           WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
           WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
           ELSE 'UNKNOWN or CITYWIDE'
       END AS borough,

       CAST(latitude AS DECIMAL) AS latitude,
       CAST(longitude AS DECIMAL) AS longitude,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters
   WHERE collision_id IS NOT NULL
   AND crash_date IS NOT NULL
   AND CAST(crash_date AS DATE) >= '2020-01-01'
   AND CAST(crash_date AS DATE) < '2026-10-21'

   -- Deduplicate
   QUALIFY ROW_NUMBER() OVER (PARTITION BY collision_id ORDER BY crash_date DESC) = 1
)

SELECT * FROM cleaned