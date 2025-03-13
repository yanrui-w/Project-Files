------------------------------------------Change-Over-Time Trends------------------------------------------

/*High-level overview of total sales, number of customers, quantity by year*/
SELECT
YEAR(order_date) AS order_year,
SUM(sales_amount) AS total_sales,
COUNT(customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY YEAR(order_date)

/*Drill down to months*/
SELECT
YEAR(order_date) AS order_year,
MONTH(order_date) AS order_month,
SUM(sales_amount) AS total_sales,
COUNT(customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY YEAR(order_date), MONTH(order_date)
/* OR */
SELECT
DATETRUNC(month, order_date) AS order_date,
SUM(sales_amount) AS total_sales,
COUNT(customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY DATETRUNC(month, order_date)
/* OR */
SELECT
FORMAT(order_date, 'yyyy-MMM') AS order_date,
SUM(sales_amount) AS total_sales,
COUNT(customer_key) AS total_customers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY FORMAT(order_date, 'yyyy-MMM')
ORDER BY FORMAT(order_date, 'yyyy-MMM')

------------------------------------------Cumulative Analysis------------------------------------------

/*View total sales per month, running total of sales and moving avg of price over time*/
SELECT
order_date,
total_sales,
avg_price,
SUM(total_sales) OVER (PARTITION BY YEAR(order_date) ORDER BY order_date) AS running_total_sales,
AVG(avg_price) OVER (PARTITION BY YEAR(order_date) ORDER BY order_date) AS moving_avg_price
FROM
(
SELECT
DATETRUNC(month, order_date) AS order_date,
SUM(sales_amount) AS total_sales,
AVG(price) AS avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
) t

------------------------------------------Performance Analysis------------------------------------------

/*Analyze the yearly performance of products by comparing each product's sales to
both its average sales performance and the previous year's sales.*/
WITH yearly_product_sales AS (
SELECT
p.product_name,
YEAR(f.order_date) AS order_year,
SUM(f.sales_amount) AS current_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY p.product_name, YEAR(f.order_date)
)
SELECT
product_name,
order_year,
current_sales,
-- avg sales
AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
-- current vs avg
current_sales - AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
CASE WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) > 0 THEN 'Above Avg'
	 WHEN current_sales - AVG(current_sales) OVER (PARTITION BY product_name) < 0 THEN 'Below Avg'
	 ELSE 'Avg'
END avg_change,
-- previous year sales
LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS py_sales,
-- current vs previous (YOY)
current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS diff_py,
CASE WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) > 0 THEN 'Increase'
	 WHEN current_sales - LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) < 0 THEN 'Decrease'
	 ELSE 'No Change'
END py_change
FROM yearly_product_sales
ORDER BY product_name, order_year

------------------------------------------Part-to-Whole Proportional------------------------------------------

/*Which categories contribute the most to overall sales?*/
WITH category_sales AS (
SELECT
p.category,
SUM(f.sales_amount) AS total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON f.product_key = p.product_key
GROUP BY p.category
)
SELECT
category,
total_sales,
SUM(total_sales) OVER () AS overall_sales,
CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER ())*100, 2), '%') AS percentage_of_sales
FROM category_sales
ORDER BY total_sales DESC

------------------------------------------Data Segmentation------------------------------------------

/*Segment products into cost ranges and
count how many products fall into each segment*/
WITH product_segments AS (
SELECT
product_key,
product_name,
cost,
CASE WHEN cost < 100 THEN 'Below 100'
	 WHEN cost BETWEEN 100 AND 500 THEN '100-500'
	 WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
	 ELSE 'Above 1000'
END cost_range
FROM gold.dim_products
)
SELECT
cost_range,
COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY COUNT(product_key) DESC

/*Group customers into 3 segments based on their spending behavior:
	- VIP: at least 12 months of history and spending more than €5,000
	- Regular: at least 12 months of history but spending €5,000 or less
	- New: lifespan less than 12 months
And find the total number of customers by each group.*/
WITH customer_spending AS (
SELECT
c.customer_key,
SUM(f.sales_amount) AS total_spending,
MIN(f.order_date) AS first_order,
MAX(f.order_date) AS last_order,
DATEDIFF(month, MIN(f.order_date), MAX(f.order_date)) AS lifespan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key = c.customer_key
GROUP BY c.customer_key
)
SELECT
COUNT(customer_key) AS total_customers,
customer_segment
FROM (
SELECT
customer_key,
CASE WHEN lifespan >= 12 AND total_spending > 5000 THEN 'VIP'
	 WHEN lifespan >= 12 AND total_spending <= 5000 THEN 'Regular'
	 ELSE 'New'
END customer_segment
FROM customer_spending
) t
GROUP BY customer_segment
ORDER BY total_customers DESC

------------------------------------------Reporting------------------------------------------

/*
=======================================================================================
Customer Report
=======================================================================================
Purpose:
	- This report consolidates key customer metrics and behaviors

Highlights:
	1. Gathers essential fields such as names, ages, and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and age groups.
	3. Aggregates customer-level metrics:
		- total orders
		- total sales
		- total quantity purchased
		- total products
		- lifespan (in months)
	4. Calculates valuable KPIs:
		- recency (months since last order)
		- average order value
		- average monthly spend
=======================================================================================
*/
CREATE VIEW gold.report_customers AS
-- 1) Base Query: Retrieves core columns from tables
WITH base_query AS (
SELECT
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
DATEDIFF(year, c.birthdate, GETDATE()) AS age
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON c.customer_key = f.customer_key
WHERE f.order_date IS NOT NULL
),
-- 2) Customer Aggregations: Summarizes key metrics at the customer level
customer_aggregation AS (
SELECT
customer_key,
customer_number,
customer_name,
age,
COUNT(DISTINCT order_number) AS total_orders,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS total_quantity,
COUNT(DISTINCT product_key) AS total_products,
MAX(order_date) AS last_order_date,
DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
FROM base_query
GROUP BY customer_key, customer_number, customer_name, age
)
-- 3) Customer Segmentations
SELECT
customer_key,
customer_number,
customer_name,
age,
CASE 
	 WHEN age < 20 THEN 'Under 20'
	 WHEN age BETWEEN 20 AND 29 THEN '20-29'
	 WHEN age BETWEEN 30 AND 39 THEN '30-39'
	 WHEN age BETWEEN 40 AND 49 THEN '40-49'
	 ELSE '50 and above'
END AS age_group,
CASE 
	 WHEN lifespan >= 12 AND total_sales > 5000 THEN 'VIP'
	 WHEN lifespan >= 12 AND total_sales <= 5000 THEN 'Regular'
	 ELSE 'New'
END AS customer_segment,
last_order_date,
total_orders,
total_quantity,
total_sales,
total_products,
lifespan,
-- 4) Compute recency, average order value (AVO), and average monthly spend
DATEDIFF(month, last_order_date, GETDATE()) AS recency,
CASE 
	 WHEN total_orders = 0 THEN 0
	 ELSE total_sales / total_orders
END AS avg_order_value,
CASE
	 WHEN lifespan = 0 THEN total_sales
	 ELSE total_sales / lifespan
END AS avg_monthly_spend
FROM customer_aggregation

/*
=======================================================================================
Product Report
=======================================================================================
Purpose:
	- This report consolidates key product metrics and behaviors.

Highlights:
	1. Gathers essential fields such as product name, category, subcategory, and cost.
	2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
	3. Aggregates product-level metrics:
		- total orders
		- total sales
		- total quantity sold
		- total customers (unique)
		- lifespan (in months)
	4. Calculates valuable KPIs:
		- recency (months since last sale)
		- average order revenue (AOR)
		- average monthly revenue
=======================================================================================
*/
CREATE VIEW gold.report_products AS
-- 1) Base Query
WITH base_query AS (
SELECT
f.product_key,
p.product_name,
p.category,
p.subcategory,
p.cost,
f.order_date,
f.order_number,
f.sales_amount,
f.quantity,
f.customer_key
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
ON p.product_key = f.product_key
WHERE f.order_date IS NOT NULL
),
-- 2) Product Aggregations
product_aggregations AS (
SELECT
product_key,
product_name,
category,
subcategory,
cost,
COUNT(DISTINCT order_number) AS total_orders,
SUM(sales_amount) AS total_sales,
SUM(quantity) AS total_quantity_sold,
COUNT(DISTINCT customer_key) AS total_customers,
MAX(order_date) AS last_sales_date,
DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan,
ROUND(AVG(CAST(sales_amount AS FLOAT) / NULLIF(quantity,0)),1) AS avt_selling_price
FROM base_query
GROUP BY
product_key,
product_name,
category,
subcategory,
cost
)
-- 3) Final Query
SELECT 
product_key,
product_name,
category,
subcategory,
cost,
last_sales_date,
total_orders,
total_sales,
total_quantity_sold,
total_customers,
lifespan,
avt_selling_price,
CASE
	 WHEN total_sales > 50000 THEN 'High-Performers'
	 WHEN total_sales >= 10000  THEN 'Mid-Range'
	 ELSE 'Low-Performers'
END AS product_segment,
-- 4) Compute recency, average order revenue, and average monthly revenue
DATEDIFF(month, last_sales_date, GETDATE()) AS recency,
CASE 
	 WHEN total_orders = 0 THEN 0
	 ELSE total_sales / total_orders
END AS avg_order_revenue,
CASE
	 WHEN lifespan = 0 THEN total_sales
	 ELSE total_sales / lifespan
END AS avg_monthly_revenue
FROM product_aggregations