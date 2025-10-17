-- ============================================
-- NYC Taxi Tables Creation Script for Trino
-- ============================================
-- This script creates the required tables for Superset dashboard
-- Run this in Trino CLI after processing data with PySpark

-- ============================================
-- STEP 1: Create Schema
-- ============================================

CREATE SCHEMA IF NOT EXISTS nyc_taxi
WITH (location = 'hdfs:///user/hive/warehouse/nyc_taxi.db');

-- ============================================
-- STEP 2: Create nyc_taxi_aggregated Table
-- ============================================

-- Option A: External table pointing to Parquet files in HDFS
CREATE TABLE IF NOT EXISTS nyc_taxi.nyc_taxi_aggregated (
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
    external_location = 'hdfs:///user/hive/warehouse/nyc_taxi/aggregated/'
);

-- Option B: External table pointing to S3
/*
CREATE TABLE IF NOT EXISTS nyc_taxi.nyc_taxi_aggregated (
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
    external_location = 's3://your-bucket/nyc_taxi/aggregated/'
);
*/

-- Option C: CSV format (for testing with sample data)
/*
CREATE TABLE IF NOT EXISTS nyc_taxi.nyc_taxi_aggregated (
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
    format = 'CSV',
    external_location = 'file:///path/to/data/',
    csv_separator = ',',
    skip_header_line_count = 1
);
*/

-- ============================================
-- STEP 3: Create taxi_zones Table
-- ============================================

-- Option A: External table pointing to Parquet
CREATE TABLE IF NOT EXISTS nyc_taxi.taxi_zones (
    LocationID INT,
    Borough VARCHAR,
    Zone VARCHAR,
    service_zone VARCHAR,
    latitude DOUBLE,
    longitude DOUBLE
)
WITH (
    format = 'PARQUET',
    external_location = 'hdfs:///user/hive/warehouse/nyc_taxi/zones/'
);

-- Option B: CSV format (most common for taxi zones)
/*
CREATE TABLE IF NOT EXISTS nyc_taxi.taxi_zones (
    LocationID INT,
    Borough VARCHAR,
    Zone VARCHAR,
    service_zone VARCHAR,
    latitude DOUBLE,
    longitude DOUBLE
)
WITH (
    format = 'CSV',
    external_location = 'file:///path/to/zones/',
    csv_separator = ',',
    skip_header_line_count = 1
);
*/

-- ============================================
-- STEP 4: Verify Tables
-- ============================================

-- Show all tables
SHOW TABLES IN nyc_taxi;

-- Count rows
SELECT 'nyc_taxi_aggregated' as table_name, COUNT(*) as row_count 
FROM nyc_taxi.nyc_taxi_aggregated
UNION ALL
SELECT 'taxi_zones' as table_name, COUNT(*) as row_count 
FROM nyc_taxi.taxi_zones;

-- Sample data
SELECT * FROM nyc_taxi.nyc_taxi_aggregated LIMIT 5;
SELECT * FROM nyc_taxi.taxi_zones LIMIT 5;

-- ============================================
-- STEP 5: Data Quality Checks
-- ============================================

-- Check date range
SELECT 
    taxi_type,
    MIN(Pickup_Time) as earliest_date,
    MAX(Pickup_Time) as latest_date,
    COUNT(*) as record_count,
    SUM(number) as total_trips
FROM nyc_taxi.nyc_taxi_aggregated
GROUP BY taxi_type;

-- Check zones
SELECT 
    Borough,
    COUNT(*) as zone_count
FROM nyc_taxi.taxi_zones
GROUP BY Borough
ORDER BY zone_count DESC;

-- Test join
SELECT 
    t.Pickup_Time,
    z.Zone,
    z.Borough,
    t.number as trips,
    t.Total_Amount as revenue
FROM nyc_taxi.nyc_taxi_aggregated t
JOIN nyc_taxi.taxi_zones z ON t.Pickup_Location = z.LocationID
WHERE t.Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '7' DAY, '%Y-%m-%d %H')
ORDER BY t.number DESC
LIMIT 10;

-- ============================================
-- STEP 6: Create Useful Views (Optional)
-- ============================================

-- View: Recent data only (last 30 days)
CREATE OR REPLACE VIEW nyc_taxi.recent_trips AS
SELECT *
FROM nyc_taxi.nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H');

-- View: Trip data with zone information
CREATE OR REPLACE VIEW nyc_taxi.trips_with_zones AS
SELECT 
    t.*,
    z.Zone as pickup_zone,
    z.Borough as pickup_borough
FROM nyc_taxi.nyc_taxi_aggregated t
LEFT JOIN nyc_taxi.taxi_zones z ON t.Pickup_Location = z.LocationID;

-- View: Daily summary
CREATE OR REPLACE VIEW nyc_taxi.daily_summary AS
SELECT 
    DATE(Pickup_Time) as trip_date,
    taxi_type,
    SUM(number) as total_trips,
    CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as total_revenue,
    CAST(AVG(AVG_Total_Amount) AS DECIMAL(8,2)) as avg_fare,
    CAST(AVG(AVG_Trip_Distance) AS DECIMAL(8,2)) as avg_distance
FROM nyc_taxi.nyc_taxi_aggregated
GROUP BY DATE(Pickup_Time), taxi_type
ORDER BY trip_date DESC;

-- ============================================
-- NOTES:
-- ============================================
-- 1. Adjust 'external_location' paths to match your environment
-- 2. Choose format (PARQUET, CSV) based on your processed data
-- 3. For HDFS: hdfs:///path/to/data
-- 4. For S3: s3://bucket-name/path/to/data
-- 5. For local: file:///absolute/path/to/data
-- 6. Ensure Trino has proper permissions to access the location
-- 7. Run verification queries after table creation
-- 8. If tables already exist, use DROP TABLE first or CREATE OR REPLACE

