# ⚡ Performance Optimization Guide for Large-Scale NYC Taxi Data

## Problem: 2+ Billion Records Performance Issues

When dealing with **2+ billion records**, the standard aggregation query becomes impractical:
- Full table scans take hours
- Memory issues
- Timeout errors
- High compute costs

---

## 🎯 Solution Strategy

### 1. **Partition the Table** (MOST IMPORTANT)
### 2. **Create Materialized Views** (Pre-aggregate)
### 3. **Use Incremental Updates** (Not full scans)
### 4. **Add Indexes** (Speed up filtering)
### 5. **Limit Query Scope** (Date filters)

---

## Solution 1: Partitioned Table (RECOMMENDED)

### Create Partitioned Table by Date

```sql
-- Drop existing table
DROP TABLE IF EXISTS nyc_yellowtrip;

-- Create partitioned table
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
    format = 'PARQUET',
    partitioned_by = ARRAY['pickup_date'],  -- Partition by date!
    bucketed_by = ARRAY['vendor_name'],     -- Optional: bucket by vendor
    bucket_count = 10
);

-- Add computed partition column
ALTER TABLE nyc_yellowtrip 
ADD COLUMN pickup_date DATE 
AS DATE(trip_pickup_datetime);
```

### Benefits:
- ✅ Query only scans relevant partitions
- ✅ 100-1000x faster for date-filtered queries
- ✅ Trino can skip entire partitions
- ✅ Much lower cost

### Query with Partition Filtering:
```sql
-- FAST: Only scans last 30 days of data
SELECT 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    NULL as Pickup_Location,
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
WHERE pickup_date >= DATE '2024-01-01'  -- Partition filter!
    AND pickup_date < DATE '2024-02-01'
    AND trip_pickup_datetime IS NOT NULL
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H')
ORDER BY Pickup_Time;
```

**Performance**: 2 billion rows → only scans ~60 million rows (30 days)

---

## Solution 2: Materialized View (FASTEST)

### Create Pre-Aggregated Table

Instead of aggregating 2B rows on every query, pre-aggregate once:

```sql
-- Step 1: Create materialized aggregated table
CREATE TABLE nyc_taxi_aggregated_mat (
    pickup_date DATE,
    pickup_hour INT,
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
    partitioned_by = ARRAY['pickup_date', 'taxi_type']
);

-- Step 2: Populate with aggregated data (run once or incrementally)
INSERT INTO nyc_taxi_aggregated_mat
SELECT 
    DATE(trip_pickup_datetime) as pickup_date,
    HOUR(trip_pickup_datetime) as pickup_hour,
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    NULL as Pickup_Location,
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
WHERE DATE(trip_pickup_datetime) = DATE '2024-01-01'  -- Process one day at a time!
    AND trip_pickup_datetime IS NOT NULL
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY 
    DATE(trip_pickup_datetime),
    HOUR(trip_pickup_datetime),
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H');
```

### Incremental Daily Update Script:
```sql
-- Run this daily to update with new data
-- This only processes yesterday's data (much faster!)
INSERT INTO nyc_taxi_aggregated_mat
SELECT 
    DATE(trip_pickup_datetime) as pickup_date,
    HOUR(trip_pickup_datetime) as pickup_hour,
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    NULL as Pickup_Location,
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
WHERE DATE(trip_pickup_datetime) = CURRENT_DATE - INTERVAL '1' DAY  -- Yesterday only!
    AND trip_pickup_datetime IS NOT NULL
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY 
    DATE(trip_pickup_datetime),
    HOUR(trip_pickup_datetime),
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H');
```

### Query the Materialized View (INSTANT):
```sql
-- This is now INSTANT - no aggregation needed!
SELECT * FROM nyc_taxi_aggregated_mat
WHERE pickup_date >= DATE '2024-01-01'
ORDER BY Pickup_Time;
```

**Performance**: 
- First aggregation: Hours (but run once per day)
- Subsequent queries: Milliseconds!
- Result: ~8,760 rows/year (24 hours × 365 days) instead of 2B rows

---

## Solution 3: Approximate Aggregations (FAST but Approximate)

For exploratory analysis, use approximate functions:

```sql
-- Use APPROX functions for 10-100x speedup
SELECT 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    APPROX_COUNT_DISTINCT(vendor_name) as approx_vendors,
    APPROX_SUM(total_amt) as approx_total_amount,  -- Fast approximate sum
    APPROX_AVG(total_amt) as approx_avg_fare,       -- Fast approximate average
    APPROX_PERCENTILE(total_amt, 0.5) as median_fare,
    COUNT(*) as number
FROM nyc_yellowtrip
WHERE trip_pickup_datetime >= TIMESTAMP '2024-01-01 00:00:00'
    AND trip_pickup_datetime < TIMESTAMP '2024-02-01 00:00:00'
    AND total_amt > 0
GROUP BY DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H')
LIMIT 1000;
```

**Accuracy**: ±1-2% error (acceptable for dashboards)
**Performance**: 10-100x faster

---

## Solution 4: Add Date Filter ALWAYS

### ❌ BAD - Scans entire 2B rows:
```sql
SELECT COUNT(*) FROM nyc_yellowtrip;  -- SLOW!
```

### ✅ GOOD - Scans only recent data:
```sql
-- Always include date filter!
SELECT COUNT(*) 
FROM nyc_yellowtrip
WHERE trip_pickup_datetime >= CURRENT_DATE - INTERVAL '30' DAY;  -- FAST!
```

### Updated View with Date Filter:
```sql
CREATE OR REPLACE VIEW nyc_taxi_aggregated AS
SELECT 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    NULL as Pickup_Location,
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
WHERE trip_pickup_datetime >= CURRENT_DATE - INTERVAL '90' DAY  -- Only last 90 days!
    AND trip_pickup_datetime IS NOT NULL
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H');
```

---

## Solution 5: Sampling for Dashboards

For exploratory dashboards, use sampling:

```sql
-- Sample 1% of data for dashboard preview
SELECT 
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    SUM(total_amt) * 100 as Estimated_Total_Amount,  -- Scale up by 100
    AVG(total_amt) as AVG_Total_Amount,
    COUNT(*) * 100 as Estimated_Trips,  -- Scale up by 100
    'yellow' as taxi_type
FROM nyc_yellowtrip TABLESAMPLE BERNOULLI (1)  -- Sample 1%
WHERE trip_pickup_datetime >= CURRENT_DATE - INTERVAL '30' DAY
    AND trip_pickup_datetime IS NOT NULL
    AND total_amt > 0
GROUP BY DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H');
```

**Performance**: 100x faster (scans 20M instead of 2B rows)
**Use Case**: Dashboard prototyping, exploratory analysis

---

## Solution 6: Use Bucketing for High-Cardinality Grouping

If you need to group by coordinates (high cardinality):

```sql
-- Create bucketed table
CREATE TABLE nyc_yellowtrip_bucketed (
    -- all columns
)
WITH (
    format = 'PARQUET',
    partitioned_by = ARRAY['pickup_date'],
    bucketed_by = ARRAY['location_bucket'],
    bucket_count = 1000
);

-- Add location bucket column
ALTER TABLE nyc_yellowtrip_bucketed
ADD COLUMN location_bucket INT AS 
    CAST(FLOOR(start_lat * 1000) AS INT) * 1000 + 
    CAST(FLOOR(start_lon * 1000) AS INT);

-- Query is now much faster
SELECT 
    location_bucket,
    COUNT(*) as trips
FROM nyc_yellowtrip_bucketed
WHERE pickup_date >= DATE '2024-01-01'
GROUP BY location_bucket;
```

---

## Solution 7: Scheduled Aggregation Job

### Daily Aggregation Pipeline:

```bash
#!/bin/bash
# run_daily_aggregation.sh
# Schedule with cron: 0 2 * * * /path/to/run_daily_aggregation.sh

YESTERDAY=$(date -d "yesterday" +%Y-%m-%d)

trino --server localhost:8080 --catalog hive --schema nyc_taxi << EOF

-- Aggregate yesterday's data only
INSERT INTO nyc_taxi_aggregated_mat
SELECT 
    DATE(trip_pickup_datetime) as pickup_date,
    HOUR(trip_pickup_datetime) as pickup_hour,
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
    NULL as Pickup_Location,
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
WHERE DATE(trip_pickup_datetime) = DATE '$YESTERDAY'
    AND trip_pickup_datetime IS NOT NULL
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY 
    DATE(trip_pickup_datetime),
    HOUR(trip_pickup_datetime),
    DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H');

EOF

echo "Aggregation complete for $YESTERDAY"
```

**Schedule**: Run at 2 AM daily via cron
**Result**: Dashboard always shows up-to-date data without slow queries

---

## Comparison Table

| Solution | Performance | Complexity | Best For |
|----------|-------------|------------|----------|
| **Partitioned Table** | 100-1000x faster | Medium | Production |
| **Materialized View** | 10,000x faster | Medium | Dashboards |
| **Approximate Agg** | 10-100x faster | Low | Exploratory |
| **Date Filtering** | 10-100x faster | Very Low | All queries |
| **Sampling** | 100x faster | Low | Prototyping |
| **Incremental Updates** | N/A | High | Data Pipeline |

---

## Recommended Architecture for 2B+ Records

### Ideal Setup:

```
┌─────────────────────────────────────────────────────┐
│           Raw Data (2B+ records)                    │
│   Partitioned by: pickup_date                       │
│   Format: Parquet (compressed)                      │
│   Storage: S3 / HDFS                                │
└────────────────┬────────────────────────────────────┘
                 │
                 │ Daily Aggregation Job (2 AM)
                 ↓
┌─────────────────────────────────────────────────────┐
│      Materialized Aggregated Table                  │
│   ~8,760 rows/year (hourly aggregates)             │
│   Partitioned by: pickup_date, taxi_type            │
│   Updates: Incremental (yesterday's data)           │
└────────────────┬────────────────────────────────────┘
                 │
                 │ Superset Queries (milliseconds)
                 ↓
┌─────────────────────────────────────────────────────┐
│            Superset Dashboard                        │
│   - Real-time KPIs                                  │
│   - Interactive charts                              │
│   - Sub-second response times                       │
└─────────────────────────────────────────────────────┘
```

---

## Quick Win: Immediate Fix for Your Query

### Replace this (SLOW):
```sql
FROM lakehouse.ws_55ccd057_4fff_4d3f_92d7_212ebac1d7cf.nyc_yellowtrip
WHERE trip_pickup_datetime IS NOT NULL
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H')
```

### With this (FAST):
```sql
FROM lakehouse.ws_55ccd057_4fff_4d3f_92d7_212ebac1d7cf.nyc_yellowtrip
WHERE trip_pickup_datetime >= TIMESTAMP '2024-01-01 00:00:00'  -- ADD THIS!
    AND trip_pickup_datetime < TIMESTAMP '2024-02-01 00:00:00'
    AND total_amt > 0
    AND trip_distance > 0
GROUP BY DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H')
LIMIT 10000;  -- ADD THIS TOO!
```

**Improvement**: 100x faster (processes 1 month instead of all data)

---

## Monitoring Query Performance

### Check query execution time:
```sql
-- Enable query profiling
SET SESSION query_max_execution_time = '5m';

-- Check explain plan
EXPLAIN ANALYZE
SELECT ...;

-- Look for:
-- - Partition filters being used
-- - Number of rows scanned
-- - Memory usage
```

---

## Best Practices Summary

### ✅ DO:
1. **Partition by date** (pickup_date)
2. **Create materialized aggregated tables**
3. **Always add date filters** (last 30-90 days)
4. **Use incremental updates** (process only new data)
5. **Add LIMIT clauses** during development
6. **Use approximate functions** for exploration
7. **Monitor query costs** and execution times

### ❌ DON'T:
1. ❌ Scan entire 2B row table without filters
2. ❌ Create views without date restrictions
3. ❌ Run ad-hoc aggregations on full dataset
4. ❌ Forget to add LIMIT during testing
5. ❌ Use SELECT * on large tables
6. ❌ Create too many small partitions (<1GB each)

---

## Cost Optimization

For cloud environments (AWS, GCP, Azure):

**Without optimization**: 
- Full scan: 2B rows × 200 bytes ≈ 400 GB scanned
- Cost: ~$2-5 per query (depending on cloud provider)

**With partitioning + date filter**:
- Filtered scan: 60M rows × 200 bytes ≈ 12 GB scanned
- Cost: ~$0.06 per query

**With materialized view**:
- Pre-aggregated: 8,760 rows × 200 bytes ≈ 1.7 MB scanned
- Cost: ~$0.0001 per query

**Savings**: 40,000x cost reduction! 💰

---

## Next Steps

1. **Immediate**: Add date filters to all queries
2. **Short-term**: Create partitioned table
3. **Medium-term**: Build materialized aggregated table
4. **Long-term**: Set up incremental daily aggregation pipeline

---

**Your query with 2B records will go from hours to milliseconds!** ⚡


