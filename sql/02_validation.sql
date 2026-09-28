-- ============================================================
-- 02_validation.sql  (v2 — matches new CSV staging schema)
--
-- PURPOSE:
-- Validate that the BTS December 2025 data (from the new
-- Marketing Carrier CSV export) was imported completely and
-- that important source fields look correct.
--
-- CHANGES FROM THE ORIGINAL SCRIPT:
--   - The form_type check has been removed. That field doesn't
--     exist in this data source (BTS dropped it), so there's
--     nothing left to validate there.
--   - Expected row count is now 644,987, not 644,995 — this
--     source has already excluded the 8 Form-3A duplicate
--     records that the old file included with duplicate_flag='Y'.
--   - The date range comment reflects the new 'YYYY-MM-DD' format.
-- ============================================================

-- 1. Validate row count
-- Counts every record imported into the staging table.
-- Expected result: 644,987 rows.
-- This confirms that no records were lost during import.
SELECT COUNT(*)
FROM stg_flights_202512;

-- 2. Validate date range
-- Finds the earliest and latest flight dates in the imported file.
-- Expected range: 2025-12-01 through 2025-12-31.
-- This confirms that the file contains the expected December 2025 period.
SELECT
    MIN(flight_date_raw) AS first_date,
    MAX(flight_date_raw) AS last_date
FROM stg_flights_202512;

-- 3. Check duplicate flag
-- Counts how many records are marked with each duplicate status.
-- Expected result: all rows 'N' — this source excludes flagged
-- duplicates at the point of export rather than including them.
SELECT
    duplicate_flag,
    COUNT(*) AS records
FROM stg_flights_202512
GROUP BY duplicate_flag;

-- 4. Check cancellation codes
-- Counts flights by cancellation code.
-- Helps verify that cancellation values imported correctly
-- and shows the distribution of cancellation reasons.
SELECT
    cancellation_code,
    COUNT(*) AS flights
FROM stg_flights_202512
GROUP BY cancellation_code
ORDER BY flights DESC;

-- 5. Count unique airports
-- COUNT(DISTINCT) counts unique origin and destination airport codes.
-- This helps validate the geographic coverage of the dataset.
SELECT
    COUNT(DISTINCT origin) AS origin_airports,
    COUNT(DISTINCT destination) AS destination_airports
FROM stg_flights_202512;

-- 6. Find the busiest origin airports
-- Groups flights by origin airport and counts the number of records.
-- Results are sorted from highest to lowest.
-- LIMIT 10 returns only the ten busiest origins.
SELECT
    origin,
    COUNT(*) AS flights
FROM stg_flights_202512
GROUP BY origin
ORDER BY flights DESC
LIMIT 10;

-- 7. Inspect sample flight records
-- Displays important fields from ten records so the imported
-- values can be visually checked before cleaning and transformation.
SELECT
    marketing_carrier,
    marketing_flight_number,
    operating_carrier,
    origin,
    destination,
    flight_date_raw,
    scheduled_departure_crs,
    actual_departure,
    departure_delay,
    scheduled_arrival_crs,
    actual_arrival,
    arrival_delay,
    taxi_out,
    taxi_in,
    air_time
FROM stg_flights_202512
LIMIT 10;
