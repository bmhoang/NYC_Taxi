"""
Load NYC Taxi Sample Data into Trino and Create Aggregated View
This script creates tables from the sample CSV files
"""

import pandas as pd
from sqlalchemy import create_engine, text
import sys

# Configuration
TRINO_HOST = 'localhost'
TRINO_PORT = 8080
TRINO_USER = 'admin'
TRINO_CATALOG = 'hive'
TRINO_SCHEMA = 'nyc_taxi'

# Sample data directory
SAMPLE_DIR = 'sampledata/'

def print_header(text):
    print(f"\n{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}")

def print_success(text):
    print(f"✓ {text}")

def print_error(text):
    print(f"✗ {text}")

def main():
    print_header("NYC Taxi Sample Data Loader")
    
    # Create SQLAlchemy engine
    connection_string = f"trino://{TRINO_USER}@{TRINO_HOST}:{TRINO_PORT}/{TRINO_CATALOG}/{TRINO_SCHEMA}"
    
    try:
        print(f"\nConnecting to Trino: {connection_string}")
        engine = create_engine(connection_string)
        conn = engine.connect()
        print_success("Connected to Trino")
    except Exception as e:
        print_error(f"Failed to connect: {e}")
        print("\nMake sure:")
        print("1. Trino is running: trino --server localhost:8080")
        print("2. Install trino connector: pip install trino sqlalchemy-trino")
        sys.exit(1)
    
    # ============================================
    # STEP 1: Load Green Trip CSV
    # ============================================
    
    print_header("STEP 1: Loading Green Trip Data")
    
    try:
        green_df = pd.read_csv(f'{SAMPLE_DIR}nyc_greentrip.csv')
        print_success(f"Loaded {len(green_df)} rows from nyc_greentrip.csv")
        
        # Show sample
        print("\nSample data:")
        print(green_df.head(3)[['lpep_pickup_datetime', 'pulocationid', 'total_amount', 'trip_distance']])
        
        # Convert datetime columns
        green_df['lpep_pickup_datetime'] = pd.to_datetime(green_df['lpep_pickup_datetime'])
        green_df['lpep_dropoff_datetime'] = pd.to_datetime(green_df['lpep_dropoff_datetime'])
        
        # Write to Trino (this creates the table)
        print("\nWriting to Trino table: nyc_greentrip...")
        green_df.to_sql('nyc_greentrip', con=engine, if_exists='replace', index=False, method='multi')
        print_success("Created table: nyc_greentrip")
        
    except FileNotFoundError:
        print_error(f"File not found: {SAMPLE_DIR}nyc_greentrip.csv")
        print("Please ensure sample data is in the 'sampledata/' directory")
        sys.exit(1)
    except Exception as e:
        print_error(f"Error loading green trip data: {e}")
        sys.exit(1)
    
    # ============================================
    # STEP 2: Create Aggregated View
    # ============================================
    
    print_header("STEP 2: Creating Aggregated View")
    
    aggregation_sql = """
    CREATE OR REPLACE VIEW nyc_taxi_aggregated AS
    SELECT 
        DATE_FORMAT(lpep_pickup_datetime, '%Y-%m-%d %H') as Pickup_Time,
        pulocationid as Pickup_Location,
        SUM(total_amount) as Total_Amount,
        AVG(total_amount) as AVG_Total_Amount,
        SUM(trip_distance) as Total_Trip_Distance,
        AVG(trip_distance) as AVG_Trip_Distance,
        SUM(passenger_count) as Total_Passenger_Count,
        AVG(CAST(passenger_count AS DOUBLE)) as AVG_Passenger_Count,
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
    """
    
    try:
        conn.execute(text(aggregation_sql))
        print_success("Created view: nyc_taxi_aggregated")
    except Exception as e:
        print_error(f"Error creating view: {e}")
        sys.exit(1)
    
    # ============================================
    # STEP 3: Create Taxi Zones Table
    # ============================================
    
    print_header("STEP 3: Creating Taxi Zones Table")
    
    # Create taxi zones dataframe with locations from sample
    zones_data = {
        'LocationID': [168, 78, 95, 130, 260, 82, 106, 134, 255, 66, 254, 60, 159, 42, 91, 216, 118, 198],
        'Borough': ['Queens', 'Manhattan', 'Queens', 'Queens', 'Queens', 'Manhattan', 'Manhattan', 
                   'Queens', 'Queens', 'Manhattan', 'Queens', 'Manhattan', 'Queens', 'Manhattan', 
                   'Queens', 'Manhattan', 'Manhattan', 'Queens'],
        'Zone': ['Steinway', 'East Harlem South', 'Woodhaven', 'Jamaica', 'Far Rockaway', 
                'East Village', 'Gramercy', 'Jamaica Estates', 'Forest Park', 'East Chelsea',
                'Forest Hills', 'Midtown East', 'Ridgewood', 'Central Park', 'Elmhurst',
                'West Village', 'Harlem', 'Sunnyside'],
        'service_zone': ['Boro Zone', 'Boro Zone', 'Boro Zone', 'Boro Zone', 'Boro Zone',
                        'Yellow Zone', 'Yellow Zone', 'Boro Zone', 'Boro Zone', 'Yellow Zone',
                        'Boro Zone', 'Yellow Zone', 'Boro Zone', 'Yellow Zone', 'Boro Zone',
                        'Yellow Zone', 'Boro Zone', 'Boro Zone'],
        'latitude': [40.7740, 40.7957, 40.6892, 40.6902, 40.5990, 40.7264, 40.7368,
                    40.7197, 40.7016, 40.7465, 40.7183, 40.7549, 40.7021, 40.7829,
                    40.7361, 40.7357, 40.8116, 40.7433],
        'longitude': [-73.9030, -73.9389, -73.8569, -73.8063, -73.7565, -73.9818, -73.9830,
                     -73.7874, -73.8563, -73.9972, -73.8448, -73.9709, -73.9053, -73.9654,
                     -73.8820, -74.0023, -73.9465, -73.9196]
    }
    
    zones_df = pd.DataFrame(zones_data)
    
    try:
        zones_df.to_sql('taxi_zones', con=engine, if_exists='replace', index=False, method='multi')
        print_success(f"Created table: taxi_zones with {len(zones_df)} zones")
    except Exception as e:
        print_error(f"Error creating taxi zones: {e}")
    
    # ============================================
    # STEP 4: Verify Data
    # ============================================
    
    print_header("STEP 4: Verification")
    
    try:
        # Count aggregated rows
        result = conn.execute(text("SELECT COUNT(*) FROM nyc_taxi_aggregated"))
        agg_count = result.fetchone()[0]
        print_success(f"Aggregated view has {agg_count} rows")
        
        # Show sample
        print("\nSample aggregated data:")
        result = conn.execute(text("""
            SELECT 
                Pickup_Time,
                Pickup_Location,
                number as trips,
                CAST(Total_Amount AS DECIMAL(10,2)) as revenue,
                taxi_type
            FROM nyc_taxi_aggregated
            ORDER BY trips DESC
            LIMIT 5
        """))
        
        for row in result:
            print(f"  {row.Pickup_Time} | Location {row.Pickup_Location} | {row.trips} trips | ${row.revenue}")
        
        # Test join
        print("\nSample with zone names:")
        result = conn.execute(text("""
            SELECT 
                t.Pickup_Time,
                z.Zone,
                z.Borough,
                t.number as trips,
                CAST(t.Total_Amount AS DECIMAL(10,2)) as revenue
            FROM nyc_taxi_aggregated t
            LEFT JOIN taxi_zones z ON t.Pickup_Location = z.LocationID
            ORDER BY t.number DESC
            LIMIT 5
        """))
        
        for row in result:
            print(f"  {row.Pickup_Time} | {row.Zone}, {row.Borough} | {row.trips} trips | ${row.revenue}")
        
    except Exception as e:
        print_error(f"Error during verification: {e}")
    
    conn.close()
    
    # ============================================
    # SUCCESS!
    # ============================================
    
    print_header("SUCCESS!")
    print("""
✓ Tables created:
  - nyc_greentrip (raw data)
  - nyc_taxi_aggregated (aggregated view)
  - taxi_zones (location reference)

✓ Ready for Superset!

Next steps:
1. Open Superset: http://localhost:8088
2. Add Trino connection: trino://admin@localhost:8080/hive/nyc_taxi
3. Add dataset: nyc_taxi_aggregated
4. Start creating charts!

Test queries in Trino CLI:
  trino --server localhost:8080 --catalog hive --schema nyc_taxi
  SELECT * FROM nyc_taxi_aggregated;
  SELECT * FROM taxi_zones;
    """)

if __name__ == "__main__":
    print("\nNYC Taxi Sample Data Loader")
    print("="*60)
    
    # Check dependencies
    try:
        import pandas
        import sqlalchemy
        from trino.dbapi import connect
    except ImportError as e:
        print_error(f"Missing dependency: {e}")
        print("\nInstall required packages:")
        print("  pip install pandas sqlalchemy trino sqlalchemy-trino")
        sys.exit(1)
    
    main()

