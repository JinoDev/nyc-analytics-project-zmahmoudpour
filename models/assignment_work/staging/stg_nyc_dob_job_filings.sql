-- Clean and standardize DOB NOW Build job application filings
-- One row per job filing

WITH source AS (
    SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
),

cleaned AS (
    SELECT
        -- Everything else passes through untouched
        * EXCEPT (
            job_filing_number,
            filing_date,
            approved_date,
            current_status_date,
            first_permit_date,
            signoff_date,
            borough,
            postcode,
            zip,
            council_district
        ),

        -- Identifiers
        CAST(job_filing_number AS STRING) AS job_filing_id,

        -- Dates: two of these arrived as STRING in the raw load, so cast them
        CAST(filing_date AS TIMESTAMP) AS filing_date,
        CAST(approved_date AS TIMESTAMP) AS approved_date,
        CAST(current_status_date AS TIMESTAMP) AS current_status_date,
        SAFE_CAST(first_permit_date AS TIMESTAMP) AS first_permit_date,
        SAFE_CAST(signoff_date AS TIMESTAMP) AS signoff_date,

        -- Location - standardized borough, same rules as the 311 model
        CASE
            WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
            WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
            WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
            WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
            ELSE 'UNKNOWN or CITYWIDE'
        END AS borough,

        -- Conformed zip: postcode is the job site, renamed to match the 311 model
        CASE
            WHEN LENGTH(TRIM(CAST(postcode AS STRING))) = 5 THEN TRIM(CAST(postcode AS STRING))
            ELSE NULL
        END AS zip,

        -- The raw `zip` column is the applicant's, so give it a name that says so
        CAST(zip AS STRING) AS applicant_zip,

        CAST(council_district AS STRING) AS council_district,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

    -- Filters
    WHERE job_filing_number IS NOT NULL
      AND filing_date IS NOT NULL

    -- Deduplicate: keep the most recently updated row per filing
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY job_filing_number
        ORDER BY current_status_date DESC
    ) = 1
)

SELECT * FROM cleaned