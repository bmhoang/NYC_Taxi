-- ============================================
-- Create NYC Taxi Aggregated View from Sample Data
-- ============================================
-- This script creates the nyc_taxi_aggregated view using the sample CSV files
-- Best used with nyc_greentrip.csv which has all required columns
-- Run in Trino: trino --server localhost:8080 --catalog hive --schema nyc_taxi

-- ============================================
-- STEP 1: Create Schema
-- ============================================

CREATE SCHEMA IF NOT EXISTS nyc_taxi;
USE nyc_taxi;

-- ============================================
-- STEP 2: Create External Tables for CSV Files
-- ============================================

-- Table 1: Green Trip (BEST DATA - Use this!)
DROP TABLE IF EXISTS nyc_greentrip;

CREATE TABLE nyc_greentrip (
    vendorid INT,
    lpep_pickup_datetime TIMESTAMP,
    lpep_dropoff_datetime TIMESTAMP,
    store_and_fwd_flag VARCHAR,
    ratecodeid INT,
    pulocationid INT,
    dolocationid INT,
    passenger_count INT,
    trip_distance DOUBLE,
    fare_amount DOUBLE,
    extra DOUBLE,
    mta_tax DOUBLE,
    tip_amount DOUBLE,
    tolls_amount DOUBLE,
    ehail_fee VARCHAR,  -- Changed to VARCHAR (can be empty)
    improvement_surcharge DOUBLE,
    total_amount DOUBLE,
    payment_type INT,
    trip_type DOUBLE,
    congestion_surcharge INT
)
WITH (
    format = 'CSV',
    external_location = 'file:///e:/source/NYC_Taxi/sampledata/',
    csv_separator = ',',
    skip_header_line_count = 1
);

-- Verify Green Trip data loaded
SELECT 'Green Trip Count' as table_name, COUNT(*) as row_count FROM nyc_greentrip;
SELECT * FROM nyc_greentrip LIMIT 5;


-- Table 2: Yellow Trip (Old format, 2009 data)
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
    mta_tax VARCHAR,  -- Can be empty
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

-- Verify Yellow Trip data loaded
SELECT 'Yellow Trip Count' as table_name, COUNT(*) FROM nyc_yellowtrip;


-- ============================================
-- STEP 3: Create Aggregated View
-- ============================================

-- Option A: Green Trip Only (RECOMMENDED)
DROP VIEW IF EXISTS nyc_taxi_aggregated;

CREATE VIEW nyc_taxi_aggregated AS
SELECT 
    -- Extract hour from pickup datetime (format: '2020-07-31 17')
    DATE_FORMAT(lpep_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    
    -- Pickup location
    pulocationid as Pickup_Location,
    
    -- Aggregated amounts
    SUM(total_amount) as Total_Amount,
    AVG(total_amount) as AVG_Total_Amount,
    
    -- Aggregated distances  
    SUM(trip_distance) as Total_Trip_Distance,
    AVG(trip_distance) as AVG_Trip_Distance,
    
    -- Aggregated passenger counts
    SUM(passenger_count) as Total_Passenger_Count,
    AVG(CAST(passenger_count AS DOUBLE)) as AVG_Passenger_Count,
    
    -- Fare components
    SUM(fare_amount) as Fare_Amount,
    SUM(extra) as Extra,
    SUM(tip_amount) as tip_amount,
    SUM(tolls_amount) as tolls_amount,
    
    -- Trip count
    COUNT(*) as number,
    
    -- Taxi type
    'green' as taxi_type
    
FROM nyc_greentrip
WHERE lpep_pickup_datetime IS NOT NULL
    AND total_amount > 0
    AND trip_distance > 0
    AND pulocationid IS NOT NULL
GROUP BY 
    DATE_FORMAT(lpep_pickup_datetime, '%Y-%m-%d %H'),
    pulocationid
ORDER BY Pickup_Time, Pickup_Location;

-- ============================================
-- STEP 4: Verify Aggregated View
-- ============================================

-- Check row count
SELECT 'Aggregated View' as view_name, COUNT(*) as row_count 
FROM nyc_taxi_aggregated;

-- Sample data
SELECT 
    Pickup_Time,
    Pickup_Location,
    number as trips,
    CAST(Total_Amount AS DECIMAL(10,2)) as revenue,
    CAST(AVG_Total_Amount AS DECIMAL(10,2)) as avg_fare,
    CAST(Total_Trip_Distance AS DECIMAL(10,2)) as total_miles,
    taxi_type
FROM nyc_taxi_aggregated
ORDER BY Pickup_Time, trips DESC;

-- Summary statistics
SELECT 
    taxi_type,
    COUNT(*) as aggregated_rows,
    MIN(Pickup_Time) as earliest_time,
    MAX(Pickup_Time) as latest_time,
    SUM(number) as total_trips,
    CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as total_revenue,
    CAST(AVG(AVG_Total_Amount) AS DECIMAL(8,2)) as overall_avg_fare
FROM nyc_taxi_aggregated
GROUP BY taxi_type;


-- ============================================
-- OPTIONAL: Create Combined View (Green + Yellow)
-- ============================================

/*
-- Uncomment to create combined view with both taxi types

DROP VIEW IF EXISTS green_aggregated;
DROP VIEW IF EXISTS yellow_aggregated;
DROP VIEW IF EXISTS nyc_taxi_aggregated;

-- Green taxi aggregation
CREATE VIEW green_aggregated AS
SELECT 
    DATE_FORMAT(lpep_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    pulocationid as Pickup_Location,
    SUM(total_amount) as Total_Amount,
    AVG(total_amount) as AVG_Total_Amount,
    SUM(trip_distance) as Total_Trip_Distance,
    AVG(trip_distance) as AVG_Trip_Distance,
    SUM(passenger_count) as Total_Passenger_Count,
    AVG(CAST(passenger_count AS DOUBLE)) as AVG_Passenger_Count,
    SUM(fare_amount) as Fare_Amount,
    SUM(extra) as Extra,
    SUM(tip_amount) as tip_amount,
    SUM(tolls_amount) as tolls_amount,
    COUNT(*) as number,
    'green' as taxi_type
FROM nyc_greentrip
WHERE lpep_pickup_datetime IS NOT NULL
    AND total_amount > 0
    AND trip_distance > 0
    AND pulocationid IS NOT NULL
GROUP BY 
    DATE_FORMAT(lpep_pickup_datetime, '%Y-%m-%d %H'),
    pulocationid;

-- Yellow taxi aggregation (no LocationID, grouped by time only)
CREATE VIEW yellow_aggregated AS
SELECT 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    NULL as Pickup_Location,  -- Old data doesn't have LocationID
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
FROM nyc_yellowtrip
WHERE trip_pickup_datetime IS NOT NULL
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H');

-- Combined view
CREATE VIEW nyc_taxi_aggregated AS
SELECT * FROM green_aggregated
UNION ALL
SELECT * FROM yellow_aggregated
ORDER BY Pickup_Time, taxi_type;

-- Verify combined view
SELECT 
    taxi_type,
    COUNT(*) as aggregated_rows,
    MIN(Pickup_Time) as earliest_time,
    MAX(Pickup_Time) as latest_time,
    SUM(number) as total_trips
FROM nyc_taxi_aggregated
GROUP BY taxi_type;
*/


-- ============================================
-- STEP 5: Create Sample Taxi Zones Table
-- ============================================

-- Create a small taxi zones table for the locations in our sample
DROP TABLE IF EXISTS taxi_zones;

CREATE TABLE taxi_zones (
    LocationID INT,
    Borough VARCHAR,
    Zone VARCHAR,
    service_zone VARCHAR,
    latitude DOUBLE,
    longitude DOUBLE
);

-- Insert sample zones for the locations in green trip data
INSERT INTO taxi_zones VALUES
(168, 'Queens', 'Steinway', 'Boro Zone', 40.7740, -73.9030),
(78, 'Manhattan', 'East Harlem South', 'Boro Zone', 40.7957, -73.9389),
(95, 'Queens', 'Woodhaven', 'Boro Zone', 40.6892, -73.8569),
(130, 'Queens', 'Jamaica', 'Boro Zone', 40.6902, -73.8063),
(260, 'Queens', 'Far Rockaway', 'Boro Zone', 40.5990, -73.7565),
(82, 'Manhattan', 'East Village', 'Yellow Zone', 40.7264, -73.9818),
(106, 'Manhattan', 'Gramercy', 'Yellow Zone', 40.7368, -73.9830),
(134, 'Queens', 'Jamaica Estates', 'Boro Zone', 40.7197, -73.7874),
(255, 'Queens', 'Forest Park', 'Boro Zone', 40.7016, -73.8563),
(66, 'Manhattan', 'East Chelsea', 'Yellow Zone', 40.7465, -73.9972),
(254, 'Queens', 'Forest Hills', 'Boro Zone', 40.7183, -73.8448),
(60, 'Manhattan', 'Midtown East', 'Yellow Zone', 40.7549, -73.9709),
(159, 'Queens', 'Ridgewood', 'Boro Zone', 40.7021, -73.9053),
(42, 'Manhattan', 'Central Park', 'Yellow Zone', 40.7829, -73.9654),
(91, 'Queens', 'Elmhurst', 'Boro Zone', 40.7361, -73.8820),
(216, 'Manhattan', 'West Village', 'Yellow Zone', 40.7357, -74.0023),
(118, 'Manhattan', 'Harlem', 'Boro Zone', 40.8116, -73.9465),
(198, 'Queens', 'Sunnyside', 'Boro Zone', 40.7433, -73.9196);

-- Verify taxi zones
SELECT COUNT(*) as zone_count FROM taxi_zones;
SELECT * FROM taxi_zones ORDER BY LocationID LIMIT 10;


-- ============================================
-- STEP 6: Test Join Between Tables
-- ============================================

-- Test join to verify everything works
SELECT 
    t.Pickup_Time,
    z.Borough,
    z.Zone,
    t.number as trips,
    CAST(t.Total_Amount AS DECIMAL(10,2)) as revenue,
    CAST(t.AVG_Total_Amount AS DECIMAL(10,2)) as avg_fare,
    t.taxi_type
FROM nyc_taxi_aggregated t
LEFT JOIN taxi_zones z ON t.Pickup_Location = z.LocationID
ORDER BY t.Pickup_Time, t.number DESC
LIMIT 10;


-- ============================================
-- STEP 7: Test Queries for Superset
-- ============================================

-- Query 1: Trips by hour
SELECT 
    SUBSTRING(Pickup_Time, 12, 2) as hour_of_day,
    SUM(number) as total_trips,
    CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as total_revenue
FROM nyc_taxi_aggregated
GROUP BY SUBSTRING(Pickup_Time, 12, 2)
ORDER BY hour_of_day;

-- Query 2: Top pickup locations
SELECT 
    t.Pickup_Location,
    z.Zone,
    z.Borough,
    SUM(t.number) as total_trips,
    CAST(SUM(t.Total_Amount) AS DECIMAL(10,2)) as total_revenue
FROM nyc_taxi_aggregated t
LEFT JOIN taxi_zones z ON t.Pickup_Location = z.LocationID
GROUP BY t.Pickup_Location, z.Zone, z.Borough
ORDER BY total_trips DESC
LIMIT 10;

-- Query 3: Average fare by location
SELECT 
    z.Borough,
    COUNT(DISTINCT t.Pickup_Location) as location_count,
    SUM(t.number) as total_trips,
    CAST(AVG(t.AVG_Total_Amount) AS DECIMAL(8,2)) as avg_fare
FROM nyc_taxi_aggregated t
LEFT JOIN taxi_zones z ON t.Pickup_Location = z.LocationID
WHERE z.Borough IS NOT NULL
GROUP BY z.Borough
ORDER BY total_trips DESC;


-- ============================================
-- SUCCESS!
-- ============================================

SELECT '✓ Tables created successfully!' as status;
SELECT '✓ nyc_taxi_aggregated view ready!' as status;
SELECT '✓ taxi_zones table populated!' as status;
SELECT '✓ Ready to connect Superset!' as status;

-- Show final summary
SELECT 
    'Data Summary' as info,
    (SELECT COUNT(*) FROM nyc_greentrip) as raw_green_rows,
    (SELECT COUNT(*) FROM nyc_taxi_aggregated) as aggregated_rows,
    (SELECT COUNT(*) FROM taxi_zones) as zone_count;

