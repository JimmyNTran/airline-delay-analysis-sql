-- ============================================================
-- 04_load_all_months.sql
--
-- PURPOSE:
-- Load and transform multiple months of BTS Marketing Carrier
-- On-Time Performance data in a single run, instead of manually
-- repeating 01/02/03 for each month.
--
-- HOW TO USE:
--   1. Edit the v_paths and v_months arrays below so they list
--      every month's CSV file you have, in matching order
--      (v_paths[1] must correspond to v_months[1], etc).
--      The paths below are placeholders — point them at wherever
--      you've saved the BTS monthly CSVs on your own machine.
--   2. Run this whole script. It will:
--        - (Re)create a single reusable staging table
--        - Rebuild flights_clean from scratch
--        - Loop through every month you listed: load it into
--          staging, transform it, and insert it into flights_clean
--   3. Check the "Messages" tab in pgAdmin's Query Tool output —
--      it prints a row count for each month as it goes, so you
--      can confirm nothing silently failed.
--
-- NOTE: This fully rebuilds flights_clean every time you run it.
-- That's intentional — it keeps the script safe to re-run without
-- worrying about duplicate rows piling up. Just make sure the
-- arrays below list every month you want included, every time.
-- ============================================================

-- One reusable staging table (replaces the old per-month
-- stg_flights_202512-style tables). It gets TRUNCATEd and
-- reloaded once per month inside the loop below.
DROP TABLE IF EXISTS stg_flights_raw;

CREATE TABLE stg_flights_raw (
    year TEXT, quarter TEXT, month TEXT, day_of_month TEXT, day_of_week TEXT,
    flight_date_raw TEXT,
    marketing_carrier TEXT, operated_or_branded_code_share_partners TEXT,
    dot_id_marketing_airline TEXT, iata_code_marketing_airline TEXT, marketing_flight_number TEXT,
    originally_scheduled_operating_carrier TEXT, dot_id_originally_scheduled_operating_carrier TEXT,
    iata_code_originally_scheduled_operating_carrier TEXT, originally_scheduled_operating_flight_number TEXT,
    operating_carrier TEXT, dot_id_operating_carrier TEXT, iata_code_operating_carrier TEXT,
    tail_number TEXT, operating_flight_number TEXT,
    origin_airport_id TEXT, origin_airport_seq_id TEXT, origin_city_market_id TEXT, origin TEXT,
    origin_city_name TEXT, origin_state TEXT, origin_state_fips TEXT, origin_state_name TEXT, origin_wac TEXT,
    dest_airport_id TEXT, dest_airport_seq_id TEXT, dest_city_market_id TEXT, destination TEXT,
    dest_city_name TEXT, dest_state TEXT, dest_state_fips TEXT, dest_state_name TEXT, dest_wac TEXT,
    scheduled_departure_crs TEXT, actual_departure TEXT, departure_delay TEXT, departure_delay_minutes TEXT,
    departure_delayed_15_flag TEXT, departure_delay_group TEXT, departure_time_block TEXT,
    taxi_out TEXT, wheels_off TEXT,
    wheels_on TEXT, taxi_in TEXT, scheduled_arrival_crs TEXT, actual_arrival TEXT, arrival_delay TEXT,
    arrival_delay_minutes TEXT, arrival_delayed_15_flag TEXT, arrival_delay_group TEXT, arrival_time_block TEXT,
    cancelled_flag TEXT, cancellation_code TEXT, diverted_flag TEXT,
    crs_elapsed_time TEXT, actual_elapsed_time TEXT, air_time TEXT, flight_count TEXT,
    distance TEXT, distance_group TEXT,
    carrier_delay TEXT, weather_delay TEXT, nas_delay TEXT, security_delay TEXT, late_aircraft_delay TEXT,
    first_departure_time TEXT, total_additional_ground_time TEXT, longest_additional_ground_time TEXT,
    diverted_airport_landings TEXT, div_reached_dest TEXT, div_actual_elapsed_time TEXT,
    div_arr_delay TEXT, div_distance TEXT,
    div1_airport TEXT, div1_airport_id TEXT, div1_airport_seq_id TEXT, div1_wheels_on TEXT,
    div1_total_ground_time TEXT, div1_longest_ground_time TEXT, div1_wheels_off TEXT, div1_tail_number TEXT,
    div2_airport TEXT, div2_airport_id TEXT, div2_airport_seq_id TEXT, div2_wheels_on TEXT,
    div2_total_ground_time TEXT, div2_longest_ground_time TEXT, div2_wheels_off TEXT, div2_tail_number TEXT,
    div3_airport TEXT, div3_airport_id TEXT, div3_airport_seq_id TEXT, div3_wheels_on TEXT,
    div3_total_ground_time TEXT, div3_longest_ground_time TEXT, div3_wheels_off TEXT, div3_tail_number TEXT,
    div4_airport TEXT, div4_airport_id TEXT, div4_airport_seq_id TEXT, div4_wheels_on TEXT,
    div4_total_ground_time TEXT, div4_longest_ground_time TEXT, div4_wheels_off TEXT, div4_tail_number TEXT,
    div5_airport TEXT, div5_airport_id TEXT, div5_airport_seq_id TEXT, div5_wheels_on TEXT,
    div5_total_ground_time TEXT, div5_longest_ground_time TEXT, div5_wheels_off TEXT, div5_tail_number TEXT,
    duplicate_flag TEXT,
    _trailing_blank TEXT
);

-- Fresh flights_clean every run (safe to re-run this whole script).
-- primary_cause_view (created in 05) depends on flights_clean, so drop it
-- first; re-run the SETUP section of 05 afterwards to recreate it.
DROP VIEW IF EXISTS primary_cause_view;
DROP TABLE IF EXISTS flights_clean;

CREATE TABLE flights_clean(
    source_month DATE,
    marketing_carrier TEXT,
    marketing_flight_number INTEGER,
    operating_carrier TEXT,
    operating_flight_number INTEGER,
    origin TEXT,
    destination TEXT,
    route TEXT,
    flight_date DATE,
    day_of_week INTEGER,
    scheduled_departure INTEGER,
    actual_departure INTEGER,
    scheduled_arrival INTEGER,
    actual_arrival INTEGER,
    scheduled_elapsed_minutes INTEGER,
    actual_elapsed_minutes INTEGER,
    air_time_minutes INTEGER,
    taxi_out_minutes INTEGER,
    taxi_in_minutes INTEGER,
    departure_delay_minutes INTEGER,
    arrival_delay_minutes INTEGER,
    tail_number TEXT,
    cancellation_code TEXT,
    cancelled BOOLEAN,
    diverted_airport_landings INTEGER,
    diverted BOOLEAN,
    carrier_delay_minutes INTEGER,
    weather_delay_minutes INTEGER,
    nas_delay_minutes INTEGER,
    security_delay_minutes INTEGER,
    late_aircraft_delay_minutes INTEGER,
    arrival_delayed_15 BOOLEAN,
    departure_delayed_15 BOOLEAN,
    severe_arrival_delay_60 BOOLEAN,
    on_time BOOLEAN,
    departure_period TEXT,
    form_type TEXT,
    duplicate_flag TEXT
);

-- ============================================================
-- EDIT THESE TWO ARRAYS to match the months you actually have.
-- v_paths[i] must be the file for v_months[i] — same order.
-- Add or remove lines as needed; just keep both arrays the same length.
-- ============================================================
DO $$
DECLARE
    v_paths TEXT[] := ARRAY[
        'C:\path\to\your\data\On_Time_Marketing_Carrier_On_Time_Performance_(Beginning_January_2018)_2025_1.csv',
        'C:\path\to\your\data\On_Time_Marketing_Carrier_On_Time_Performance_(Beginning_January_2018)_2025_2.csv',
        'C:\path\to\your\data\On_Time_Marketing_Carrier_On_Time_Performance_(Beginning_January_2018)_2025_3.csv',
        'C:\path\to\your\data\On_Time_Marketing_Carrier_On_Time_Performance_(Beginning_January_2018)_2025_4.csv',
        'C:\path\to\your\data\On_Time_Marketing_Carrier_On_Time_Performance_(Beginning_January_2018)_2025_5.csv',
        'C:\path\to\your\data\On_Time_Marketing_Carrier_On_Time_Performance_(Beginning_January_2018)_2025_6.csv',
        'C:\path\to\your\data\On_Time_Marketing_Carrier_On_Time_Performance_(Beginning_January_2018)_2025_7.csv',
        'C:\path\to\your\data\On_Time_Marketing_Carrier_On_Time_Performance_(Beginning_January_2018)_2025_8.csv',
        'C:\path\to\your\data\On_Time_Marketing_Carrier_On_Time_Performance_(Beginning_January_2018)_2025_9.csv',
        'C:\path\to\your\data\On_Time_Marketing_Carrier_On_Time_Performance_(Beginning_January_2018)_2025_10.csv',
        'C:\path\to\your\data\On_Time_Marketing_Carrier_On_Time_Performance_(Beginning_January_2018)_2025_11.csv',
        'C:\path\to\your\data\On_Time_Marketing_Carrier_On_Time_Performance_(Beginning_January_2018)_2025_12.csv'
    ];
    v_months DATE[] := ARRAY[
        DATE '2025-01-01',
        DATE '2025-02-01',
        DATE '2025-03-01',
        DATE '2025-04-01',
        DATE '2025-05-01',
        DATE '2025-06-01',
        DATE '2025-07-01',
        DATE '2025-08-01',
        DATE '2025-09-01',
        DATE '2025-10-01',
        DATE '2025-11-01',
        DATE '2025-12-01'
    ];
    v_month DATE;
    v_path TEXT;
    v_rows BIGINT;
    i INT;
BEGIN
    FOR i IN 1..array_length(v_paths, 1) LOOP
        v_path := v_paths[i];
        v_month := v_months[i];

        TRUNCATE stg_flights_raw;

        EXECUTE format(
            'COPY stg_flights_raw FROM %L WITH (FORMAT csv, HEADER true, DELIMITER '','', QUOTE ''"'')',
            v_path
        );
        GET DIAGNOSTICS v_rows = ROW_COUNT;
        RAISE NOTICE 'Staged % rows for %', v_rows, v_month;

        INSERT INTO flights_clean(
            source_month, marketing_carrier, marketing_flight_number, operating_carrier, operating_flight_number,
            origin, destination, route, flight_date, day_of_week,
            scheduled_departure, actual_departure, scheduled_arrival, actual_arrival,
            scheduled_elapsed_minutes, actual_elapsed_minutes, air_time_minutes, taxi_out_minutes, taxi_in_minutes,
            departure_delay_minutes, arrival_delay_minutes, tail_number, cancellation_code, cancelled,
            diverted_airport_landings, diverted, carrier_delay_minutes, weather_delay_minutes, nas_delay_minutes,
            security_delay_minutes, late_aircraft_delay_minutes, arrival_delayed_15, departure_delayed_15,
            severe_arrival_delay_60, on_time, departure_period, form_type, duplicate_flag
        )
        SELECT
            v_month,
            marketing_carrier,
            NULLIF(TRIM(marketing_flight_number), '')::NUMERIC::INTEGER,
            operating_carrier,
            NULLIF(TRIM(operating_flight_number), '')::NUMERIC::INTEGER,
            TRIM(origin),
            TRIM(destination),
            TRIM(origin) || '-' || TRIM(destination),
            TO_DATE(flight_date_raw, 'YYYY-MM-DD'),
            NULLIF(TRIM(day_of_week), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(scheduled_departure_crs), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(actual_departure), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(scheduled_arrival_crs), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(actual_arrival), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(crs_elapsed_time), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(actual_elapsed_time), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(air_time), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(taxi_out), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(taxi_in), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(departure_delay), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(arrival_delay), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(tail_number), ''),
            NULLIF(TRIM(cancellation_code), ''),
            CASE WHEN NULLIF(TRIM(cancellation_code), '') IS NOT NULL THEN TRUE ELSE FALSE END,
            COALESCE(NULLIF(TRIM(diverted_airport_landings), '')::NUMERIC::INTEGER, 0),
            CASE WHEN COALESCE(NULLIF(TRIM(diverted_airport_landings), '')::NUMERIC::INTEGER, 0) > 0 THEN TRUE ELSE FALSE END,
            NULLIF(TRIM(carrier_delay), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(weather_delay), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(nas_delay), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(security_delay), '')::NUMERIC::INTEGER,
            NULLIF(TRIM(late_aircraft_delay), '')::NUMERIC::INTEGER,
            CASE
                WHEN NULLIF(TRIM(arrival_delay), '') IS NULL THEN NULL
                WHEN NULLIF(TRIM(arrival_delay), '')::NUMERIC >= 15 THEN TRUE
                ELSE FALSE
            END,
            CASE
                WHEN NULLIF(TRIM(departure_delay), '') IS NULL THEN NULL
                WHEN NULLIF(TRIM(departure_delay), '')::NUMERIC >= 15 THEN TRUE
                ELSE FALSE
            END,
            CASE
                WHEN NULLIF(TRIM(arrival_delay), '') IS NULL THEN NULL
                WHEN NULLIF(TRIM(arrival_delay), '')::NUMERIC >= 60 THEN TRUE
                ELSE FALSE
            END,
            CASE
                WHEN NULLIF(TRIM(arrival_delay), '') IS NULL THEN NULL
                WHEN NULLIF(TRIM(cancellation_code), '') IS NOT NULL THEN FALSE
                WHEN COALESCE(NULLIF(TRIM(diverted_airport_landings), '')::NUMERIC::INTEGER, 0) > 0 THEN FALSE
                WHEN NULLIF(TRIM(arrival_delay), '')::NUMERIC < 15 THEN TRUE
                ELSE FALSE
            END,
            CASE
                WHEN NULLIF(TRIM(scheduled_departure_crs), '') IS NULL THEN NULL
                WHEN NULLIF(TRIM(scheduled_departure_crs), '')::NUMERIC < 600 THEN 'Early Morning'
                WHEN NULLIF(TRIM(scheduled_departure_crs), '')::NUMERIC < 1200 THEN 'Morning'
                WHEN NULLIF(TRIM(scheduled_departure_crs), '')::NUMERIC < 1800 THEN 'Afternoon'
                ELSE 'Evening'
            END,
            NULL,
            duplicate_flag
        FROM stg_flights_raw
        WHERE duplicate_flag <> 'Y';

        GET DIAGNOSTICS v_rows = ROW_COUNT;
        RAISE NOTICE 'Inserted % rows into flights_clean for %', v_rows, v_month;

    END LOOP;
END $$;
