-- ============================================================
-- 05_kpi_analysis.sql
--
-- PURPOSE:
-- Answer key operational questions about U.S. airline delays and
-- cancellations using the full 12-month flights_clean table
-- (2025 BTS Marketing Carrier On-Time Performance data).
-- This is the "ANALYZE" step from the project notes.
--
-- HOW TO RUN:
-- Run the SETUP section once to (re)create the view. After that,
-- every query below can be highlighted and run on its own.
--
-- CONTENTS:
--   SETUP  primary_cause_view (reusable delay-cause labeling)
--   Q1     What is the #1 cause of flight delays?
--   Q2     Which carriers perform best, fairly compared?
--   Q2b    Which carriers drive the Late Aircraft problem?
--   Q2c    Why do Frontier (F9) and Allegiant (G4) rank worst?
--   Q3     Which routes and airports perform worst, and why?
--   Q4     Which carriers cancel most, where, when, and why?
-- ============================================================


-- ============================================================
-- SETUP: primary_cause_view
-- ============================================================
-- Labels every flight delayed 15+ minutes with its PRIMARY cause:
-- whichever of the 5 BTS delay-cause fields has the most minutes.
-- BTS only assigns cause minutes to flights delayed 15+ minutes,
-- so NULL cause fields are treated as 0 with COALESCE.
--
-- Saved as a permanent view so the labeling logic is written once
-- instead of being re-pasted as a CTE in every query below.
-- Note: if two causes tie, CASE picks the first one listed.

DROP VIEW IF EXISTS primary_cause_view;

CREATE VIEW primary_cause_view AS
WITH delay_causes AS (
    SELECT
        marketing_carrier,
        source_month,
        origin,
        destination,
        arrival_delay_minutes,
        COALESCE(carrier_delay_minutes, 0)       AS carrier_delay_minutes,
        COALESCE(weather_delay_minutes, 0)       AS weather_delay_minutes,
        COALESCE(nas_delay_minutes, 0)           AS nas_delay_minutes,
        COALESCE(security_delay_minutes, 0)      AS security_delay_minutes,
        COALESCE(late_aircraft_delay_minutes, 0) AS late_aircraft_delay_minutes
    FROM flights_clean
    WHERE arrival_delayed_15 = TRUE
)
SELECT
    *,
    GREATEST(carrier_delay_minutes, weather_delay_minutes, nas_delay_minutes,
             security_delay_minutes, late_aircraft_delay_minutes) AS max_cause_minutes,
    CASE GREATEST(carrier_delay_minutes, weather_delay_minutes, nas_delay_minutes,
                  security_delay_minutes, late_aircraft_delay_minutes)
        WHEN carrier_delay_minutes       THEN 'Carrier'
        WHEN weather_delay_minutes       THEN 'Weather'
        WHEN nas_delay_minutes           THEN 'Air Traffic System (NAS)'
        WHEN security_delay_minutes      THEN 'Security'
        WHEN late_aircraft_delay_minutes THEN 'Late Aircraft'
    END AS primary_cause
FROM delay_causes;


-- ============================================================
-- Q1: What is the #1 cause of flight delays?
-- ============================================================

-- Q1a: Frequency and average severity by primary cause
SELECT
    primary_cause,
    COUNT(*) AS delayed_flights,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_delayed_flights,
    ROUND(AVG(arrival_delay_minutes), 1) AS avg_delay_minutes
FROM primary_cause_view
GROUP BY primary_cause
ORDER BY delayed_flights DESC;

-- Q1b: Total minutes lost system-wide by primary cause
SELECT
    primary_cause,
    COUNT(*) AS delayed_flights,
    ROUND(AVG(arrival_delay_minutes), 1) AS avg_delay_minutes,
    SUM(arrival_delay_minutes) AS total_minutes_lost
FROM primary_cause_view
GROUP BY primary_cause
ORDER BY total_minutes_lost DESC;

-- FINDING:
-- Late Aircraft (38.9%) and Carrier (29.4%) delays are 68.3% of
-- delayed flights and ~74% of all delay-minutes lost (91.7M of
-- 124.7M). Weather is the most severe per incident (119.9 min
-- average) but rare: 4.1% of delayed flights and ~7% of minutes
-- lost. Improving turnaround times and reducing cascading
-- late-aircraft delays would do far more for reliability than any
-- weather-mitigation effort.


-- ============================================================
-- Q2: Which carriers perform best, fairly compared?
-- ============================================================

-- Q2-1: Naive on-time ranking (every carrier's whole network).
-- COUNT(on_time) skips NULLs, so cancelled/diverted flights are
-- excluded from the denominator automatically.
SELECT
    marketing_carrier,
    COUNT(on_time) AS flights_with_known_status,
    SUM(CASE WHEN on_time THEN 1 ELSE 0 END) AS on_time_flights,
    ROUND(100.0 * SUM(CASE WHEN on_time THEN 1 ELSE 0 END) / COUNT(on_time), 1) AS on_time_pct
FROM flights_clean
GROUP BY marketing_carrier
ORDER BY on_time_pct DESC;

-- Q2-2: Fairness-adjusted ranking. Only routes flown by 2+ carriers
-- are kept, so carriers are compared head-to-head on the same
-- airports, distances, and weather exposure.
WITH route_carrier_counts AS (
    SELECT route, COUNT(DISTINCT marketing_carrier) AS carriers_on_route
    FROM flights_clean
    GROUP BY route
),
shared_routes AS (
    SELECT route
    FROM route_carrier_counts
    WHERE carriers_on_route >= 2
)
SELECT
    f.marketing_carrier,
    COUNT(f.on_time) AS flights_with_known_status,
    ROUND(100.0 * SUM(CASE WHEN f.on_time THEN 1 ELSE 0 END) / COUNT(f.on_time), 1) AS on_time_pct_on_shared_routes
FROM flights_clean f
JOIN shared_routes sr ON f.route = sr.route
GROUP BY f.marketing_carrier
ORDER BY on_time_pct_on_shared_routes DESC;

-- Q2-3: Verification. Split carriers into Shared vs. Exclusive routes
-- to see how each route type performs on its own.
WITH route_carrier_counts AS (
    SELECT route, COUNT(DISTINCT marketing_carrier) AS carriers_on_route
    FROM flights_clean
    GROUP BY route
),
route_type AS (
    SELECT
        route,
        CASE WHEN carriers_on_route >= 2 THEN 'Shared' ELSE 'Exclusive' END AS route_type
    FROM route_carrier_counts
)
SELECT
    f.marketing_carrier,
    rt.route_type,
    COUNT(f.on_time) AS flights,
    ROUND(100.0 * SUM(CASE WHEN f.on_time THEN 1 ELSE 0 END) / COUNT(f.on_time), 1) AS on_time_pct
FROM flights_clean f
JOIN route_type rt ON f.route = rt.route
WHERE f.marketing_carrier IN ('UA', 'G4')
GROUP BY f.marketing_carrier, rt.route_type
ORDER BY f.marketing_carrier, rt.route_type;

-- FINDING:
-- Frontier stays dead last in both rankings, so its poor performance
-- isn't explained by a harder route network. United moves up (6th to
-- 4th) once uncontested routes are removed. Allegiant's score is close
-- to unusable for benchmarking: ~90% of its flights are on routes with
-- no direct competitor.


-- ============================================================
-- Q2b: Which carriers drive the Late Aircraft problem?
-- ============================================================

-- Q2b-1: Raw count (favors big carriers purely by volume)
SELECT
    marketing_carrier,
    COUNT(*) AS late_aircraft_delays
FROM primary_cause_view
WHERE primary_cause = 'Late Aircraft'
GROUP BY marketing_carrier
ORDER BY late_aircraft_delays DESC;

-- Q2b-2: Rate relative to each carrier's own flight volume.
-- LEFT JOIN keeps every carrier even with zero Late Aircraft delays.
WITH carrier_totals AS (
    SELECT marketing_carrier, COUNT(*) AS total_flights
    FROM flights_clean
    GROUP BY marketing_carrier
),
late_aircraft_by_carrier AS (
    SELECT marketing_carrier, COUNT(*) AS late_aircraft_delays
    FROM primary_cause_view
    WHERE primary_cause = 'Late Aircraft'
    GROUP BY marketing_carrier
)
SELECT
    ct.marketing_carrier,
    ct.total_flights,
    COALESCE(la.late_aircraft_delays, 0) AS late_aircraft_delays,
    ROUND(100.0 * COALESCE(la.late_aircraft_delays, 0) / ct.total_flights, 2) AS pct_of_flights_late_aircraft
FROM carrier_totals ct
LEFT JOIN late_aircraft_by_carrier la ON ct.marketing_carrier = la.marketing_carrier
ORDER BY pct_of_flights_late_aircraft DESC;

-- FINDING:
-- The rate reverses the raw ranking. AA, UA, and DL have some of the
-- LOWEST Late Aircraft rates once adjusted for size (DL is best at
-- 5.78%). Frontier (12.54%) and Allegiant (11.30%), two of the
-- smallest carriers, are worst, the opposite of what "bigger hubs =
-- more cascade risk" would predict.


-- ============================================================
-- Q2c: Why do Frontier (F9) and Allegiant (G4) rank worst?
-- ============================================================

-- Q2c-1 (Hypothesis 1, RULED OUT): tighter aircraft utilization.
-- Flights per distinct tail number is a proxy for how hard each
-- carrier works its fleet. (Proxy only: tail counts include planes
-- that joined or left the fleet mid-year.)
WITH carrier_aircraft AS (
    SELECT
        marketing_carrier,
        COUNT(*) AS total_flights,
        COUNT(DISTINCT tail_number) AS distinct_aircraft
    FROM flights_clean
    WHERE tail_number IS NOT NULL
    GROUP BY marketing_carrier
)
SELECT
    marketing_carrier,
    total_flights,
    distinct_aircraft,
    ROUND(total_flights::NUMERIC / distinct_aircraft, 1) AS flights_per_aircraft
FROM carrier_aircraft
ORDER BY flights_per_aircraft DESC;

-- Q2c-2 (Hypothesis 2): seasonal pattern.
-- Late Aircraft rate by month for F9 and G4.
WITH carrier_month_totals AS (
    SELECT marketing_carrier, source_month, COUNT(*) AS total_flights
    FROM flights_clean
    WHERE marketing_carrier IN ('F9', 'G4')
    GROUP BY marketing_carrier, source_month
),
late_aircraft_month AS (
    SELECT marketing_carrier, source_month, COUNT(*) AS late_aircraft_delays
    FROM primary_cause_view
    WHERE primary_cause = 'Late Aircraft'
      AND marketing_carrier IN ('F9', 'G4')
    GROUP BY marketing_carrier, source_month
)
SELECT
    cmt.marketing_carrier,
    cmt.source_month,
    cmt.total_flights,
    COALESCE(lam.late_aircraft_delays, 0) AS late_aircraft_delays,
    ROUND(100.0 * COALESCE(lam.late_aircraft_delays, 0) / cmt.total_flights, 2) AS pct_late_aircraft
FROM carrier_month_totals cmt
LEFT JOIN late_aircraft_month lam
    ON  cmt.marketing_carrier = lam.marketing_carrier
    AND cmt.source_month      = lam.source_month
ORDER BY cmt.marketing_carrier, cmt.source_month;

-- Q2c-3: Does WEATHER follow the same seasonal shape? If so, weather
-- is likely the upstream trigger behind the Late Aircraft spikes.
WITH carrier_month_totals AS (
    SELECT marketing_carrier, source_month, COUNT(*) AS total_flights
    FROM flights_clean
    WHERE marketing_carrier IN ('F9', 'G4')
    GROUP BY marketing_carrier, source_month
),
weather_month AS (
    SELECT marketing_carrier, source_month, COUNT(*) AS weather_delays
    FROM primary_cause_view
    WHERE primary_cause = 'Weather'
      AND marketing_carrier IN ('F9', 'G4')
    GROUP BY marketing_carrier, source_month
)
SELECT
    cmt.marketing_carrier,
    cmt.source_month,
    cmt.total_flights,
    COALESCE(wm.weather_delays, 0) AS weather_delays,
    ROUND(100.0 * COALESCE(wm.weather_delays, 0) / cmt.total_flights, 2) AS pct_weather
FROM carrier_month_totals cmt
LEFT JOIN weather_month wm
    ON  cmt.marketing_carrier = wm.marketing_carrier
    AND cmt.source_month      = wm.source_month
ORDER BY cmt.marketing_carrier, cmt.source_month;

-- Q2c-4: Ground congestion via taxi times, an independent signal that
-- doesn't depend on BTS's delay-cause labeling.
SELECT
    marketing_carrier,
    source_month,
    ROUND(AVG(taxi_out_minutes), 2) AS avg_taxi_out_minutes,
    ROUND(AVG(taxi_in_minutes), 2) AS avg_taxi_in_minutes,
    ROUND(AVG(taxi_out_minutes + taxi_in_minutes), 2) AS avg_total_taxi_minutes
FROM flights_clean
WHERE marketing_carrier IN ('F9', 'G4')
  AND cancelled = FALSE   -- cancelled flights never taxi
GROUP BY marketing_carrier, source_month
ORDER BY marketing_carrier, source_month;

-- FINDING:
-- Hypothesis 1 ruled out: Southwest works its fleet hardest of all 10
-- carriers yet doesn't have the worst Late Aircraft rate.
-- Hypothesis 2 partly supported: F9/G4 Late Aircraft rates peak in
-- June-July and bottom out in September, and weather delays and taxi
-- times peak in the same summer months. December's spike is only
-- partly explained: taxi times rise, but same-flight weather
-- attribution is low, likely because BTS tags only the FIRST delayed
-- flight in a chain as "Weather" and relabels every inherited delay
-- downstream as "Late Aircraft." January is a counter-example: G4's
-- taxi times are its highest of the year while Late Aircraft stays
-- low, so congestion alone isn't sufficient either.
-- Takeaway: F9/G4 would benefit most from added schedule buffer in
-- June-July and December, when multiple stressors compound.


-- ============================================================
-- Q3: Which routes and airports perform worst, and why?
-- ============================================================

-- Q3a: Worst routes. HAVING filters AFTER grouping, dropping routes
-- flown under 500 times a year (too few flights to trust the rate).
SELECT
    route,
    COUNT(*) AS total_flights,
    COUNT(on_time) AS flights_with_known_status,
    ROUND(100.0 * SUM(CASE WHEN on_time THEN 1 ELSE 0 END) / COUNT(on_time), 1) AS on_time_pct,
    ROUND(AVG(scheduled_elapsed_minutes), 0) AS avg_scheduled_flight_minutes
FROM flights_clean
GROUP BY route
HAVING COUNT(*) >= 500
ORDER BY on_time_pct ASC
LIMIT 15;

-- Q3b: Worst airports. UNION ALL stacks origin and destination rows so
-- each flight counts toward BOTH airports it touches.
WITH airport_flights AS (
    SELECT origin AS airport, on_time
    FROM flights_clean
    UNION ALL
    SELECT destination AS airport, on_time
    FROM flights_clean
)
SELECT
    airport,
    COUNT(*) AS total_flights_touching_airport,
    COUNT(on_time) AS flights_with_known_status,
    ROUND(100.0 * SUM(CASE WHEN on_time THEN 1 ELSE 0 END) / COUNT(on_time), 1) AS on_time_pct
FROM airport_flights
GROUP BY airport
HAVING COUNT(*) >= 1000
ORDER BY on_time_pct ASC
LIMIT 15;

-- Q3c: Which carriers serve the problem airports?
SELECT
    origin AS airport,
    marketing_carrier,
    COUNT(*) AS flights
FROM flights_clean
WHERE origin IN ('SFB', 'PIE', 'ASE', 'EGE', 'LCK')
GROUP BY origin, marketing_carrier
ORDER BY airport, flights DESC;

-- Q3d: Delay-cause mix for flights touching the mountain airports
-- (Aspen and Eagle/Vail), compared against the Q1a system baseline.
SELECT
    primary_cause,
    COUNT(*) AS delayed_flights,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_delayed_flights,
    ROUND(AVG(arrival_delay_minutes), 1) AS avg_delay_minutes
FROM primary_cause_view
WHERE origin IN ('ASE', 'EGE')
   OR destination IN ('ASE', 'EGE')
GROUP BY primary_cause
ORDER BY delayed_flights DESC;

-- FINDING:
-- Route length is NOT the driver: the 15 worst routes range from 79 to
-- 232 scheduled minutes. The worst airports split into two unrelated
-- clusters:
--   1. Mountain-resort airports (ASE, EGE), served mainly by UA, AA,
--      and DL. Weather causes 14.7% of their delays vs. 4.1% system-
--      wide (~3.6x) and runs longer (127.3 vs. 119.9 min). This is a
--      geography problem even well-resourced carriers can't overcome.
--   2. Allegiant's secondary leisure airports (SFB, PIE, LCK), served
--      almost entirely by G4. Minimal ground infrastructure compounds
--      the carrier's own tight scheduling from Q2c.
-- Treating "small/regional airport" as one category would have missed
-- this distinction. The two clusters need different fixes: weather
-- contingency and de-icing capacity vs. G4 scheduling changes.


-- ============================================================
-- Q4: Which carriers cancel most, where, when, and why?
-- ============================================================

-- Q4a: Cancellation rate by carrier. Divides by COUNT(*) (not
-- COUNT(on_time)) because cancelled flights are what's being measured.
SELECT
    marketing_carrier,
    COUNT(*) AS total_flights,
    SUM(CASE WHEN cancelled THEN 1 ELSE 0 END) AS cancelled_flights,
    ROUND(100.0 * SUM(CASE WHEN cancelled THEN 1 ELSE 0 END) / COUNT(*), 2) AS cancellation_pct
FROM flights_clean
GROUP BY marketing_carrier
ORDER BY cancellation_pct DESC;

-- Q4b: Cancellation reasons for the highest (AA) and lowest (G4)
-- carriers. PARTITION BY resets the percentage within each carrier,
-- so each carrier's reasons sum to 100%.
SELECT
    marketing_carrier,
    CASE cancellation_code
        WHEN 'A' THEN 'Carrier'
        WHEN 'B' THEN 'Weather'
        WHEN 'C' THEN 'Air Traffic System (NAS)'
        WHEN 'D' THEN 'Security'
    END AS cancellation_reason,
    COUNT(*) AS cancelled_flights,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY marketing_carrier), 1) AS pct_of_carrier_cancellations
FROM flights_clean
WHERE cancelled = TRUE
  AND marketing_carrier IN ('AA', 'G4')
GROUP BY marketing_carrier, cancellation_code
ORDER BY marketing_carrier, cancelled_flights DESC;

-- Q4c: WHERE do American's weather cancellations happen?
SELECT
    origin AS airport,
    COUNT(*) AS weather_cancellations,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_aa_weather_cancellations
FROM flights_clean
WHERE marketing_carrier = 'AA'
  AND cancelled = TRUE
  AND cancellation_code = 'B'
GROUP BY origin
ORDER BY weather_cancellations DESC
LIMIT 10;

-- Q4d: WHEN do American's weather cancellations happen?
SELECT
    source_month,
    COUNT(*) AS weather_cancellations,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_aa_weather_cancellations
FROM flights_clean
WHERE marketing_carrier = 'AA'
  AND cancelled = TRUE
  AND cancellation_code = 'B'
GROUP BY source_month
ORDER BY source_month;

-- FINDING:
-- American cancels most (2.36%, well above the next carrier at 1.77%);
-- Allegiant cancels least (0.47%) despite having one of the worst Late
-- Aircraft rates, suggesting it prefers to delay and still fly.
-- Weather causes only 4.1% of delays but 74.9% of AA's and 58.7% of
-- G4's cancellations: airlines cancel outright once weather is severe.
-- AA's weather cancellations are concentrated at DFW (19.2%, more than
-- double any other airport) and are bimodal by month: January (17.4%,
-- ice) and July (16.5%, severe thunderstorms), while December is low
-- (4.9%). Takeaway: weather-contingency planning at DFW covering both
-- its winter-ice and summer-storm seasons would address a
-- disproportionate share of AA's cancellations.
