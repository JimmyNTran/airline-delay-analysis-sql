-- ============================================================
-- 03_create_flights_clean.sql  (v2 — sources from CSV staging schema)
--
-- PURPOSE:
-- Create an analysis-ready flight table from the raw staging
-- data. Same target schema and derived logic as before — only
-- the source columns and a few cast details have changed to
-- match BTS's current CSV export.
--
-- KEY DIFFERENCES FROM THE ORIGINAL SCRIPT:
--   1. flight_date_raw is now 'YYYY-MM-DD' text, not 'YYYYMMDD'.
--      The TO_DATE() mask below has been updated accordingly.
--   2. Many numeric fields arrive as decimal-formatted text
--      (e.g. "4.00", "-29.00") instead of plain integers.
--      Casts now go through ::NUMERIC before ::INTEGER so both
--      "4.00" and "4"-style values convert safely.
--   3. form_type no longer exists in this data source (BTS
--      dropped it). It's inserted as NULL going forward.
--   4. duplicate_flag is still filtered out defensively, even
--      though this source has already excluded Form-3A
--      duplicates at the source (all rows currently show 'N').
-- ============================================================

DROP TABLE IF EXISTS flights_clean;

-- Same fixed schema as before, so months from either source
-- (old ASCII or new CSV) can sit in the same table.
CREATE TABLE flights_clean(
    -- Source tracking
    source_month DATE,
    -- Flight identification
    marketing_carrier TEXT,
    marketing_flight_number INTEGER,
    operating_carrier TEXT,
    operating_flight_number INTEGER,
    -- Route and date
    origin TEXT,
    destination TEXT,
    route TEXT,
    flight_date DATE,
    day_of_week INTEGER,
    -- Scheduled and actual times
    scheduled_departure INTEGER,
    actual_departure INTEGER,
    scheduled_arrival INTEGER,
    actual_arrival INTEGER,
    -- Flight duration
    scheduled_elapsed_minutes INTEGER,
    actual_elapsed_minutes INTEGER,
    air_time_minutes INTEGER,
    taxi_out_minutes INTEGER,
    taxi_in_minutes INTEGER,
    -- Delay measurements
    departure_delay_minutes INTEGER,
    arrival_delay_minutes INTEGER,
    -- Aircraft
    tail_number TEXT,
    -- Cancellation and diversion
    cancellation_code TEXT,
    cancelled BOOLEAN,
    diverted_airport_landings INTEGER,
    diverted BOOLEAN,
    -- Delay causes
    carrier_delay_minutes INTEGER,
    weather_delay_minutes INTEGER,
    nas_delay_minutes INTEGER,
    security_delay_minutes INTEGER,
    late_aircraft_delay_minutes INTEGER,
    -- Analysis flags
    arrival_delayed_15 BOOLEAN,
    departure_delayed_15 BOOLEAN,
    severe_arrival_delay_60 BOOLEAN,
    on_time BOOLEAN,
    -- Time category
    departure_period TEXT,
    -- BTS metadata
    form_type TEXT,
    duplicate_flag TEXT
);

-- Insert and transform December 2025 staging data (new CSV source).
-- To load another month: change the DATE literal and the FROM
-- table name to that month's staging table, then rerun this
-- INSERT block (the CREATE TABLE above only needs to run once).
INSERT INTO flights_clean(
    source_month,
    marketing_carrier,
    marketing_flight_number,
    operating_carrier,
    operating_flight_number,
    origin,
    destination,
    route,
    flight_date,
    day_of_week,
    scheduled_departure,
    actual_departure,
    scheduled_arrival,
    actual_arrival,
    scheduled_elapsed_minutes,
    actual_elapsed_minutes,
    air_time_minutes,
    taxi_out_minutes,
    taxi_in_minutes,
    departure_delay_minutes,
    arrival_delay_minutes,
    tail_number,
    cancellation_code,
    cancelled,
    diverted_airport_landings,
    diverted,
    carrier_delay_minutes,
    weather_delay_minutes,
    nas_delay_minutes,
    security_delay_minutes,
    late_aircraft_delay_minutes,
    arrival_delayed_15,
    departure_delayed_15,
    severe_arrival_delay_60,
    on_time,
    departure_period,
    form_type,
    duplicate_flag
)

SELECT
    -- Track which monthly source file produced the record.
    DATE '2025-12-01' AS source_month,

    marketing_carrier,
    NULLIF(TRIM(marketing_flight_number), '')::NUMERIC::INTEGER,
    operating_carrier,
    NULLIF(TRIM(operating_flight_number), '')::NUMERIC::INTEGER,

    -- Route information.
    TRIM(origin),
    TRIM(destination),
    TRIM(origin) || '-' || TRIM(destination) AS route,

    -- Convert 'YYYY-MM-DD' text into a PostgreSQL DATE.
    -- (Original ASCII source used 'YYYYMMDD' — this format changed.)
    TO_DATE(flight_date_raw, 'YYYY-MM-DD') AS flight_date,

    NULLIF(TRIM(day_of_week), '')::NUMERIC::INTEGER,

    -- Scheduled and actual flight times.
    NULLIF(TRIM(scheduled_departure_crs), '')::NUMERIC::INTEGER,
    NULLIF(TRIM(actual_departure), '')::NUMERIC::INTEGER,
    NULLIF(TRIM(scheduled_arrival_crs), '')::NUMERIC::INTEGER,
    NULLIF(TRIM(actual_arrival), '')::NUMERIC::INTEGER,

    -- Flight duration.
    NULLIF(TRIM(crs_elapsed_time), '')::NUMERIC::INTEGER,
    NULLIF(TRIM(actual_elapsed_time), '')::NUMERIC::INTEGER,
    NULLIF(TRIM(air_time), '')::NUMERIC::INTEGER,
    NULLIF(TRIM(taxi_out), '')::NUMERIC::INTEGER,
    NULLIF(TRIM(taxi_in), '')::NUMERIC::INTEGER,

    -- Delay measurements.
    NULLIF(TRIM(departure_delay), '')::NUMERIC::INTEGER,
    NULLIF(TRIM(arrival_delay), '')::NUMERIC::INTEGER,

    -- Aircraft.
    NULLIF(TRIM(tail_number), ''),

    -- Cancellation code.
    NULLIF(TRIM(cancellation_code), ''),

    -- Create cancellation flag.
    CASE
        WHEN NULLIF(TRIM(cancellation_code), '') IS NOT NULL
            THEN TRUE
        ELSE FALSE
    END AS cancelled,

    -- Number of diversion landings.
    COALESCE(
        NULLIF(TRIM(diverted_airport_landings), '')::NUMERIC::INTEGER,
        0
    ),

    -- Create diversion flag.
    CASE
        WHEN COALESCE(
            NULLIF(TRIM(diverted_airport_landings), '')::NUMERIC::INTEGER,
            0
        ) > 0
            THEN TRUE
        ELSE FALSE
    END AS diverted,

    -- Delay causes.
    NULLIF(TRIM(carrier_delay), '')::NUMERIC::INTEGER,
    NULLIF(TRIM(weather_delay), '')::NUMERIC::INTEGER,
    NULLIF(TRIM(nas_delay), '')::NUMERIC::INTEGER,
    NULLIF(TRIM(security_delay), '')::NUMERIC::INTEGER,
    NULLIF(TRIM(late_aircraft_delay), '')::NUMERIC::INTEGER,

    -- Arrival delayed 15+ minutes (computed the same way as before,
    -- rather than trusting BTS's own arrival_delayed_15_flag column,
    -- so the definition stays identical across every month/source).
    CASE
        WHEN NULLIF(TRIM(arrival_delay), '') IS NULL
            THEN NULL
        WHEN NULLIF(TRIM(arrival_delay), '')::NUMERIC >= 15
            THEN TRUE
        ELSE FALSE
    END AS arrival_delayed_15,

    -- Departure delayed 15+ minutes.
    CASE
        WHEN NULLIF(TRIM(departure_delay), '') IS NULL
            THEN NULL
        WHEN NULLIF(TRIM(departure_delay), '')::NUMERIC >= 15
            THEN TRUE
        ELSE FALSE
    END AS departure_delayed_15,

    -- Severe arrival delay: 60+ minutes.
    CASE
        WHEN NULLIF(TRIM(arrival_delay), '') IS NULL
            THEN NULL
        WHEN NULLIF(TRIM(arrival_delay), '')::NUMERIC >= 60
            THEN TRUE
        ELSE FALSE
    END AS severe_arrival_delay_60,

    -- Create on-time flag.
    CASE
        WHEN NULLIF(TRIM(arrival_delay), '') IS NULL
            THEN NULL
        WHEN NULLIF(TRIM(cancellation_code), '') IS NOT NULL
            THEN FALSE
        WHEN COALESCE(
            NULLIF(TRIM(diverted_airport_landings), '')::NUMERIC::INTEGER,
            0
        ) > 0
            THEN FALSE
        WHEN NULLIF(TRIM(arrival_delay), '')::NUMERIC < 15
            THEN TRUE
        ELSE FALSE
    END AS on_time,

    -- Convert scheduled departure into a time-of-day category.
    CASE
        WHEN NULLIF(TRIM(scheduled_departure_crs), '') IS NULL
            THEN NULL
        WHEN NULLIF(TRIM(scheduled_departure_crs), '')::NUMERIC < 600
            THEN 'Early Morning'
        WHEN NULLIF(TRIM(scheduled_departure_crs), '')::NUMERIC < 1200
            THEN 'Morning'
        WHEN NULLIF(TRIM(scheduled_departure_crs), '')::NUMERIC < 1800
            THEN 'Afternoon'
        ELSE 'Evening'
    END AS departure_period,

    -- form_type no longer exists in this data source.
    NULL AS form_type,

    duplicate_flag

FROM stg_flights_202512
WHERE duplicate_flag <> 'Y';  -- defensive; this source has already excluded these
