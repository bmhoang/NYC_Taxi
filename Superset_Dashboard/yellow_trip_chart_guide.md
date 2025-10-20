# 🚕 Yellow Trip Data - Chart Compatibility Guide

## Yellow Trip Data Structure (2009 Format)

**Available Columns:**
```
✓ trip_pickup_datetime      - Timestamp
✓ trip_dropoff_datetime     - Timestamp
✓ passenger_count           - Integer
✓ trip_distance             - Double
✓ start_lon, start_lat      - Coordinates (NO LocationID!)
✓ end_lon, end_lat          - Coordinates
✓ payment_type              - VARCHAR (CASH/Credit)
✓ fare_amt                  - Double
✓ surcharge                 - Double
✓ mta_tax                   - VARCHAR (can be empty)
✓ tip_amt                   - Double
✓ tolls_amt                 - Double
✓ total_amt                 - Double
✓ vendor_name               - VARCHAR
✓ rate_code                 - VARCHAR (can be empty)
```

**Missing Columns (vs Green Trip):**
```
✗ PULocationID              - Only has lat/lon coordinates
✗ DOLocationID              - Only has lat/lon coordinates
✗ vendorid (numeric)        - Has vendor_name (string) instead
✗ extra                     - Has surcharge instead
```

---

## ✅ Charts That WORK with Yellow Trip

### 1. Time-Based Charts (FULLY COMPATIBLE)

#### A. **Trips Over Time (Hourly/Daily)**
```sql
SELECT 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as hour,
    COUNT(*) as trip_count,
    AVG(total_amt) as avg_fare
FROM nyc_yellowtrip
GROUP BY hour
ORDER BY hour;
```
**Chart Types**: Line Chart, Area Chart, Bar Chart
**Why it works**: Has datetime column
**Superset Charts**: ✅ All time-series visualizations

---

#### B. **Busy Hours Analysis**
```sql
SELECT 
    HOUR(trip_pickup_datetime) as hour_of_day,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare,
    AVG(trip_distance) as avg_distance
FROM nyc_yellowtrip
GROUP BY hour_of_day
ORDER BY hour_of_day;
```
**Chart Types**: Bar Chart, Line Chart
**Why it works**: Extract hour from timestamp
**Superset Charts**: ✅ Hourly pattern analysis

---

#### C. **Day of Week Patterns**
```sql
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
GROUP BY day_num, day_name
ORDER BY day_num;
```
**Chart Types**: Bar Chart, Radar Chart
**Superset Charts**: ✅ Daily pattern visualization

---

### 2. Financial Analysis Charts (FULLY COMPATIBLE)

#### A. **Total Revenue KPI**
```sql
SELECT 
    SUM(total_amt) as total_revenue,
    COUNT(*) as total_trips,
    AVG(total_amt) as avg_fare
FROM nyc_yellowtrip;
```
**Chart Types**: Big Number, KPI Card
**Superset Charts**: ✅ All KPI visualizations

---

#### B. **Average Fare Trends**
```sql
SELECT 
    DATE(trip_pickup_datetime) as trip_date,
    AVG(total_amt) as avg_fare,
    MIN(total_amt) as min_fare,
    MAX(total_amt) as max_fare
FROM nyc_yellowtrip
GROUP BY trip_date
ORDER BY trip_date;
```
**Chart Types**: Line Chart with confidence bands
**Superset Charts**: ✅ Financial trend analysis

---

#### C. **Fare Distribution Histogram**
```sql
SELECT 
    CASE 
        WHEN total_amt < 10 THEN '$0-10'
        WHEN total_amt < 20 THEN '$10-20'
        WHEN total_amt < 30 THEN '$20-30'
        WHEN total_amt < 50 THEN '$30-50'
        ELSE '$50+'
    END as fare_bucket,
    COUNT(*) as trip_count
FROM nyc_yellowtrip
WHERE total_amt > 0
GROUP BY fare_bucket
ORDER BY MIN(total_amt);
```
**Chart Types**: Histogram, Bar Chart
**Superset Charts**: ✅ Distribution analysis

---

#### D. **Fare Components Breakdown**
```sql
SELECT 
    'Base Fare' as component,
    SUM(fare_amt) as amount
FROM nyc_yellowtrip
UNION ALL
SELECT 'Surcharge', SUM(surcharge) FROM nyc_yellowtrip
UNION ALL
SELECT 'Tips', SUM(tip_amt) FROM nyc_yellowtrip
UNION ALL
SELECT 'Tolls', SUM(tolls_amt) FROM nyc_yellowtrip;
```
**Chart Types**: Stacked Bar, Pie Chart, Donut Chart
**Superset Charts**: ✅ Revenue composition

---

### 3. Trip Analysis Charts (FULLY COMPATIBLE)

#### A. **Distance Distribution**
```sql
SELECT 
    CASE 
        WHEN trip_distance < 1 THEN '<1 mi'
        WHEN trip_distance < 2 THEN '1-2 mi'
        WHEN trip_distance < 5 THEN '2-5 mi'
        WHEN trip_distance < 10 THEN '5-10 mi'
        ELSE '10+ mi'
    END as distance_bucket,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare
FROM nyc_yellowtrip
WHERE trip_distance > 0
GROUP BY distance_bucket
ORDER BY MIN(trip_distance);
```
**Chart Types**: Histogram, Bar Chart
**Superset Charts**: ✅ Distance analysis

---

#### B. **Distance vs Fare Scatter Plot**
```sql
SELECT 
    trip_distance,
    total_amt,
    passenger_count
FROM nyc_yellowtrip
WHERE trip_distance > 0 
    AND trip_distance < 50
    AND total_amt > 0
    AND total_amt < 200;
```
**Chart Types**: Scatter Plot
**Superset Charts**: ✅ Correlation analysis
**Insight**: See if fare correlates with distance

---

#### C. **Trip Duration Analysis**
```sql
SELECT 
    HOUR(trip_pickup_datetime) as pickup_hour,
    AVG((UNIX_TIMESTAMP(trip_dropoff_datetime) - 
         UNIX_TIMESTAMP(trip_pickup_datetime)) / 60) as avg_duration_minutes,
    COUNT(*) as trips
FROM nyc_yellowtrip
GROUP BY pickup_hour
ORDER BY pickup_hour;
```
**Chart Types**: Line Chart, Bar Chart
**Superset Charts**: ✅ Duration patterns

---

### 4. Passenger Analysis Charts (FULLY COMPATIBLE)

#### A. **Passenger Count Distribution**
```sql
SELECT 
    passenger_count,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare,
    AVG(trip_distance) as avg_distance
FROM nyc_yellowtrip
WHERE passenger_count > 0
GROUP BY passenger_count
ORDER BY passenger_count;
```
**Chart Types**: Bar Chart, Pie Chart
**Superset Charts**: ✅ Passenger patterns

---

#### B. **Average Passengers by Hour**
```sql
SELECT 
    HOUR(trip_pickup_datetime) as hour_of_day,
    AVG(passenger_count) as avg_passengers,
    COUNT(*) as trips
FROM nyc_yellowtrip
GROUP BY hour_of_day
ORDER BY hour_of_day;
```
**Chart Types**: Line Chart, Area Chart
**Superset Charts**: ✅ Time-based passenger trends

---

### 5. Payment Analysis Charts (FULLY COMPATIBLE)

#### A. **Payment Type Distribution**
```sql
SELECT 
    payment_type,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare,
    AVG(tip_amt) as avg_tip,
    SUM(total_amt) as total_revenue
FROM nyc_yellowtrip
GROUP BY payment_type
ORDER BY trips DESC;
```
**Chart Types**: Pie Chart, Bar Chart
**Superset Charts**: ✅ Payment method analysis
**Insight**: 2009 Cash vs Credit patterns

---

#### B. **Tip Analysis by Payment Type**
```sql
SELECT 
    payment_type,
    AVG(tip_amt) as avg_tip,
    AVG(tip_amt / NULLIF(fare_amt, 0) * 100) as avg_tip_percentage,
    COUNT(*) as trips
FROM nyc_yellowtrip
WHERE fare_amt > 0
GROUP BY payment_type;
```
**Chart Types**: Grouped Bar Chart
**Superset Charts**: ✅ Tipping behavior
**Insight**: Credit card users tip more

---

### 6. Geographic Charts (SPECIAL HANDLING)

#### A. **Coordinate-Based Map (NO ZONES)**
```sql
-- Direct coordinate plotting
SELECT 
    start_lat as latitude,
    start_lon as longitude,
    COUNT(*) as trip_count,
    AVG(total_amt) as avg_fare
FROM nyc_yellowtrip
WHERE start_lat IS NOT NULL 
    AND start_lon IS NOT NULL
    AND start_lat BETWEEN 40.5 AND 41.0  -- NYC bounds
    AND start_lon BETWEEN -74.3 AND -73.7
GROUP BY start_lat, start_lon;
```
**Chart Types**: Deck.gl Scatterplot, Deck.gl Hexagon
**Superset Charts**: ⚠️ WORKS but without zone names
**Limitation**: No "Brooklyn", "Manhattan" labels - just coordinates

---

#### B. **Geographic Heatmap (Coordinates)**
```sql
SELECT 
    start_lat as pickup_lat,
    start_lon as pickup_lon,
    end_lat as dropoff_lat,
    end_lon as dropoff_lon,
    trip_distance,
    total_amt
FROM nyc_yellowtrip
WHERE start_lat IS NOT NULL 
    AND start_lon IS NOT NULL;
```
**Chart Types**: Deck.gl Arc Layer (origin-destination)
**Superset Charts**: ⚠️ WORKS but shows raw coordinates
**Use Case**: Visualize trip flows by coordinates

---

### 7. Vendor Analysis (UNIQUE TO YELLOW)

#### A. **Vendor Performance Comparison**
```sql
SELECT 
    vendor_name,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare,
    AVG(tip_amt) as avg_tip,
    AVG(trip_distance) as avg_distance
FROM nyc_yellowtrip
GROUP BY vendor_name;
```
**Chart Types**: Grouped Bar Chart, Radar Chart
**Superset Charts**: ✅ Vendor comparison
**Insight**: Which vendor (VTS, CMT, etc.) performs better?

---

### 8. Rate Code Analysis (UNIQUE TO YELLOW)

#### A. **Rate Code Distribution**
```sql
SELECT 
    CASE 
        WHEN rate_code = '' OR rate_code IS NULL THEN 'Standard'
        ELSE rate_code
    END as rate_type,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare,
    AVG(trip_distance) as avg_distance
FROM nyc_yellowtrip
GROUP BY rate_type;
```
**Chart Types**: Pie Chart, Bar Chart
**Superset Charts**: ✅ Rate code analysis
**Use Case**: Standard vs negotiated vs group rates

---

## ❌ Charts That DON'T WORK with Yellow Trip

### 1. **Top Pickup Locations by Zone Name**
```sql
-- ❌ CANNOT DO THIS - No LocationID
SELECT 
    Pickup_Location,  -- Doesn't exist!
    Zone,             -- Doesn't exist!
    COUNT(*) as trips
FROM nyc_yellowtrip
JOIN taxi_zones ON ... -- Can't join!
```
**Why it fails**: No `PULocationID` column
**Alternative**: Use coordinate-based map instead

---

### 2. **Borough-Level Analysis**
```sql
-- ❌ CANNOT DO THIS - No Borough reference
SELECT 
    Borough,  -- Can't determine from coordinates alone
    COUNT(*) as trips
FROM nyc_yellowtrip
```
**Why it fails**: Need complex geo-fencing to map coordinates to boroughs
**Alternative**: Manual coordinate range filtering (complex)

---

### 3. **Zone-to-Zone Trip Analysis**
```sql
-- ❌ CANNOT DO THIS - No LocationIDs
SELECT 
    pickup_zone,
    dropoff_zone,
    COUNT(*) as trips
FROM nyc_yellowtrip
```
**Why it fails**: No zone identifiers
**Alternative**: Coordinate-based clustering (advanced)

---

### 4. **Join with taxi_zones Table**
```sql
-- ❌ CANNOT DO THIS - No common key
SELECT 
    t.*,
    z.Zone,
    z.Borough
FROM nyc_yellowtrip t
JOIN taxi_zones z ON t.??? = z.LocationID  -- No match field!
```
**Why it fails**: Different data structure (coordinates vs IDs)
**Alternative**: Create spatial join (requires PostGIS or advanced GIS)

---

## 🔄 Workarounds for Missing LocationID

### Option 1: Simple Borough Classification (Approximate)
```sql
-- Rough Manhattan detection by coordinates
SELECT 
    CASE 
        WHEN start_lat BETWEEN 40.70 AND 40.88 
         AND start_lon BETWEEN -74.02 AND -73.90 
            THEN 'Likely Manhattan'
        WHEN start_lat < 40.70 THEN 'Likely Brooklyn/Queens'
        ELSE 'Other'
    END as rough_area,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare
FROM nyc_yellowtrip
WHERE start_lat IS NOT NULL
GROUP BY rough_area;
```
**Chart Types**: Pie Chart, Bar Chart
**Accuracy**: ~70-80% (rough estimation)

---

### Option 2: Cluster Coordinates (Advanced)
```sql
-- Group similar coordinates
SELECT 
    ROUND(start_lat, 2) as lat_cluster,
    ROUND(start_lon, 2) as lon_cluster,
    COUNT(*) as trips,
    AVG(total_amt) as avg_fare
FROM nyc_yellowtrip
GROUP BY lat_cluster, lon_cluster
HAVING trips > 2;
```
**Chart Types**: Heatmap Grid
**Use Case**: Find hotspot clusters

---

## 📊 Recommended Yellow Trip Dashboard

### Dashboard Layout (Without Zone Names)

**Section 1: Time Analysis**
✅ Trips Over Time (Line Chart)
✅ Busy Hours (Bar Chart)
✅ Day of Week Patterns (Radar Chart)

**Section 2: Financial Analysis**
✅ Total Revenue KPI
✅ Average Fare KPI
✅ Fare Distribution (Histogram)
✅ Fare Components (Stacked Bar)

**Section 3: Trip Characteristics**
✅ Distance Distribution (Histogram)
✅ Distance vs Fare (Scatter Plot)
✅ Trip Duration by Hour (Line Chart)

**Section 4: Passenger & Payment**
✅ Passenger Count (Bar Chart)
✅ Payment Type Distribution (Pie Chart)
✅ Tips by Payment Method (Grouped Bar)

**Section 5: Geographic (Coordinate-Based)**
⚠️ Pickup Coordinate Map (Scatter - no zone labels)
⚠️ Trip Flow Map (Arc visualization)

**Section 6: Unique Analysis**
✅ Vendor Comparison
✅ Rate Code Analysis

---

## 💡 Yellow Trip Strengths

### What Yellow Trip is BEST For:

1. **Historical Analysis** (2009 data)
   - Shows pre-Uber/Lyft era
   - Cash payment dominance
   - Traditional taxi operations

2. **Payment Method Studies**
   - Cash vs Credit in 2009
   - Tipping behavior evolution
   - Payment technology adoption

3. **Vendor Performance**
   - Compare VTS, CMT, etc.
   - Operational efficiency

4. **Coordinate-Level Precision**
   - Exact pickup/dropoff points
   - Street-level analysis
   - Route optimization potential

---

## 🎯 Chart Compatibility Summary

| Chart Type | Compatible? | Notes |
|------------|-------------|-------|
| Time Series | ✅ Yes | Full support |
| KPIs (Revenue, Fare) | ✅ Yes | Full support |
| Fare Distribution | ✅ Yes | Full support |
| Distance Analysis | ✅ Yes | Full support |
| Passenger Analysis | ✅ Yes | Full support |
| Payment Analysis | ✅ Yes | UNIQUE - has Cash/Credit |
| Coordinate Map | ⚠️ Partial | Works but no zone names |
| Borough Analysis | ❌ No | Need coordinate mapping |
| Zone-Level Analysis | ❌ No | No LocationID |
| Top Zones Table | ❌ No | No zone reference |
| Vendor Analysis | ✅ Yes | UNIQUE to Yellow |
| Rate Code Analysis | ✅ Yes | UNIQUE to Yellow |

---

## ✅ Recommended Approach

### For Yellow Trip Data:

**DO Use For:**
- ✅ Time-based analysis (all charts)
- ✅ Financial metrics (all charts)
- ✅ Trip characteristics (distance, duration)
- ✅ Payment method analysis
- ✅ Vendor comparison
- ✅ Historical comparison (2009 baseline)

**DON'T Use For:**
- ❌ Zone-specific analysis (unless you add spatial processing)
- ❌ Borough-level insights (without geo-fencing)
- ❌ "Top Locations" tables with zone names

**Combine With Green Trip:**
- Historical evolution (2009 → 2020)
- Payment method changes over time
- Fare inflation analysis
- Industry transformation (pre/post ride-share)

---

**Bottom Line**: Yellow Trip works for **~70% of standard charts** - all time-based, financial, and trip analysis charts work perfectly. Geographic analysis requires workarounds since it lacks LocationID.


