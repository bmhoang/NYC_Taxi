# 📥 Data Ingestion Guide - Creating Tables in Trino

This guide shows you how to get NYC Taxi data from source and load it into Trino for your Superset dashboard.

---

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [Step 1: Download Raw Data](#step-1-download-raw-data)
3. [Step 2: Process Data with PySpark](#step-2-process-data-with-pyspark)
4. [Step 3: Get Taxi Zones Data](#step-3-get-taxi-zones-data)
5. [Step 4: Load Data into Trino](#step-4-load-data-into-trino)
6. [Step 5: Verify Tables](#step-5-verify-tables)
7. [Alternative: Sample Data for Testing](#alternative-sample-data-for-testing)

---

## Prerequisites

### Required Software:
- **Python 3.7+** with PySpark
- **Trino** cluster running
- **Storage**: Hive, S3, or local file system
- At least **50GB free disk space** (for processing)

### Install Dependencies:
```bash
# Install PySpark
pip install pyspark

# Install Pandas (for data processing)
pip install pandas

# Install Trino CLI (optional, for testing)
pip install trino-python-client
```

---

## Step 1: Download Raw Data

### Option A: Download from NYC TLC Website (Official Source)

**NYC Taxi & Limousine Commission Data**: https://www1.nyc.gov/site/tlc/about/tlc-trip-record-data.page

```bash
# Create data directory
mkdir -p ~/nyc_taxi_data/raw
cd ~/nyc_taxi_data/raw

# Download Yellow Taxi data (example: 2018)
# Yellow taxi data URLs format: https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_YYYY-MM.parquet

# Download using wget or curl (example for Jan-Dec 2018)
for month in {01..12}; do
    wget https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2018-${month}.parquet
done

# Download Green Taxi data (example: 2018)
for month in {01..12}; do
    wget https://d37ci6vzurychx.cloudfront.net/trip-data/green_tripdata_2018-${month}.parquet
done
```

**Note**: Recent data is in Parquet format. Older data (2017-2018) may be in CSV format:
```bash
# For CSV format (older data)
wget https://s3.amazonaws.com/nyc-tlc/trip+data/yellow_tripdata_2018-01.csv
```

### Option B: Use AWS S3 Public Dataset

NYC Taxi data is available on AWS Open Data:
```bash
# Using AWS CLI
aws s3 ls s3://nyc-tlc/trip-data/ --no-sign-request

# Download specific files
aws s3 cp s3://nyc-tlc/trip-data/yellow_tripdata_2018-01.parquet . --no-sign-request
```

### Option C: Download Sample Data (For Testing)

```bash
# Download just one month for testing
wget https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-01.parquet
wget https://d37ci6vzurychx.cloudfront.net/trip-data/green_tripdata_2024-01.parquet
```

---

## Step 2: Process Data with PySpark

### Update the Existing PySparkCalculation.py Script

The project already has `Scripts/PySparkCalculation.py`. Let's update it for Trino:

**Create: `Scripts/PySparkCalculation_Updated.py`**

```python
"""
Updated PySpark script to process NYC Taxi data for Trino/Superset
Creates aggregated table: nyc_taxi_aggregated
"""

from pyspark.sql import SparkSession
from pyspark.sql.functions import substring, sum, avg, count, col
import os

# Configuration
INPUT_PATH = "/path/to/nyc_taxi_data/raw"  # Update this
OUTPUT_PATH = "/path/to/nyc_taxi_data/processed"  # Update this
TAXI_TYPE = "yellow"  # or "green"
YEAR = "2018"
MONTHS = ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"]

# Initialize Spark Session
spark = SparkSession.builder \
    .appName("NYC Taxi Data Processing for Trino") \
    .config("spark.sql.adaptive.enabled", "true") \
    .config("spark.driver.memory", "4g") \
    .config("spark.executor.memory", "4g") \
    .getOrCreate()

print(f"Processing {TAXI_TYPE} taxi data for {YEAR}")

# Create output directory
os.makedirs(OUTPUT_PATH, exist_ok=True)

for month in MONTHS:
    print(f"\n{'='*60}")
    print(f"Processing {YEAR}-{month}")
    print(f"{'='*60}")
    
    try:
        # Construct file path (adjust extension based on your data format)
        file_path = f"{INPUT_PATH}/{TAXI_TYPE}_tripdata_{YEAR}-{month}.parquet"
        
        # Try Parquet first, fall back to CSV
        if os.path.exists(file_path):
            df = spark.read.parquet(file_path)
        else:
            file_path = f"{INPUT_PATH}/{TAXI_TYPE}_tripdata_{YEAR}-{month}.csv"
            df = spark.read.csv(file_path, header=True, inferSchema=True)
        
        print(f"Loaded {df.count()} rows from {file_path}")
        
        # Register as temporary view
        df.createOrReplaceTempView(f"taxi_{YEAR}{month}")
        
        # Determine pickup datetime column name (varies by taxi type and year)
        # Yellow: tpep_pickup_datetime, Green: lpep_pickup_datetime
        pickup_col = "tpep_pickup_datetime" if TAXI_TYPE == "yellow" else "lpep_pickup_datetime"
        
        # Aggregate data by hour and pickup location
        aggregated = spark.sql(f"""
            SELECT 
                SUBSTRING({pickup_col}, 1, 13) AS Pickup_Time,
                PULocationID AS Pickup_Location,
                SUM(total_amount) AS Total_Amount,
                AVG(total_amount) AS AVG_Total_Amount,
                SUM(trip_distance) AS Total_Trip_Distance,
                AVG(trip_distance) AS AVG_Trip_Distance,
                SUM(passenger_count) AS Total_Passenger_Count,
                AVG(passenger_count) AS AVG_Passenger_Count,
                SUM(fare_amount) AS Fare_Amount,
                SUM(extra) AS Extra,
                SUM(tip_amount) AS tip_amount,
                SUM(tolls_amount) AS tolls_amount,
                COUNT(*) AS number,
                '{TAXI_TYPE}' AS taxi_type
            FROM taxi_{YEAR}{month}
            WHERE {pickup_col} IS NOT NULL
                AND SUBSTRING({pickup_col}, 1, 7) = '{YEAR}-{month}'
                AND total_amount > 0
                AND trip_distance > 0
                AND PULocationID IS NOT NULL
            GROUP BY SUBSTRING({pickup_col}, 1, 13), PULocationID
            ORDER BY Pickup_Time, Pickup_Location
        """)
        
        print(f"Aggregated to {aggregated.count()} rows")
        
        # Save as Parquet (efficient format for Trino)
        output_file = f"{OUTPUT_PATH}/{TAXI_TYPE}_{YEAR}{month}_aggregated"
        aggregated.write.mode("overwrite").parquet(output_file)
        
        print(f"✓ Saved to {output_file}")
        
    except Exception as e:
        print(f"✗ Error processing {YEAR}-{month}: {str(e)}")
        continue

print(f"\n{'='*60}")
print("Processing completed!")
print(f"{'='*60}")

# Combine all monthly files into one (optional)
print("\nCombining all months into single table...")
all_files = [f"{OUTPUT_PATH}/{TAXI_TYPE}_{YEAR}{month}_aggregated" 
             for month in MONTHS 
             if os.path.exists(f"{OUTPUT_PATH}/{TAXI_TYPE}_{YEAR}{month}_aggregated")]

if all_files:
    combined = spark.read.parquet(*all_files)
    combined.write.mode("overwrite").parquet(f"{OUTPUT_PATH}/{TAXI_TYPE}_{YEAR}_all_aggregated")
    print(f"✓ Combined file saved: {OUTPUT_PATH}/{TAXI_TYPE}_{YEAR}_all_aggregated")
    print(f"Total rows: {combined.count()}")
else:
    print("✗ No files to combine")

spark.stop()
```

### Run the Script:

```bash
# Update paths in the script first
python Scripts/PySparkCalculation_Updated.py
```

### Expected Output:
```
Processing yellow taxi data for 2018
============================================================
Processing 2018-01
============================================================
Loaded 8760687 rows from yellow_tripdata_2018-01.parquet
Aggregated to 145234 rows
✓ Saved to /path/to/processed/yellow_201801_aggregated
...
```

---

## Step 3: Get Taxi Zones Data

### Download Taxi Zone Lookup Table

```bash
# Create directory
mkdir -p ~/nyc_taxi_data/zones
cd ~/nyc_taxi_data/zones

# Download taxi zone lookup CSV
wget https://d37ci6vzurychx.cloudfront.net/misc/taxi+_zone_lookup.csv

# Download shapefile (for map coordinates)
wget https://d37ci6vzurychx.cloudfront.net/misc/taxi_zones.zip
unzip taxi_zones.zip
```

### Process Taxi Zones with Latitude/Longitude

**Create: `Scripts/create_taxi_zones_table.py`**

```python
"""
Create taxi_zones table with latitude/longitude from shapefile
"""

import pandas as pd
import geopandas as gpd

# Read the taxi zone lookup
zones_csv = pd.read_csv('taxi+_zone_lookup.csv')

# Read the shapefile for geographic coordinates
zones_shp = gpd.read_file('taxi_zones.shp')

# Calculate centroid (center point) of each zone
zones_shp['longitude'] = zones_shp.geometry.centroid.x
zones_shp['latitude'] = zones_shp.geometry.centroid.y

# Merge with lookup data
zones_merged = zones_shp.merge(
    zones_csv,
    left_on='LocationID',
    right_on='LocationID',
    how='left'
)

# Select and rename columns
taxi_zones = zones_merged[[
    'LocationID',
    'Borough',
    'Zone',
    'service_zone',
    'latitude',
    'longitude'
]]

# Save as CSV for loading into Trino
taxi_zones.to_csv('taxi_zones_with_coords.csv', index=False)

print(f"Created taxi_zones table with {len(taxi_zones)} zones")
print("\nSample data:")
print(taxi_zones.head())
```

**Run it:**
```bash
pip install geopandas
python Scripts/create_taxi_zones_table.py
```

---

## Step 4: Load Data into Trino

### Option A: Load into Hive (Recommended)

If your Trino uses Hive connector:

**Step 4.1: Create Hive External Tables**

```sql
-- Connect to Hive or use Trino CLI
trino --server localhost:8080 --catalog hive --schema default

-- Create schema
CREATE SCHEMA IF NOT EXISTS nyc_taxi;

-- Create nyc_taxi_aggregated table
CREATE TABLE nyc_taxi.nyc_taxi_aggregated (
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

-- Load data (if using Hive)
LOAD DATA INPATH '/path/to/processed/yellow_2018_all_aggregated' 
INTO TABLE nyc_taxi.nyc_taxi_aggregated;

-- Create taxi_zones table
CREATE TABLE nyc_taxi.taxi_zones (
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
```

### Option B: Load from S3

```sql
-- If using S3 as storage
CREATE TABLE nyc_taxi.nyc_taxi_aggregated (
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
```

### Option C: Load from Local CSV (For Testing)

```sql
-- Convert Parquet to CSV first
CREATE TABLE nyc_taxi.nyc_taxi_aggregated (
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
```

### Load Taxi Zones Table:

```bash
# Convert shapefile data to CSV
python Scripts/create_taxi_zones_table.py

# Copy to Trino accessible location
# Then create table in Trino
```

```sql
CREATE TABLE nyc_taxi.taxi_zones (
    LocationID INT,
    Borough VARCHAR,
    Zone VARCHAR,
    service_zone VARCHAR,
    latitude DOUBLE,
    longitude DOUBLE
)
WITH (
    format = 'CSV',
    external_location = 'file:///path/to/taxi_zones/',
    csv_separator = ',',
    skip_header_line_count = 1
);
```

---

## Step 5: Verify Tables

### Test in Trino CLI:

```sql
-- Connect to Trino
trino --server localhost:8080 --catalog hive --schema nyc_taxi

-- Check if tables exist
SHOW TABLES;

-- Count rows
SELECT COUNT(*) FROM nyc_taxi_aggregated;
-- Expected: ~2-3 million rows per year

SELECT COUNT(*) FROM taxi_zones;
-- Expected: 263 rows (NYC has 263 taxi zones)

-- Sample data
SELECT * FROM nyc_taxi_aggregated LIMIT 10;

SELECT * FROM taxi_zones LIMIT 10;

-- Test join
SELECT 
    t.Pickup_Time,
    z.Zone,
    z.Borough,
    t.number as trips
FROM nyc_taxi_aggregated t
JOIN taxi_zones z ON t.Pickup_Location = z.LocationID
ORDER BY t.Pickup_Time DESC
LIMIT 10;

-- Verify data quality
SELECT 
    taxi_type,
    COUNT(*) as record_count,
    MIN(Pickup_Time) as earliest_date,
    MAX(Pickup_Time) as latest_date,
    SUM(number) as total_trips
FROM nyc_taxi_aggregated
GROUP BY taxi_type;
```

**Expected Output:**
```
taxi_type | record_count | earliest_date  | latest_date    | total_trips
----------|--------------|----------------|----------------|------------
yellow    | 1,850,432    | 2018-01-01 00  | 2018-12-31 23  | 112,608,261
green     | 645,123      | 2018-01-01 00  | 2018-12-31 23  | 24,521,456
```

---

## Alternative: Sample Data for Testing

If you want to test the dashboard without downloading full datasets:

### Quick Test with Sample Data

**Create: `Scripts/generate_sample_data.py`**

```python
"""
Generate sample NYC Taxi data for testing
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta

# Generate sample aggregated data
np.random.seed(42)

# 30 days, 24 hours, 100 top locations
dates = pd.date_range('2024-01-01', periods=30*24, freq='H')
locations = range(1, 101)

data = []
for date in dates:
    for location in np.random.choice(locations, size=50, replace=False):
        data.append({
            'Pickup_Time': date.strftime('%Y-%m-%d %H'),
            'Pickup_Location': int(location),
            'Total_Amount': round(np.random.uniform(500, 5000), 2),
            'AVG_Total_Amount': round(np.random.uniform(15, 50), 2),
            'Total_Trip_Distance': round(np.random.uniform(50, 500), 2),
            'AVG_Trip_Distance': round(np.random.uniform(2, 15), 2),
            'Total_Passenger_Count': int(np.random.uniform(50, 200)),
            'AVG_Passenger_Count': round(np.random.uniform(1.2, 2.5), 2),
            'Fare_Amount': round(np.random.uniform(400, 4000), 2),
            'Extra': round(np.random.uniform(20, 200), 2),
            'tip_amount': round(np.random.uniform(50, 800), 2),
            'tolls_amount': round(np.random.uniform(0, 200), 2),
            'number': int(np.random.uniform(20, 150)),
            'taxi_type': np.random.choice(['yellow', 'green'], p=[0.7, 0.3])
        })

df = pd.DataFrame(data)
df.to_csv('sample_nyc_taxi_aggregated.csv', index=False)
print(f"Generated {len(df)} sample records")

# Generate sample taxi zones
zones_data = []
for i in range(1, 101):
    zones_data.append({
        'LocationID': i,
        'Borough': np.random.choice(['Manhattan', 'Brooklyn', 'Queens', 'Bronx', 'Staten Island']),
        'Zone': f'Zone {i}',
        'service_zone': 'Boro Zone' if i > 50 else 'Yellow Zone',
        'latitude': round(40.7 + np.random.uniform(-0.15, 0.15), 6),
        'longitude': round(-74.0 + np.random.uniform(-0.15, 0.15), 6)
    })

zones_df = pd.DataFrame(zones_data)
zones_df.to_csv('sample_taxi_zones.csv', index=False)
print(f"Generated {len(zones_df)} sample zones")
```

**Run and load:**
```bash
python Scripts/generate_sample_data.py

# Load into Trino using CSV format
```

---

## 📊 Data Pipeline Summary

```
┌─────────────────────────────────────────────────────────────┐
│                    NYC Taxi Data Pipeline                   │
└─────────────────────────────────────────────────────────────┘

Step 1: Download Raw Data
  ↓
  [NYC TLC Website] → [Parquet/CSV Files] (8-10M rows/month)
  ↓
Step 2: Process with PySpark
  ↓
  [PySparkCalculation.py] → [Aggregated Parquet] (150K rows/month)
  ↓
Step 3: Load into Storage
  ↓
  [HDFS/S3/Local] → [Parquet Files]
  ↓
Step 4: Create Trino Tables
  ↓
  [External Tables] → [Queryable via SQL]
  ↓
Step 5: Connect Superset
  ↓
  [Superset Dashboard] → [Real-time Analytics]
```

---

## 🎯 Quick Start Commands

### Full Pipeline (Linux/Mac):

```bash
#!/bin/bash
# Complete NYC Taxi data pipeline

# 1. Download data
mkdir -p ~/nyc_taxi_data/{raw,processed,zones}
cd ~/nyc_taxi_data/raw
wget https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_2024-01.parquet
wget https://d37ci6vzurychx.cloudfront.net/trip-data/green_tripdata_2024-01.parquet

# 2. Process with PySpark
python Scripts/PySparkCalculation_Updated.py

# 3. Download zones
cd ~/nyc_taxi_data/zones
wget https://d37ci6vzurychx.cloudfront.net/misc/taxi+_zone_lookup.csv
python Scripts/create_taxi_zones_table.py

# 4. Load into Trino
trino --server localhost:8080 --catalog hive --schema nyc_taxi < create_tables.sql

# 5. Verify
trino --server localhost:8080 --catalog hive --schema nyc_taxi
```

---

## 🐛 Troubleshooting

### Issue: "File not found"
**Solution**: Check if Parquet files exist, try CSV format for older data

### Issue: "Out of memory in PySpark"
**Solution**: Increase Spark memory:
```python
.config("spark.driver.memory", "8g") \
.config("spark.executor.memory", "8g")
```

### Issue: "Trino can't read Parquet files"
**Solution**: Ensure Hive metastore is configured, check file permissions

### Issue: "Missing taxi zone coordinates"
**Solution**: Install geopandas: `pip install geopandas`

---

## 📚 Additional Resources

- **NYC TLC Data**: https://www1.nyc.gov/site/tlc/about/tlc-trip-record-data.page
- **Taxi Zones Shapefile**: https://d37ci6vzurychx.cloudfront.net/misc/taxi_zones.zip
- **Data Dictionary**: See PDFs in project root
- **Trino Documentation**: https://trino.io/docs/current/
- **PySpark Guide**: https://spark.apache.org/docs/latest/api/python/

---

**Last Updated**: October 2025  
**Status**: Production Ready

