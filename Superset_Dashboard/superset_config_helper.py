"""
Superset Configuration Helper Script for NYC Taxi Dashboard
This script helps set up Apache Superset dashboards programmatically using the Superset API

Author: Based on NYC Taxi project by Sekyung Na
Date: October 2025
Requirements: pip install requests pandas
"""

import requests
import json
from typing import Dict, List, Optional
import time


class SupersetHelper:
    """Helper class to interact with Apache Superset API"""
    
    def __init__(self, superset_url: str, username: str, password: str):
        """
        Initialize Superset API client
        
        Args:
            superset_url: Base URL of Superset instance (e.g., 'http://localhost:8088')
            username: Superset username
            password: Superset password
        """
        self.base_url = superset_url.rstrip('/')
        self.username = username
        self.password = password
        self.session = requests.Session()
        self.access_token = None
        self._login()
    
    def _login(self):
        """Authenticate with Superset and obtain access token"""
        login_url = f"{self.base_url}/api/v1/security/login"
        
        payload = {
            "username": self.username,
            "password": self.password,
            "provider": "db",
            "refresh": True
        }
        
        try:
            response = self.session.post(login_url, json=payload)
            response.raise_for_status()
            
            data = response.json()
            self.access_token = data.get("access_token")
            
            # Set authorization header for future requests
            self.session.headers.update({
                "Authorization": f"Bearer {self.access_token}",
                "Content-Type": "application/json"
            })
            
            print("✓ Successfully authenticated with Superset")
            return True
            
        except requests.exceptions.RequestException as e:
            print(f"✗ Authentication failed: {e}")
            return False
    
    def get_csrf_token(self):
        """Get CSRF token for POST requests"""
        url = f"{self.base_url}/api/v1/security/csrf_token/"
        response = self.session.get(url)
        response.raise_for_status()
        return response.json()["result"]
    
    def create_database_connection(self, 
                                   database_name: str,
                                   sqlalchemy_uri: str,
                                   expose_in_sqllab: bool = True) -> Optional[int]:
        """
        Create a database connection in Superset
        
        Args:
            database_name: Name for the database connection
            sqlalchemy_uri: SQLAlchemy connection URI (e.g., 'trino://user@host:port/catalog')
            expose_in_sqllab: Whether to expose in SQL Lab
            
        Returns:
            Database ID if successful, None otherwise
        """
        url = f"{self.base_url}/api/v1/database/"
        
        payload = {
            "database_name": database_name,
            "sqlalchemy_uri": sqlalchemy_uri,
            "expose_in_sqllab": expose_in_sqllab,
            "allow_ctas": False,
            "allow_cvas": False,
            "allow_dml": False,
            "allow_multi_schema_metadata_fetch": True,
            "allow_run_async": True,
            "cache_timeout": 3600
        }
        
        try:
            response = self.session.post(url, json=payload)
            response.raise_for_status()
            
            db_id = response.json()["id"]
            print(f"✓ Created database connection: {database_name} (ID: {db_id})")
            return db_id
            
        except requests.exceptions.RequestException as e:
            print(f"✗ Failed to create database connection: {e}")
            if hasattr(e.response, 'text'):
                print(f"  Response: {e.response.text}")
            return None
    
    def list_databases(self) -> List[Dict]:
        """List all database connections"""
        url = f"{self.base_url}/api/v1/database/"
        response = self.session.get(url)
        response.raise_for_status()
        return response.json()["result"]
    
    def create_dataset(self,
                      database_id: int,
                      schema: str,
                      table_name: str,
                      description: str = "") -> Optional[int]:
        """
        Create a dataset (table) in Superset
        
        Args:
            database_id: ID of the database connection
            schema: Schema name
            table_name: Table name
            description: Optional description
            
        Returns:
            Dataset ID if successful, None otherwise
        """
        url = f"{self.base_url}/api/v1/dataset/"
        
        payload = {
            "database": database_id,
            "schema": schema,
            "table_name": table_name,
            "description": description
        }
        
        try:
            response = self.session.post(url, json=payload)
            response.raise_for_status()
            
            dataset_id = response.json()["id"]
            print(f"✓ Created dataset: {schema}.{table_name} (ID: {dataset_id})")
            return dataset_id
            
        except requests.exceptions.RequestException as e:
            print(f"✗ Failed to create dataset: {e}")
            if hasattr(e.response, 'text'):
                print(f"  Response: {e.response.text}")
            return None
    
    def list_datasets(self) -> List[Dict]:
        """List all datasets"""
        url = f"{self.base_url}/api/v1/dataset/"
        response = self.session.get(url)
        response.raise_for_status()
        return response.json()["result"]
    
    def create_chart(self,
                    dataset_id: int,
                    chart_name: str,
                    viz_type: str,
                    params: Dict,
                    description: str = "") -> Optional[int]:
        """
        Create a chart in Superset
        
        Args:
            dataset_id: ID of the dataset
            chart_name: Name for the chart
            viz_type: Visualization type (e.g., 'big_number', 'line', 'bar', 'table')
            params: Chart parameters/configuration
            description: Optional description
            
        Returns:
            Chart ID if successful, None otherwise
        """
        url = f"{self.base_url}/api/v1/chart/"
        
        payload = {
            "slice_name": chart_name,
            "viz_type": viz_type,
            "datasource_id": dataset_id,
            "datasource_type": "table",
            "params": json.dumps(params),
            "description": description
        }
        
        try:
            response = self.session.post(url, json=payload)
            response.raise_for_status()
            
            chart_id = response.json()["id"]
            print(f"✓ Created chart: {chart_name} (ID: {chart_id})")
            return chart_id
            
        except requests.exceptions.RequestException as e:
            print(f"✗ Failed to create chart: {e}")
            if hasattr(e.response, 'text'):
                print(f"  Response: {e.response.text}")
            return None
    
    def create_dashboard(self,
                        dashboard_title: str,
                        description: str = "",
                        published: bool = True) -> Optional[int]:
        """
        Create a dashboard in Superset
        
        Args:
            dashboard_title: Title for the dashboard
            description: Optional description
            published: Whether to publish the dashboard
            
        Returns:
            Dashboard ID if successful, None otherwise
        """
        url = f"{self.base_url}/api/v1/dashboard/"
        
        payload = {
            "dashboard_title": dashboard_title,
            "description": description,
            "published": published,
            "json_metadata": json.dumps({
                "color_scheme": "",
                "label_colors": {},
                "shared_label_colors": {},
                "expanded_slices": {}
            }),
            "position_json": json.dumps({})
        }
        
        try:
            response = self.session.post(url, json=payload)
            response.raise_for_status()
            
            dashboard_id = response.json()["id"]
            print(f"✓ Created dashboard: {dashboard_title} (ID: {dashboard_id})")
            return dashboard_id
            
        except requests.exceptions.RequestException as e:
            print(f"✗ Failed to create dashboard: {e}")
            if hasattr(e.response, 'text'):
                print(f"  Response: {e.response.text}")
            return None


# ==============================================
# Chart Configuration Templates
# ==============================================

def get_kpi_chart_config(metric: str, metric_label: str) -> Dict:
    """Get configuration for a KPI Big Number chart"""
    return {
        "viz_type": "big_number_total",
        "metric": metric,
        "header_font_size": 0.4,
        "subheader_font_size": 0.15,
        "y_axis_format": ",.0f",
        "adhoc_filters": []
    }


def get_time_series_config(time_column: str, metric: str, groupby: List[str] = None) -> Dict:
    """Get configuration for a time series line chart"""
    config = {
        "viz_type": "echarts_timeseries_line",
        "time_grain_sqla": "P1D",
        "x_axis": time_column,
        "metrics": [metric],
        "groupby": groupby or [],
        "row_limit": 10000,
        "truncate_metric": True,
        "show_legend": True,
        "rich_tooltip": True,
        "show_markers": False
    }
    return config


def get_bar_chart_config(x_axis: str, metric: str, groupby: List[str] = None) -> Dict:
    """Get configuration for a bar chart"""
    return {
        "viz_type": "echarts_timeseries_bar",
        "x_axis": x_axis,
        "metrics": [metric],
        "groupby": groupby or [],
        "row_limit": 100,
        "show_legend": True,
        "rich_tooltip": True
    }


def get_pie_chart_config(dimension: str, metric: str) -> Dict:
    """Get configuration for a pie chart"""
    return {
        "viz_type": "pie",
        "groupby": [dimension],
        "metric": metric,
        "row_limit": 10,
        "show_legend": True,
        "show_labels": True,
        "labels_outside": True
    }


def get_table_config(columns: List[str], metrics: List[str]) -> Dict:
    """Get configuration for a table chart"""
    return {
        "viz_type": "table",
        "all_columns": [],
        "groupby": columns,
        "metrics": metrics,
        "row_limit": 100,
        "table_timestamp_format": "%Y-%m-%d %H:%M:%S",
        "page_length": 25,
        "include_search": True,
        "show_cell_bars": True
    }


# ==============================================
# NYC Taxi Dashboard Setup Functions
# ==============================================

def setup_nyc_taxi_dashboard(superset: SupersetHelper,
                            trino_uri: str,
                            schema_name: str = "nyc_taxi",
                            table_name: str = "nyc_taxi_aggregated"):
    """
    Complete setup of NYC Taxi dashboard
    
    Args:
        superset: SupersetHelper instance
        trino_uri: Trino connection URI
        schema_name: Schema name in Trino
        table_name: Table name in Trino
    """
    print("\n" + "="*60)
    print("NYC Taxi Dashboard Setup")
    print("="*60 + "\n")
    
    # Step 1: Create database connection
    print("Step 1: Creating Trino database connection...")
    db_id = superset.create_database_connection(
        database_name="NYC Taxi Trino",
        sqlalchemy_uri=trino_uri
    )
    
    if not db_id:
        print("Failed to create database connection. Exiting.")
        return
    
    time.sleep(2)  # Wait for database to be registered
    
    # Step 2: Create dataset
    print("\nStep 2: Creating dataset...")
    dataset_id = superset.create_dataset(
        database_id=db_id,
        schema=schema_name,
        table_name=table_name,
        description="NYC Taxi aggregated data by hour and location"
    )
    
    if not dataset_id:
        print("Failed to create dataset. Exiting.")
        return
    
    time.sleep(2)
    
    # Step 3: Create charts
    print("\nStep 3: Creating charts...")
    chart_ids = []
    
    # KPI Charts
    kpi_charts = [
        ("Total Trips", "SUM(number)", ",.0f"),
        ("Total Revenue", "SUM(Total_Amount)", "$,.2f"),
        ("Average Fare", "AVG(AVG_Total_Amount)", "$,.2f"),
        ("Total Miles", "SUM(Total_Trip_Distance)", ",.1f")
    ]
    
    for chart_name, metric, format_str in kpi_charts:
        config = {
            "metric": metric,
            "viz_type": "big_number_total",
            "header_font_size": 0.4,
            "y_axis_format": format_str
        }
        chart_id = superset.create_chart(
            dataset_id=dataset_id,
            chart_name=chart_name,
            viz_type="big_number_total",
            params=config,
            description=f"KPI: {chart_name}"
        )
        if chart_id:
            chart_ids.append(chart_id)
        time.sleep(1)
    
    # Time Series Chart - Trips Over Time
    time_series_config = {
        "viz_type": "echarts_timeseries_line",
        "x_axis": "Pickup_Time",
        "metrics": ["SUM(number)"],
        "groupby": ["taxi_type"],
        "time_grain_sqla": "PT1H",
        "show_legend": True
    }
    chart_id = superset.create_chart(
        dataset_id=dataset_id,
        chart_name="Trips Over Time",
        viz_type="echarts_timeseries_line",
        params=time_series_config,
        description="Hourly trip count by taxi type"
    )
    if chart_id:
        chart_ids.append(chart_id)
    time.sleep(1)
    
    # Bar Chart - Busy Hours
    bar_config = {
        "viz_type": "echarts_timeseries_bar",
        "x_axis": "Pickup_Time",
        "metrics": ["SUM(number)"],
        "groupby": ["taxi_type"],
        "row_limit": 24
    }
    chart_id = superset.create_chart(
        dataset_id=dataset_id,
        chart_name="Busy Hours Analysis",
        viz_type="echarts_timeseries_bar",
        params=bar_config,
        description="Trip volume by hour of day"
    )
    if chart_id:
        chart_ids.append(chart_id)
    time.sleep(1)
    
    # Table - Top Pickup Locations
    table_config = {
        "viz_type": "table",
        "groupby": ["Pickup_Location"],
        "metrics": [
            "SUM(number)",
            "SUM(Total_Amount)",
            "AVG(AVG_Trip_Distance)"
        ],
        "row_limit": 20,
        "show_cell_bars": True,
        "order_desc": True
    }
    chart_id = superset.create_chart(
        dataset_id=dataset_id,
        chart_name="Top Pickup Locations",
        viz_type="table",
        params=table_config,
        description="Top 20 busiest pickup locations"
    )
    if chart_id:
        chart_ids.append(chart_id)
    
    # Step 4: Create dashboard
    print("\nStep 4: Creating dashboard...")
    dashboard_id = superset.create_dashboard(
        dashboard_title="NYC Taxi Analytics Dashboard",
        description="Comprehensive analytics for NYC taxi trips - pickup patterns, revenue analysis, and location insights",
        published=True
    )
    
    if dashboard_id:
        print(f"\n{'='*60}")
        print("✓ Dashboard setup completed successfully!")
        print(f"{'='*60}")
        print(f"\nDashboard ID: {dashboard_id}")
        print(f"Created {len(chart_ids)} charts")
        print(f"\nAccess your dashboard at:")
        print(f"{superset.base_url}/superset/dashboard/{dashboard_id}/")
        print(f"\n{'='*60}\n")
    
    return {
        "database_id": db_id,
        "dataset_id": dataset_id,
        "chart_ids": chart_ids,
        "dashboard_id": dashboard_id
    }


# ==============================================
# Example Usage
# ==============================================

def main():
    """Example usage of the Superset helper"""
    
    # Configuration
    SUPERSET_URL = "http://localhost:8088"  # Change to your Superset URL
    USERNAME = "admin"  # Change to your username
    PASSWORD = "admin"  # Change to your password
    
    # Trino connection details
    TRINO_HOST = "localhost"
    TRINO_PORT = 8080
    TRINO_CATALOG = "hive"
    TRINO_SCHEMA = "nyc_taxi"
    TRINO_USER = "admin"
    
    # Build Trino URI
    trino_uri = f"trino://{TRINO_USER}@{TRINO_HOST}:{TRINO_PORT}/{TRINO_CATALOG}"
    
    print("""
    ╔═══════════════════════════════════════════════════════════╗
    ║         NYC Taxi Superset Dashboard Setup Script         ║
    ╚═══════════════════════════════════════════════════════════╝
    
    This script will:
    1. Connect to your Superset instance
    2. Create a Trino database connection
    3. Create a dataset from your NYC taxi data
    4. Generate multiple charts (KPIs, time series, tables)
    5. Assemble a complete dashboard
    
    Please ensure:
    - Apache Superset is running
    - Trino is accessible
    - NYC taxi data is available in Trino
    
    """)
    
    # Get user confirmation
    confirm = input("Continue with setup? (yes/no): ").strip().lower()
    if confirm not in ['yes', 'y']:
        print("Setup cancelled.")
        return
    
    try:
        # Initialize Superset helper
        superset = SupersetHelper(
            superset_url=SUPERSET_URL,
            username=USERNAME,
            password=PASSWORD
        )
        
        # Run setup
        result = setup_nyc_taxi_dashboard(
            superset=superset,
            trino_uri=trino_uri,
            schema_name=TRINO_SCHEMA,
            table_name="nyc_taxi_aggregated"
        )
        
        if result:
            print("\n✓ All done! Your NYC Taxi dashboard is ready to use.")
        
    except Exception as e:
        print(f"\n✗ Error during setup: {e}")
        import traceback
        traceback.print_exc()


if __name__ == "__main__":
    main()

