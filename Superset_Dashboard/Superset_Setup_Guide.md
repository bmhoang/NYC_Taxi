# NYC Taxi Data Visualization - Apache Superset Dashboard Guide

## Overview
This guide helps you create an Apache Superset dashboard to visualize NYC Taxi data stored in Trino, following the same analytical goals as the existing Qlik Sense and Tableau dashboards.

## Prerequisites
- Apache Superset installed and running
- NYC Taxi data available in Trino
- Trino connection details (host, port, catalog, schema)

## Table of Contents
1. [Connecting Superset to Trino](#connecting-superset-to-trino)
2. [Data Structure Assumptions](#data-structure-assumptions)
3. [Dashboard Design](#dashboard-design)
4. [Chart Configurations](#chart-configurations)
5. [SQL Queries for Visualizations](#sql-queries-for-visualizations)

---

## Connecting Superset to Trino

### Step 1: Install Trino Python Driver
```bash
pip install trino
```

### Step 2: Add Trino Database Connection in Superset
1. Navigate to **Data > Databases** in Superset
2. Click **+ Database**
3. Select **Trino** from the supported databases
4. Configure the connection string:
```
trino://username@host:port/catalog/schema
```

Example:
```
trino://admin@localhost:8080/hive/nyc_taxi
```

### Step 3: Test Connection
Click "Test Connection" to verify the setup.

---

## Data Structure Assumptions

Based on the PySparkCalculation.py script, assuming your Trino table has the following structure:

**Table: `nyc_taxi_aggregated`**
```sql
Pickup_Time              VARCHAR    -- Format: 'YYYY-MM-DD HH'
Pickup_Location          INT        -- PULocationID
Total_Amount             DOUBLE
AVG_Total_Amount         DOUBLE
Total_Trip_Distance      DOUBLE
AVG_Trip_Distance        DOUBLE
Total_Passenger_Count    INT
AVG_Passenger_Count      DOUBLE
Fare_Amount              DOUBLE
Extra                    DOUBLE
tip_amount               DOUBLE
tolls_amount             DOUBLE
number                   INT        -- Count of trips
taxi_type                VARCHAR    -- 'yellow' or 'green'
```

**Optional Table: `taxi_zones`** (for map visualization)
```sql
LocationID               INT
Borough                  VARCHAR
Zone                     VARCHAR
service_zone             VARCHAR
latitude                 DOUBLE
longitude                DOUBLE
```

---

## Dashboard Design

Create a dashboard with 4 main sections (similar to Qlik Sense layout):

### 1. **Summary Dashboard**
- Key Performance Indicators (KPIs)
- Time series trends
- Taxi type comparison

### 2. **Amount Details Dashboard**
- Fare breakdown by components
- Average fare analysis
- Payment patterns

### 3. **Trip Details Dashboard**
- Trip distance analysis
- Passenger count distribution
- Hourly trip patterns

### 4. **Map Dashboard**
- Geographic heat map of pickup locations
- Top pickup zones
- Borough-level analysis

---

## Chart Configurations

### Dashboard 1: Summary

#### Chart 1.1: Key Metrics (Big Number with Trendline)
**Metrics to Display:**
- Total Trips
- Total Revenue
- Average Fare
- Total Miles

**Chart Type:** Big Number with Trendline
**Time Column:** Pickup_Time
**Metric:** See queries below

#### Chart 1.2: Trips Over Time
**Chart Type:** Line Chart
**X-Axis:** Pickup_Time (hourly)
**Y-Axis:** Number of trips
**Group By:** taxi_type (yellow vs green)

#### Chart 1.3: Revenue Over Time
**Chart Type:** Area Chart
**X-Axis:** Pickup_Time
**Y-Axis:** Total_Amount
**Group By:** taxi_type

#### Chart 1.4: Daily Pattern (Busy Hours)
**Chart Type:** Bar Chart
**X-Axis:** Hour of day (0-23)
**Y-Axis:** Total trips
**Group By:** taxi_type

---

### Dashboard 2: Amount Details

#### Chart 2.1: Fare Components Breakdown
**Chart Type:** Stacked Bar Chart
**Categories:** Fare_Amount, Extra, tip_amount, tolls_amount
**Metric:** SUM of each component

#### Chart 2.2: Average Fare by Hour
**Chart Type:** Line Chart
**X-Axis:** Hour of day
**Y-Axis:** AVG_Total_Amount

#### Chart 2.3: Fare Distribution
**Chart Type:** Histogram
**X-Axis:** Total_Amount (binned)
**Y-Axis:** Frequency

#### Chart 2.4: Tip Percentage Analysis
**Chart Type:** Box Plot
**Y-Axis:** (tip_amount / Fare_Amount * 100) as tip_percentage

---

### Dashboard 3: Trip Details

#### Chart 3.1: Trip Distance Distribution
**Chart Type:** Histogram
**X-Axis:** AVG_Trip_Distance (binned)
**Y-Axis:** Number of trips

#### Chart 3.2: Average Passengers by Hour
**Chart Type:** Bar Chart
**X-Axis:** Hour of day
**Y-Axis:** AVG_Passenger_Count

#### Chart 3.3: Distance vs Fare Scatter
**Chart Type:** Scatter Plot
**X-Axis:** Total_Trip_Distance
**Y-Axis:** Total_Amount
**Size:** number (trip count)

#### Chart 3.4: Top 10 Busiest Pickup Locations
**Chart Type:** Bar Chart (Horizontal)
**X-Axis:** Number of trips
**Y-Axis:** Pickup_Location (with zone name if joined)

---

### Dashboard 4: Map Visualization

#### Chart 4.1: Pickup Location Heat Map
**Chart Type:** Deck.gl Scatterplot
**Longitude:** longitude (from taxi_zones)
**Latitude:** latitude (from taxi_zones)
**Weight:** number (trip count)

#### Chart 4.2: Borough Comparison
**Chart Type:** Pie Chart
**Dimension:** Borough
**Metric:** Total trips

---

## SQL Queries for Visualizations

### Query 1: Total Trips KPI
```sql
SELECT 
    SUM(number) as total_trips
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d')
```

### Query 2: Total Revenue KPI
```sql
SELECT 
    ROUND(SUM(Total_Amount), 2) as total_revenue
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d')
```

### Query 3: Average Fare KPI
```sql
SELECT 
    ROUND(SUM(Total_Amount) / SUM(number), 2) as avg_fare
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d')
```

### Query 4: Total Distance KPI
```sql
SELECT 
    ROUND(SUM(Total_Trip_Distance), 2) as total_miles
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d')
```

### Query 5: Trips Over Time (Hourly)
```sql
SELECT 
    Pickup_Time,
    taxi_type,
    SUM(number) as trip_count
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d')
GROUP BY Pickup_Time, taxi_type
ORDER BY Pickup_Time
```

### Query 6: Busy Hours Analysis (Daily Pattern)
```sql
SELECT 
    CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
    taxi_type,
    SUM(number) as total_trips,
    ROUND(SUM(Total_Amount), 2) as total_revenue
FROM nyc_taxi_aggregated
GROUP BY SUBSTR(Pickup_Time, 12, 2), taxi_type
ORDER BY hour_of_day
```

### Query 7: Fare Components Breakdown
```sql
SELECT 
    'Fare Amount' as component,
    SUM(Fare_Amount) as amount
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d')

UNION ALL

SELECT 
    'Extra' as component,
    SUM(Extra) as amount
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d')

UNION ALL

SELECT 
    'Tips' as component,
    SUM(tip_amount) as amount
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d')

UNION ALL

SELECT 
    'Tolls' as component,
    SUM(tolls_amount) as amount
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d')
```

### Query 8: Top 10 Busiest Pickup Locations
```sql
SELECT 
    t.Pickup_Location,
    z.Zone as location_name,
    z.Borough,
    SUM(t.number) as total_trips,
    ROUND(SUM(t.Total_Amount), 2) as total_revenue
FROM nyc_taxi_aggregated t
LEFT JOIN taxi_zones z ON t.Pickup_Location = z.LocationID
GROUP BY t.Pickup_Location, z.Zone, z.Borough
ORDER BY total_trips DESC
LIMIT 10
```

### Query 9: Trip Distance vs Fare (for Scatter Plot)
```sql
SELECT 
    Pickup_Location,
    AVG_Trip_Distance as avg_distance,
    AVG_Total_Amount as avg_fare,
    SUM(number) as trip_count
FROM nyc_taxi_aggregated
WHERE AVG_Trip_Distance > 0 AND AVG_Trip_Distance < 50  -- Filter outliers
GROUP BY Pickup_Location, AVG_Trip_Distance, AVG_Total_Amount
HAVING SUM(number) > 10  -- Only locations with significant trips
```

### Query 10: Hourly Patterns by Day of Week
```sql
SELECT 
    CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
    CASE 
        WHEN day_of_week(DATE(Pickup_Time)) = 1 THEN 'Monday'
        WHEN day_of_week(DATE(Pickup_Time)) = 2 THEN 'Tuesday'
        WHEN day_of_week(DATE(Pickup_Time)) = 3 THEN 'Wednesday'
        WHEN day_of_week(DATE(Pickup_Time)) = 4 THEN 'Thursday'
        WHEN day_of_week(DATE(Pickup_Time)) = 5 THEN 'Friday'
        WHEN day_of_week(DATE(Pickup_Time)) = 6 THEN 'Saturday'
        WHEN day_of_week(DATE(Pickup_Time)) = 7 THEN 'Sunday'
    END as day_name,
    SUM(number) as trip_count
FROM nyc_taxi_aggregated
GROUP BY SUBSTR(Pickup_Time, 12, 2), day_of_week(DATE(Pickup_Time))
ORDER BY day_of_week(DATE(Pickup_Time)), hour_of_day
```

### Query 11: Geographic Data for Map (requires join with taxi_zones)
```sql
SELECT 
    z.LocationID,
    z.Zone,
    z.Borough,
    z.latitude,
    z.longitude,
    SUM(t.number) as total_trips,
    SUM(t.Total_Amount) as total_revenue,
    AVG(t.AVG_Trip_Distance) as avg_distance
FROM taxi_zones z
LEFT JOIN nyc_taxi_aggregated t ON z.LocationID = t.Pickup_Location
WHERE t.Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d')
GROUP BY z.LocationID, z.Zone, z.Borough, z.latitude, z.longitude
HAVING SUM(t.number) > 0
```

### Query 12: Revenue Breakdown by Taxi Type
```sql
SELECT 
    taxi_type,
    SUM(number) as total_trips,
    ROUND(SUM(Total_Amount), 2) as total_revenue,
    ROUND(SUM(Fare_Amount), 2) as base_fare,
    ROUND(SUM(tip_amount), 2) as total_tips,
    ROUND(SUM(Total_Amount) / SUM(number), 2) as avg_fare_per_trip
FROM nyc_taxi_aggregated
GROUP BY taxi_type
```

---

## Dashboard Filters

Add the following filters to your dashboard for interactivity:

### Filter 1: Date Range
- **Column:** Pickup_Time
- **Filter Type:** Time Range
- **Default:** Last 30 days

### Filter 2: Taxi Type
- **Column:** taxi_type
- **Filter Type:** Filter Select
- **Options:** Yellow, Green, All

### Filter 3: Borough (if taxi_zones table is available)
- **Column:** Borough (from joined table)
- **Filter Type:** Filter Select
- **Options:** Manhattan, Brooklyn, Queens, Bronx, Staten Island, All

### Filter 4: Hour of Day
- **Column:** Hour extracted from Pickup_Time
- **Filter Type:** Numerical Range
- **Range:** 0-23

---

## Step-by-Step Dashboard Creation

### Step 1: Create Dataset
1. Go to **Data > Datasets**
2. Click **+ Dataset**
3. Select your Trino database
4. Select schema: `nyc_taxi` (or your schema name)
5. Select table: `nyc_taxi_aggregated`
6. Click **Add**

### Step 2: Create Virtual Metrics
In the dataset configuration, add calculated columns:
- **Hour of Day:** `CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER)`
- **Date Only:** `DATE(Pickup_Time)`
- **Tip Percentage:** `(tip_amount / NULLIF(Fare_Amount, 0)) * 100`

### Step 3: Create Charts
1. Go to **Charts** and click **+ Chart**
2. Select your dataset
3. Choose chart type based on the configurations above
4. Configure metrics, dimensions, and filters
5. Save each chart with a descriptive name

### Step 4: Assemble Dashboard
1. Go to **Dashboards** and click **+ Dashboard**
2. Name it "NYC Taxi Analytics Dashboard"
3. Drag and drop your saved charts onto the dashboard
4. Arrange them in a logical layout (use tabs for different sections)
5. Add dashboard-level filters
6. Save and publish

---

## Best Practices

### Performance Optimization
1. **Use Materialized Views:** Pre-aggregate data in Trino for faster queries
2. **Add Indexes:** Ensure Pickup_Time and Pickup_Location are indexed
3. **Set Row Limits:** Limit results to 10,000 rows for scatter plots and detailed views
4. **Use Caching:** Enable Superset's query result caching (default: 1 hour)

### Visual Design
1. **Color Scheme:** Use consistent colors (e.g., yellow for yellow cabs, green for green cabs)
2. **Layout:** Group related charts together
3. **Tooltips:** Enable detailed tooltips for all charts
4. **Labels:** Add clear axis labels and titles
5. **Mobile Responsive:** Test dashboard on different screen sizes

### Data Quality
1. **Filter Outliers:** Exclude trips with distance > 100 miles or fare > $500
2. **Handle Nulls:** Use `NULLIF` and `COALESCE` in queries
3. **Data Validation:** Add data quality metrics to the dashboard

---

## Advanced Features

### 1. Time Comparison
Enable time comparison to see week-over-week or month-over-month changes:
```sql
-- Current week vs previous week
WITH current_week AS (
    SELECT SUM(number) as trips
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '7' DAY, '%Y-%m-%d')
),
previous_week AS (
    SELECT SUM(number) as trips
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '14' DAY, '%Y-%m-%d')
    AND Pickup_Time < DATE_FORMAT(CURRENT_DATE - INTERVAL '7' DAY, '%Y-%m-%d')
)
SELECT 
    c.trips as current_trips,
    p.trips as previous_trips,
    ROUND(((c.trips - p.trips) * 100.0 / p.trips), 2) as percent_change
FROM current_week c, previous_week p
```

### 2. Predictive Analytics
If you have a machine learning model, integrate predictions:
- Predicted busy hours
- Estimated revenue forecasts
- Demand predictions by zone

### 3. Alerts
Set up alerts for:
- Revenue drops below threshold
- Unusual trip patterns
- Data pipeline failures

---

## Troubleshooting

### Issue: Slow Query Performance
**Solution:** 
- Add WHERE clauses to limit date ranges
- Create aggregated materialized views in Trino
- Reduce the number of rows returned

### Issue: Map Not Showing Points
**Solution:**
- Verify latitude/longitude columns are DOUBLE type
- Check for NULL values in coordinate columns
- Ensure coordinates are in decimal degrees (not DMS)

### Issue: Connection Timeout
**Solution:**
- Increase Trino query timeout settings
- Check network connectivity
- Verify Trino cluster is running

---

## Additional Resources

- **Apache Superset Documentation:** https://superset.apache.org/docs/intro
- **Trino Documentation:** https://trino.io/docs/current/
- **NYC Taxi Data Dictionary:** See PDFs in project root
- **Original Dashboard Reference:** See screenshots in `QlikSense_Dashboard/` and `Tableau_Dashboard/`

---

## Next Steps

1. ✅ Set up Trino connection in Superset
2. ✅ Create dataset from nyc_taxi_aggregated table
3. ✅ Build KPI charts (4 big number charts)
4. ✅ Create time series charts (trips and revenue over time)
5. ✅ Build busy hours analysis chart
6. ✅ Create fare breakdown visualizations
7. ✅ Add trip details charts
8. ✅ Configure map visualization (requires taxi_zones table)
9. ✅ Assemble all charts into dashboard
10. ✅ Add filters and publish

---

**Author:** Based on NYC Taxi project by Sekyung Na  
**Date:** October 2025  
**Version:** 1.0

