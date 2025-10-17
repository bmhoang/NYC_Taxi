#!/bin/bash

# ============================================
# NYC Taxi Data Pipeline - Quick Start Script
# ============================================
# This script automates the entire data ingestion process
# Author: Based on NYC Taxi project
# Date: October 2025

set -e  # Exit on error

# ============================================
# Configuration - EDIT THESE PATHS
# ============================================

# Base directory for data
DATA_DIR="${HOME}/nyc_taxi_data"
RAW_DIR="${DATA_DIR}/raw"
PROCESSED_DIR="${DATA_DIR}/processed"
ZONES_DIR="${DATA_DIR}/zones"

# Year and months to process
YEAR="2024"
MONTHS=("01")  # Add more months: ("01" "02" "03" ... "12")

# Taxi types
TAXI_TYPES=("yellow" "green")

# Trino connection
TRINO_HOST="localhost"
TRINO_PORT="8080"
TRINO_CATALOG="hive"
TRINO_SCHEMA="nyc_taxi"

# ============================================
# Functions
# ============================================

print_header() {
    echo ""
    echo "============================================"
    echo "$1"
    echo "============================================"
}

print_info() {
    echo "[INFO] $1"
}

print_success() {
    echo "[✓] $1"
}

print_error() {
    echo "[✗] $1"
}

# ============================================
# STEP 1: Setup Directories
# ============================================

print_header "STEP 1: Setting up directories"

mkdir -p "${RAW_DIR}"
mkdir -p "${PROCESSED_DIR}"
mkdir -p "${ZONES_DIR}"

print_success "Directories created:
  - Raw data: ${RAW_DIR}
  - Processed: ${PROCESSED_DIR}
  - Zones: ${ZONES_DIR}"

# ============================================
# STEP 2: Download Raw Data
# ============================================

print_header "STEP 2: Downloading NYC Taxi data"

cd "${RAW_DIR}"

for taxi_type in "${TAXI_TYPES[@]}"; do
    print_info "Downloading ${taxi_type} taxi data..."
    
    for month in "${MONTHS[@]}"; do
        file_name="${taxi_type}_tripdata_${YEAR}-${month}.parquet"
        url="https://d37ci6vzurychx.cloudfront.net/trip-data/${file_name}"
        
        if [ -f "${file_name}" ]; then
            print_info "File exists: ${file_name} (skipping)"
        else
            print_info "Downloading: ${file_name}"
            if wget -q "${url}"; then
                print_success "Downloaded: ${file_name}"
            else
                print_error "Failed to download: ${file_name}"
                # Try CSV format for older data
                file_name="${taxi_type}_tripdata_${YEAR}-${month}.csv"
                url="https://s3.amazonaws.com/nyc-tlc/trip+data/${file_name}"
                print_info "Trying CSV format: ${file_name}"
                if wget -q "${url}"; then
                    print_success "Downloaded CSV: ${file_name}"
                else
                    print_error "Failed to download CSV version"
                fi
            fi
        fi
    done
done

# ============================================
# STEP 3: Download Taxi Zones
# ============================================

print_header "STEP 3: Downloading taxi zones data"

cd "${ZONES_DIR}"

# Download taxi zone lookup
if [ ! -f "taxi+_zone_lookup.csv" ]; then
    print_info "Downloading taxi zone lookup..."
    wget -q "https://d37ci6vzurychx.cloudfront.net/misc/taxi+_zone_lookup.csv"
    print_success "Downloaded taxi zone lookup"
else
    print_info "Taxi zone lookup already exists"
fi

# Download shapefile
if [ ! -f "taxi_zones.shp" ]; then
    print_info "Downloading taxi zones shapefile..."
    wget -q "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zones.zip"
    unzip -q taxi_zones.zip
    rm taxi_zones.zip
    print_success "Downloaded and extracted taxi zones shapefile"
else
    print_info "Taxi zones shapefile already exists"
fi

# ============================================
# STEP 4: Process Data with PySpark
# ============================================

print_header "STEP 4: Processing data with PySpark"

print_info "This step requires PySpark to be installed"
print_info "If you haven't installed it: pip install pyspark"

# Check if PySpark is installed
if ! python3 -c "import pyspark" 2>/dev/null; then
    print_error "PySpark not found. Installing..."
    pip install pyspark
fi

print_info "Creating PySpark processing script..."

# Create inline PySpark script
cat > "${DATA_DIR}/process_data.py" << 'PYEOF'
from pyspark.sql import SparkSession
from pyspark.sql.functions import substring, sum, avg, count
import sys
import os

if len(sys.argv) < 5:
    print("Usage: process_data.py <raw_dir> <output_dir> <year> <taxi_type>")
    sys.exit(1)

raw_dir = sys.argv[1]
output_dir = sys.argv[2]
year = sys.argv[3]
taxi_type = sys.argv[4]

spark = SparkSession.builder \
    .appName("NYC Taxi Processing") \
    .config("spark.driver.memory", "4g") \
    .getOrCreate()

print(f"Processing {taxi_type} taxi data for {year}")

# Find all files for this type and year
import glob
pattern = f"{raw_dir}/{taxi_type}_tripdata_{year}-*.{{parquet,csv}}"
files = glob.glob(pattern.replace('{parquet,csv}', 'parquet')) + \
        glob.glob(pattern.replace('{parquet,csv}', 'csv'))

if not files:
    print(f"No files found matching pattern: {pattern}")
    sys.exit(1)

all_data = []

for file_path in files:
    print(f"Processing: {file_path}")
    
    if file_path.endswith('.parquet'):
        df = spark.read.parquet(file_path)
    else:
        df = spark.read.csv(file_path, header=True, inferSchema=True)
    
    pickup_col = "tpep_pickup_datetime" if taxi_type == "yellow" else "lpep_pickup_datetime"
    
    aggregated = df.selectExpr(
        f"substring({pickup_col}, 1, 13) as Pickup_Time",
        "PULocationID as Pickup_Location",
        "total_amount as Total_Amount",
        "trip_distance as Trip_Distance",
        "passenger_count as Passenger_Count",
        "fare_amount as Fare_Amount",
        "extra as Extra",
        "tip_amount",
        "tolls_amount"
    ).filter(
        f"{pickup_col} is not null and total_amount > 0 and trip_distance > 0"
    ).groupBy("Pickup_Time", "Pickup_Location").agg(
        sum("Total_Amount").alias("Total_Amount"),
        avg("Total_Amount").alias("AVG_Total_Amount"),
        sum("Trip_Distance").alias("Total_Trip_Distance"),
        avg("Trip_Distance").alias("AVG_Trip_Distance"),
        sum("Passenger_Count").alias("Total_Passenger_Count"),
        avg("Passenger_Count").alias("AVG_Passenger_Count"),
        sum("Fare_Amount").alias("Fare_Amount"),
        sum("Extra").alias("Extra"),
        sum("tip_amount").alias("tip_amount"),
        sum("tolls_amount").alias("tolls_amount"),
        count("*").alias("number")
    )
    
    all_data.append(aggregated)

# Combine all months
from functools import reduce
combined = reduce(lambda df1, df2: df1.union(df2), all_data)

# Add taxi_type column
from pyspark.sql.functions import lit
combined = combined.withColumn("taxi_type", lit(taxi_type))

# Save
output_path = f"{output_dir}/{taxi_type}_{year}_aggregated"
combined.write.mode("overwrite").parquet(output_path)

print(f"Saved {combined.count()} rows to {output_path}")
spark.stop()
PYEOF

# Run PySpark for each taxi type
for taxi_type in "${TAXI_TYPES[@]}"; do
    print_info "Processing ${taxi_type} taxi data with PySpark..."
    python3 "${DATA_DIR}/process_data.py" "${RAW_DIR}" "${PROCESSED_DIR}" "${YEAR}" "${taxi_type}"
    print_success "Processed ${taxi_type} taxi data"
done

# ============================================
# STEP 5: Process Taxi Zones
# ============================================

print_header "STEP 5: Processing taxi zones with coordinates"

cd "${ZONES_DIR}"

cat > "process_zones.py" << 'PYEOF'
import pandas as pd

try:
    import geopandas as gpd
    zones_csv = pd.read_csv('taxi+_zone_lookup.csv')
    zones_shp = gpd.read_file('taxi_zones.shp')
    zones_shp['longitude'] = zones_shp.geometry.centroid.x
    zones_shp['latitude'] = zones_shp.geometry.centroid.y
    
    zones_merged = zones_shp.merge(zones_csv, on='LocationID', how='left')
    taxi_zones = zones_merged[['LocationID', 'Borough', 'Zone', 'service_zone', 'latitude', 'longitude']]
    taxi_zones.to_csv('taxi_zones_with_coords.csv', index=False)
    print(f"Created taxi_zones table with {len(taxi_zones)} zones")
    
except ImportError:
    print("geopandas not found, using simple centroid calculation")
    zones = pd.read_csv('taxi+_zone_lookup.csv')
    # Add dummy coordinates (NYC approximate center)
    zones['latitude'] = 40.7128
    zones['longitude'] = -74.0060
    zones[['LocationID', 'Borough', 'Zone', 'service_zone', 'latitude', 'longitude']].to_csv(
        'taxi_zones_with_coords.csv', index=False
    )
    print(f"Created basic taxi_zones table with {len(zones)} zones")
    print("Note: Install geopandas for accurate coordinates: pip install geopandas")
PYEOF

python3 process_zones.py
print_success "Processed taxi zones"

# ============================================
# STEP 6: Summary
# ============================================

print_header "Data Pipeline Completed!"

print_info "Summary:"
echo "  - Raw data downloaded: ${RAW_DIR}"
echo "  - Processed data: ${PROCESSED_DIR}"
echo "  - Taxi zones: ${ZONES_DIR}/taxi_zones_with_coords.csv"

print_header "Next Steps:"
echo "1. Copy processed data to Trino-accessible location (HDFS/S3)"
echo "2. Run create_tables.sql in Trino:"
echo "   trino --server ${TRINO_HOST}:${TRINO_PORT} --catalog ${TRINO_CATALOG} --schema ${TRINO_SCHEMA} -f create_tables.sql"
echo "3. Verify tables:"
echo "   SELECT COUNT(*) FROM nyc_taxi_aggregated;"
echo "   SELECT COUNT(*) FROM taxi_zones;"
echo "4. Connect Superset and create dashboard!"

print_success "All done! 🎉"

