-- Complaint dimension for 311 service requests
-- Grain: one row per distinct complaint_type + descriptor + descriptor_2

WITH stg_311 AS (
    SELECT * FROM {{ ref('stg_311_traffic') }}
),

distinct_complaints AS (
    SELECT DISTINCT
        NULLIF(TRIM(complaint_type), '') AS complaint_type,
        NULLIF(TRIM(descriptor), '') AS descriptor,
        NULLIF(TRIM(descriptor_2), '') AS descriptor_2
    FROM stg_311
    WHERE complaint_type IS NOT NULL
),

dim_complaint AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['complaint_type', 'descriptor', 'descriptor_2']) }} AS complaint_key,
        complaint_type,
        descriptor,
        descriptor_2
    FROM distinct_complaints
),

-- Null placeholder row: a request with no complaint type points here
null_placeholder AS (
    SELECT
        '-1' AS complaint_key,
        'Unknown' AS complaint_type,
        'Unknown' AS descriptor,
        'Unknown' AS descriptor_2
)

SELECT * FROM dim_complaint
UNION ALL
SELECT * FROM null_placeholder