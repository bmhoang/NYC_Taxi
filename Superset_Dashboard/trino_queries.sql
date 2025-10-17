-- ============================================
-- NYC Taxi Superset Dashboard - Trino Queries
-- ============================================
-- These queries are optimized for Trino and can be used directly in Apache Superset
-- Adjust table names and date ranges as needed

-- ============================================
-- SECTION 1: KEY PERFORMANCE INDICATORS (KPIs)
-- ============================================

-- Query 1.1: Total Trips (Last 30 Days)
SELECT 
    SUM(number) as total_trips
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H');

-- Query 1.2: Total Revenue (Last 30 Days)
SELECT 
    CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as total_revenue
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H');

-- Query 1.3: Average Fare per Trip
SELECT 
    CAST(SUM(Total_Amount) / NULLIF(SUM(number), 0) AS DECIMAL(8,2)) as avg_fare
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H');

-- Query 1.4: Total Distance (Miles)
SELECT 
    CAST(SUM(Total_Trip_Distance) AS DECIMAL(12,2)) as total_miles
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H');

-- Query 1.5: Average Trip Distance
SELECT 
    CAST(SUM(Total_Trip_Distance) / NULLIF(SUM(number), 0) AS DECIMAL(8,2)) as avg_trip_distance
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H');

-- Query 1.6: Total Tips
SELECT 
    CAST(SUM(tip_amount) AS DECIMAL(12,2)) as total_tips
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H');


-- ============================================
-- SECTION 2: TIME SERIES ANALYSIS
-- ============================================

-- Query 2.1: Trips Over Time (Hourly) - Last 7 Days
SELECT 
    Pickup_Time as pickup_datetime,
    taxi_type,
    SUM(number) as trip_count,
    CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as revenue
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '7' DAY, '%Y-%m-%d %H')
GROUP BY Pickup_Time, taxi_type
ORDER BY Pickup_Time;

-- Query 2.2: Daily Aggregated Trips
SELECT 
    DATE(Pickup_Time) as trip_date,
    taxi_type,
    SUM(number) as total_trips,
    CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as total_revenue,
    CAST(AVG(AVG_Total_Amount) AS DECIMAL(8,2)) as avg_fare
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '90' DAY, '%Y-%m-%d %H')
GROUP BY DATE(Pickup_Time), taxi_type
ORDER BY trip_date;

-- Query 2.3: Month-over-Month Comparison
SELECT 
    DATE_TRUNC('month', DATE(Pickup_Time)) as month,
    taxi_type,
    SUM(number) as total_trips,
    CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as total_revenue
FROM nyc_taxi_aggregated
GROUP BY DATE_TRUNC('month', DATE(Pickup_Time)), taxi_type
ORDER BY month DESC;


-- ============================================
-- SECTION 3: HOURLY PATTERNS (BUSY HOURS)
-- ============================================

-- Query 3.1: Trips by Hour of Day (All Time Average)
SELECT 
    CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
    taxi_type,
    SUM(number) as total_trips,
    CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as total_revenue,
    CAST(AVG(AVG_Total_Amount) AS DECIMAL(8,2)) as avg_fare
FROM nyc_taxi_aggregated
GROUP BY SUBSTR(Pickup_Time, 12, 2), taxi_type
ORDER BY hour_of_day;

-- Query 3.2: Busiest Hours (Top 10)
SELECT 
    CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
    SUM(number) as total_trips
FROM nyc_taxi_aggregated
GROUP BY SUBSTR(Pickup_Time, 12, 2)
ORDER BY total_trips DESC
LIMIT 10;

-- Query 3.3: Hourly Patterns by Day of Week
SELECT 
    CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
    CASE DAY_OF_WEEK(DATE(Pickup_Time))
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
        WHEN 7 THEN 'Sunday'
    END as day_name,
    DAY_OF_WEEK(DATE(Pickup_Time)) as day_num,
    SUM(number) as trip_count,
    CAST(AVG(AVG_Total_Amount) AS DECIMAL(8,2)) as avg_fare
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
GROUP BY SUBSTR(Pickup_Time, 12, 2), DAY_OF_WEEK(DATE(Pickup_Time))
ORDER BY day_num, hour_of_day;

-- Query 3.4: Weekday vs Weekend Pattern
SELECT 
    CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
    CASE 
        WHEN DAY_OF_WEEK(DATE(Pickup_Time)) IN (6, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END as day_type,
    SUM(number) as total_trips,
    CAST(AVG(AVG_Total_Amount) AS DECIMAL(8,2)) as avg_fare
FROM nyc_taxi_aggregated
GROUP BY SUBSTR(Pickup_Time, 12, 2), 
    CASE 
        WHEN DAY_OF_WEEK(DATE(Pickup_Time)) IN (6, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END
ORDER BY hour_of_day;


-- ============================================
-- SECTION 4: LOCATION ANALYSIS (TOP ZONES)
-- ============================================

-- Query 4.1: Top 20 Busiest Pickup Locations
SELECT 
    Pickup_Location,
    SUM(number) as total_trips,
    CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as total_revenue,
    CAST(AVG(AVG_Trip_Distance) AS DECIMAL(8,2)) as avg_distance,
    CAST(AVG(AVG_Total_Amount) AS DECIMAL(8,2)) as avg_fare
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
GROUP BY Pickup_Location
ORDER BY total_trips DESC
LIMIT 20;

-- Query 4.2: Top Pickup Locations with Zone Names (requires taxi_zones table)
SELECT 
    t.Pickup_Location,
    z.Zone as zone_name,
    z.Borough,
    SUM(t.number) as total_trips,
    CAST(SUM(t.Total_Amount) AS DECIMAL(12,2)) as total_revenue,
    CAST(AVG(t.AVG_Trip_Distance) AS DECIMAL(8,2)) as avg_distance
FROM nyc_taxi_aggregated t
LEFT JOIN taxi_zones z ON t.Pickup_Location = z.LocationID
WHERE t.Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
GROUP BY t.Pickup_Location, z.Zone, z.Borough
ORDER BY total_trips DESC
LIMIT 20;

-- Query 4.3: Borough Level Summary
SELECT 
    z.Borough,
    SUM(t.number) as total_trips,
    CAST(SUM(t.Total_Amount) AS DECIMAL(12,2)) as total_revenue,
    CAST(SUM(t.Total_Trip_Distance) AS DECIMAL(12,2)) as total_distance,
    CAST(AVG(t.AVG_Total_Amount) AS DECIMAL(8,2)) as avg_fare
FROM nyc_taxi_aggregated t
LEFT JOIN taxi_zones z ON t.Pickup_Location = z.LocationID
WHERE t.Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    AND z.Borough IS NOT NULL
GROUP BY z.Borough
ORDER BY total_trips DESC;


-- ============================================
-- SECTION 5: FARE ANALYSIS
-- ============================================

-- Query 5.1: Fare Components Breakdown
SELECT 
    'Base Fare' as component,
    CAST(SUM(Fare_Amount) AS DECIMAL(12,2)) as total_amount,
    CAST(SUM(Fare_Amount) * 100.0 / SUM(Total_Amount) AS DECIMAL(5,2)) as percentage
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')

UNION ALL

SELECT 
    'Extra Charges' as component,
    CAST(SUM(Extra) AS DECIMAL(12,2)) as total_amount,
    CAST(SUM(Extra) * 100.0 / NULLIF(SUM(Total_Amount), 0) AS DECIMAL(5,2)) as percentage
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')

UNION ALL

SELECT 
    'Tips' as component,
    CAST(SUM(tip_amount) AS DECIMAL(12,2)) as total_amount,
    CAST(SUM(tip_amount) * 100.0 / NULLIF(SUM(Total_Amount), 0) AS DECIMAL(5,2)) as percentage
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')

UNION ALL

SELECT 
    'Tolls' as component,
    CAST(SUM(tolls_amount) AS DECIMAL(12,2)) as total_amount,
    CAST(SUM(tolls_amount) * 100.0 / NULLIF(SUM(Total_Amount), 0) AS DECIMAL(5,2)) as percentage
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')

ORDER BY total_amount DESC;

-- Query 5.2: Average Fare by Hour
SELECT 
    CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
    CAST(SUM(Total_Amount) / NULLIF(SUM(number), 0) AS DECIMAL(8,2)) as avg_fare,
    CAST(SUM(Fare_Amount) / NULLIF(SUM(number), 0) AS DECIMAL(8,2)) as avg_base_fare,
    CAST(SUM(tip_amount) / NULLIF(SUM(number), 0) AS DECIMAL(8,2)) as avg_tip
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
GROUP BY SUBSTR(Pickup_Time, 12, 2)
ORDER BY hour_of_day;

-- Query 5.3: Fare Distribution (Histogram Data)
SELECT 
    CASE 
        WHEN AVG_Total_Amount < 10 THEN '$0-10'
        WHEN AVG_Total_Amount < 20 THEN '$10-20'
        WHEN AVG_Total_Amount < 30 THEN '$20-30'
        WHEN AVG_Total_Amount < 40 THEN '$30-40'
        WHEN AVG_Total_Amount < 50 THEN '$40-50'
        WHEN AVG_Total_Amount < 75 THEN '$50-75'
        WHEN AVG_Total_Amount < 100 THEN '$75-100'
        ELSE '$100+'
    END as fare_bucket,
    SUM(number) as trip_count
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    AND AVG_Total_Amount > 0
    AND AVG_Total_Amount < 500  -- Filter outliers
GROUP BY 
    CASE 
        WHEN AVG_Total_Amount < 10 THEN '$0-10'
        WHEN AVG_Total_Amount < 20 THEN '$10-20'
        WHEN AVG_Total_Amount < 30 THEN '$20-30'
        WHEN AVG_Total_Amount < 40 THEN '$30-40'
        WHEN AVG_Total_Amount < 50 THEN '$40-50'
        WHEN AVG_Total_Amount < 75 THEN '$50-75'
        WHEN AVG_Total_Amount < 100 THEN '$75-100'
        ELSE '$100+'
    END
ORDER BY 
    CASE 
        WHEN AVG_Total_Amount < 10 THEN 1
        WHEN AVG_Total_Amount < 20 THEN 2
        WHEN AVG_Total_Amount < 30 THEN 3
        WHEN AVG_Total_Amount < 40 THEN 4
        WHEN AVG_Total_Amount < 50 THEN 5
        WHEN AVG_Total_Amount < 75 THEN 6
        WHEN AVG_Total_Amount < 100 THEN 7
        ELSE 8
    END;

-- Query 5.4: Tip Analysis
SELECT 
    taxi_type,
    CAST(SUM(tip_amount) AS DECIMAL(12,2)) as total_tips,
    CAST(SUM(tip_amount) / NULLIF(SUM(Fare_Amount), 0) * 100 AS DECIMAL(5,2)) as avg_tip_percentage,
    CAST(SUM(tip_amount) / NULLIF(SUM(number), 0) AS DECIMAL(8,2)) as avg_tip_per_trip
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
GROUP BY taxi_type;


-- ============================================
-- SECTION 6: TRIP DISTANCE ANALYSIS
-- ============================================

-- Query 6.1: Distance Distribution
SELECT 
    CASE 
        WHEN AVG_Trip_Distance < 1 THEN '0-1 mi'
        WHEN AVG_Trip_Distance < 2 THEN '1-2 mi'
        WHEN AVG_Trip_Distance < 3 THEN '2-3 mi'
        WHEN AVG_Trip_Distance < 5 THEN '3-5 mi'
        WHEN AVG_Trip_Distance < 10 THEN '5-10 mi'
        WHEN AVG_Trip_Distance < 20 THEN '10-20 mi'
        ELSE '20+ mi'
    END as distance_bucket,
    SUM(number) as trip_count,
    CAST(AVG(AVG_Total_Amount) AS DECIMAL(8,2)) as avg_fare
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    AND AVG_Trip_Distance > 0
    AND AVG_Trip_Distance < 100  -- Filter outliers
GROUP BY 
    CASE 
        WHEN AVG_Trip_Distance < 1 THEN '0-1 mi'
        WHEN AVG_Trip_Distance < 2 THEN '1-2 mi'
        WHEN AVG_Trip_Distance < 3 THEN '2-3 mi'
        WHEN AVG_Trip_Distance < 5 THEN '3-5 mi'
        WHEN AVG_Trip_Distance < 10 THEN '5-10 mi'
        WHEN AVG_Trip_Distance < 20 THEN '10-20 mi'
        ELSE '20+ mi'
    END
ORDER BY trip_count DESC;

-- Query 6.2: Average Distance by Hour
SELECT 
    CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
    CAST(SUM(Total_Trip_Distance) / NULLIF(SUM(number), 0) AS DECIMAL(8,2)) as avg_distance,
    SUM(number) as trip_count
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
GROUP BY SUBSTR(Pickup_Time, 12, 2)
ORDER BY hour_of_day;

-- Query 6.3: Distance vs Fare Correlation
SELECT 
    Pickup_Location,
    CAST(AVG(AVG_Trip_Distance) AS DECIMAL(8,2)) as avg_distance,
    CAST(AVG(AVG_Total_Amount) AS DECIMAL(8,2)) as avg_fare,
    SUM(number) as trip_count
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    AND AVG_Trip_Distance > 0
    AND AVG_Trip_Distance < 50
    AND AVG_Total_Amount > 0
    AND AVG_Total_Amount < 200
GROUP BY Pickup_Location
HAVING SUM(number) > 100  -- Only significant locations
ORDER BY trip_count DESC
LIMIT 100;


-- ============================================
-- SECTION 7: PASSENGER ANALYSIS
-- ============================================

-- Query 7.1: Average Passengers by Hour
SELECT 
    CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
    CAST(SUM(Total_Passenger_Count) / NULLIF(SUM(number), 0) AS DECIMAL(8,2)) as avg_passengers,
    SUM(number) as trip_count
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
GROUP BY SUBSTR(Pickup_Time, 12, 2)
ORDER BY hour_of_day;

-- Query 7.2: Passenger Count Distribution
SELECT 
    CAST(AVG_Passenger_Count AS INTEGER) as passenger_count,
    SUM(number) as trip_count,
    CAST(SUM(number) * 100.0 / SUM(SUM(number)) OVER () AS DECIMAL(5,2)) as percentage
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    AND AVG_Passenger_Count > 0
    AND AVG_Passenger_Count <= 6
GROUP BY CAST(AVG_Passenger_Count AS INTEGER)
ORDER BY passenger_count;


-- ============================================
-- SECTION 8: TAXI TYPE COMPARISON
-- ============================================

-- Query 8.1: Yellow vs Green Taxi Comparison
SELECT 
    taxi_type,
    SUM(number) as total_trips,
    CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as total_revenue,
    CAST(SUM(Total_Trip_Distance) AS DECIMAL(12,2)) as total_distance,
    CAST(SUM(Total_Amount) / NULLIF(SUM(number), 0) AS DECIMAL(8,2)) as avg_fare,
    CAST(SUM(Total_Trip_Distance) / NULLIF(SUM(number), 0) AS DECIMAL(8,2)) as avg_distance,
    CAST(SUM(Total_Passenger_Count) / NULLIF(SUM(number), 0) AS DECIMAL(8,2)) as avg_passengers
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
GROUP BY taxi_type;

-- Query 8.2: Market Share by Taxi Type
SELECT 
    taxi_type,
    SUM(number) as trip_count,
    CAST(SUM(number) * 100.0 / SUM(SUM(number)) OVER () AS DECIMAL(5,2)) as market_share_percentage
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
GROUP BY taxi_type;


-- ============================================
-- SECTION 9: MAP VISUALIZATION QUERIES
-- ============================================

-- Query 9.1: Geographic Data for Heatmap (Pickup Locations)
SELECT 
    z.LocationID,
    z.Zone,
    z.Borough,
    z.latitude,
    z.longitude,
    SUM(t.number) as total_trips,
    CAST(SUM(t.Total_Amount) AS DECIMAL(12,2)) as total_revenue,
    CAST(AVG(t.AVG_Trip_Distance) AS DECIMAL(8,2)) as avg_distance
FROM taxi_zones z
LEFT JOIN nyc_taxi_aggregated t ON z.LocationID = t.Pickup_Location
WHERE t.Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    AND z.latitude IS NOT NULL
    AND z.longitude IS NOT NULL
GROUP BY z.LocationID, z.Zone, z.Borough, z.latitude, z.longitude
HAVING SUM(t.number) > 0
ORDER BY total_trips DESC;

-- Query 9.2: Top Pickup Zones for Map (with size indicator)
SELECT 
    z.LocationID,
    z.Zone,
    z.Borough,
    z.latitude,
    z.longitude,
    SUM(t.number) as total_trips,
    CAST(LN(SUM(t.number) + 1) * 10 AS INTEGER) as marker_size  -- Logarithmic scale for marker size
FROM taxi_zones z
INNER JOIN nyc_taxi_aggregated t ON z.LocationID = t.Pickup_Location
WHERE t.Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    AND z.latitude IS NOT NULL
    AND z.longitude IS NOT NULL
GROUP BY z.LocationID, z.Zone, z.Borough, z.latitude, z.longitude
HAVING SUM(t.number) >= 100  -- Only show zones with significant activity
ORDER BY total_trips DESC
LIMIT 50;


-- ============================================
-- SECTION 10: ADVANCED ANALYTICS
-- ============================================

-- Query 10.1: Week-over-Week Growth
WITH current_week AS (
    SELECT 
        SUM(number) as trips,
        CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as revenue
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '7' DAY, '%Y-%m-%d %H')
),
previous_week AS (
    SELECT 
        SUM(number) as trips,
        CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as revenue
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '14' DAY, '%Y-%m-%d %H')
        AND Pickup_Time < DATE_FORMAT(CURRENT_DATE - INTERVAL '7' DAY, '%Y-%m-%d %H')
)
SELECT 
    c.trips as current_week_trips,
    p.trips as previous_week_trips,
    CAST((c.trips - p.trips) * 100.0 / NULLIF(p.trips, 0) AS DECIMAL(8,2)) as trips_growth_pct,
    c.revenue as current_week_revenue,
    p.revenue as previous_week_revenue,
    CAST((c.revenue - p.revenue) * 100.0 / NULLIF(p.revenue, 0) AS DECIMAL(8,2)) as revenue_growth_pct
FROM current_week c, previous_week p;

-- Query 10.2: Peak vs Off-Peak Analysis
SELECT 
    CASE 
        WHEN CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) BETWEEN 7 AND 9 THEN 'Morning Peak (7-9 AM)'
        WHEN CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) BETWEEN 17 AND 19 THEN 'Evening Peak (5-7 PM)'
        WHEN CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) BETWEEN 10 AND 16 THEN 'Midday (10 AM-4 PM)'
        WHEN CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) BETWEEN 20 AND 23 THEN 'Night (8-11 PM)'
        ELSE 'Late Night/Early Morning'
    END as time_period,
    SUM(number) as total_trips,
    CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as total_revenue,
    CAST(AVG(AVG_Total_Amount) AS DECIMAL(8,2)) as avg_fare,
    CAST(AVG(AVG_Trip_Distance) AS DECIMAL(8,2)) as avg_distance
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
GROUP BY 
    CASE 
        WHEN CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) BETWEEN 7 AND 9 THEN 'Morning Peak (7-9 AM)'
        WHEN CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) BETWEEN 17 AND 19 THEN 'Evening Peak (5-7 PM)'
        WHEN CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) BETWEEN 10 AND 16 THEN 'Midday (10 AM-4 PM)'
        WHEN CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) BETWEEN 20 AND 23 THEN 'Night (8-11 PM)'
        ELSE 'Late Night/Early Morning'
    END
ORDER BY total_trips DESC;

-- Query 10.3: Revenue per Mile Analysis
SELECT 
    taxi_type,
    CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
    CAST(SUM(Total_Amount) / NULLIF(SUM(Total_Trip_Distance), 0) AS DECIMAL(8,2)) as revenue_per_mile,
    SUM(number) as trip_count
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    AND Total_Trip_Distance > 0
GROUP BY taxi_type, SUBSTR(Pickup_Time, 12, 2)
ORDER BY taxi_type, hour_of_day;

-- ============================================
-- NOTES:
-- ============================================
-- 1. Replace 'nyc_taxi_aggregated' with your actual table name
-- 2. Replace 'taxi_zones' with your actual zone lookup table name
-- 3. Adjust date ranges as needed (currently using last 30 days for most queries)
-- 4. Add WHERE clauses to filter by taxi_type if needed
-- 5. Some queries assume the existence of a taxi_zones table with LocationID, Zone, Borough, latitude, and longitude
-- 6. For map visualizations, ensure you have valid latitude/longitude data
-- 7. All monetary values are cast to DECIMAL(12,2) for proper formatting
-- 8. Outlier filtering is applied where appropriate (e.g., distance < 100 miles, fare < $500)

