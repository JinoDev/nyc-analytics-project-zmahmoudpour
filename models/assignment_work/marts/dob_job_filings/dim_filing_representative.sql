-- Filing representative dimension for DOB NOW job filings
-- Grain: one row per distinct combo of filing representative attributes

WITH stg_dob AS (
    SELECT * FROM {{ ref('stg_nyc_dob_job_filings') }}
),

distinct_filing_reps AS (
    SELECT DISTINCT
        filing_representative_first_name     AS first_name,
        filing_representative_middle_initial AS middle_initial,
        filing_representative_last_name      AS last_name,
        filing_representative_business_name  AS business_name,
        filing_representative_street_name    AS street_name,
        filing_representative_city           AS city,
        filing_representative_state          AS state,
        filing_representative_zip            AS zip
    FROM stg_dob
    WHERE filing_representative_first_name    IS NOT NULL
       OR filing_representative_last_name     IS NOT NULL
       OR filing_representative_business_name IS NOT NULL
       OR filing_representative_street_name   IS NOT NULL
       OR filing_representative_city          IS NOT NULL
       OR filing_representative_state         IS NOT NULL
       OR filing_representative_zip           IS NOT NULL
),

dim_filing_rep AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'first_name', 'middle_initial', 'last_name', 'business_name',
            'street_name', 'city', 'state', 'zip'
        ]) }} AS filing_representative_key,

        first_name,
        middle_initial,
        last_name,
        business_name,
        street_name,
        city,
        state,
        zip

    FROM distinct_filing_reps
),

-- Null-placeholder row
-- Some DOB job filings don't have one per initial data review
null_placeholder AS (
    SELECT
        '-1' AS filing_representative_key,
        CAST(NULL AS STRING) AS first_name,
        CAST(NULL AS STRING) AS middle_initial,
        CAST(NULL AS STRING) AS last_name,
        CAST(NULL AS STRING) AS business_name,
        CAST(NULL AS STRING) AS street_name,
        CAST(NULL AS STRING) AS city,
        CAST(NULL AS STRING) AS state,
        CAST(NULL AS STRING) AS zip
)

SELECT * FROM dim_filing_rep
UNION ALL
SELECT * FROM null_placeholder