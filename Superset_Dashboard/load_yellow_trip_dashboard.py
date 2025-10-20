"""
NYC Yellow Taxi Dashboard Setup Script
Loads Yellow Trip (2009) data and creates dashboard views in Trino
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
SAMPLE_DIR = 'sampledata/'

def print_header(text):
    print(f"\n{'='*70}")
    print(f"  {text}")
    print(f"{'='*70}")

def print_success(text):
    print(f"✓ {text}")

def print_error(text):
    print(f"✗ {text}")

def print_info(text):
    print(f"ℹ {text}")

def main():
    print_header("NYC Yellow Taxi Dashboard Setup (2009 Data)")
    
    # Create SQLAlchemy engine
    connection_string = f"trino://{TRINO_USER}@{TRINO_HOST}:{TRINO_PORT}/{TRINO_CATALOG}/{TRINO_SCHEMA}"
    
    try:
        print(f"\n Connecting to Trino...")
        print(f"   {connection_string}")
        engine = create_engine(connection_string)
        conn = engine.connect()
        print_success("Connected to Trino")
    except Exception as e:
        print_error(f"Failed to connect: {e}")
        print("\nTroubleshooting:")
        print("1. Ensure Trino is running")
        print("2. Install: pip install trino sqlalchemy-trino")
        sys.exit(1)
    
    # ============================================
    # STEP 1: Load Yellow Trip CSV
    # ============================================
    
    print_header("STEP 1: Loading Yellow Trip Data")
    
    try:
        yellow_df = pd.read_csv(f'{SAMPLE_DIR}nyc_yellowtrip.csv')
        print_success(f"Loaded {len(yellow_df)} rows from nyc_yellowtrip.csv")
        
        # Show sample
        print("\nSample data (first 3 rows):")
        print(yellow_df.head(3)[['trip_pickup_datetime', 'payment_type', 
                                   'total_amt', 'trip_distance']].to_string())
        
        # Convert datetime columns
        yellow_df['trip_pickup_datetime'] = pd.to_datetime(yellow_df['trip_pickup_datetime'])
        yellow_df['trip_dropoff_datetime'] = pd.to_datetime(yellow_df['trip_dropoff_datetime'])
        
        # Write to Trino
        print("\n📊 Writing to Trino table: nyc_yellowtrip...")
        yellow_df.to_sql('nyc_yellowtrip', con=engine, if_exists='replace', 
                         index=False, method='multi', chunksize=1000)
        print_success("Created table: nyc_yellowtrip")
        
    except FileNotFoundError:
        print_error(f"File not found: {SAMPLE_DIR}nyc_yellowtrip.csv")
        print(f"Please ensure file exists in '{SAMPLE_DIR}' directory")
        sys.exit(1)
    except Exception as e:
        print_error(f"Error loading data: {e}")
        sys.exit(1)
    
    # ============================================
    # STEP 2: Create Aggregated View
    # ============================================
    
    print_header("STEP 2: Creating Aggregated View")
    
    aggregation_sql = """
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
    WHERE trip_pickup_datetime IS NOT NULL
        AND total_amt > 0
        AND trip_distance > 0
    GROUP BY 
        DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H')
    """
    
    try:
        conn.execute(text(aggregation_sql))
        print_success("Created view: nyc_taxi_aggregated")
        print_info("Note: Pickup_Location is NULL (Yellow Trip has coordinates, not LocationID)")
    except Exception as e:
        print_error(f"Error creating view: {e}")
        sys.exit(1)
    
    # ============================================
    # STEP 3: Create Dashboard Views
    # ============================================
    
    print_header("STEP 3: Creating Dashboard Views")
    
    views = {
        'hourly_metrics': """
            CREATE OR REPLACE VIEW hourly_metrics AS
            SELECT 
                CAST(SUBSTR(DATE_FORMAT(trip_pickup_datetime, '%Y-%m-%d %H'), 12, 2) AS INTEGER) as hour_of_day,
                COUNT(*) as total_trips,
                AVG(total_amt) as avg_fare,
                AVG(trip_distance) as avg_distance,
                AVG(passenger_count) as avg_passengers,
                SUM(total_amt) as total_revenue
            FROM nyc_yellowtrip
            WHERE trip_pickup_datetime IS NOT NULL AND total_amt > 0
            GROUP BY hour_of_day
            ORDER BY hour_of_day
        """,
        
        'payment_analysis': """
            CREATE OR REPLACE VIEW payment_analysis AS
            SELECT 
                payment_type,
                COUNT(*) as trip_count,
                AVG(total_amt) as avg_fare,
                AVG(tip_amt) as avg_tip,
                AVG(tip_amt / NULLIF(fare_amt, 0) * 100) as avg_tip_pct,
                SUM(total_amt) as total_revenue
            FROM nyc_yellowtrip
            WHERE total_amt > 0
            GROUP BY payment_type
            ORDER BY trip_count DESC
        """,
        
        'vendor_performance': """
            CREATE OR REPLACE VIEW vendor_performance AS
            SELECT 
                vendor_name,
                COUNT(*) as trip_count,
                AVG(total_amt) as avg_fare,
                AVG(trip_distance) as avg_distance,
                AVG(tip_amt) as avg_tip,
                SUM(total_amt) as total_revenue
            FROM nyc_yellowtrip
            GROUP BY vendor_name
            ORDER BY trip_count DESC
        """,
        
        'fare_distribution': """
            CREATE OR REPLACE VIEW fare_distribution AS
            SELECT 
                CASE 
                    WHEN total_amt < 5 THEN '$0-5'
                    WHEN total_amt < 10 THEN '$5-10'
                    WHEN total_amt < 15 THEN '$10-15'
                    WHEN total_amt < 20 THEN '$15-20'
                    WHEN total_amt < 30 THEN '$20-30'
                    ELSE '$30+'
                END as fare_bucket,
                COUNT(*) as trip_count
            FROM nyc_yellowtrip
            WHERE total_amt > 0 AND total_amt < 100
            GROUP BY fare_bucket
            ORDER BY MIN(total_amt)
        """
    }
    
    for view_name, view_sql in views.items():
        try:
            conn.execute(text(view_sql))
            print_success(f"Created view: {view_name}")
        except Exception as e:
            print_error(f"Error creating {view_name}: {e}")
    
    # ============================================
    # STEP 4: Calculate KPIs
    # ============================================
    
    print_header("STEP 4: Dashboard KPIs")
    
    kpis = {
        "Total Trips": "SELECT COUNT(*) FROM nyc_yellowtrip",
        "Total Revenue": "SELECT CAST(SUM(total_amt) AS DECIMAL(12,2)) FROM nyc_yellowtrip",
        "Average Fare": "SELECT CAST(AVG(total_amt) AS DECIMAL(8,2)) FROM nyc_yellowtrip WHERE total_amt > 0",
        "Total Miles": "SELECT CAST(SUM(trip_distance) AS DECIMAL(12,2)) FROM nyc_yellowtrip",
        "Avg Distance": "SELECT CAST(AVG(trip_distance) AS DECIMAL(8,2)) FROM nyc_yellowtrip WHERE trip_distance > 0"
    }
    
    print("\n📊 Key Performance Indicators:")
    for kpi_name, kpi_sql in kpis.items():
        try:
            result = conn.execute(text(kpi_sql))
            value = result.fetchone()[0]
            print(f"   • {kpi_name:15s}: {value}")
        except Exception as e:
            print_error(f"Error calculating {kpi_name}: {e}")
    
    # ============================================
    # STEP 5: Sample Queries
    # ============================================
    
    print_header("STEP 5: Sample Data Preview")
    
    try:
        # Show aggregated data
        result = conn.execute(text("""
            SELECT 
                Pickup_Time,
                number as trips,
                CAST(Total_Amount AS DECIMAL(10,2)) as revenue,
                CAST(AVG_Total_Amount AS DECIMAL(8,2)) as avg_fare,
                taxi_type
            FROM nyc_taxi_aggregated
            ORDER BY trips DESC
            LIMIT 5
        """))
        
        print("\n📈 Top 5 Hours by Trip Count:")
        print("   Time            | Trips | Revenue  | Avg Fare | Type")
        print("   " + "-"*60)
        for row in result:
            print(f"   {row[0]} | {row[1]:5d} | ${row[2]:7.2f} | ${row[3]:6.2f} | {row[4]}")
        
        # Show payment analysis
        result = conn.execute(text("""
            SELECT 
                payment_type,
                trip_count,
                CAST(avg_fare AS DECIMAL(8,2)) as avg_fare,
                CAST(avg_tip_pct AS DECIMAL(5,2)) as avg_tip_pct
            FROM payment_analysis
        """))
        
        print("\n💳 Payment Method Analysis:")
        print("   Method    | Trips | Avg Fare | Avg Tip %")
        print("   " + "-"*45)
        for row in result:
            print(f"   {row[0]:9s} | {row[1]:5d} | ${row[2]:7.2f} | {row[3]:5.1f}%")
        
    except Exception as e:
        print_error(f"Error running sample queries: {e}")
    
    conn.close()
    
    # ============================================
    # SUCCESS!
    # ============================================
    
    print_header("✅ SUCCESS - Dashboard Ready!")
    
    print("""
📊 Tables & Views Created:
   • nyc_yellowtrip         (raw data table)
   • nyc_taxi_aggregated    (aggregated view - compatible with Green format)
   • hourly_metrics         (time patterns)
   • payment_analysis       (Cash vs Credit)
   • vendor_performance     (vendor comparison)
   • fare_distribution      (fare buckets)

🎨 Available Chart Types:
   ✅ Time Series (trips over time)
   ✅ Busy Hours Bar Chart
   ✅ KPI Cards (revenue, trips, avg fare)
   ✅ Payment Method Pie Chart (unique to Yellow!)
   ✅ Vendor Comparison (unique to Yellow!)
   ✅ Fare Distribution Histogram
   ✅ Distance vs Fare Scatter
   ✅ Passenger Analysis
   ✅ Trip Duration Analysis
   ⚠️  Geographic map (coordinates only, no zone names)

📍 Geographic Limitation:
   Yellow Trip (2009) uses lat/lon coordinates, not LocationID.
   Maps will show points but without zone names like "Manhattan" or "Brooklyn".

🚀 Next Steps:
   1. Open Superset: http://localhost:8088
   2. Add Trino connection:
      URI: trino://admin@localhost:8080/hive/nyc_taxi
   3. Add datasets:
      - nyc_taxi_aggregated (for main dashboard)
      - hourly_metrics (for time analysis)
      - payment_analysis (for payment charts)
      - vendor_performance (for vendor charts)
   4. Start creating charts!

💡 Pro Tip:
   Combine with Green Trip data (2020) for historical comparison:
   - 2009 (Yellow) vs 2020 (Green)
   - Show industry evolution over 11 years
   - Cash dominance (2009) vs Credit cards (2020)

📖 See Superset_Dashboard/yellow_trip_chart_guide.md for detailed chart examples!
    """)

if __name__ == "__main__":
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

