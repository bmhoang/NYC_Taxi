# 📊 Sample Data Analysis & Aggregation Strategy

## Sample Data Review (10 rows each)

### ✅ Table 1: nyc_greentrip.csv (BEST FIT)
**Columns Available:**
- `lpep_pickup_datetime` ✓
- `pulocationid` ✓ (Perfect!)
- `dolocationid` ✓
- `passenger_count` ✓
- `trip_distance` ✓
- `fare_amount` ✓
- `extra` ✓
- `mta_tax` ✓
- `tip_amount` ✓
- `tolls_amount` ✓
- `total_amount` ✓
- `payment_type` ✓
- `vendorid` ✓

**Assessment**: ⭐⭐⭐⭐⭐ PERFECT MATCH! This has ALL required columns for aggregation.

---

### ⚠️ Table 2: nyc_yellowtrip.csv (NEEDS MAPPING)
**Columns Available:**
- `trip_pickup_datetime` ✓
- `start_lon`, `start_lat` ⚠️ (Coordinates, NOT LocationID)
- `end_lon`, `end_lat` ⚠️
- `passenger_count` ✓
- `trip_distance` ✓
- `fare_amt` ✓
- `surcharge` ⚠️ (Different from 'extra')
- `tip_amt` ✓
- `tolls_amt` ✓
- `total_amt` ✓

**Assessment**: ⭐⭐⭐ USABLE but old format (2009). Missing:
- `PULocationID` - has lat/lon instead
- `extra` column - has surcharge instead
- Needs coordinate-to-zone mapping

---

### ❌ Table 3: nyc_for_hire_vehicle.csv (NOT USABLE)
**Columns Available:**
- `pickup_datetime` ✓
- `pulocationid` ✓ (but many nulls)
- `dolocationid` ✓ (but many nulls)

**Missing Critical Data:**
- ❌ No fare_amount
- ❌ No trip_distance
- ❌ No passenger_count
- ❌ No tip_amount
- ❌ No total_amount

**Assessment**: ⭐ Cannot create meaningful aggregation - missing financial data.

---

### ⚠️ Table 4: nyc_highvolume_for_hire_vehicle.csv (PARTIALLY USABLE)
**Columns Available:**
- `pickup_datetime` ✓
- `pulocationid` ✓
- `dolocationid` ✓
- `trip_miles` ✓ (instead of trip_distance)
- `base_passenger_fare` ⚠️ (not total_amount)
- `tolls` ✓
- `tips` ✓
- `sales_tax` ✓
- `congestion_surcharge` ✓

**Missing:**
- ❌ No passenger_count
- ❌ No clear total_amount (need to calculate)

**Assessment**: ⭐⭐⭐ Can be adapted but requires calculation.

---

## 🎯 Recommendation: Use Green Trip Data

**Best Option**: `nyc_greentrip.csv`
- Has all required columns
- Modern format (2020)
- Includes LocationID (no mapping needed)
- Ready for direct aggregation

---

## SQL Scripts to Create Aggregated View

### Option A: Use Green Trip Data Only (Recommended)

```sql
-- Create aggregated view from Green Taxi data
CREATE OR REPLACE VIEW nyc_taxi_aggregated AS
SELECT 
    -- Extract hour from pickup datetime
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
    AVG(passenger_count) as AVG_Passenger_Count,
    
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
```

---

### Option B: Combine Green + Yellow (Requires Coordinate Mapping)

```sql
-- Step 1: Create view for Green Taxi
CREATE OR REPLACE VIEW green_aggregated AS
SELECT 
    DATE_FORMAT(lpep_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    pulocationid as Pickup_Location,
    SUM(total_amount) as Total_Amount,
    AVG(total_amount) as AVG_Total_Amount,
    SUM(trip_distance) as Total_Trip_Distance,
    AVG(trip_distance) as AVG_Trip_Distance,
    SUM(passenger_count) as Total_Passenger_Count,
    AVG(passenger_count) as AVG_Passenger_Count,
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

-- Step 2: Create view for Yellow Taxi (simplified - without location mapping)
CREATE OR REPLACE VIEW yellow_aggregated AS
SELECT 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    NULL as Pickup_Location,  -- Old data doesn't have LocationID
    SUM(total_amt) as Total_Amount,
    AVG(total_amt) as AVG_Total_Amount,
    SUM(trip_distance) as Total_Trip_Distance,
    AVG(trip_distance) as AVG_Trip_Distance,
    SUM(passenger_count) as Total_Passenger_Count,
    AVG(passenger_count) as AVG_Passenger_Count,
    SUM(fare_amt) as Fare_Amount,
    SUM(surcharge) as Extra,  -- Note: surcharge instead of extra
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

-- Step 3: Combine both
CREATE OR REPLACE VIEW nyc_taxi_aggregated AS
SELECT * FROM green_aggregated
UNION ALL
SELECT * FROM yellow_aggregated;
```

---

### Option C: Include High Volume For-Hire (Advanced)

```sql
-- Add high volume for-hire vehicles (Uber, Lyft, etc.)
CREATE OR REPLACE VIEW hvfhv_aggregated AS
SELECT 
    DATE_FORMAT(pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    pulocationid as Pickup_Location,
    
    -- Calculate total_amount (not directly available)
    SUM(base_passenger_fare + COALESCE(tolls, 0) + COALESCE(sales_tax, 0) + 
        COALESCE(congestion_surcharge, 0) + COALESCE(airport_fee, 0)) as Total_Amount,
    AVG(base_passenger_fare + COALESCE(tolls, 0) + COALESCE(sales_tax, 0) + 
        COALESCE(congestion_surcharge, 0) + COALESCE(airport_fee, 0)) as AVG_Total_Amount,
    
    SUM(trip_miles) as Total_Trip_Distance,
    AVG(trip_miles) as AVG_Trip_Distance,
    
    -- No passenger count available
    0 as Total_Passenger_Count,
    0 as AVG_Passenger_Count,
    
    SUM(base_passenger_fare) as Fare_Amount,
    SUM(COALESCE(congestion_surcharge, 0) + COALESCE(airport_fee, 0)) as Extra,
    SUM(COALESCE(tips, 0)) as tip_amount,
    SUM(COALESCE(tolls, 0)) as tolls_amount,
    COUNT(*) as number,
    'hvfhv' as taxi_type
    
FROM nyc_highvolume_for_hire_vehicle
WHERE pickup_datetime IS NOT NULL
    AND base_passenger_fare > 0
    AND trip_miles > 0
    AND pulocationid IS NOT NULL
GROUP BY 
    DATE_FORMAT(pickup_datetime, '%Y-%m-%d %H'),
    pulocationid;

-- Combine all three types
CREATE OR REPLACE VIEW nyc_taxi_aggregated AS
SELECT * FROM green_aggregated
UNION ALL
SELECT * FROM yellow_aggregated
UNION ALL
SELECT * FROM hvfhv_aggregated;
```

---

## 🐍 Python Script to Load Sample Data into Trino

```python
"""
Load sample CSV data into Trino and create aggregated view
"""

from trino.dbapi import connect
import pandas as pd

# Configuration
TRINO_HOST = 'localhost'
TRINO_PORT = 8080
TRINO_CATALOG = 'hive'
TRINO_SCHEMA = 'nyc_taxi'

# Connect to Trino
conn = connect(
    host=TRINO_HOST,
    port=TRINO_PORT,
    user='admin',
    catalog=TRINO_CATALOG,
    schema=TRINO_SCHEMA
)

cursor = conn.cursor()

# Create schema
cursor.execute(f"CREATE SCHEMA IF NOT EXISTS {TRINO_SCHEMA}")
print(f"✓ Created schema: {TRINO_SCHEMA}")

# Step 1: Load Green Trip data
print("\nLoading Green Trip data...")
green_df = pd.read_csv('sampledata/nyc_greentrip.csv')

# Create table for raw green trip data
cursor.execute("""
    CREATE TABLE IF NOT EXISTS nyc_greentrip (
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
        ehail_fee DOUBLE,
        improvement_surcharge DOUBLE,
        total_amount DOUBLE,
        payment_type INT,
        trip_type DOUBLE,
        congestion_surcharge DOUBLE
    )
""")

# Insert data (in real scenario, use LOAD DATA or external table)
# For sample, we'll create the aggregated view directly

# Step 2: Create aggregated view
print("\nCreating nyc_taxi_aggregated view...")
cursor.execute("""
    CREATE OR REPLACE VIEW nyc_taxi_aggregated AS
    SELECT 
        DATE_FORMAT(lpep_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
        pulocationid as Pickup_Location,
        SUM(total_amount) as Total_Amount,
        AVG(total_amount) as AVG_Total_Amount,
        SUM(trip_distance) as Total_Trip_Distance,
        AVG(trip_distance) as AVG_Trip_Distance,
        SUM(passenger_count) as Total_Passenger_Count,
        AVG(passenger_count) as AVG_Passenger_Count,
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
        pulocationid
""")

print("✓ Created nyc_taxi_aggregated view")

# Verify
cursor.execute("SELECT COUNT(*) FROM nyc_taxi_aggregated")
count = cursor.fetchone()[0]
print(f"\n✓ Aggregated view has {count} rows")

# Sample query
cursor.execute("SELECT * FROM nyc_taxi_aggregated LIMIT 5")
rows = cursor.fetchall()
print("\nSample data:")
for row in rows:
    print(row)

conn.close()
```

---

## 📋 Step-by-Step Instructions

### Using Green Trip Data (Simplest)

**Step 1: Create table in Trino**
```bash
trino --server localhost:8080 --catalog hive --schema nyc_taxi
```

**Step 2: Load CSV file**
```sql
-- Option A: Create external table pointing to CSV
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
    ehail_fee DOUBLE,
    improvement_surcharge DOUBLE,
    total_amount DOUBLE,
    payment_type INT,
    trip_type DOUBLE,
    congestion_surcharge DOUBLE
)
WITH (
    format = 'CSV',
    external_location = 'file:///e:/source/NYC_Taxi/sampledata/',
    csv_separator = ',',
    skip_header_line_count = 1
);
```

**Step 3: Create aggregated view**
```sql
-- Copy the SQL from Option A above
CREATE OR REPLACE VIEW nyc_taxi_aggregated AS ...
```

**Step 4: Verify**
```sql
SELECT * FROM nyc_taxi_aggregated;
-- Should return aggregated rows grouped by hour and location
```

---

## ✅ Summary

**Can we create `nyc_taxi_aggregated` from sample data?**

✅ **YES!** Best option: **Use `nyc_greentrip.csv`**

**Why Green Trip is Perfect:**
1. ✅ Has PULocationID (no coordinate mapping needed)
2. ✅ Has all required columns
3. ✅ Modern format (2020 data)
4. ✅ Direct aggregation possible
5. ✅ Only 11 rows but demonstrates structure

**Limitations with 11 rows:**
- Only represents ~10 hours of data for a few locations
- Won't show full NYC coverage (263 zones)
- Limited for testing time-series visualizations
- But PERFECT for proof-of-concept and structure validation

**Next Step:**
Run the SQL script in the next file I'll create!

