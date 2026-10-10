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
--   SETUP       primary_cause_view (reusable delay-cause labeling)
--   VALIDATION  data checks run before any analysis (results recorded)
--   Q1          What is the #1 cause of flight delays?
--   Q2          Which carriers perform best, fairly compared?
--   Q2b         Which carriers drive the Late Aircraft problem?
--   Q2c         Why do Frontier (F9) and Allegiant (G4) have the worst
--               Late Aircraft rates?
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
-- Edge case: 14 delayed flights have no cause minutes recorded at all
-- (max_cause_minutes = 0, see check V7). GREATEST returns 0 and CASE
-- matches the first line, so they are labeled 'Carrier'. That is
-- 0.001% of delayed flights and changes no percentage; a production
-- version would label them 'Unknown'.

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
-- VALIDATION: data checks run before any analysis
-- ============================================================
-- Each check below was run against the loaded flights_clean table.
-- Results are recorded under each query.

-- V1. Total row count (completeness, the headline number).
SELECT COUNT(*) AS total_flights
FROM flights_clean;
-- RESULT: 7,736,770 flights.

-- V2. Count by month: catches a month loaded twice or missing.
SELECT source_month,
       COUNT(*)          AS flights,
       MIN(flight_date)  AS first_date,
       MAX(flight_date)  AS last_date
FROM flights_clean
GROUP BY source_month
ORDER BY source_month;
-- RESULT: 12 months, each loaded once (559,577 in Feb to 696,049 in
-- Jul). Every month's first and last flight_date fall inside that
-- month, and the 12 months sum to 7,736,770. December = 644,987,
-- matching the source file's expected count in 02_validation.sql.

-- V3. Rows filed under the wrong month (consistency).
SELECT COUNT(*) AS mismatched_rows
FROM flights_clean
WHERE DATE_TRUNC('month', flight_date)::date <> source_month;
-- RESULT: 0.

-- V4. Duplicate flights (uniqueness).
SELECT marketing_carrier, marketing_flight_number, flight_date, origin, destination,
       COUNT(*) AS copies
FROM flights_clean
GROUP BY marketing_carrier, marketing_flight_number, flight_date, origin, destination
HAVING COUNT(*) > 1
LIMIT 20;
-- RESULT: no rows returned.

-- V5. Carrier totals reconcile to the grand total.
SELECT marketing_carrier, COUNT(*) AS flights,
       SUM(COUNT(*)) OVER () AS grand_total
FROM flights_clean
GROUP BY marketing_carrier
ORDER BY flights DESC;
-- RESULT: 10 carriers summing to 7,736,770.

-- V6. Cross-check of Q1 using a second method: delay minutes SPLIT
-- across every contributing cause (Q1 instead assigns each flight's
-- whole delay to its single primary cause).
SELECT
  ROUND(100.0 * SUM(COALESCE(late_aircraft_delay_minutes,0) + COALESCE(carrier_delay_minutes,0))
        / SUM(COALESCE(late_aircraft_delay_minutes,0) + COALESCE(carrier_delay_minutes,0)
            + COALESCE(nas_delay_minutes,0) + COALESCE(weather_delay_minutes,0)
            + COALESCE(security_delay_minutes,0)), 1) AS late_plus_carrier_pct,
  ROUND(100.0 * SUM(COALESCE(weather_delay_minutes,0))
        / SUM(COALESCE(late_aircraft_delay_minutes,0) + COALESCE(carrier_delay_minutes,0)
            + COALESCE(nas_delay_minutes,0) + COALESCE(weather_delay_minutes,0)
            + COALESCE(security_delay_minutes,0)), 1) AS weather_pct
FROM flights_clean;
-- RESULT: Late Aircraft + Carrier = 71.8%, Weather = 6.5%.
-- Q1b's primary-cause method gives 73.6% and 6.7%. Both methods agree:
-- about three-quarters of delay time, with Weather around 7%.

-- V7. Delayed flights with no cause minutes recorded (edge case).
SELECT COUNT(*) AS no_cause_flights
FROM primary_cause_view
WHERE max_cause_minutes = 0;
-- RESULT: 14 of 1,685,334 delayed flights (see SETUP note).


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
-- Late Aircraft (38.9%) and Carrier (29.4%) are the top primary causes:
-- together about two-thirds (68.3%) of the 1,685,334 delayed flights,
-- and ~74% of delay-minutes (91.7M of 124.7M). Weather is the most
-- severe per incident (119.9 min average) but rare: 4.1% of delayed
-- flights and ~7% of minutes lost (8.3M). Improving turnaround times
-- and reducing cascading late-aircraft delays would do far more for
-- reliability than weather mitigation.


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
-- Frontier is last in both rankings (72.1% naive, 72.0% on shared
-- routes), so its poor performance isn't explained by a harder route
-- network.
-- United moves from 6th to 4th, but not because its own rate improved
-- (78.2% -> 78.1%; Q2-3 shows 78.3% exclusive vs. 78.1% shared).
-- Southwest (78.6% -> 77.8%) and Alaska (78.5% -> 77.0%) drop on
-- contested routes, so their naive scores were partly boosted by
-- exclusive routes. Ranks 3-6 sit within 0.4 points in the naive
-- ranking, so this is a small shift in a tight group.
-- Allegiant is hard to benchmark: 89.6% of its flights are on routes
-- with no direct competitor (Q2-3).


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
-- Adjusting for size reshuffles the raw ranking. Frontier (12.54%) and
-- Allegiant (11.30%), two of the smallest carriers, have the worst
-- rates, the opposite of what "bigger hubs = more cascade risk" would
-- predict. American (10.15%) and Southwest (10.73%) lead on raw counts
-- and stay in the worst four by rate. United (6.62%) and Delta (5.78%)
-- fall into the better half, and Spirit has the lowest rate (5.00%).
-- The 10 raw counts sum to 656,381, matching Q1's Late Aircraft total.


-- ============================================================
-- Q2c: Why do Frontier (F9) and Allegiant (G4) have the worst
--      Late Aircraft rates?
-- ============================================================

-- Q2c-1 (Hypothesis 1): tighter aircraft utilization.
-- Flights per distinct tail number is a proxy for how hard each
-- carrier works its fleet. Filtered to flights each airline OPERATES
-- itself (operating_carrier = marketing_carrier), because this BTS
-- table files flights under the marketing carrier, which would mix
-- regional partners' aircraft into the legacy carriers' counts.
-- (Proxy only: tail counts include planes that joined or left the
-- fleet mid-year.)
WITH carrier_aircraft AS (
    SELECT
        operating_carrier,
        COUNT(*) AS total_flights,
        COUNT(DISTINCT tail_number) AS distinct_aircraft
    FROM flights_clean
    WHERE tail_number IS NOT NULL
      AND operating_carrier = marketing_carrier
    GROUP BY operating_carrier
)
SELECT
    operating_carrier,
    total_flights,
    distinct_aircraft,
    ROUND(total_flights::NUMERIC / distinct_aircraft, 1) AS flights_per_aircraft
FROM carrier_aircraft
ORDER BY flights_per_aircraft DESC;
-- RESULT: Hypothesis 1 NOT SUPPORTED: no consistent link between fleet
-- utilization and Late Aircraft rate. Southwest (1st) and Frontier
-- (3rd) work their fleets hard and have high rates, but Hawaiian
-- (2nd) and Spirit (4th) work theirs just as hard with the two
-- lowest rates, and Allegiant (8th) has the 2nd-worst rate while
-- using its planes less than most.

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
-- Note: diverted flights are included, and a flight missing either
-- taxi value drops out of avg_total_taxi_minutes.
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
-- Hypothesis 1 (fleet utilization): not supported, see Q2c-1 result.
-- Hypothesis 2 (seasonality): partly supported.
--   * Both carriers' Late Aircraft rates peak in June-July (F9 17.4% /
--     15.9%, G4 14.5% / 13.9%) and bottom out in September (F9 8.7%,
--     G4 7.2%). Weather delays rise in the same summer months for both.
--   * Frontier's taxi times peak in June-July, matching its Late
--     Aircraft peak. Allegiant's taxi times peak in winter (Jan-Feb),
--     with summer only mid-range, while its Late Aircraft rate is low
--     in Jan-Feb, so congestion alone doesn't explain it. Taxi swings
--     are modest for both (2-3 minutes across the year).
--   * December's Late Aircraft spike (F9 14.7%; G4 14.7%, its highest
--     month) is NOT matched by weather delays (low for F9, mid-year for
--     G4). This is consistent with BTS tagging only the FIRST delayed
--     flight in a chain as "Weather" and relabeling every inherited
--     delay downstream as "Late Aircraft." Taxi times rise modestly in
--     December for both.
-- Weather-coded delays are small (0.2-3.5% of flights) next to Late
-- Aircraft (7-17%), so the two move together; this doesn't show that
-- weather causes the Late Aircraft delays.
-- Takeaway: F9/G4 would benefit most from added schedule buffer in
-- June-July and December.


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
-- Note: the 1,000-flight cutoff admits very small airports (about
-- 1,400-2,000 flights), whose rates swing more from chance.
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

-- Q3c: Which carriers serve the problem airports? (departures only)
SELECT
    origin AS airport,
    marketing_carrier,
    COUNT(*) AS flights
FROM flights_clean
WHERE origin IN ('USA', 'SFB', 'PIE', 'LCK', 'ASE', 'EGE',
                 'SUX', 'CMX', 'SLN', 'COD', 'DIK')
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
-- 232 scheduled minutes. Aspen appears in 4 of them and DFW in 5 (DFW
-- is also American's top weather-cancellation airport, Q4c).
-- Among the 15 worst airports, three clusters stand out:
--   1. Mountain-resort airports (ASE 3rd-worst, EGE 5th), served mainly
--      by UA, AA, and DL. Weather causes 14.7% of their delays vs. 4.1%
--      system-wide (~3.6x) and runs longer (127.3 vs. 119.9 min). But
--      Carrier is still the #1 cause there (36.2% vs. 29.4% system-
--      wide), so weather adds risk on top of operational issues rather
--      than replacing them.
--   2. Allegiant's leisure airports: USA (Concord, NC, the single worst
--      at 56.8%), SFB (2nd), PIE (7th), and LCK (15th). Every departure
--      at all four is G4, compounding the carrier's own Late Aircraft
--      problem from Q2b.
--   3. Small United-marketed regional airports: SUX, CMX, SLN, COD, and
--      DIK, where every departure is UA (about 700-970 departures each,
--      likely flown by United's regional partners). Their volumes are
--      small, so these rates swing more from chance.
-- The clusters need different fixes: weather contingency and de-icing
-- capacity at mountain airports, G4 scheduling changes, and a closer
-- look at United's small regional service.


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

-- Q4e: Does DFW itself follow the same seasonal pattern?
SELECT
    source_month,
    COUNT(*) AS dfw_weather_cancellations
FROM flights_clean
WHERE marketing_carrier = 'AA'
  AND cancelled = TRUE
  AND cancellation_code = 'B'
  AND origin = 'DFW'
GROUP BY source_month
ORDER BY source_month;

-- FINDING:
-- American cancels most (2.36%): about 1.3x the next carrier (Frontier,
-- 1.77%) and 1.7x Delta and United (1.36%). Allegiant cancels least
-- (0.47%) despite the 2nd-worst Late Aircraft rate, which suggests it
-- may prefer to delay and still fly rather than cancel and refund.
-- Weather causes only 4.1% of delayed flights but 74.9% of AA's and
-- 58.7% of G4's cancellations: airlines appear to cancel outright once
-- weather is severe.
-- AA's weather cancellations are concentrated: DFW alone is 19.2%
-- (2.3x the next airport, CLT), and the top 5 airports together are
-- 46.6%. Across AA's network they are bimodal by month: January
-- (17.4%) and July (16.5%) peak, December is low (4.9%), and
-- September-October are lowest (under 2%).
-- DFW itself (Q4e, months sum to its 6,767): one sharp January peak
-- (1,369, ~20%, ice) plus a long March-August storm season (624-797 per
-- month, 62% of the year combined). September (101), December (56) and
-- February (264) are quiet. So DFW does not peak in July; AA's network-
-- wide July peak comes partly from other airports.
-- Takeaway: weather-contingency planning at DFW (January ice and the
-- March-August storm season) and the other top-5 airports would address
-- nearly half of AA's weather cancellations.
