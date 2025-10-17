# Superset Chart Configurations for NYC Taxi Dashboard

Quick reference guide for creating specific chart types in Apache Superset.

## Table of Contents
- [KPI / Big Number Charts](#kpi--big-number-charts)
- [Time Series Charts](#time-series-charts)
- [Bar Charts](#bar-charts)
- [Pie Charts](#pie-charts)
- [Tables](#tables)
- [Map Visualizations](#map-visualizations)
- [Heatmaps](#heatmaps)
- [Filters](#filters)

---

## KPI / Big Number Charts

### Total Trips KPI
```
Chart Type: Big Number
Metric: SUM(number)
Number Format: ,d
Time Range: Last 30 days
```

### Total Revenue KPI
```
Chart Type: Big Number
Metric: SUM(Total_Amount)
Number Format: $,.2f
Time Range: Last 30 days
```

### Average Fare KPI
```
Chart Type: Big Number with Trendline
Metric: SUM(Total_Amount) / SUM(number)
Number Format: $,.2f
Time Column: Pickup_Time
Time Range: Last 30 days
Show Trendline: Yes
```

### Average Distance KPI
```
Chart Type: Big Number
Metric: SUM(Total_Trip_Distance) / SUM(number)
Number Format: ,.1f mi
Time Range: Last 30 days
```

---

## Time Series Charts

### Trips Over Time (Hourly)
```
Chart Type: Time-series Line Chart
Time Column: Pickup_Time
Time Grain: Hour
Metrics: SUM(number)
Group by: taxi_type
Show Legend: Yes
Show Markers: No
Y-Axis Format: ,d
Color Scheme: supersetColors (yellow=#FFD700, green=#90EE90)
```

### Revenue Over Time
```
Chart Type: Time-series Area Chart
Time Column: Pickup_Time
Time Grain: Day
Metrics: SUM(Total_Amount)
Group by: taxi_type
Stack: Yes
Show Legend: Yes
Y-Axis Format: $,.0f
```

### Daily Trip Pattern
```
Chart Type: Time-series Bar Chart
Time Column: Pickup_Time
Time Grain: Hour
Metrics: SUM(number)
Group by: taxi_type
Show Legend: Yes
Show Bar Values: No
Y-Axis Format: ,d
```

---

## Bar Charts

### Busy Hours Analysis
```
Chart Type: Bar Chart
X-Axis: HOUR(Pickup_Time) or CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER)
Metrics: SUM(number)
Group by: taxi_type
Sort by: X-Axis ascending
Show Legend: Yes
X-Axis Label: Hour of Day (0-23)
Y-Axis Label: Number of Trips
Y-Axis Format: ,d
```

### Top 10 Pickup Locations
```
Chart Type: Bar Chart (Horizontal)
X-Axis: SUM(number)
Y-Axis: Pickup_Location
Sort by: Metric descending
Row Limit: 10
Show Values: Yes
Number Format: ,d
```

### Fare Components Breakdown
```
Chart Type: Stacked Bar Chart
X-Axis: taxi_type
Metrics: 
  - SUM(Fare_Amount)
  - SUM(Extra)
  - SUM(tip_amount)
  - SUM(tolls_amount)
Stack: Yes
Show Legend: Yes
Y-Axis Format: $,.0f
```

---

## Pie Charts

### Taxi Type Market Share
```
Chart Type: Pie Chart
Dimension: taxi_type
Metric: SUM(number)
Number Format: ,d
Show Labels: Yes
Show Legend: Yes
Show Percentage: Yes
Color Scheme:
  - Yellow: #FFD700
  - Green: #32CD32
```

### Borough Distribution
```
Chart Type: Pie Chart
Dimension: Borough (from taxi_zones joined)
Metric: SUM(number)
Row Limit: 5
Show Labels: Yes
Show Legend: Yes
Donut Mode: Yes (optional)
```

---

## Tables

### Top Pickup Locations Table
```
Chart Type: Table
Columns: 
  - Pickup_Location
  - SUM(number) AS "Total Trips"
  - SUM(Total_Amount) AS "Total Revenue"
  - AVG(AVG_Trip_Distance) AS "Avg Distance"
  - AVG(AVG_Total_Amount) AS "Avg Fare"
Sort by: Total Trips DESC
Row Limit: 20
Show Cell Bars: Yes (for metrics)
Page Length: 10
Enable Search: Yes
Column Formats:
  - Total Trips: ,d
  - Total Revenue: $,.2f
  - Avg Distance: ,.2f mi
  - Avg Fare: $,.2f
```

### Hourly Performance Table
```
Chart Type: Table
Columns:
  - HOUR(Pickup_Time) AS "Hour"
  - taxi_type AS "Taxi Type"
  - SUM(number) AS "Trips"
  - SUM(Total_Amount) AS "Revenue"
Group by: Hour, Taxi Type
Sort by: Hour ASC
Show Totals: Yes
Conditional Formatting: Apply color scale to Trips column
```

---

## Map Visualizations

### Deck.gl Scatterplot (Pickup Heatmap)
```
Chart Type: deck.gl Scatterplot
Query Mode: Query
SQL Query: 
  SELECT 
    z.longitude,
    z.latitude,
    SUM(t.number) as weight,
    z.Zone as name
  FROM taxi_zones z
  JOIN nyc_taxi_aggregated t ON z.LocationID = t.Pickup_Location
  GROUP BY z.longitude, z.latitude, z.Zone
  
Longitude: longitude
Latitude: latitude
Weight: weight
Point Size: Auto / Fixed (5-15)
Point Color: 
  - Scheme: Blue to Red
  - Or Fixed: #FF5733
Viewport:
  - Latitude: 40.7128
  - Longitude: -74.0060
  - Zoom: 10
  - Bearing: 0
  - Pitch: 0
Tooltip: name
```

### Deck.gl Hexagon Layer (Geographic Density)
```
Chart Type: deck.gl Hexagon
Query Mode: Query
SQL Query: Same as Scatterplot
Longitude: longitude
Latitude: latitude
Weight: weight
Hexagon Radius: 1000 (meters)
Color Scheme: Blue to Red
Elevation: Based on weight
Show Legend: Yes
```

---

## Heatmaps

### Hour x Day of Week Heatmap
```
Chart Type: Heatmap
SQL Query:
  SELECT 
    CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER) as hour,
    DAY_OF_WEEK(DATE(Pickup_Time)) as day_of_week,
    SUM(number) as trips
  FROM nyc_taxi_aggregated
  GROUP BY hour, day_of_week

X-Axis: hour
Y-Axis: day_of_week
Metric: SUM(trips)
Color Scheme: Sequential (Light to Dark)
Show Values: Yes
Normalize: By Row or Column (optional)
```

---

## Filters

### Date Range Filter
```
Filter Type: Time Range
Column: Pickup_Time
Default Value: Last 30 days
Enable Time Comparison: Yes (optional)
```

### Taxi Type Filter
```
Filter Type: Select Filter
Column: taxi_type
Options: Yellow, Green
Default: All
Multiple Selection: Yes
```

### Borough Filter (requires taxi_zones)
```
Filter Type: Select Filter
Column: Borough
Options: Manhattan, Brooklyn, Queens, Bronx, Staten Island
Default: All
Multiple Selection: Yes
```

### Hour Range Filter
```
Filter Type: Numerical Range
Column: HOUR(Pickup_Time)
Min: 0
Max: 23
Default: All (0-23)
```

---

## Common SQL Expressions

### Custom Columns

**Hour of Day**
```sql
CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER)
```

**Day of Week**
```sql
DAY_OF_WEEK(DATE(Pickup_Time))
```

**Date Only**
```sql
DATE(Pickup_Time)
```

**Week Number**
```sql
WEEK(DATE(Pickup_Time))
```

**Month Name**
```sql
DATE_FORMAT(DATE(Pickup_Time), '%b %Y')
```

**Is Weekend**
```sql
CASE WHEN DAY_OF_WEEK(DATE(Pickup_Time)) IN (6, 7) THEN 'Weekend' ELSE 'Weekday' END
```

**Tip Percentage**
```sql
CASE WHEN Fare_Amount > 0 THEN (tip_amount / Fare_Amount) * 100 ELSE 0 END
```

**Revenue per Mile**
```sql
CASE WHEN Total_Trip_Distance > 0 THEN Total_Amount / Total_Trip_Distance ELSE 0 END
```

### Custom Metrics

**Average Fare per Trip**
```sql
SUM(Total_Amount) / NULLIF(SUM(number), 0)
```

**Total Tip Percentage**
```sql
SUM(tip_amount) / NULLIF(SUM(Fare_Amount), 0) * 100
```

**Trips per Hour**
```sql
SUM(number) / COUNT(DISTINCT DATE_TRUNC('hour', Pickup_Time))
```

---

## Color Schemes

### Recommended Colors for NYC Taxi

**Yellow Taxi**: `#FFD700` (Gold)  
**Green Taxi**: `#32CD32` (LimeGreen)

### Color Schemes by Category

**Revenue Metrics**: 
- Green gradient: `#d4edda` → `#155724`

**Trip Count Metrics**: 
- Blue gradient: `#cce5ff` → `#004085`

**Heat Maps**: 
- Red gradient: `#fff5f5` → `#c53030`

**Geographic Maps**: 
- Blue to Red: `#0080ff` → `#ff0000`

---

## Dashboard Layout Tips

### Recommended Dashboard Structure

```
┌─────────────────────────────────────────────────────────┐
│                    Dashboard Filters                    │
│  [Date Range]  [Taxi Type]  [Borough]  [Hour Range]    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────┬──────────┬──────────┬──────────┐        │
│  │ Trips    │ Revenue  │ Avg Fare │ Distance │        │
│  │ KPI      │ KPI      │ KPI      │ KPI      │        │
│  └──────────┴──────────┴──────────┴──────────┘        │
│                                                         │
│  ┌─────────────────────────────────────────────┐       │
│  │     Trips Over Time (Line Chart)            │       │
│  │                                             │       │
│  └─────────────────────────────────────────────┘       │
│                                                         │
│  ┌──────────────────────┬──────────────────────┐       │
│  │  Busy Hours          │  Top Locations       │       │
│  │  (Bar Chart)         │  (Table)             │       │
│  │                      │                      │       │
│  └──────────────────────┴──────────────────────┘       │
│                                                         │
│  ┌─────────────────────────────────────────────┐       │
│  │     Geographic Heatmap (Map)                │       │
│  │                                             │       │
│  └─────────────────────────────────────────────┘       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Size Guidelines

- **KPI Cards**: Width: 25%, Height: 200px
- **Main Charts**: Width: 100%, Height: 400px
- **Side-by-Side Charts**: Width: 50% each, Height: 400px
- **Tables**: Width: 100% or 50%, Height: 400-600px
- **Maps**: Width: 100%, Height: 600px

---

## Performance Optimization

### Chart-Level Settings

1. **Row Limit**: 
   - KPIs: 1
   - Time series: 10,000
   - Tables: 100-1,000
   - Maps: 500-1,000

2. **Async Query Execution**: Enable for slow queries

3. **Cache Timeout**: 
   - Real-time data: 300 seconds (5 min)
   - Historical data: 3600 seconds (1 hour)
   - Static data: 86400 seconds (24 hours)

4. **Query Simplification**:
   - Pre-aggregate data in Trino
   - Use materialized views
   - Limit date ranges with filters

---

## Advanced Features

### Drill-Down Configuration

Enable drill-down from summary to detail:
1. Click on bar/point in chart
2. Apply filter to dashboard
3. Show detailed table/map

### Cross-Filtering

Enable cross-filtering between charts:
- Dashboard Settings → Enable cross-filtering
- Click on one chart to filter others

### Scheduled Reports

1. Navigate to Dashboard
2. Click "..." → "Email Reports"
3. Set schedule (daily, weekly, monthly)
4. Add recipients
5. Select format (PNG, PDF)

### Alerts

Set up alerts for key metrics:
1. Go to Charts → Select chart
2. Click "Alerts" → "Create Alert"
3. Set condition (e.g., Total Trips < 1000)
4. Set notification method (Email, Slack)
5. Set check frequency

---

## Troubleshooting

### Chart Not Loading
- Check SQL syntax in SQL Lab first
- Verify dataset permissions
- Check row limit (increase if needed)
- Clear browser cache

### Map Not Showing Data
- Verify latitude/longitude columns exist
- Check for NULL values in coordinates
- Ensure coordinates are decimal degrees (not DMS)
- Verify viewport settings (zoom level)

### Slow Performance
- Add date range filters
- Reduce row limits
- Create aggregated views in Trino
- Enable async queries
- Increase cache timeout

### Colors Not Showing
- Check color scheme in chart settings
- Verify custom colors in JSON
- Clear dashboard cache
- Force refresh (Ctrl+F5)

---

## Resources

- **Superset Documentation**: https://superset.apache.org/docs/intro
- **Chart Gallery**: https://superset.apache.org/gallery
- **Trino Functions**: https://trino.io/docs/current/functions.html
- **NYC Taxi Data Dictionary**: See PDFs in project root

---

*Last Updated: October 2025*

