-- ============================================
-- OPTIMIZED QUERIES FOR 2+ BILLION RECORDS
-- ============================================
-- Performance-optimized versions of NYC Yellow Trip queries
-- For table: lakehouse.ws_55ccd057_4fff_4d3f_92d7_212ebac1d7cf.nyc_yellowtrip

-- ============================================
-- IMMEDIATE FIX: Add Date Filter
-- ============================================

-- ❌ SLOW VERSION (scans 2B rows):
/*
SELECT 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    NULL as Pickup_Location,
    SUM(total_amt) as Total_Amount,
    AVG(total_amt) as AVG_Total_Amount,
    SUM(trip_distance) as Total_Trip_Distance,
    AVG(trip_distance) as AVG_Trip_Distance,
    SUM(passenger_count) as Total_Passenger_Count,
    AVG(CAST(passenger_count AS DOUBLE)) as AVG_Passenger_Count,
    SUM(fare_amt) as Fare_Amount,
    SUM(surcharge) as Extra,
    SUM(tip_amt) as tip_amount,
    SUM(tolls_amt) as tolls_amount,
    COUNT(*) as number,
    'yellow' as taxi_type
FROM lakehouse.ws_55ccd057_4fff_4d3f_92d7_212ebac1d7cf.nyc_yellowtrip
WHERE trip_pickup_datetime IS NOT NULL
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H')
ORDER BY Pickup_Time
LIMIT 1;
*/

-- ✅ FAST VERSION (with date filter):
CREATE OR REPLACE VIEW nyc_taxi_aggregated_optimized AS
SELECT 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    NULL as Pickup_Location,
    SUM(total_amt) as Total_Amount,
    AVG(total_amt) as AVG_Total_Amount,
    SUM(trip_distance) as Total_Trip_Distance,
    AVG(trip_distance) as AVG_Trip_Distance,
    SUM(passenger_count) as Total_Passenger_Count,
    AVG(CAST(passenger_count AS DOUBLE)) as AVG_Passenger_Count,
    SUM(fare_amt) as Fare_Amount,
    SUM(surcharge) as Extra,
    SUM(tip_amt) as tip_amount,
    SUM(tolls_amt) as tolls_amount,
    COUNT(*) as number,
    'yellow' as taxi_type
FROM lakehouse.ws_55ccd057_4fff_4d3f_92d7_212ebac1d7cf.nyc_yellowtrip
WHERE trip_pickup_datetime >= CURRENT_TIMESTAMP - INTERVAL '90' DAY  -- ← CRITICAL!
    AND trip_pickup_datetime IS NOT NULL
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H');

-- Test query (should be much faster)
SELECT * FROM nyc_taxi_aggregated_optimized 
ORDER BY Pickup_Time DESC
LIMIT 10;


-- ============================================
-- OPTION 1: Rolling Window View (Last N Days)
-- ============================================

-- Last 30 days only
CREATE OR REPLACE VIEW nyc_taxi_last_30d AS
SELECT 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    NULL as Pickup_Location,
    SUM(total_amt) as Total_Amount,
    AVG(total_amt) as AVG_Total_Amount,
    SUM(trip_distance) as Total_Trip_Distance,
    AVG(trip_distance) as AVG_Trip_Distance,
    SUM(passenger_count) as Total_Passenger_Count,
    AVG(CAST(passenger_count AS DOUBLE)) as AVG_Passenger_Count,
    SUM(fare_amt) as Fare_Amount,
    SUM(surcharge) as Extra,
    SUM(tip_amt) as tip_amount,
    SUM(tolls_amt) as tolls_amount,
    COUNT(*) as number,
    'yellow' as taxi_type
FROM lakehouse.ws_55ccd057_4fff_4d3f_92d7_212ebac1d7cf.nyc_yellowtrip
WHERE trip_pickup_datetime >= CURRENT_DATE - INTERVAL '30' DAY
    AND trip_pickup_datetime < CURRENT_DATE + INTERVAL '1' DAY
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H');


-- ============================================
-- OPTION 2: Specific Date Range Query
-- ============================================

-- For Superset - pass date parameters
CREATE OR REPLACE VIEW nyc_taxi_aggregated AS
SELECT 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    NULL as Pickup_Location,
    SUM(total_amt) as Total_Amount,
    AVG(total_amt) as AVG_Total_Amount,
    SUM(trip_distance) as Total_Trip_Distance,
    AVG(trip_distance) as AVG_Trip_Distance,
    SUM(passenger_count) as Total_Passenger_Count,
    AVG(CAST(passenger_count AS DOUBLE)) as AVG_Passenger_Count,
    SUM(fare_amt) as Fare_Amount,
    SUM(surcharge) as Extra,
    SUM(tip_amt) as tip_amount,
    SUM(tolls_amt) as tolls_amount,
    COUNT(*) as number,
    'yellow' as taxi_type
FROM lakehouse.ws_55ccd057_4fff_4d3f_92d7_212ebac1d7cf.nyc_yellowtrip
WHERE trip_pickup_datetime >= TIMESTAMP '2024-01-01 00:00:00'  -- Change dates as needed
    AND trip_pickup_datetime < TIMESTAMP '2024-02-01 00:00:00'
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H');


-- ============================================
-- OPTION 3: Approximate Aggregation (FASTEST)
-- ============================================

-- For exploratory analysis - 10-100x faster
CREATE OR REPLACE VIEW nyc_taxi_approx AS
SELECT 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    NULL as Pickup_Location,
    -- Use APPROX functions for speed
    APPROX_SUM(total_amt) as Total_Amount,
    AVG(total_amt) as AVG_Total_Amount,  -- AVG is already efficient
    APPROX_SUM(trip_distance) as Total_Trip_Distance,
    AVG(trip_distance) as AVG_Trip_Distance,
    APPROX_SUM(passenger_count) as Total_Passenger_Count,
    AVG(CAST(passenger_count AS DOUBLE)) as AVG_Passenger_Count,
    APPROX_SUM(fare_amt) as Fare_Amount,
    APPROX_SUM(surcharge) as Extra,
    APPROX_SUM(tip_amt) as tip_amount,
    APPROX_SUM(tolls_amt) as tolls_amount,
    COUNT(*) as number,
    'yellow' as taxi_type
FROM lakehouse.ws_55ccd057_4fff_4d3f_92d7_212ebac1d7cf.nyc_yellowtrip
WHERE trip_pickup_datetime >= CURRENT_DATE - INTERVAL '90' DAY
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H');


-- ============================================
-- OPTION 4: Sampling for Dashboard Prototyping
-- ============================================

-- Sample 1% of data for fast dashboard testing
CREATE OR REPLACE VIEW nyc_taxi_sample AS
SELECT 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    NULL as Pickup_Location,
    SUM(total_amt) * 100 as Total_Amount,  -- Scale up by 100
    AVG(total_amt) as AVG_Total_Amount,     -- AVG doesn't need scaling
    SUM(trip_distance) * 100 as Total_Trip_Distance,
    AVG(trip_distance) as AVG_Trip_Distance,
    SUM(passenger_count) * 100 as Total_Passenger_Count,
    AVG(CAST(passenger_count AS DOUBLE)) as AVG_Passenger_Count,
    SUM(fare_amt) * 100 as Fare_Amount,
    SUM(surcharge) * 100 as Extra,
    SUM(tip_amt) * 100 as tip_amount,
    SUM(tolls_amt) * 100 as tolls_amount,
    COUNT(*) * 100 as number,  -- Scale up by 100
    'yellow' as taxi_type
FROM lakehouse.ws_55ccd057_4fff_4d3f_92d7_212ebac1d7cf.nyc_yellowtrip 
    TABLESAMPLE BERNOULLI (1)  -- Sample 1% of rows
WHERE trip_pickup_datetime >= CURRENT_DATE - INTERVAL '90' DAY
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H');


-- ============================================
-- RECOMMENDED: Create Materialized Table
-- ============================================

-- Step 1: Create materialized aggregated table (one time)
CREATE TABLE IF NOT EXISTS nyc_taxi_aggregated_mat (
    pickup_date DATE,
    pickup_hour INT,
    Pickup_Time VARCHAR,
    Pickup_Location INT,
    Total_Amount DOUBLE,
    AVG_Total_Amount DOUBLE,
    Total_Trip_Distance DOUBLE,
    AVG_Trip_Distance DOUBLE,
    Total_Passenger_Count INT,
    AVG_Passenger_Count DOUBLE,
    Fare_Amount DOUBLE,
    Extra DOUBLE,
    tip_amount DOUBLE,
    tolls_amount DOUBLE,
    number INT,
    taxi_type VARCHAR
)
WITH (
    format = 'PARQUET',
    partitioned_by = ARRAY['pickup_date']
);

-- Step 2: Populate with historical data (run once, process one month at a time)
-- Example for January 2024:
INSERT INTO nyc_taxi_aggregated_mat
SELECT 
    DATE(trip_pickup_datetime) as pickup_date,
    HOUR(trip_pickup_datetime) as pickup_hour,
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    NULL as Pickup_Location,
    SUM(total_amt) as Total_Amount,
    AVG(total_amt) as AVG_Total_Amount,
    SUM(trip_distance) as Total_Trip_Distance,
    AVG(trip_distance) as AVG_Trip_Distance,
    SUM(passenger_count) as Total_Passenger_Count,
    AVG(CAST(passenger_count AS DOUBLE)) as AVG_Passenger_Count,
    SUM(fare_amt) as Fare_Amount,
    SUM(surcharge) as Extra,
    SUM(tip_amt) as tip_amount,
    SUM(tolls_amt) as tolls_amount,
    COUNT(*) as number,
    'yellow' as taxi_type
FROM lakehouse.ws_55ccd057_4fff_4d3f_92d7_212ebac1d7cf.nyc_yellowtrip
WHERE trip_pickup_datetime >= TIMESTAMP '2024-01-01 00:00:00'
    AND trip_pickup_datetime < TIMESTAMP '2024-02-01 00:00:00'
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY 
    DATE(trip_pickup_datetime),
    HOUR(trip_pickup_datetime),
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H');

-- Step 3: Query the materialized table (FAST!)
SELECT * FROM nyc_taxi_aggregated_mat
WHERE pickup_date >= DATE '2024-01-01'
ORDER BY Pickup_Time;


-- ============================================
-- DAILY INCREMENTAL UPDATE SCRIPT
-- ============================================

-- Run this daily to add yesterday's data
INSERT INTO nyc_taxi_aggregated_mat
SELECT 
    DATE(trip_pickup_datetime) as pickup_date,
    HOUR(trip_pickup_datetime) as pickup_hour,
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    NULL as Pickup_Location,
    SUM(total_amt) as Total_Amount,
    AVG(total_amt) as AVG_Total_Amount,
    SUM(trip_distance) as Total_Trip_Distance,
    AVG(trip_distance) as AVG_Trip_Distance,
    SUM(passenger_count) as Total_Passenger_Count,
    AVG(CAST(passenger_count AS DOUBLE)) as AVG_Passenger_Count,
    SUM(fare_amt) as Fare_Amount,
    SUM(surcharge) as Extra,
    SUM(tip_amt) as tip_amount,
    SUM(tolls_amt) as tolls_amount,
    COUNT(*) as number,
    'yellow' as taxi_type
FROM lakehouse.ws_55ccd057_4fff_4d3f_92d7_212ebac1d7cf.nyc_yellowtrip
WHERE DATE(trip_pickup_datetime) = CURRENT_DATE - INTERVAL '1' DAY  -- Yesterday only
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY 
    DATE(trip_pickup_datetime),
    HOUR(trip_pickup_datetime),
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H');


-- ============================================
-- PERFORMANCE MONITORING
-- ============================================

-- Check query execution plan
EXPLAIN ANALYZE
SELECT * FROM nyc_taxi_aggregated_optimized LIMIT 10;

-- Monitor query performance
SHOW STATS FOR nyc_yellowtrip;

-- Check partition information (if table is partitioned)
SHOW PARTITIONS FROM nyc_yellowtrip;


-- ============================================
-- SUPERSET CONFIGURATION
-- ============================================

-- Use this view in Superset for best performance
CREATE OR REPLACE VIEW nyc_taxi_for_superset AS
SELECT * FROM nyc_taxi_aggregated_mat
WHERE pickup_date >= CURRENT_DATE - INTERVAL '365' DAY;  -- Last year only

-- Or use the rolling window view
-- CREATE OR REPLACE VIEW nyc_taxi_for_superset AS
-- SELECT * FROM nyc_taxi_last_30d;


-- ============================================
-- SUMMARY
-- ============================================

/*
Performance Comparison (2B records):

Query Type                  | Rows Scanned    | Time        | Recommendation
----------------------------|-----------------|-------------|----------------
No date filter             | 2,000,000,000   | Hours       | ❌ Never do this
With 30-day filter         | 60,000,000      | Minutes     | ⚠️  OK for ad-hoc
With 7-day filter          | 14,000,000      | Seconds     | ✅ Good
Approx aggregation         | 60,000,000      | Seconds     | ✅ Good for exploration
Sampling (1%)              | 20,000,000      | Seconds     | ✅ Good for prototyping
Materialized table         | 720 (30d×24h)   | Milliseconds| ✅ BEST for dashboards

RECOMMENDED APPROACH:
1. Create materialized table (nyc_taxi_aggregated_mat)
2. Run daily incremental updates
3. Query materialized table in Superset
4. Result: Sub-second dashboard performance!
*/

