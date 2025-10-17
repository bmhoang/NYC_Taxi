# Advanced & Innovative Chart Ideas for NYC Taxi Dashboard

Beyond the standard charts, here are innovative visualizations that can extract deeper insights from your NYC Taxi data.

## 📊 Table of Contents
1. [Efficiency & Profitability Charts](#efficiency--profitability-charts)
2. [Predictive & Forecasting Charts](#predictive--forecasting-charts)
3. [Anomaly Detection Charts](#anomaly-detection-charts)
4. [Network Flow Visualizations](#network-flow-visualizations)
5. [Advanced Comparison Charts](#advanced-comparison-charts)
6. [Optimization & Strategy Charts](#optimization--strategy-charts)
7. [Real-time Monitoring Charts](#real-time-monitoring-charts)
8. [Behavioral Pattern Charts](#behavioral-pattern-charts)

---

## Efficiency & Profitability Charts

### 1. Revenue Per Minute by Hour & Location
**Insight**: Identify which hours and locations generate the most revenue per time unit, not just total revenue.

**SQL Query**:
```sql
SELECT 
    Pickup_Location,
    CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
    -- Assuming average trip takes 20 minutes (adjust based on your data)
    CAST(SUM(Total_Amount) / NULLIF(SUM(number), 0) / 20.0 AS DECIMAL(8,2)) as revenue_per_minute,
    SUM(number) as trip_count,
    CAST(AVG(AVG_Total_Amount) AS DECIMAL(8,2)) as avg_fare
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
GROUP BY Pickup_Location, SUBSTR(Pickup_Time, 12, 2)
HAVING SUM(number) > 50
ORDER BY revenue_per_minute DESC
LIMIT 20
```

**Chart Type**: Heatmap (Hour x Location, color = revenue/min)
**Value**: Shows drivers where to maximize earnings per time invested


### 2. Fare Efficiency Score (Distance-Adjusted Revenue)
**Insight**: Which zones offer best fare per mile ratio?

**SQL Query**:
```sql
SELECT 
    Pickup_Location,
    taxi_type,
    CAST(SUM(Total_Amount) / NULLIF(SUM(Total_Trip_Distance), 0) AS DECIMAL(8,2)) as revenue_per_mile,
    CAST(SUM(tip_amount) / NULLIF(SUM(Total_Trip_Distance), 0) AS DECIMAL(8,2)) as tip_per_mile,
    SUM(number) as trip_count,
    CAST(AVG(AVG_Trip_Distance) AS DECIMAL(8,2)) as avg_distance
FROM nyc_taxi_aggregated
WHERE Total_Trip_Distance > 0.5  -- Filter very short trips
    AND Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
GROUP BY Pickup_Location, taxi_type
HAVING SUM(number) > 100
ORDER BY revenue_per_mile DESC
LIMIT 30
```

**Chart Type**: Scatter Plot (X=avg_distance, Y=revenue_per_mile, Size=trip_count)
**Value**: Identifies sweet spot zones with optimal distance and fare


### 3. Capacity Utilization Index
**Insight**: Are taxis being efficiently used by passenger count?

**SQL Query**:
```sql
SELECT 
    CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
    CASE 
        WHEN DAY_OF_WEEK(DATE(Pickup_Time)) IN (6, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END as day_type,
    -- Assuming max capacity is 4 passengers
    CAST(SUM(Total_Passenger_Count) / (SUM(number) * 4.0) * 100 AS DECIMAL(5,2)) as capacity_utilization_pct,
    CAST(SUM(Total_Passenger_Count) / NULLIF(SUM(number), 0) AS DECIMAL(8,2)) as avg_passengers,
    SUM(number) as trip_count
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
GROUP BY SUBSTR(Pickup_Time, 12, 2), 
    CASE 
        WHEN DAY_OF_WEEK(DATE(Pickup_Time)) IN (6, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END
ORDER BY hour_of_day
```

**Chart Type**: Dual-axis Line Chart (Capacity % + Trip Count)
**Value**: Shows opportunity for ride-sharing or demand for larger vehicles

---

## Predictive & Forecasting Charts

### 4. Demand Forecast by Hour (Next Week Prediction)
**Insight**: Use historical patterns to predict future demand

**SQL Query** (7-day moving average as simple forecast):
```sql
WITH hourly_avg AS (
    SELECT 
        CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
        DAY_OF_WEEK(DATE(Pickup_Time)) as day_of_week,
        AVG(number) as avg_trips_per_location,
        STDDEV(number) as stddev_trips
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '28' DAY, '%Y-%m-%d %H')
        AND Pickup_Time < DATE_FORMAT(CURRENT_DATE - INTERVAL '7' DAY, '%Y-%m-%d %H')
    GROUP BY SUBSTR(Pickup_Time, 12, 2), DAY_OF_WEEK(DATE(Pickup_Time))
)
SELECT 
    hour_of_day,
    day_of_week,
    CAST(avg_trips_per_location * 260 AS INTEGER) as forecasted_total_trips,  -- 260 zones
    CAST(avg_trips_per_location * 260 - stddev_trips * 260 AS INTEGER) as lower_bound,
    CAST(avg_trips_per_location * 260 + stddev_trips * 260 AS INTEGER) as upper_bound
FROM hourly_avg
ORDER BY day_of_week, hour_of_day
```

**Chart Type**: Line Chart with Confidence Bands
**Value**: Helps with resource planning and driver scheduling


### 5. Seasonality & Trend Decomposition
**Insight**: Separate long-term trends from seasonal patterns

**SQL Query**:
```sql
WITH monthly_data AS (
    SELECT 
        DATE_TRUNC('month', DATE(Pickup_Time)) as month,
        SUM(number) as total_trips,
        CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as total_revenue
    FROM nyc_taxi_aggregated
    GROUP BY DATE_TRUNC('month', DATE(Pickup_Time))
),
with_lag AS (
    SELECT 
        month,
        total_trips,
        total_revenue,
        LAG(total_trips, 1) OVER (ORDER BY month) as prev_month_trips,
        LAG(total_trips, 12) OVER (ORDER BY month) as prev_year_trips
    FROM monthly_data
)
SELECT 
    month,
    total_trips,
    prev_month_trips,
    prev_year_trips,
    CAST((total_trips - prev_month_trips) * 100.0 / NULLIF(prev_month_trips, 0) AS DECIMAL(8,2)) as mom_growth_pct,
    CAST((total_trips - prev_year_trips) * 100.0 / NULLIF(prev_year_trips, 0) AS DECIMAL(8,2)) as yoy_growth_pct
FROM with_lag
ORDER BY month
```

**Chart Type**: Multiple Time Series with Trendlines
**Value**: Understand long-term business health vs seasonal fluctuations

---

## Anomaly Detection Charts

### 6. Outlier Detection Dashboard
**Insight**: Identify unusual patterns that might indicate data quality issues or special events

**SQL Query**:
```sql
WITH stats AS (
    SELECT 
        AVG(number) as mean_trips,
        STDDEV(number) as stddev_trips,
        AVG(AVG_Total_Amount) as mean_fare,
        STDDEV(AVG_Total_Amount) as stddev_fare
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
)
SELECT 
    t.Pickup_Time,
    t.Pickup_Location,
    t.number as trips,
    t.AVG_Total_Amount as avg_fare,
    CASE 
        WHEN t.number > s.mean_trips + 3 * s.stddev_trips THEN 'High Trip Outlier'
        WHEN t.number < s.mean_trips - 3 * s.stddev_trips THEN 'Low Trip Outlier'
        WHEN t.AVG_Total_Amount > s.mean_fare + 3 * s.stddev_fare THEN 'High Fare Outlier'
        WHEN t.AVG_Total_Amount < s.mean_fare - 3 * s.stddev_fare THEN 'Low Fare Outlier'
        ELSE 'Normal'
    END as outlier_type,
    CAST((t.number - s.mean_trips) / NULLIF(s.stddev_trips, 0) AS DECIMAL(8,2)) as z_score_trips,
    CAST((t.AVG_Total_Amount - s.mean_fare) / NULLIF(s.stddev_fare, 0) AS DECIMAL(8,2)) as z_score_fare
FROM nyc_taxi_aggregated t
CROSS JOIN stats s
WHERE t.Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '7' DAY, '%Y-%m-%d %H')
    AND (
        t.number > s.mean_trips + 3 * s.stddev_trips OR
        t.number < s.mean_trips - 3 * s.stddev_trips OR
        t.AVG_Total_Amount > s.mean_fare + 3 * s.stddev_fare OR
        t.AVG_Total_Amount < s.mean_fare - 3 * s.stddev_fare
    )
ORDER BY ABS((t.number - s.mean_trips) / NULLIF(s.stddev_trips, 0)) DESC
LIMIT 50
```

**Chart Type**: Scatter Plot with Z-score coloring + Table of anomalies
**Value**: Quickly spot data issues, special events, or emerging trends


### 7. Variance Stability Chart
**Insight**: Monitor if trip patterns are becoming more or less predictable

**SQL Query**:
```sql
SELECT 
    DATE_TRUNC('week', DATE(Pickup_Time)) as week,
    Pickup_Location,
    CAST(AVG(number) AS DECIMAL(8,2)) as avg_trips,
    CAST(STDDEV(number) AS DECIMAL(8,2)) as stddev_trips,
    CAST(STDDEV(number) / NULLIF(AVG(number), 0) AS DECIMAL(8,4)) as coefficient_of_variation
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '90' DAY, '%Y-%m-%d %H')
GROUP BY DATE_TRUNC('week', DATE(Pickup_Time)), Pickup_Location
HAVING AVG(number) > 10
ORDER BY week, coefficient_of_variation DESC
```

**Chart Type**: Time Series of Coefficient of Variation
**Value**: Helps understand predictability of demand for resource planning

---

## Network Flow Visualizations

### 8. Temporal Flow Patterns (Pickup Migration Throughout Day)
**Insight**: How does pickup activity shift geographically through the day?

**SQL Query**:
```sql
WITH location_ranks AS (
    SELECT 
        CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
        Pickup_Location,
        SUM(number) as trips,
        ROW_NUMBER() OVER (PARTITION BY SUBSTR(Pickup_Time, 12, 2) ORDER BY SUM(number) DESC) as rank
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    GROUP BY SUBSTR(Pickup_Time, 12, 2), Pickup_Location
)
SELECT 
    hour_of_day,
    Pickup_Location,
    trips,
    rank
FROM location_ranks
WHERE rank <= 10
ORDER BY hour_of_day, rank
```

**Chart Type**: Bump Chart / Ranking Evolution
**Value**: Shows how top locations change throughout the day


### 9. Concentration Index (Market Dominance)
**Insight**: How concentrated is taxi demand? (Pareto analysis)

**SQL Query**:
```sql
WITH location_totals AS (
    SELECT 
        Pickup_Location,
        SUM(number) as total_trips,
        CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as total_revenue
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    GROUP BY Pickup_Location
),
ranked AS (
    SELECT 
        Pickup_Location,
        total_trips,
        total_revenue,
        SUM(total_trips) OVER () as overall_trips,
        SUM(total_revenue) OVER () as overall_revenue,
        ROW_NUMBER() OVER (ORDER BY total_trips DESC) as rank,
        SUM(total_trips) OVER (ORDER BY total_trips DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) as cumulative_trips
    FROM location_totals
)
SELECT 
    rank,
    Pickup_Location,
    total_trips,
    CAST(total_trips * 100.0 / overall_trips AS DECIMAL(5,2)) as pct_of_total,
    CAST(cumulative_trips * 100.0 / overall_trips AS DECIMAL(5,2)) as cumulative_pct
FROM ranked
ORDER BY rank
LIMIT 100
```

**Chart Type**: Pareto Chart (Bar + Cumulative Line)
**Value**: Classic 80/20 analysis - do 20% of locations drive 80% of trips?

---

## Advanced Comparison Charts

### 10. Yellow vs Green Competitive Analysis by Territory
**Insight**: Where do yellow and green cabs compete directly?

**SQL Query**:
```sql
WITH taxi_comparison AS (
    SELECT 
        Pickup_Location,
        SUM(CASE WHEN taxi_type = 'yellow' THEN number ELSE 0 END) as yellow_trips,
        SUM(CASE WHEN taxi_type = 'green' THEN number ELSE 0 END) as green_trips,
        SUM(CASE WHEN taxi_type = 'yellow' THEN Total_Amount ELSE 0 END) as yellow_revenue,
        SUM(CASE WHEN taxi_type = 'green' THEN Total_Amount ELSE 0 END) as green_revenue
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    GROUP BY Pickup_Location
    HAVING yellow_trips > 0 AND green_trips > 0  -- Only contested zones
)
SELECT 
    Pickup_Location,
    yellow_trips,
    green_trips,
    yellow_trips + green_trips as total_trips,
    CAST(yellow_trips * 100.0 / (yellow_trips + green_trips) AS DECIMAL(5,2)) as yellow_market_share,
    CAST(green_trips * 100.0 / (yellow_trips + green_trips) AS DECIMAL(5,2)) as green_market_share,
    CAST(yellow_revenue AS DECIMAL(12,2)) as yellow_revenue,
    CAST(green_revenue AS DECIMAL(12,2)) as green_revenue,
    CASE 
        WHEN yellow_trips > green_trips * 3 THEN 'Yellow Dominated'
        WHEN green_trips > yellow_trips * 3 THEN 'Green Dominated'
        ELSE 'Competitive'
    END as market_status
FROM taxi_comparison
ORDER BY total_trips DESC
LIMIT 50
```

**Chart Type**: Bubble Chart (X=yellow_trips, Y=green_trips, Size=total_revenue, Color=market_status)
**Value**: Strategic insights for taxi companies on market competition


### 11. Profitability Matrix (BCG-style)
**Insight**: Classify zones by growth rate and trip volume (Stars, Cash Cows, Question Marks, Dogs)

**SQL Query**:
```sql
WITH current_period AS (
    SELECT 
        Pickup_Location,
        SUM(number) as current_trips
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    GROUP BY Pickup_Location
),
previous_period AS (
    SELECT 
        Pickup_Location,
        SUM(number) as previous_trips
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '60' DAY, '%Y-%m-%d %H')
        AND Pickup_Time < DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    GROUP BY Pickup_Location
)
SELECT 
    c.Pickup_Location,
    c.current_trips,
    p.previous_trips,
    CAST((c.current_trips - p.previous_trips) * 100.0 / NULLIF(p.previous_trips, 0) AS DECIMAL(8,2)) as growth_rate,
    CASE 
        WHEN c.current_trips >= (SELECT AVG(current_trips) FROM current_period) 
            AND (c.current_trips - p.previous_trips) * 100.0 / NULLIF(p.previous_trips, 0) >= 
                (SELECT AVG((c2.current_trips - p2.previous_trips) * 100.0 / NULLIF(p2.previous_trips, 0)) 
                 FROM current_period c2 JOIN previous_period p2 ON c2.Pickup_Location = p2.Pickup_Location)
            THEN 'Star (High Growth, High Volume)'
        WHEN c.current_trips >= (SELECT AVG(current_trips) FROM current_period)
            THEN 'Cash Cow (Low Growth, High Volume)'
        WHEN (c.current_trips - p.previous_trips) * 100.0 / NULLIF(p.previous_trips, 0) >= 
                (SELECT AVG((c2.current_trips - p2.previous_trips) * 100.0 / NULLIF(p2.previous_trips, 0)) 
                 FROM current_period c2 JOIN previous_period p2 ON c2.Pickup_Location = p2.Pickup_Location)
            THEN 'Question Mark (High Growth, Low Volume)'
        ELSE 'Dog (Low Growth, Low Volume)'
    END as category
FROM current_period c
JOIN previous_period p ON c.Pickup_Location = p.Pickup_Location
WHERE p.previous_trips > 0
ORDER BY c.current_trips DESC
```

**Chart Type**: Quadrant Scatter Plot (X=volume, Y=growth, Color=category)
**Value**: Strategic location portfolio analysis

---

## Optimization & Strategy Charts

### 12. Idle Time Minimization Map
**Insight**: Which zones have shortest gaps between trips (continuous demand)?

**SQL Query**:
```sql
WITH hourly_intensity AS (
    SELECT 
        Pickup_Location,
        CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
        SUM(number) as trips_per_hour,
        COUNT(DISTINCT DATE(Pickup_Time)) as days_observed
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    GROUP BY Pickup_Location, SUBSTR(Pickup_Time, 12, 2)
)
SELECT 
    Pickup_Location,
    hour_of_day,
    CAST(trips_per_hour / NULLIF(days_observed, 0) AS DECIMAL(8,2)) as avg_trips_per_hour,
    -- Assuming 60 minutes / avg trips = avg wait time between pickups
    CAST(60.0 / NULLIF(trips_per_hour / NULLIF(days_observed, 0), 0) AS DECIMAL(8,2)) as estimated_wait_minutes,
    days_observed
FROM hourly_intensity
WHERE trips_per_hour / NULLIF(days_observed, 0) >= 5  -- At least 5 trips/hour on average
ORDER BY estimated_wait_minutes ASC
LIMIT 50
```

**Chart Type**: Heatmap (Location x Hour, Color=wait_time)
**Value**: Drivers can position themselves in zones with minimal idle time


### 13. Optimal Shift Analysis
**Insight**: Which 8-hour shift windows are most profitable?

**SQL Query**:
```sql
WITH hourly_revenue AS (
    SELECT 
        CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
        CAST(SUM(Total_Amount) / COUNT(DISTINCT DATE(Pickup_Time)) AS DECIMAL(12,2)) as avg_daily_revenue,
        CAST(SUM(number) / COUNT(DISTINCT DATE(Pickup_Time)) AS DECIMAL(8,2)) as avg_daily_trips
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    GROUP BY SUBSTR(Pickup_Time, 12, 2)
)
SELECT 
    start_hour,
    start_hour + 8 as end_hour,
    CAST(SUM(avg_daily_revenue) AS DECIMAL(12,2)) as shift_revenue,
    CAST(SUM(avg_daily_trips) AS DECIMAL(8,2)) as shift_trips,
    CAST(SUM(avg_daily_revenue) / 8.0 AS DECIMAL(8,2)) as revenue_per_hour
FROM (
    SELECT 
        h1.hour_of_day as start_hour,
        h2.hour_of_day,
        h2.avg_daily_revenue,
        h2.avg_daily_trips
    FROM hourly_revenue h1
    CROSS JOIN hourly_revenue h2
    WHERE h2.hour_of_day >= h1.hour_of_day 
        AND h2.hour_of_day < (h1.hour_of_day + 8)
) shifts
GROUP BY start_hour
ORDER BY shift_revenue DESC
```

**Chart Type**: Bar Chart with Hour Ranges
**Value**: Helps drivers choose optimal working hours


### 14. Tip Yield Optimization
**Insight**: When and where do customers tip best (relative to fare)?

**SQL Query**:
```sql
SELECT 
    Pickup_Location,
    CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
    CASE 
        WHEN DAY_OF_WEEK(DATE(Pickup_Time)) IN (6, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END as day_type,
    CAST(SUM(tip_amount) / NULLIF(SUM(Fare_Amount), 0) * 100 AS DECIMAL(5,2)) as avg_tip_percentage,
    CAST(SUM(tip_amount) / NULLIF(SUM(number), 0) AS DECIMAL(8,2)) as avg_tip_per_trip,
    SUM(number) as trip_count,
    CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as total_revenue
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    AND Fare_Amount > 0
GROUP BY Pickup_Location, SUBSTR(Pickup_Time, 12, 2),
    CASE 
        WHEN DAY_OF_WEEK(DATE(Pickup_Time)) IN (6, 7) THEN 'Weekend'
        ELSE 'Weekday'
    END
HAVING SUM(number) > 20
ORDER BY avg_tip_percentage DESC
LIMIT 100
```

**Chart Type**: 3D Bubble Chart or Heatmap (Hour x Location, Size=tip%, Color=trip_count)
**Value**: Maximize earnings through strategic positioning

---

## Real-time Monitoring Charts

### 15. Live Performance Dashboard (Current Hour vs Historical)
**Insight**: How is current hour performing vs historical average?

**SQL Query**:
```sql
WITH current_hour AS (
    SELECT 
        SUM(number) as current_trips,
        CAST(SUM(Total_Amount) AS DECIMAL(12,2)) as current_revenue
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_TIMESTAMP, '%Y-%m-%d %H')
),
historical_avg AS (
    SELECT 
        CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
        DAY_OF_WEEK(DATE(Pickup_Time)) as day_of_week,
        AVG(number) * 260 as avg_total_trips,  -- 260 zones
        AVG(Total_Amount) * 260 as avg_total_revenue
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
        AND Pickup_Time < DATE_FORMAT(CURRENT_DATE - INTERVAL '1' DAY, '%Y-%m-%d %H')
    GROUP BY SUBSTR(Pickup_Time, 12, 2), DAY_OF_WEEK(DATE(Pickup_Time))
)
SELECT 
    c.current_trips,
    c.current_revenue,
    CAST(h.avg_total_trips AS INTEGER) as expected_trips,
    CAST(h.avg_total_revenue AS DECIMAL(12,2)) as expected_revenue,
    CAST((c.current_trips - h.avg_total_trips) * 100.0 / NULLIF(h.avg_total_trips, 0) AS DECIMAL(8,2)) as trips_variance_pct,
    CAST((c.current_revenue - h.avg_total_revenue) * 100.0 / NULLIF(h.avg_total_revenue, 0) AS DECIMAL(8,2)) as revenue_variance_pct
FROM current_hour c
CROSS JOIN historical_avg h
WHERE h.hour_of_day = CAST(DATE_FORMAT(CURRENT_TIMESTAMP, '%H') AS INTEGER)
    AND h.day_of_week = DAY_OF_WEEK(CURRENT_DATE)
```

**Chart Type**: KPI Cards with Variance Indicators (Green/Red)
**Value**: Real-time alerting for operational teams


### 16. Rolling Performance Metrics (Last 24 Hours)
**Insight**: Continuous monitoring of key metrics

**SQL Query**:
```sql
SELECT 
    Pickup_Time,
    SUM(number) OVER (ORDER BY Pickup_Time ROWS BETWEEN 23 PRECEDING AND CURRENT ROW) as rolling_24h_trips,
    CAST(AVG(AVG_Total_Amount) OVER (ORDER BY Pickup_Time ROWS BETWEEN 23 PRECEDING AND CURRENT ROW) AS DECIMAL(8,2)) as rolling_24h_avg_fare,
    CAST(AVG(number) OVER (ORDER BY Pickup_Time ROWS BETWEEN 23 PRECEDING AND CURRENT ROW) AS DECIMAL(8,2)) as rolling_24h_avg_trips_per_location
FROM (
    SELECT 
        Pickup_Time,
        SUM(number) as number,
        AVG(AVG_Total_Amount) as AVG_Total_Amount
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_TIMESTAMP - INTERVAL '48' HOUR, '%Y-%m-%d %H')
    GROUP BY Pickup_Time
) hourly_agg
ORDER BY Pickup_Time DESC
LIMIT 48
```

**Chart Type**: Time Series with Rolling Average
**Value**: Smooth out noise and see true trends

---

## Behavioral Pattern Charts

### 17. Passenger Group Size Patterns
**Insight**: Do groups travel at specific times or from specific locations?

**SQL Query**:
```sql
SELECT 
    CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
    Pickup_Location,
    CASE 
        WHEN AVG_Passenger_Count <= 1 THEN 'Solo (1)'
        WHEN AVG_Passenger_Count <= 2 THEN 'Couple (2)'
        WHEN AVG_Passenger_Count <= 4 THEN 'Small Group (3-4)'
        ELSE 'Large Group (5+)'
    END as group_size,
    COUNT(*) as occurrence_count,
    CAST(AVG(AVG_Total_Amount) AS DECIMAL(8,2)) as avg_fare,
    CAST(AVG(AVG_Trip_Distance) AS DECIMAL(8,2)) as avg_distance
FROM nyc_taxi_aggregated
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
    AND AVG_Passenger_Count > 0
GROUP BY SUBSTR(Pickup_Time, 12, 2), Pickup_Location,
    CASE 
        WHEN AVG_Passenger_Count <= 1 THEN 'Solo (1)'
        WHEN AVG_Passenger_Count <= 2 THEN 'Couple (2)'
        WHEN AVG_Passenger_Count <= 4 THEN 'Small Group (3-4)'
        ELSE 'Large Group (5+)'
    END
ORDER BY hour_of_day, occurrence_count DESC
```

**Chart Type**: Stacked Area Chart (Hour x Group Size Distribution)
**Value**: Vehicle type optimization (need more vans?)


### 18. Trip Distance Behavior by Time
**Insight**: Do people take longer trips at certain times?

**SQL Query**:
```sql
WITH distance_categories AS (
    SELECT 
        CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
        CASE 
            WHEN AVG_Trip_Distance < 2 THEN 'Short (<2 mi)'
            WHEN AVG_Trip_Distance < 5 THEN 'Medium (2-5 mi)'
            WHEN AVG_Trip_Distance < 10 THEN 'Long (5-10 mi)'
            ELSE 'Very Long (10+ mi)'
        END as distance_category,
        SUM(number) as trip_count,
        CAST(AVG(AVG_Total_Amount) AS DECIMAL(8,2)) as avg_fare
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
        AND AVG_Trip_Distance > 0
        AND AVG_Trip_Distance < 100
    GROUP BY SUBSTR(Pickup_Time, 12, 2),
        CASE 
            WHEN AVG_Trip_Distance < 2 THEN 'Short (<2 mi)'
            WHEN AVG_Trip_Distance < 5 THEN 'Medium (2-5 mi)'
            WHEN AVG_Trip_Distance < 10 THEN 'Long (5-10 mi)'
            ELSE 'Very Long (10+ mi)'
        END
)
SELECT 
    hour_of_day,
    distance_category,
    trip_count,
    avg_fare,
    CAST(trip_count * 100.0 / SUM(trip_count) OVER (PARTITION BY hour_of_day) AS DECIMAL(5,2)) as pct_of_hour
FROM distance_categories
ORDER BY hour_of_day, distance_category
```

**Chart Type**: 100% Stacked Bar Chart (Hour x Distance Category %)
**Value**: Understand trip purpose (short=local errands, long=airport/commute?)


### 19. Payment Method Correlation (if available)
**Insight**: Premium tip zones and payment preferences

**Note**: This requires payment_type data if available in your dataset

**Conceptual SQL**:
```sql
-- If you have payment_type column
SELECT 
    Pickup_Location,
    payment_type,
    COUNT(*) as trip_count,
    CAST(AVG(tip_amount) AS DECIMAL(8,2)) as avg_tip,
    CAST(AVG(tip_amount / NULLIF(Fare_Amount, 0) * 100) AS DECIMAL(5,2)) as avg_tip_pct
FROM raw_taxi_data  -- Your raw table
WHERE pickup_datetime >= CURRENT_DATE - INTERVAL '30' DAY
GROUP BY Pickup_Location, payment_type
HAVING COUNT(*) > 50
ORDER BY avg_tip_pct DESC
```

**Chart Type**: Grouped Bar Chart or Heatmap
**Value**: Credit card riders tip more (encourage card payments)

---

## Multi-Dimensional Analysis

### 20. Correlation Matrix Heatmap
**Insight**: Which metrics move together?

**SQL Query**:
```sql
WITH metrics AS (
    SELECT 
        Pickup_Location,
        CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour_of_day,
        CAST(SUM(number) AS DECIMAL(12,2)) as trips,
        CAST(AVG(AVG_Total_Amount) AS DECIMAL(12,2)) as avg_fare,
        CAST(AVG(AVG_Trip_Distance) AS DECIMAL(12,2)) as avg_distance,
        CAST(AVG(AVG_Passenger_Count) AS DECIMAL(12,2)) as avg_passengers,
        CAST(SUM(tip_amount) / NULLIF(SUM(Fare_Amount), 0) * 100 AS DECIMAL(12,2)) as tip_pct
    FROM nyc_taxi_aggregated
    WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')
        AND Total_Trip_Distance > 0
    GROUP BY Pickup_Location, SUBSTR(Pickup_Time, 12, 2)
    HAVING SUM(number) > 10
)
SELECT 
    'Trips vs Fare' as metric_pair,
    CAST(CORR(trips, avg_fare) AS DECIMAL(5,3)) as correlation
FROM metrics

UNION ALL

SELECT 
    'Trips vs Distance' as metric_pair,
    CAST(CORR(trips, avg_distance) AS DECIMAL(5,3)) as correlation
FROM metrics

UNION ALL

SELECT 
    'Fare vs Distance' as metric_pair,
    CAST(CORR(avg_fare, avg_distance) AS DECIMAL(5,3)) as correlation
FROM metrics

UNION ALL

SELECT 
    'Passengers vs Fare' as metric_pair,
    CAST(CORR(avg_passengers, avg_fare) AS DECIMAL(5,3)) as correlation
FROM metrics

UNION ALL

SELECT 
    'Tip % vs Distance' as metric_pair,
    CAST(CORR(tip_pct, avg_distance) AS DECIMAL(5,3)) as correlation
FROM metrics
```

**Chart Type**: Heatmap or Network Diagram
**Value**: Understand interdependencies between business metrics


### 21. Sunburst Chart (Hierarchical Breakdown)
**Insight**: Revenue hierarchy: Borough → Zone → Hour → Taxi Type

**SQL Query** (for Superset Sunburst):
```sql
SELECT 
    z.Borough as level1,
    z.Zone as level2,
    CONCAT('Hour ', CAST(SUBSTR(t.Pickup_Time, 12, 2) AS VARCHAR)) as level3,
    t.taxi_type as level4,
    CAST(SUM(t.Total_Amount) AS DECIMAL(12,2)) as value
FROM nyc_taxi_aggregated t
LEFT JOIN taxi_zones z ON t.Pickup_Location = z.LocationID
WHERE t.Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '7' DAY, '%Y-%m-%d %H')
    AND z.Borough IS NOT NULL
GROUP BY z.Borough, z.Zone, SUBSTR(t.Pickup_Time, 12, 2), t.taxi_type
ORDER BY level1, level2, level3, level4
```

**Chart Type**: Sunburst or Treemap
**Value**: Interactive exploration of revenue hierarchy

---

## Implementation Priority

### High Value, Easy to Implement:
1. **Revenue Per Minute by Hour** - Immediate driver value
2. **Fare Efficiency Score** - Strategic positioning
3. **Optimal Shift Analysis** - Scheduling optimization
4. **Tip Yield Optimization** - Earnings maximization
5. **Pareto Analysis** - 80/20 insights

### Medium Value, Medium Complexity:
6. **Capacity Utilization** - Fleet optimization
7. **Yellow vs Green Competition** - Market strategy
8. **Anomaly Detection** - Data quality
9. **Trip Distance Behavior** - Usage patterns
10. **Profitability Matrix (BCG)** - Portfolio analysis

### High Value, Complex:
11. **Demand Forecasting** - Predictive planning
12. **Real-time Performance Dashboard** - Operations monitoring
13. **Correlation Matrix** - Deep analytics
14. **Temporal Flow Patterns** - Geographic dynamics

---

## Visualization Best Practices

### For Each Chart Type:

1. **Efficiency Charts**: Use color gradients (green=good, red=bad)
2. **Anomaly Charts**: Use outlier highlighting and annotations
3. **Comparison Charts**: Use consistent colors for same entities
4. **Time Series**: Add trendlines and moving averages
5. **Heatmaps**: Use perceptually uniform color scales
6. **Network Charts**: Limit to top N nodes for clarity

### Interactive Features to Enable:

- **Drill-down**: Click location → see hourly breakdown
- **Cross-filtering**: Select hour → update all charts
- **Tooltips**: Show detailed metrics on hover
- **Export**: Allow data download for further analysis
- **Alerts**: Set thresholds for automatic notifications

---

## Next Steps

1. **Prioritize** which charts provide most business value
2. **Test** queries on your Trino instance
3. **Prototype** 2-3 high-priority charts first
4. **Gather Feedback** from stakeholders (drivers, dispatchers, managers)
5. **Iterate** and refine based on usage
6. **Automate** with scheduled refreshes

---

**Last Updated**: October 2025  
**Status**: Innovation Proposal - Ready for Implementation

