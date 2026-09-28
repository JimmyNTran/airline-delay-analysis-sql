-- ============================================================
-- 01_create_staging_table.sql  (v2 — Marketing Carrier CSV schema)
--
-- PURPOSE:
-- Create a raw staging table matching BTS's current CSV export
-- for the "Marketing Carrier On-Time Performance" table.
-- All source columns are stored as TEXT to preserve raw values
-- and avoid datatype conversion errors during import.
--
-- NOTE: This replaces the earlier pipe-delimited ASCII schema.
-- BTS no longer serves that raw layout for this table — every
-- download (including re-downloads of December 2025) now comes
-- in this 120-column quoted CSV format instead.
-- ============================================================

DROP TABLE IF EXISTS stg_flights_202512;

CREATE TABLE stg_flights_202512 (

    -- Time period
    year TEXT,
    quarter TEXT,
    month TEXT,
    day_of_month TEXT,
    day_of_week TEXT,
    flight_date_raw TEXT,               -- NOTE: format is now YYYY-MM-DD, not YYYYMMDD

    -- Marketing carrier / codeshare identification
    marketing_carrier TEXT,
    operated_or_branded_code_share_partners TEXT,
    dot_id_marketing_airline TEXT,
    iata_code_marketing_airline TEXT,
    marketing_flight_number TEXT,

    -- Originally scheduled code-share carrier
    originally_scheduled_operating_carrier TEXT,
    dot_id_originally_scheduled_operating_carrier TEXT,
    iata_code_originally_scheduled_operating_carrier TEXT,
    originally_scheduled_operating_flight_number TEXT,

    -- Operating carrier
    operating_carrier TEXT,
    dot_id_operating_carrier TEXT,
    iata_code_operating_carrier TEXT,
    tail_number TEXT,
    operating_flight_number TEXT,

    -- Origin
    origin_airport_id TEXT,
    origin_airport_seq_id TEXT,
    origin_city_market_id TEXT,
    origin TEXT,
    origin_city_name TEXT,
    origin_state TEXT,
    origin_state_fips TEXT,
    origin_state_name TEXT,
    origin_wac TEXT,

    -- Destination
    dest_airport_id TEXT,
    dest_airport_seq_id TEXT,
    dest_city_market_id TEXT,
    destination TEXT,
    dest_city_name TEXT,
    dest_state TEXT,
    dest_state_fips TEXT,
    dest_state_name TEXT,
    dest_wac TEXT,

    -- Departure performance
    scheduled_departure_crs TEXT,
    actual_departure TEXT,
    departure_delay TEXT,
    departure_delay_minutes TEXT,
    departure_delayed_15_flag TEXT,     -- BTS's own precomputed flag (available if you want it)
    departure_delay_group TEXT,
    departure_time_block TEXT,
    taxi_out TEXT,
    wheels_off TEXT,

    -- Arrival performance
    wheels_on TEXT,
    taxi_in TEXT,
    scheduled_arrival_crs TEXT,
    actual_arrival TEXT,
    arrival_delay TEXT,
    arrival_delay_minutes TEXT,
    arrival_delayed_15_flag TEXT,       -- BTS's own precomputed flag (available if you want it)
    arrival_delay_group TEXT,
    arrival_time_block TEXT,

    -- Cancellations / diversions
    cancelled_flag TEXT,
    cancellation_code TEXT,
    diverted_flag TEXT,

    -- Flight summary
    crs_elapsed_time TEXT,
    actual_elapsed_time TEXT,
    air_time TEXT,
    flight_count TEXT,
    distance TEXT,
    distance_group TEXT,

    -- Delay causes
    carrier_delay TEXT,
    weather_delay TEXT,
    nas_delay TEXT,
    security_delay TEXT,
    late_aircraft_delay TEXT,

    -- Gate return information
    first_departure_time TEXT,
    total_additional_ground_time TEXT,
    longest_additional_ground_time TEXT,

    -- Diversion summary
    diverted_airport_landings TEXT,
    div_reached_dest TEXT,
    div_actual_elapsed_time TEXT,
    div_arr_delay TEXT,
    div_distance TEXT,

    -- Diversion 1
    div1_airport TEXT,
    div1_airport_id TEXT,
    div1_airport_seq_id TEXT,
    div1_wheels_on TEXT,
    div1_total_ground_time TEXT,
    div1_longest_ground_time TEXT,
    div1_wheels_off TEXT,
    div1_tail_number TEXT,

    -- Diversion 2
    div2_airport TEXT,
    div2_airport_id TEXT,
    div2_airport_seq_id TEXT,
    div2_wheels_on TEXT,
    div2_total_ground_time TEXT,
    div2_longest_ground_time TEXT,
    div2_wheels_off TEXT,
    div2_tail_number TEXT,

    -- Diversion 3
    div3_airport TEXT,
    div3_airport_id TEXT,
    div3_airport_seq_id TEXT,
    div3_wheels_on TEXT,
    div3_total_ground_time TEXT,
    div3_longest_ground_time TEXT,
    div3_wheels_off TEXT,
    div3_tail_number TEXT,

    -- Diversion 4
    div4_airport TEXT,
    div4_airport_id TEXT,
    div4_airport_seq_id TEXT,
    div4_wheels_on TEXT,
    div4_total_ground_time TEXT,
    div4_longest_ground_time TEXT,
    div4_wheels_off TEXT,
    div4_tail_number TEXT,

    -- Diversion 5
    div5_airport TEXT,
    div5_airport_id TEXT,
    div5_airport_seq_id TEXT,
    div5_wheels_on TEXT,
    div5_total_ground_time TEXT,
    div5_longest_ground_time TEXT,
    div5_wheels_off TEXT,
    div5_tail_number TEXT,

    -- BTS metadata
    duplicate_flag TEXT,

    -- BTS's export ends every row with a trailing comma, producing
    -- one extra empty field. This column absorbs it; it's always blank.
    _trailing_blank TEXT
);

-- ============================================================
-- Load the file (run separately, after adjusting the path):
--
-- COPY stg_flights_202512
-- FROM '/full/path/to/On_Time_Marketing_Carrier_On_Time_Performance__Beginning_January_2018__2025_12.csv'
-- WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"');
--
-- Use \copy instead of COPY if running from psql on your own
-- machine rather than a server with direct file access.
-- ============================================================
