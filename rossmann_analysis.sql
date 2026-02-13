/* 
Project: Rossmann Retail Performance Analysis
Objective: Analyze sales, customer behavior, promotions, and competition impact.
*/

--- DATABASE CREATION
CREATE DATABASE rossmann_analysis;
USE rossmann_analysis;

--- TABLE 1: stores, Source: store.csv
CREATE TABLE stores (
	store_id INT PRIMARY KEY,
    store_type CHAR(1),
    assortment CHAR (1),
    competition_distance INT,
    competition_open_since_month INT,
    competition_open_since_year INT,
    promo2 INT,
    promo2_since_week INT,
    promo2_since_year INT,
    promo_interval VARCHAR (20)
);

--- TABLE 2: sales, Source: train.csv
CREATE TABLE sales (
	store_id INT,
    date DATE,
    day_of_week INT,
    sales INT,
    customers INT,
    open INT,
    promo INT,
    state_holiday CHAR (1),
    school_holiday INT,
    PRIMARY KEY (store_id, date),
    FOREIGN KEY (store_id) REFERENCES stores(store_id)
);

SHOW VARIABLES LIKE 'local_infile';
SET GLOBAL local_infile = 1;

LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\store.csv'
INTO TABLE stores
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
	store_id,
    store_type,
    assortment,
    @competition_distance,
    @competition_open_since_month,
    @competition_open_since_year,
    promo2,
    @promo2_since_week,
    @promo2_since_year,
    promo_interval
)
SET
	competition_distance = NULLIF(@competition_distance, ''),
    competition_open_since_month = NULLIF(@competition_open_since_month, ''),
    competition_open_since_year = NULLIF(@competition_open_since_year, ''),
    promo2_since_week = NULLIF(@promo2_since_week, ''),
    promo2_since_year = NULLIF(@promo_since_year, '');
    
SELECT COUNT(*) FROM stores;

LOAD DATA INFILE 'C:\\ProgramData\\MySQL\\MySQL Server 8.0\\Uploads\\train.csv'
INTO TABLE sales
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
	store_id,
    day_of_week,
    @date,
    sales,
    customers,
    open,
    promo,
    state_holiday,
    school_holiday
)
SET date = STR_TO_DATE(@date, '%Y-%m-%d');

SELECT COUNT(*) FROM sales;

SELECT MIN(date), MAX(date) FROm sales;

SELECT
	COUNT(*)AS closed_days,
    SUM(sales) AS sales_on_closed_days
FROM sales
WHERE open = 0;

SELECT COUNT(*)
FROM sales
WHERE customers IS NULL;

--- Create an Analysis-Ready View to make queries cleaner and faster.

CREATE VIEW sales_clean AS
SELECT
	s.store_id,
    s.date,
    s.day_of_week,
    s.sales,
    s.customers,
    s.promo,
    s.state_holiday,
    s.school_holiday,
    st.store_type,
    st.assortment,
    st.competition_distance
FROM sales s
JOIN stores st ON s.store_id = st.store_id
WHERE s.open = 1;

--- KPI ANALYSIS – REVENUE & SALES PERFORMANCE

--- KPI 1: Total sales
--- How much revenue did the business generate in total?

SELECT
	SUM(sales) AS total_sales
FROM sales_clean;

--- This KPI provides a high-level view of overall business performance across all stores and dates

--- KPI 2 Average Daily Sales per store
--- On an average day, how much does a store sell?

SELECT
	AVG(sales) AS avg_daily_sales
FROM sales_clean;

--- This matters because it normalizes performance, makes stores comparable and is heavily used by management

--- KPI 3 Total sales by store
--- Which stores generate the most revenue?

SELECT
	store_id,
    SUM(sales) AS total_sales
FROM sales_clean
GROUP BY store_id
ORDER BY total_sales DESC;

--- For Top 10 stores:
SELECT
	store_id,
    SUM(sales) AS total_sales
FROM sales_clean
GROUP BY store_id
ORDER BY total_sales DESC
LIMIT 10;

--- For botton 10 stores:
SELECT
	store_id,
    SUM(sales) AS total_sales
FROM sales_clean
GROUP BY store_id
ORDER BY total_sales DESC
LIMIT 10;

--- This analysis identifies top- and bottom- performing stores to support targeted operational decisions

--- KPI 4 Sales trend over time (monthly)
--- How do sales change over time? Are these seasonal patterns?

SELECT
	YEAR(date) AS year,
    MONTH(date) AS month,
    SUM(SALES) AS monthly_sales
FROM sales_clean
GROUP BY YEAR(date), MONTH(date)
ORDER BY year, month;

--- This analysis supports improves forecasting, strategic marketing allocation, and inventory planning aligned with seasonal demand patterns

--- KPI 5: Average sales by day of week
--- Do some days perform better than others?

SELECT 
	day_of_week,
    AVG(sales) AS avg_sales
FROM sales_clean
GROUP BY day_of_week
ORDER BY day_of_week;

--- This is useful for staffing, helps schedule promotions and supports operational planning

--- KPI 6: Sales Consistency (stability)
--- Which stores have stable vs volatile sales?

SELECT 
	store_id,
    AVG(sales) AS avg_sales,
    STDDEV(sales) AS sales_variability
FROM sales_clean
GROUP BY store_id
ORDER BY sales_variability DESC;

--- Stores with high variability may be riskier and harder to forecast


--- CUSTOMER BEHAVIOR ANALYSIS

--- KPI 1: Average customers per day
--- How many customers visit a store on an average day?

SELECT
	AVG(customers) AS avg_customers_per_day
FROM sales_clean;

--- This gives insights of baseline footfall and helps staffing decisions

--- KPI 2: Customers by day of week
--- Which days attract the most customers?

SELECT
	day_of_week,
    AVG(customers) AS avg_customers
FROM sales_clean
GROUP BY day_of_week
ORDER BY day_of_week;

--- Customers footfall varies by weekday, indicating opportunities for targeted stffing and promotions.

--- KPI 3 Sales per customer (spend behavior)
--- How much does an average customer spend?

SELECT
	SUM(sales) / SUM(customers) as sales_per_customer
FROM sales_clean;

--- This shows basket size and separates traffic growth vs revenue growth

--- KPI 4: Promotion Impact on Customers
--- Do promotionsbring more customers?

SELECT
	promo,
    AVG(customers) AS avg_customers
FROM sales_clean
GROUP BY promo;

--- Higher customers on promo days = footfall-driven promos, No increase = discount-only effect

--- KPI 5: Store type and customer footfall
--- Which store formats attract more customers?

SELECT
	store_type,
    AVG(customers) AS avg_customers
FROM sales_clean
GROUP BY store_type
ORDER BY avg_customers DESC;

--- KPI 6: Top stories by customer volume
--- Which stores consistently attract the most customers?

SELECT
	store_id,
    AVG(customers) AS avg_customers
FROM sales_clean
GROUP BY store_id
ORDER BY avg_customers DESC
LIMIT 10;


--- Promotion effectiveness analysis

--- KPI 1: Sales: Promo vs Non-promo
--- Do promotions increase sales?

SELECT
	promo,
    AVG(sales) AS avg_sales
FROM sales_clean
GROUP BY promo;

--- Promo = 1 higher - promotions drive revenue
--- Small gap - promotions may be unnecessary discounts

--- KPI 2 Customer Footfall impact
--- Do promotions bring in more customers?

SELECT
	promo,
    AVG(customers) AS avg_customers
FROM sales_clean
GROUP BY promo;

--- More customers = traffic-driven promotions
--- Same customers = price-only effect

--- KPI 3: Basket size (critical)
--- Do customers spend more or less during promotion?

SELECT
	promo,
    SUM(sales) / SUM(customers) AS sales_per_customer
FROM sales_clean
GROUP BY promo;

--- Basket size ↓ on promo → discount-driven sales
--- Basket size ↑ → strong cross-selling

--- KPI 4: Promo effect by store type
--- Do promotions work better for certain store formats?

SELECT
	store_type,
    promo,
    AVG(sales) AS avg_sales
FROM sales_clean
GROUP BY store_type, promo
ORDER BY store_type, promo;

--- Promotions are more effective in specific store formats, enabling targeted promotional strategies

--- KPI 5: Promo Lift (%) 

SELECT
	store_type,
    (
		AVG(CASE WHEN promo = 1 THEN sales END)
        -
        AVG(CASE WHEN promo = 0 THEN sales END)
	) / AVG(CASE WHEN PROMO = 0 THEN sales END) * 100
	AS promo_lift_percent
FROM sales_clean
GROUP BY store_type;

--- +20% = strong promo effect
--- ~ 0% = wasted promotions

--- COMPETITION & STORE CHARACTERISTICS ANALYSIS
--- How do store attributes and nearby competition impact performance?

--- KPI 1 Sales vs Competition distance
--- Do stores with closer competitors perform worse?

SELECT
	CASE
		WHEN competition_distance < 500 THEN 'Very Close'
        WHEN competition_distance < 2000 THEN 'Medium'
        ELSE 'Far'
	END AS competition_bucket,
    AVG(sales) AS avg_sales
FROM sales_clean
GROUP BY competition_bucket;

--- Lower sales when competition is “Very Close” → competitive pressure
--- No difference → strong brand dominance

--- KPI 2: Customer Footfall vs competition
--- Does nearby competition reduce customer visits?

SELECT
	CASE
		WHEN competition_distance < 500 THEN 'Very close'
        WHEN competition_distance < 2000 THEN 'Medium'
        ELSE 'Far'
	END AS competition_bucket,
    AVG(customers) AS avg_customers
FROM sales_clean
GROUP BY competition_bucket;

--- KPI 3: Store Type Performance
--- Which store formats perform best?

SELECT
	store_type,
    AVG(sales) AS avg_sales,
    AVG(customers) AS avg_customers
FROM sales_clean
GROUP BY store_type
ORDER BY avg_sales DESC;

--- Different formats behave differently → one-size-fits-all strategy fails

--- KPI 4: Assortment Depth Impact
--- Does product assortment depth matter?

SELECT
	assortment,
    AVG(sales) AS avg_sales,
    AVG(customers) AS avg_customers
FROM sales_clean
GROUP BY assortment
ORDER BY avg_sales DESC;

--- Assortment type usually means: A = basic, B = extra and C = extended

--- KPI 5: Competition × Store Type 
--- Which store types handle competiton better?

SELECT
	store_type,
    CASE
		WHEN competition_distance < 500 THEN 'Very Close'
        WHEN competition_distance < 2000 THEN 'Medium'
        ELSE 'Far'
	END AS competition_bucket,
    AVG(sales) AS avg_sales
FROM sales_clean
GROUP BY store_type, competition_bucket
ORDER BY store_type, competition_bucket;

--- identifies resilient formats, helps expansion decisions


/* 
=====================================================
FINAL PROJECT SUMMARY – ROSSMANN SALES ANALYSIS
=====================================================

This SQL analysis evaluated:

1. Revenue performance (total sales, trends, store performance)
2. Customer behavior (footfall, spend per customer, weekday patterns)
3. Promotion effectiveness (sales lift, basket size impact, promo ROI)
4. Competitive impact (competition distance, store format resilience)

Key Insights:
- Revenue varies significantly by store and season.
- Promotions are more effective in certain store types.
- Customer traffic fluctuates by weekday and promotional activity.
- Competition proximity influences performance in specific formats.
- Sales variability differs across stores, affecting forecast stability.

Business Impact:
These findings support:
- Smarter promotional strategy
- Optimized staffing and operations
- Data-driven expansion planning
- Improved forecasting accuracy

Next Steps:
- Build a Power BI dashboard using these KPIs

End of SQL Analysis.
=====================================================
*/
