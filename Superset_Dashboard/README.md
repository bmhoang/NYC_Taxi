# NYC Taxi Superset Dashboard

This directory contains resources for creating an Apache Superset dashboard to visualize NYC Taxi data stored in Trino.

## 📁 Files in This Directory

- **`Superset_Setup_Guide.md`** - Comprehensive guide for setting up Superset with Trino and creating the NYC Taxi dashboard
- **`trino_queries.sql`** - Collection of optimized SQL queries for various visualizations
- **`superset_config_helper.py`** - Python script to programmatically set up the dashboard using Superset API
- **`chart_configurations.md`** - Quick reference for chart types and configurations
- **`advanced_chart_ideas.md`** - 🆕 21 innovative chart ideas beyond standard analytics
- **`QUICK_WINS.md`** - ⭐ Top 5 high-value charts to implement first (START HERE!)
- **`INSIGHTS_GUIDE.md`** - 💡 Complete guide: what each chart tells you and how to act on it
- **`INSIGHTS_SUMMARY.md`** - 📋 One-page quick reference of all chart insights
- **`DATA_INGESTION_GUIDE.md`** - 📥 How to get data and create tables in Trino
- **`README.md`** - This file

## 🚀 Quick Start

### Prerequisites

1. **Apache Superset** installed and running
   ```bash
   pip install apache-superset
   superset db upgrade
   superset fab create-admin
   superset init
   superset run -p 8088 --with-threads --reload --debugger
   ```

2. **Trino** accessible with NYC Taxi data
   - Data should be aggregated by hour and pickup location (as per `PySparkCalculation.py`)
   - Table structure should match the schema in `Superset_Setup_Guide.md`

3. **Python packages** (for automation script):
   ```bash
   pip install requests pandas
   ```

### Option 1: Manual Setup (Recommended for Learning)

1. Read **`Superset_Setup_Guide.md`** for step-by-step instructions
2. Connect Superset to Trino using the connection string:
   ```
   trino://username@host:port/catalog/schema
   ```
3. Create datasets from your tables
4. Use queries from **`trino_queries.sql`** to create charts
5. Refer to **`chart_configurations.md`** for specific chart settings

### Option 2: Automated Setup (Fast)

1. Edit **`superset_config_helper.py`** with your connection details:
   ```python
   SUPERSET_URL = "http://localhost:8088"
   USERNAME = "admin"
   PASSWORD = "your_password"
   
   TRINO_HOST = "your_trino_host"
   TRINO_PORT = 8080
   TRINO_CATALOG = "hive"
   TRINO_SCHEMA = "nyc_taxi"
   ```

2. Run the script:
   ```bash
   python superset_config_helper.py
   ```

3. Access your dashboard at:
   ```
   http://localhost:8088/superset/dashboard/<dashboard_id>/
   ```

## 📊 Dashboard Components & Insights

The NYC Taxi dashboard provides **actionable insights** for different stakeholders:

### 1. Summary Dashboard
**Charts:**
- **KPIs**: Total Trips, Total Revenue, Average Fare, Total Distance
- **Time Series**: Trips and revenue over time
- **Busy Hours**: Hourly trip patterns

**Key Insights:**
- 📈 Is demand growing or declining? (Track business health)
- ⏰ When are peak hours? (Optimize driver scheduling)
- 💰 What's the revenue trend? (Financial planning)

**Who Uses It:** Executives, Fleet Managers, Analysts

---

### 2. Amount Details Dashboard
**Charts:**
- **Fare Breakdown**: Components (base fare, tips, tolls, extra)
- **Average Fare**: By hour and location
- **Tip Analysis**: Tip percentages and patterns

**Key Insights:**
- 💳 Where does revenue come from? (Base vs tips vs tolls)
- 🕐 When are fares highest? (Target premium hours)
- 🎁 Are customers tipping well? (Service quality indicator)

**Who Uses It:** Finance, Pricing Strategy, Drivers

---

### 3. Trip Details Dashboard
**Charts:**
- **Distance Distribution**: Trip distance histogram
- **Passenger Analysis**: Average passengers by hour
- **Top Locations**: Busiest pickup zones

**Key Insights:**
- 🚗 Short-haul or long-haul service? (Business model)
- 👥 When do groups travel? (Vehicle type needs)
- 📍 Where should drivers position? (Maximize pickups)

**Who Uses It:** Drivers, Operations, Fleet Planning

---

### 4. Map Dashboard
**Charts:**
- **Geographic Heatmap**: Pickup location density
- **Borough Analysis**: Trips by borough
- **Zone Details**: Interactive map with trip counts

**Key Insights:**
- 🗺️ Where is demand concentrated? (Hot spots)
- 🏙️ Are all areas served equally? (Service equity)
- 🎯 Where to expand? (Growth opportunities)

**Who Uses It:** Strategy, Regulators, Green Taxi Operators

---

## 💡 Understanding Your Dashboard

### Quick Start - Read These First:
1. **`INSIGHTS_SUMMARY.md`** ⚡ - One-page quick reference of what each chart means
2. **`INSIGHTS_GUIDE.md`** 📖 - Detailed guide with examples and actions

### Real Questions Answered by the Dashboard:

#### For Drivers:
- ❓ "Where should I drive at 6 PM to make the most money?"  
  ✅ **Answer**: Check Top Locations + Revenue Per Minute → Position at Financial District ($1.45/min)

- ❓ "Should I work morning or evening shift?"  
  ✅ **Answer**: Check Optimal Shift Analysis → Evening earns $285/day vs morning $265/day

- ❓ "When do customers tip best?"  
  ✅ **Answer**: Check Tip Optimization → Wall St lunch (22%) and Friday nights (19%)

#### For Managers:
- ❓ "How many drivers do I need at 8 AM?"  
  ✅ **Answer**: Check Busy Hours → 8 AM has 30K trips, need 3x more drivers than off-peak

- ❓ "Which zones should we prioritize?"  
  ✅ **Answer**: Check Pareto Analysis → Top 50 zones = 85% of revenue (focus here)

- ❓ "Is the business healthy?"  
  ✅ **Answer**: Check KPIs → Trips +15%, Revenue +18% = Healthy growth + pricing power

#### For Strategy:
- ❓ "Where should Green taxis expand?"  
  ✅ **Answer**: Check Competition Map → Queens/Bronx underserved, 25% growth opportunity

- ❓ "Are we losing market share to Yellow?"  
  ✅ **Answer**: Check Yellow vs Green → See zone-by-zone market dynamics

- ❓ "What's our competitive advantage?"  
  ✅ **Answer**: Check multiple metrics → Green owns outer boroughs (60% share)

## 🎨 Dashboard Design

### Color Scheme
- **Yellow Taxi**: `#FFD700` (Gold)
- **Green Taxi**: `#32CD32` (Lime Green)
- **Revenue Metrics**: Green gradient
- **Trip Count Metrics**: Blue gradient

### Layout
```
┌────────────────────────────────────────┐
│         Dashboard Filters              │
├────────────────────────────────────────┤
│  KPI Cards (4 across)                  │
├────────────────────────────────────────┤
│  Main Time Series Chart                │
├────────────────────────────────────────┤
│  Busy Hours  │  Top Locations          │
├────────────────────────────────────────┤
│  Geographic Heatmap                    │
└────────────────────────────────────────┘
```

## 📝 Key Queries

All queries are available in **`trino_queries.sql`**, organized by category:

1. **KPIs**: Total trips, revenue, average fare, distance
2. **Time Series**: Hourly/daily trends
3. **Busy Hours**: Peak time analysis
4. **Locations**: Top pickup zones
5. **Fare Analysis**: Components, distribution, tips
6. **Distance Analysis**: Trip distance patterns
7. **Passengers**: Count distribution
8. **Taxi Type**: Yellow vs Green comparison
9. **Maps**: Geographic data for visualizations
10. **Advanced**: WoW growth, peak vs off-peak

## 🔧 Customization

### Adjust Date Ranges
Most queries use a 30-day lookback. To change:
```sql
-- Change this:
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '30' DAY, '%Y-%m-%d %H')

-- To this (for 7 days):
WHERE Pickup_Time >= DATE_FORMAT(CURRENT_DATE - INTERVAL '7' DAY, '%Y-%m-%d %H')
```

### Add New Metrics
Create calculated columns in Superset:
- Hour: `CAST(SUBSTR(Pickup_Time, 12, 2) AS INTEGER)`
- Day of Week: `DAY_OF_WEEK(DATE(Pickup_Time))`
- Tip %: `(tip_amount / Fare_Amount) * 100`

### Filter Outliers
Add WHERE clauses to queries:
```sql
WHERE AVG_Trip_Distance > 0 
  AND AVG_Trip_Distance < 100
  AND AVG_Total_Amount > 0
  AND AVG_Total_Amount < 500
```

## 🗺️ Map Setup

For map visualizations, you need a `taxi_zones` table:

```sql
CREATE TABLE taxi_zones (
    LocationID INT,
    Borough VARCHAR,
    Zone VARCHAR,
    service_zone VARCHAR,
    latitude DOUBLE,
    longitude DOUBLE
)
```

Data source: https://geo.nyu.edu/catalog/nyu-2451-36743

## 🎯 Dashboard Filters

Add these filters to your dashboard for interactivity:

1. **Date Range** (Pickup_Time) - Default: Last 30 days
2. **Taxi Type** (taxi_type) - Options: Yellow, Green, All
3. **Borough** (from taxi_zones) - Options: Manhattan, Brooklyn, Queens, Bronx, Staten Island
4. **Hour Range** (0-23) - For specific time analysis

## ⚡ Performance Tips

1. **Use Materialized Views** in Trino for pre-aggregated data
2. **Enable Caching** in Superset (Settings → Cache Timeout: 3600s)
3. **Limit Row Counts**:
   - KPIs: 1 row
   - Time series: 10,000 rows
   - Tables: 100-1,000 rows
   - Maps: 500-1,000 points
4. **Add Indexes** on Pickup_Time and Pickup_Location in Trino
5. **Use Async Queries** for long-running queries

## 📚 Documentation

### Superset Resources
- **Official Docs**: https://superset.apache.org/docs/intro
- **Chart Gallery**: https://superset.apache.org/gallery
- **API Reference**: https://superset.apache.org/docs/rest-api

### Trino Resources
- **Official Docs**: https://trino.io/docs/current/
- **SQL Functions**: https://trino.io/docs/current/functions.html
- **Connectors**: https://trino.io/docs/current/connector.html

### NYC Taxi Data
- **Data Dictionary (Yellow)**: `../data_dictionary_trip_records_yellow.pdf`
- **Data Dictionary (Green)**: `../data_dictionary_trip_records_green.pdf`
- **Original Data Source**: https://www1.nyc.gov/site/tlc/about/tlc-trip-record-data.page

## 🐛 Troubleshooting

### Connection Issues
```bash
# Test Trino connection
trino --server localhost:8080 --catalog hive --schema nyc_taxi

# Check if Superset can reach Trino
curl http://trino-host:8080/v1/info
```

### Query Errors
- Test queries in Trino CLI first
- Check table and column names
- Verify data types match expectations
- Use SQL Lab in Superset to debug

### Chart Not Loading
- Clear browser cache
- Check row limits (increase if needed)
- Verify dataset permissions
- Look at Superset logs: `superset run --debug`

### Map Issues
- Ensure latitude/longitude are DOUBLE type
- Check for NULL values in coordinates
- Verify viewport settings (center on NYC: 40.7128, -74.0060)

## 🆚 Comparison with Existing Dashboards

### Qlik Sense Dashboard
- See `../QlikSense_Dashboard/` for reference screenshots
- Superset provides similar functionality with:
  - More flexible SQL queries
  - Better integration with Trino
  - Open-source and customizable

### Tableau Dashboard
- See `../Tableau_Dashboard/` for reference
- Superset advantages:
  - No licensing costs
  - Direct Trino connectivity
  - RESTful API for automation
  - Better for large datasets

## 🚀 Advanced & Innovative Charts

Beyond standard dashboards, we've created **21 innovative chart ideas** that provide deeper insights:

### Efficiency & Profitability
- **Revenue Per Minute** - Find most profitable hours/locations by time efficiency
- **Fare Efficiency Score** - Distance-adjusted revenue analysis
- **Capacity Utilization Index** - Optimize passenger count and ride-sharing

### Predictive Analytics
- **Demand Forecasting** - Predict next week's demand by hour
- **Seasonality Decomposition** - Separate trends from seasonal patterns
- **Anomaly Detection** - Identify unusual patterns and outliers

### Strategic Analysis
- **Yellow vs Green Competition** - Market share by territory
- **BCG Matrix (Profitability)** - Classify zones as Stars, Cash Cows, Question Marks, Dogs
- **Pareto Analysis** - 80/20 rule - which 20% of locations drive 80% of trips?

### Optimization
- **Optimal Shift Analysis** - Which 8-hour shifts are most profitable?
- **Tip Yield Optimization** - When and where customers tip best
- **Idle Time Minimization** - Zones with shortest gaps between trips

### Real-time Monitoring
- **Live Performance Dashboard** - Current hour vs historical average
- **Rolling 24-Hour Metrics** - Continuous performance tracking
- **Variance Stability** - Predictability monitoring

### Behavioral Patterns
- **Trip Distance Behavior** - How trip lengths vary by time
- **Passenger Group Patterns** - Solo vs group travel patterns
- **Temporal Flow** - How top locations shift throughout the day

**See `advanced_chart_ideas.md` for detailed queries and implementation guide!**

---

## 📈 Next Steps

1. ✅ Set up Superset and connect to Trino
2. ✅ Create base dashboard with KPIs and time series
3. ✅ Add location analysis and maps
4. ⬜ Implement 3-5 advanced charts from `advanced_chart_ideas.md`
5. ⬜ Set up scheduled email reports
6. ⬜ Configure alerts for anomalies
7. ⬜ Add predictive analytics (demand forecasting)
8. ⬜ Create mobile-friendly version
9. ⬜ Integrate with external systems (Slack, etc.)

## 🤝 Contributing

This dashboard is based on the original NYC Taxi project by Sekyung Na. For questions or improvements:

- **Original Author**: Sekyung Na
- **LinkedIn**: https://www.linkedin.com/in/sekyung-na-95500a5a/
- **Tableau Public**: https://public.tableau.com/profile/sekyung.na6348

## 📄 License

This project follows the same license as the parent NYC Taxi project.

---

**Last Updated**: October 2025  
**Version**: 1.0  
**Status**: Ready for Production

