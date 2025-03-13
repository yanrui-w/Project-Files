# SQL Advanced Data Analytics Project

A comprehensive collection of SQL scripts for data exploration, analytics, and reporting. These scripts cover various analyses such as database exploration, measures and metrics, time-based trends, cumulative analytics, segmentation, and more. This repository contains SQL queries designed to help data analysts and BI professionals quickly explore, segment, and analyze data within a relational database. Each script focuses on a specific analytical theme and demonstrates best practices for SQL queries.

## Create project database

## Import Tables

- gold.dim_customers
- gold.dim_products
- gold.fact_sales

## Change-Over-Time Trends

- Goals
  - Analyze how a measure evolves over time
  - Help track trends and identify seasonality in your data
- Tasks / Scripts
  - High-level overview of total sales, number of customers, quantity by year
  - Drill down to months

## Cumulative Analysis

- Goals
  - Aggregate the data progressively over time
  - Help to understand whether our business is growing or declining
- Tasks / Scripts
  - View total sales per month, running total of sales and moving avg of price over time

## Performance Analysis

- Goals
  - Compare the current value to a target value
  - Help measure success and compare performance
- Tasks / Scripts
  - Analyze the yearly performance of products by comparing each product's sales to both its average sales performance and the previous year's sales.

## Part-to-Whole Proportional

- Goals
  - Analyze how an individual part is performing compared to the overall
  - Allow us to understand which category has the greatest impact on the business
- Tasks / Scripts
  - Which categories contribute the most to overall sales?

## Data Segmentation

- Goals
  - Group the data based on a specific range
  - Help understand the correlation b/w two measures
- Tasks / Scripts
  - Segment products into cost ranges and count how many products fall into each segment
  - Group customers into 3 segments based on their spending behavior:
    - VIP: at least 12 months of history and spending more than €5,000
    - Regular: at least 12 months of history but spending €5,000 or less
    - New: lifespan less than 12 months
    - And find the total number of customers by each group.

## Reporting

- Goals

  - Collect different types of explorations and analysis
  - Help stakeholders to have insights into one object and make great decision-making

- Tasks / Scripts

  - Customer Report

    - Purpose:
      	- This report consolidates key customer metrics and behaviors

    - Highlights:

      - Gathers essential fields such as names, ages, and transaction details.

      - Segments customers into categories (VIP, Regular, New) and age groups.

      - Aggregates customer-level metrics:

        - total orders

        - total sales

        - total quantity purchased

        - total products

        - lifespan (in months)

      - Calculates valuable KPIs:

        - recency (months since last order)
        - average order value
        - average monthly spend

  - Product Report

    - Purpose:
      	- This report consolidates key product metrics and behaviors.
    - Highlights:
      - Gathers essential fields such as product name, category, subcategory, and cost.
      - Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
      - Aggregates product-level metrics:
        - total orders
        - total sales
        - total quantity sold
        - total customers (unique)
        - lifespan (in months)
      - Calculates valuable KPIs:
        - recency (months since last sale)
        - average order revenue (AOR)
        - average monthly revenue