-- ============================================
-- NYC Yellow Taxi Dashboard - Complete Setup
-- ============================================
-- This script creates a complete dashboard using Yellow Trip (2009) data
-- Run in Trino: trino --server localhost:8080 --catalog hive --schema nyc_taxi

-- ============================================
-- STEP 1: Create Schema
-- ============================================

CREATE SCHEMA IF NOT EXISTS nyc_taxi;
USE nyc_taxi;

-- ============================================
-- STEP 2: Create Yellow Trip Table from CSV
-- ============================================

DROP TABLE IF EXISTS nyc_yellowtrip;

CREATE TABLE nyc_yellowtrip (
    vendor_name VARCHAR,
    trip_pickup_datetime TIMESTAMP,
    trip_dropoff_datetime TIMESTAMP,
    passenger_count INT,
    trip_distance DOUBLE,
    start_lon DOUBLE,
    start_lat DOUBLE,
    rate_code VARCHAR,
    store_and_forward VARCHAR,
    end_lon DOUBLE,
    end_lat DOUBLE,
    payment_type VARCHAR,
    fare_amt DOUBLE,
    surcharge DOUBLE,
    mta_tax VARCHAR,
    tip_amt DOUBLE,
    tolls_amt DOUBLE,
    total_amt DOUBLE
)
WITH (
    format = 'CSV',
    external_location = 'file:///e:/source/NYC_Taxi/sampledata/',
    csv_separator = ',',
    skip_header_line_count = 1
);

-- Verify data loaded
SELECT 'Yellow Trip Raw Data' as info, COUNT(*) as row_count FROM nyc_yellowtrip;
SELECT * FROM nyc_yellowtrip LIMIT 3;


-- ============================================
-- STEP 3: Create Aggregated View (Time-Based)
-- ============================================
-- Note: Since Yellow Trip doesn't have LocationID, we aggregate by time only
-- We can optionally add coordinate-based grouping

DROP VIEW IF EXISTS nyc_taxi_aggregated;

CREATE VIEW nyc_taxi_aggregated AS
SELECT 
    -- Extract hour from pickup datetime
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    
    -- No LocationID available - use NULL or coordinate clusters
    NULL as Pickup_Location,
    
    -- Aggregated amounts
    SUM(total_amt) as Total_Amount,
    AVG(total_amt) as AVG_Total_Amount,
    
    -- Aggregated distances
    SUM(trip_distance) as Total_Trip_Distance,
    AVG(trip_distance) as AVG_Trip_Distance,
    
    -- Aggregated passenger counts
    SUM(passenger_count) as Total_Passenger_Count,
    AVG(CAST(passenger_count AS DOUBLE)) as AVG_Passenger_Count,
    
    -- Fare components (Yellow uses 'fare_amt' not 'fare_amount')
    SUM(fare_amt) as Fare_Amount,
    SUM(surcharge) as Extra,  -- Note: surcharge instead of 'extra'
    SUM(tip_amt) as tip_amount,
    SUM(tolls_amt) as tolls_amount,
    
    -- Trip count
    COUNT(*) as number,
    
    -- Taxi type
    'yellow' as taxi_type
    
FROM nyc_yellowtrip
WHERE trip_pickup_datetime IS NOT NULL
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H')
ORDER BY Pickup_Time;

-- Verify aggregated view
SELECT 'Aggregated View' as info, COUNT(*) as row_count FROM nyc_taxi_aggregated;
SELECT * FROM nyc_taxi_aggregated LIMIT 5;


-- ============================================
-- STEP 4: Create Coordinate-Based Location View (Optional)
-- ============================================
-- Group trips by coordinate clusters for geographic analysis

DROP VIEW IF EXISTS yellow_trip_locations;

CREATE VIEW yellow_trip_locations AS
SELECT 
    -- Cluster coordinates to ~100m precision (2 decimal places ≈ 1.1km, 3 ≈ 110m)
    ROUND(start_lat, 3) as latitude,
    ROUND(start_lon, 3) as longitude,
    
    -- Approximate area name (very rough)
    CASE 
        WHEN start_lat BETWEEN 40.70 AND 40.80 
         AND start_lon BETWEEN -74.02 AND -73.93 
            THEN 'Lower Manhattan'
        WHEN start_lat BETWEEN 40.75 AND 40.78
         AND start_lon BETWEEN -74.00 AND -73.95
            THEN 'Midtown Manhattan'
        WHEN start_lat BETWEEN 40.78 AND 40.88
         AND start_lon BETWEEN -73.98 AND -73.93
            THEN 'Upper Manhattan'
        WHEN start_lat < 40.70 THEN 'Brooklyn Area'
        ELSE 'Other Area'
    END as rough_area,
    
    -- Aggregated metrics
    COUNT(*) as trip_count,
    AVG(total_amt) as avg_fare,
    AVG(trip_distance) as avg_distance,
    SUM(total_amt) as total_revenue
    
FROM nyc_yellowtrip
WHERE start_lat IS NOT NULL 
    AND start_lon IS NOT NULL
    AND start_lat BETWEEN 40.5 AND 41.0  -- NYC bounds
    AND start_lon BETWEEN -74.3 AND -73.7
GROUP BY 
    ROUND(start_lat, 3),
    ROUND(start_lon, 3),
    rough_area
HAVING trip_count >= 1;

-- Verify location view
SELECT * FROM yellow_trip_locations ORDER BY trip_count DESC LIMIT 10;


-- ============================================
-- STEP 5: Create Dashboard Query Views
-- ============================================

-- View 1: Hourly Metrics (for Time Series Charts)
CREATE OR REPLACE VIEW hourly_metrics AS
SELECT 
    CAST(SUBSTR(DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H'), 12, 2) AS INTEGER) as hour_of_day,
    COUNT(*) as total_trips,
    AVG(total_amt) as avg_fare,
    AVG(trip_distance) as avg_distance,
    AVG(passenger_count) as avg_passengers,
    SUM(total_amt) as total_revenue,
    AVG(tip_amt / NULLIF(fare_amt, 0) * 100) as avg_tip_pct
FROM nyc_yellowtrip
WHERE trip_pickup_datetime IS NOT NULL
    AND total_amt > 0
GROUP BY hour_of_day
ORDER BY hour_of_day;

SELECT * FROM hourly_metrics;


-- View 2: Payment Method Analysis (Unique to Yellow Trip)
CREATE OR REPLACE VIEW payment_analysis AS
SELECT 
    payment_type,
    COUNT(*) as trip_count,
    AVG(total_amt) as avg_fare,
    AVG(tip_amt) as avg_tip,
    AVG(tip_amt / NULLIF(fare_amt, 0) * 100) as avg_tip_pct,
    SUM(total_amt) as total_revenue,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) as pct_of_trips
FROM nyc_yellowtrip
WHERE total_amt > 0
GROUP BY payment_type
ORDER BY trip_count DESC;

SELECT * FROM payment_analysis;


-- View 3: Vendor Performance (Unique to Yellow Trip)
CREATE OR REPLACE VIEW vendor_performance AS
SELECT 
    vendor_name,
    COUNT(*) as trip_count,
    AVG(total_amt) as avg_fare,
    AVG(trip_distance) as avg_distance,
    AVG(tip_amt) as avg_tip,
    SUM(total_amt) as total_revenue,
    AVG((UNIX_TIMESTAMP(trip_dropoff_datetime) - 
         UNIX_TIMESTAMP(trip_pickup_datetime)) / 60) as avg_duration_minutes
FROM nyc_yellowtrip
WHERE trip_pickup_datetime IS NOT NULL
    AND trip_dropoff_datetime IS NOT NULL
GROUP BY vendor_name
ORDER BY trip_count DESC;

SELECT * FROM vendor_performance;


-- View 4: Fare Distribution
CREATE OR REPLACE VIEW fare_distribution AS
SELECT 
    CASE 
        WHEN total_amt < 5 THEN '$0-5'
        WHEN total_amt < 10 THEN '$5-10'
        WHEN total_amt < 15 THEN '$10-15'
        WHEN total_amt < 20 THEN '$15-20'
        WHEN total_amt < 30 THEN '$20-30'
        WHEN total_amt < 50 THEN '$30-50'
        ELSE '$50+'
    END as fare_bucket,
    COUNT(*) as trip_count,
    AVG(trip_distance) as avg_distance
FROM nyc_yellowtrip
WHERE total_amt > 0 AND total_amt < 200
GROUP BY fare_bucket
ORDER BY MIN(total_amt);

SELECT * FROM fare_distribution;


-- View 5: Distance Distribution
CREATE OR REPLACE VIEW distance_distribution AS
SELECT 
    CASE 
        WHEN trip_distance < 1 THEN '0-1 mi'
        WHEN trip_distance < 2 THEN '1-2 mi'
        WHEN trip_distance < 3 THEN '2-3 mi'
        WHEN trip_distance < 5 THEN '3-5 mi'
        WHEN trip_distance < 10 THEN '5-10 mi'
        WHEN trip_distance < 20 THEN '10-20 mi'
        ELSE '20+ mi'
    END as distance_bucket,
    COUNT(*) as trip_count,
    AVG(total_amt) as avg_fare,
    AVG(tip_amt) as avg_tip
FROM nyc_yellowtrip
WHERE trip_distance > 0 AND trip_distance < 100
GROUP BY distance_bucket
ORDER BY MIN(trip_distance);

SELECT * FROM distance_distribution;


-- ============================================
-- STEP 6: Dashboard KPI Queries
-- ============================================

-- KPI 1: Total Trips
SELECT COUNT(*) as total_trips FROM nyc_yellowtrip;

-- KPI 2: Total Revenue
SELECT CAST(SUM(total_amt) AS DECIMAL(12,2)) as total_revenue FROM nyc_yellowtrip;

-- KPI 3: Average Fare
SELECT CAST(AVG(total_amt) AS DECIMAL(8,2)) as avg_fare FROM nyc_yellowtrip WHERE total_amt > 0;

-- KPI 4: Total Distance
SELECT CAST(SUM(trip_distance) AS DECIMAL(12,2)) as total_miles FROM nyc_yellowtrip;

-- KPI 5: Average Trip Distance
SELECT CAST(AVG(trip_distance) AS DECIMAL(8,2)) as avg_distance FROM nyc_yellowtrip WHERE trip_distance > 0;

-- KPI 6: Average Tip Percentage
SELECT CAST(AVG(tip_amt / NULLIF(fare_amt, 0) * 100) AS DECIMAL(5,2)) as avg_tip_pct 
FROM nyc_yellowtrip WHERE fare_amt > 0;


-- ============================================
-- STEP 7: Chart-Specific Queries
-- ============================================

-- Chart 1: Trips Over Time (Hourly)
SELECT 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as pickup_hour,
    COUNT(*) as trip_count,
    AVG(total_amt) as avg_fare
FROM nyc_yellowtrip
GROUP BY pickup_hour
ORDER BY pickup_hour;


-- Chart 2: Busy Hours Bar Chart
SELECT 
    HOUR(trip_pickup_datetime) as hour_of_day,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare,
    SUM(total_amt) as total_revenue
FROM nyc_yellowtrip
GROUP BY hour_of_day
ORDER BY hour_of_day;


-- Chart 3: Day of Week Pattern
SELECT 
    DAY_OF_WEEK(trip_pickup_datetime) as day_num,
    CASE DAY_OF_WEEK(trip_pickup_datetime)
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
        WHEN 7 THEN 'Sunday'
    END as day_name,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare
FROM nyc_yellowtrip
GROUP BY day_num
ORDER BY day_num;


-- Chart 4: Fare Components Breakdown
SELECT 'Base Fare' as component, SUM(fare_amt) as amount FROM nyc_yellowtrip
UNION ALL
SELECT 'Surcharge', SUM(surcharge) FROM nyc_yellowtrip
UNION ALL
SELECT 'Tips', SUM(tip_amt) FROM nyc_yellowtrip
UNION ALL
SELECT 'Tolls', SUM(tolls_amt) FROM nyc_yellowtrip
ORDER BY amount DESC;


-- Chart 5: Distance vs Fare Scatter
SELECT 
    trip_distance,
    total_amt,
    passenger_count
FROM nyc_yellowtrip
WHERE trip_distance > 0 
    AND trip_distance < 50
    AND total_amt > 0
    AND total_amt < 100;


-- Chart 6: Payment Method Pie Chart
SELECT 
    payment_type,
    COUNT(*) as trip_count
FROM nyc_yellowtrip
GROUP BY payment_type
ORDER BY trip_count DESC;


-- Chart 7: Tip Analysis by Payment Type
SELECT 
    payment_type,
    AVG(tip_amt) as avg_tip_amount,
    AVG(tip_amt / NULLIF(fare_amt, 0) * 100) as avg_tip_percentage,
    COUNT(*) as trips
FROM nyc_yellowtrip
WHERE fare_amt > 0
GROUP BY payment_type;


-- Chart 8: Passenger Count Distribution
SELECT 
    passenger_count,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare
FROM nyc_yellowtrip
WHERE passenger_count > 0 AND passenger_count <= 6
GROUP BY passenger_count
ORDER BY passenger_count;


-- Chart 9: Trip Duration Analysis
SELECT 
    HOUR(trip_pickup_datetime) as pickup_hour,
    AVG((UNIX_TIMESTAMP(trip_dropoff_datetime) - 
         UNIX_TIMESTAMP(trip_pickup_datetime)) / 60) as avg_duration_minutes,
    COUNT(*) as trips
FROM nyc_yellowtrip
WHERE trip_pickup_datetime IS NOT NULL
    AND trip_dropoff_datetime IS NOT NULL
GROUP BY pickup_hour
ORDER BY pickup_hour;


-- Chart 10: Geographic Heatmap (Coordinate-Based)
SELECT 
    start_lat as latitude,
    start_lon as longitude,
    COUNT(*) as trip_count,
    AVG(total_amt) as avg_fare
FROM nyc_yellowtrip
WHERE start_lat IS NOT NULL 
    AND start_lon IS NOT NULL
    AND start_lat BETWEEN 40.5 AND 41.0
    AND start_lon BETWEEN -74.3 AND -73.7
GROUP BY start_lat, start_lon
HAVING trip_count >= 1;


-- ============================================
-- STEP 8: Summary Statistics
-- ============================================

-- Overall Summary
SELECT 
    'Yellow Taxi (2009)' as dataset,
    COUNT(*) as total_trips,
    CAST(SUM(total_amt) AS DECIMAL(12,2)) as total_revenue,
    CAST(AVG(total_amt) AS DECIMAL(8,2)) as avg_fare,
    CAST(SUM(trip_distance) AS DECIMAL(12,2)) as total_miles,
    CAST(AVG(trip_distance) AS DECIMAL(8,2)) as avg_trip_distance,
    CAST(AVG(passenger_count) AS DECIMAL(4,2)) as avg_passengers,
    MIN(trip_pickup_datetime) as earliest_trip,
    MAX(trip_pickup_datetime) as latest_trip
FROM nyc_yellowtrip;


-- ============================================
-- SUCCESS MESSAGE
-- ============================================

SELECT '✓ Yellow Trip dashboard setup complete!' as status;
SELECT '✓ Tables created: nyc_yellowtrip' as status;
SELECT '✓ Views created: nyc_taxi_aggregated, hourly_metrics, payment_analysis, vendor_performance, etc.' as status;
SELECT '✓ Ready to connect Superset!' as status;

-- Next Steps:
-- 1. Open Superset: http://localhost:8088
-- 2. Add Trino connection: trino://admin@localhost:8080/hive/nyc_taxi
-- 3. Add datasets: nyc_taxi_aggregated, hourly_metrics, payment_analysis, vendor_performance
-- 4. Create charts using the queries above
-- 5. Build dashboard!

-- Note: Geographic charts will show coordinates but no zone names
-- This is expected - Yellow Trip (2009) data doesn't have LocationID

