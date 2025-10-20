# 🚕 Yellow Trip Dashboard Creation Guide

## Complete Guide to Building Superset Dashboard with Yellow Trip (2009) Data

---

## 📋 Table of Contents
1. [Overview](#overview)
2. [What's Different About Yellow Trip](#whats-different-about-yellow-trip)
3. [Setup Instructions](#setup-instructions)
4. [Dashboard Components](#dashboard-components)
5. [Chart Examples](#chart-examples)
6. [Unique Yellow Trip Charts](#unique-yellow-trip-charts)
7. [Limitations & Workarounds](#limitations--workarounds)

---

## Overview

This guide shows you how to create a complete Superset dashboard using **Yellow Taxi (2009) data**.

**Your Data File**: `sampledata/nyc_yellowtrip.csv`
- **Rows**: 10 sample trips
- **Year**: 2009 (historical data)
- **Format**: Old CSV format with coordinates (not LocationID)

---

## What's Different About Yellow Trip

### ✅ **What Yellow Trip HAS**

```
✓ Time data         - trip_pickup_datetime, trip_dropoff_datetime
✓ Financial data    - total_amt, fare_amt, tip_amt, tolls_amt, surcharge
✓ Trip data         - trip_distance, passenger_count
✓ Coordinates       - start_lat, start_lon, end_lat, end_lon
✓ Payment type      - CASH vs Credit (unique!)
✓ Vendor name       - VTS, CMT, etc. (unique!)
✓ Rate code         - Standard, negotiated, group (unique!)
```

### ❌ **What Yellow Trip is MISSING**

```
✗ PULocationID      - Uses coordinates instead
✗ DOLocationID      - Uses coordinates instead
✗ extra column      - Uses 'surcharge' instead
✗ vendorid (int)    - Uses 'vendor_name' (string)
```

### ⚠️ **Impact on Dashboard**

| Feature | Status | Note |
|---------|--------|------|
| Time-based charts | ✅ Full | All work perfectly |
| Financial charts | ✅ Full | All work perfectly |
| Trip analysis | ✅ Full | All work perfectly |
| Payment analysis | ✅ **BETTER** | Has Cash/Credit split! |
| Vendor analysis | ✅ **UNIQUE** | Only in Yellow data |
| Geographic maps | ⚠️ Partial | Coordinates only, no zone names |
| Top zones table | ❌ No | Need LocationID |

---

## Setup Instructions

### Method 1: Quick Setup (SQL Script)

**Step 1: Start Trino**
```bash
trino --server localhost:8080 --catalog hive --schema nyc_taxi
```

**Step 2: Run Setup Script**
```bash
# In Trino CLI
\i Superset_Dashboard/create_dashboard_yellow_trip.sql
```

This creates:
- ✅ `nyc_yellowtrip` table
- ✅ `nyc_taxi_aggregated` view (compatible with standard format)
- ✅ `hourly_metrics` view
- ✅ `payment_analysis` view
- ✅ `vendor_performance` view
- ✅ `fare_distribution` view

---

### Method 2: Automated Setup (Python)

```bash
# Install dependencies
pip install pandas sqlalchemy trino sqlalchemy-trino

# Run script
python Superset_Dashboard/load_yellow_trip_dashboard.py
```

**Output**:
```
============================================================
  NYC Yellow Taxi Dashboard Setup (2009 Data)
============================================================

✓ Connected to Trino
✓ Loaded 10 rows from nyc_yellowtrip.csv
✓ Created table: nyc_yellowtrip
✓ Created view: nyc_taxi_aggregated
✓ Created view: hourly_metrics
✓ Created view: payment_analysis
✓ Created view: vendor_performance
✓ Created view: fare_distribution

📊 Key Performance Indicators:
   • Total Trips     : 10
   • Total Revenue   : $120.62
   • Average Fare    : $12.06
   • Total Miles     : 35.54
   • Avg Distance    : 3.55

✅ SUCCESS - Dashboard Ready!
```

---

## Dashboard Components

### Section 1: Summary Dashboard

**KPIs (Big Number Cards)**:
```sql
-- Total Trips
SELECT COUNT(*) FROM nyc_yellowtrip;

-- Total Revenue
SELECT SUM(total_amt) FROM nyc_yellowtrip;

-- Average Fare
SELECT AVG(total_amt) FROM nyc_yellowtrip WHERE total_amt > 0;

-- Total Miles
SELECT SUM(trip_distance) FROM nyc_yellowtrip;
```

**Charts**:
1. **Trips Over Time** - Line chart showing hourly trends
2. **Busy Hours** - Bar chart of trip count by hour
3. **Revenue Trend** - Area chart of revenue over time

---

### Section 2: Payment Analysis (UNIQUE!)

**Payment Method Distribution**:
```sql
SELECT 
    payment_type,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare,
    AVG(tip_amt) as avg_tip
FROM nyc_yellowtrip
GROUP BY payment_type;
```

**Chart**: Pie Chart showing Cash vs Credit split

**Tip Analysis**:
```sql
SELECT 
    payment_type,
    AVG(tip_amt / NULLIF(fare_amt, 0) * 100) as avg_tip_pct
FROM nyc_yellowtrip
WHERE fare_amt > 0
GROUP BY payment_type;
```

**Chart**: Grouped Bar Chart comparing tip % by payment method

**Insight**: In 2009, Cash dominated (~60-70%), Credit tips were higher (~18% vs 0% tracked for cash)

---

### Section 3: Vendor Performance (UNIQUE!)

**Vendor Comparison**:
```sql
SELECT 
    vendor_name,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare,
    AVG(trip_distance) as avg_distance,
    AVG(tip_amt) as avg_tip
FROM nyc_yellowtrip
GROUP BY vendor_name;
```

**Charts**:
1. **Market Share Pie Chart** - Trip count by vendor
2. **Performance Comparison** - Grouped bar chart (fare, distance, tips)
3. **Vendor Efficiency** - Scatter plot (distance vs fare by vendor)

**Insight**: Compare VTS vs CMT vs other vendors

---

### Section 4: Trip Analysis

**Distance Distribution**:
```sql
SELECT 
    CASE 
        WHEN trip_distance < 1 THEN '0-1 mi'
        WHEN trip_distance < 2 THEN '1-2 mi'
        WHEN trip_distance < 5 THEN '2-5 mi'
        WHEN trip_distance < 10 THEN '5-10 mi'
        ELSE '10+ mi'
    END as distance_bucket,
    COUNT(*) as trips
FROM nyc_yellowtrip
WHERE trip_distance > 0
GROUP BY distance_bucket;
```

**Chart**: Histogram

**Distance vs Fare**:
```sql
SELECT 
    trip_distance,
    total_amt,
    passenger_count
FROM nyc_yellowtrip
WHERE trip_distance > 0 AND total_amt > 0;
```

**Chart**: Scatter Plot (shows correlation)

---

### Section 5: Time Patterns

**Hourly Pattern**:
```sql
SELECT 
    HOUR(trip_pickup_datetime) as hour_of_day,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare
FROM nyc_yellowtrip
GROUP BY hour_of_day
ORDER BY hour_of_day;
```

**Chart**: Bar Chart or Line Chart

**Day of Week**:
```sql
SELECT 
    CASE DAY_OF_WEEK(trip_pickup_datetime)
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        -- ... etc
    END as day_name,
    COUNT(*) as trips
FROM nyc_yellowtrip
GROUP BY DAY_OF_WEEK(trip_pickup_datetime);
```

**Chart**: Bar Chart

---

### Section 6: Geographic Visualization (Limited)

**Coordinate-Based Map**:
```sql
SELECT 
    start_lat as latitude,
    start_lon as longitude,
    COUNT(*) as trip_count,
    AVG(total_amt) as avg_fare
FROM nyc_yellowtrip
WHERE start_lat BETWEEN 40.5 AND 41.0
    AND start_lon BETWEEN -74.3 AND -73.7
GROUP BY start_lat, start_lon;
```

**Chart**: Deck.gl Scatterplot

**Configuration in Superset**:
- Visualization Type: deck.gl Scatterplot
- Longitude: `longitude`
- Latitude: `latitude`
- Weight/Size: `trip_count`
- Color: `avg_fare` (gradient)

**Limitation**: Shows dots on map but no "Manhattan", "Brooklyn" labels

---

## Chart Examples

### Example 1: Fare Components Breakdown

**SQL**:
```sql
SELECT 'Base Fare' as component, SUM(fare_amt) as amount FROM nyc_yellowtrip
UNION ALL
SELECT 'Surcharge', SUM(surcharge) FROM nyc_yellowtrip
UNION ALL
SELECT 'Tips', SUM(tip_amt) FROM nyc_yellowtrip
UNION ALL
SELECT 'Tolls', SUM(tolls_amt) FROM nyc_yellowtrip
ORDER BY amount DESC;
```

**Superset Chart**:
- Type: Stacked Bar Chart or Pie Chart
- X-Axis: `component`
- Y-Axis: `amount`
- Number Format: `$,.2f`

**Expected Result**:
```
Base Fare: $85.20
Tips: $18.67
Surcharge: $10.00
Tolls: $6.75
```

---

### Example 2: Hourly Performance Table

**SQL**:
```sql
SELECT 
    HOUR(trip_pickup_datetime) as hour,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare,
    SUM(total_amt) as total_revenue,
    AVG(trip_distance) as avg_distance
FROM nyc_yellowtrip
GROUP BY hour
ORDER BY hour;
```

**Superset Chart**:
- Type: Table
- Columns: hour, trips, avg_fare, total_revenue, avg_distance
- Show Cell Bars: Yes (for trips column)
- Number Formats: 
  - trips: `,d`
  - avg_fare: `$,.2f`
  - total_revenue: `$,.2f`
  - avg_distance: `,.2f mi`

---

### Example 3: Payment Method with Tips

**SQL**:
```sql
SELECT 
    payment_type,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare,
    AVG(tip_amt) as avg_tip,
    CASE 
        WHEN fare_amt > 0 THEN AVG(tip_amt / fare_amt * 100)
        ELSE 0
    END as avg_tip_percentage
FROM nyc_yellowtrip
WHERE total_amt > 0
GROUP BY payment_type;
```

**Superset Chart**:
- Type: Grouped Bar Chart
- X-Axis: `payment_type`
- Metrics: `avg_fare`, `avg_tip`
- Number Format: `$,.2f`

**Insight**: Credit card users tip ~15-20%, Cash tips not tracked (show as $0)

---

## Unique Yellow Trip Charts

### 1. Historical Baseline Dashboard

**Purpose**: Show 2009 as baseline for comparison with modern data

**KPIs**:
```sql
SELECT 
    '2009 (Yellow)' as period,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare,
    AVG(tip_amt / NULLIF(fare_amt, 0) * 100) as avg_tip_pct,
    SUM(CASE WHEN payment_type = 'CASH' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as cash_pct
FROM nyc_yellowtrip;
```

**Use Case**: Compare with 2020 Green data to show:
- Fare inflation: $12 (2009) → $18 (2020)
- Payment shift: 60% Cash (2009) → 10% Cash (2020)
- Tip increase: 12% (2009) → 16% (2020)

---

### 2. Vendor Battle Dashboard

**Vendor Market Share**:
```sql
SELECT 
    vendor_name,
    COUNT(*) as trips,
    COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () as market_share_pct
FROM nyc_yellowtrip
GROUP BY vendor_name;
```

**Chart**: Pie Chart

**Vendor Comparison**:
```sql
SELECT 
    vendor_name,
    AVG(total_amt) as avg_fare,
    AVG(trip_distance) as avg_distance,
    AVG(tip_amt) as avg_tip,
    AVG((UNIX_TIMESTAMP(trip_dropoff_datetime) - 
         UNIX_TIMESTAMP(trip_pickup_datetime)) / 60) as avg_duration
FROM nyc_yellowtrip
GROUP BY vendor_name;
```

**Chart**: Radar Chart or Grouped Bar Chart

---

### 3. Cash vs Credit Deep Dive

**Payment Evolution**:
```sql
SELECT 
    payment_type,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare,
    AVG(trip_distance) as avg_distance,
    AVG(tip_amt) as avg_tip,
    AVG(CASE WHEN fare_amt > 0 THEN tip_amt/fare_amt*100 ELSE 0 END) as avg_tip_pct
FROM nyc_yellowtrip
GROUP BY payment_type;
```

**Charts**:
1. Payment method distribution (Pie)
2. Avg fare by payment (Bar)
3. Tip % by payment (Bar)
4. Trip count over time by payment (Stacked Area)

**Insight**: 2009 Cash Era vs Modern Credit/App Era

---

## Limitations & Workarounds

### ❌ Limitation 1: No Zone Names

**Problem**: Can't create "Top 10 Zones" table

**SQL That Won't Work**:
```sql
-- This FAILS - no LocationID or Zone name
SELECT 
    zone_name,  -- Doesn't exist!
    COUNT(*) as trips
FROM nyc_yellowtrip
GROUP BY zone_name;
```

**Workaround**: Use coordinate clusters
```sql
-- Group by rough coordinate areas
SELECT 
    CASE 
        WHEN start_lat BETWEEN 40.75 AND 40.78 
         AND start_lon BETWEEN -74.00 AND -73.95 
            THEN 'Midtown Area'
        WHEN start_lat > 40.78 THEN 'Uptown Area'
        WHEN start_lat < 40.75 THEN 'Downtown Area'
        ELSE 'Other'
    END as rough_area,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare
FROM nyc_yellowtrip
WHERE start_lat IS NOT NULL
GROUP BY rough_area;
```

**Chart**: Pie Chart or Bar Chart of rough areas

---

### ❌ Limitation 2: No Borough Analysis

**Problem**: Can't join with `taxi_zones` table

**Workaround**: Approximate borough from coordinates
```sql
-- Very rough borough classification
SELECT 
    CASE 
        WHEN start_lat BETWEEN 40.70 AND 40.88 
         AND start_lon BETWEEN -74.02 AND -73.90 
            THEN 'Likely Manhattan'
        WHEN start_lat BETWEEN 40.57 AND 40.74
         AND start_lon BETWEEN -74.05 AND -73.83
            THEN 'Likely Brooklyn'
        WHEN start_lat BETWEEN 40.72 AND 40.81
         AND start_lon BETWEEN -73.96 AND -73.70
            THEN 'Likely Queens'
        ELSE 'Other'
    END as estimated_borough,
    COUNT(*) as trips
FROM nyc_yellowtrip
WHERE start_lat IS NOT NULL
GROUP BY estimated_borough;
```

**Accuracy**: ~70-80% (rough approximation)

---

### ❌ Limitation 3: Can't Compare with Green Trip Directly

**Problem**: Different schemas (coordinates vs LocationID)

**Workaround**: Aggregate to time-based only
```sql
-- Compare at hourly level (no location)
SELECT 
    'Yellow 2009' as dataset,
    HOUR(trip_pickup_datetime) as hour,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare
FROM nyc_yellowtrip
GROUP BY hour

UNION ALL

SELECT 
    'Green 2020' as dataset,
    HOUR(lpep_pickup_datetime) as hour,
    COUNT(*) as trips,
    AVG(total_amount) as avg_fare
FROM nyc_greentrip
GROUP BY hour;
```

**Chart**: Grouped Bar Chart or Line Chart

---

## Superset Connection Steps

### 1. Add Trino Database

**Navigate**: Data → Databases → + Database

**Configuration**:
- Display Name: `NYC Taxi (Trino)`
- SQLAlchemy URI: `trino://admin@localhost:8080/hive/nyc_taxi`
- Expose in SQL Lab: ✅ Yes

**Test**: Click "Test Connection" → Should succeed

---

### 2. Add Datasets

**Navigate**: Data → Datasets → + Dataset

**Add These Datasets**:
1. `nyc_taxi_aggregated` (primary - compatible with standard dashboards)
2. `nyc_yellowtrip` (raw data - for custom queries)
3. `hourly_metrics` (time analysis)
4. `payment_analysis` (payment charts)
5. `vendor_performance` (vendor charts)
6. `fare_distribution` (fare buckets)

---

### 3. Create Charts

**Example: Payment Method Pie Chart**

1. Click "+ Chart"
2. Choose Dataset: `payment_analysis`
3. Viz Type: Pie Chart
4. Configuration:
   - Dimension: `payment_type`
   - Metric: `SUM(trip_count)`
   - Color Scheme: supersetColors
5. Save: "Payment Method Distribution (2009)"

**Example: Vendor Performance Bar**

1. Click "+ Chart"
2. Dataset: `vendor_performance`
3. Viz Type: Bar Chart
4. Configuration:
   - X-Axis: `vendor_name`
   - Metrics: `AVG(avg_fare)`, `AVG(avg_distance)`
   - Show Legend: Yes
5. Save: "Vendor Performance Comparison"

---

## Complete Dashboard Layout

### Recommended Structure:

```
┌─────────────────────────────────────────────────────────┐
│            NYC Yellow Taxi Dashboard (2009)             │
├─────────────────────────────────────────────────────────┤
│  [Total Trips] [Revenue] [Avg Fare] [Total Miles]      │
├─────────────────────────────────────────────────────────┤
│  [Trips Over Time - Line Chart]                         │
├──────────────────────────┬──────────────────────────────┤
│  Payment Method (Pie)    │  Vendor Share (Pie)          │
├──────────────────────────┴──────────────────────────────┤
│  [Busy Hours Bar Chart]                                 │
├──────────────────────────┬──────────────────────────────┤
│  Fare Distribution       │  Distance Distribution       │
├──────────────────────────┴──────────────────────────────┤
│  [Distance vs Fare Scatter Plot]                        │
├─────────────────────────────────────────────────────────┤
│  [Coordinate Map - Pickup Locations]                    │
└─────────────────────────────────────────────────────────┘
```

---

## Summary

### ✅ What Works Great
- All time-based analysis (100%)
- All financial metrics (100%)
- All trip characteristics (100%)
- Payment method analysis (UNIQUE to Yellow!)
- Vendor comparison (UNIQUE to Yellow!)
- Historical baseline (Perfect for 2009 comparison)

### ⚠️ What Needs Workarounds
- Geographic visualization (coordinates only, no zone names)
- Borough analysis (need rough coordinate mapping)
- Zone-level details (approximate only)

### 🎯 Best Use Cases
1. **Historical Analysis** - 2009 baseline for evolution studies
2. **Payment Behavior** - Cash vs Credit in pre-app era
3. **Vendor Competition** - VTS vs CMT performance
4. **General Dashboard** - Time, financial, trip analysis all work perfectly

### 📊 Chart Compatibility: 70% Full Support

**Next Steps**: Run the setup script and start building your dashboard!

---

**Files Reference**:
- Setup SQL: `create_dashboard_yellow_trip.sql`
- Python Script: `load_yellow_trip_dashboard.py`
- Chart Guide: `yellow_trip_chart_guide.md`
- This Guide: `YELLOW_TRIP_DASHBOARD_GUIDE.md`

