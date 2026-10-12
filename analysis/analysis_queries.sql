-- ============================================================================
-- 1. Overall numbers: how big is the business?
-- ============================================================================
SELECT
    COUNT(DISTINCT order_number)  AS total_orders,
    COUNT(DISTINCT customer_key)  AS total_customers,
    SUM(sales_amount)             AS total_sales,
    SUM(quantity)                 AS total_items_sold,
    AVG(price)                    AS avg_price
FROM gold.fact_sales;


-- ============================================================================
-- 2. Sales per year (are sales growing?)
--    Rows with a missing order_date are skipped.
-- ============================================================================
SELECT
    YEAR(order_date)              AS order_year,
    COUNT(DISTINCT order_number)  AS orders,
    SUM(sales_amount)             AS total_sales,
    COUNT(DISTINCT customer_key)  AS customers
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY order_year;


-- ============================================================================
-- 3. Sales per month with a running total
-- ============================================================================
WITH monthly AS (
    SELECT
        DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1) AS order_month,
        SUM(sales_amount)                                     AS total_sales
    FROM gold.fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATEFROMPARTS(YEAR(order_date), MONTH(order_date), 1)
)
SELECT
    order_month,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_month) AS running_total_sales
FROM monthly
ORDER BY order_month;


-- ============================================================================
-- 4. Top 10 customers by total sales
-- ============================================================================
SELECT TOP 10
    c.customer_key,
    c.first_name,
    c.last_name,
    c.country,
    COUNT(DISTINCT f.order_number) AS orders,
    SUM(f.sales_amount)            AS total_sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY c.customer_key, c.first_name, c.last_name, c.country
ORDER BY total_sales DESC;


-- ============================================================================
-- 5. Sales by country (which markets matter most?)
--    Share = this country's sales / all sales, in percent.
-- ============================================================================
SELECT
    ISNULL(c.country, 'n/a')  AS country,
    SUM(f.sales_amount)       AS total_sales,
    CAST(100.0 * SUM(f.sales_amount)
         / NULLIF(SUM(SUM(f.sales_amount)) OVER (), 0) AS DECIMAL(5,2)) AS share_percent
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
    ON c.customer_key = f.customer_key
GROUP BY ISNULL(c.country, 'n/a')
ORDER BY total_sales DESC;


-- ============================================================================
-- 6. Sales by product category (which categories make the most money?)
-- ============================================================================
SELECT
    ISNULL(p.category, 'n/a')  AS category,
    COUNT(DISTINCT f.order_number) AS orders,
    SUM(f.sales_amount)        AS total_sales,
    CAST(100.0 * SUM(f.sales_amount)
         / NULLIF(SUM(SUM(f.sales_amount)) OVER (), 0) AS DECIMAL(5,2)) AS share_percent
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p
    ON p.product_key = f.product_key
GROUP BY ISNULL(p.category, 'n/a')
ORDER BY total_sales DESC;


-- ============================================================================
-- 7. Top 3 products inside each category
--    RANK() restarts the ranking for every category.
-- ============================================================================
WITH product_sales AS (
    SELECT
        p.category,
        p.product_name,
        SUM(f.sales_amount) AS total_sales
    FROM gold.fact_sales f
    JOIN gold.dim_products p
        ON p.product_key = f.product_key
    GROUP BY p.category, p.product_name
),
ranked AS (
    SELECT
        category,
        product_name,
        total_sales,
        RANK() OVER (PARTITION BY category ORDER BY total_sales DESC) AS rank_in_category
    FROM product_sales
)
SELECT category, rank_in_category, product_name, total_sales
FROM ranked
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;


-- ============================================================================
-- 8. Average days between order and shipping (how fast do we ship?)
--    Only orders where both dates exist.
-- ============================================================================
SELECT
    YEAR(order_date)                                       AS order_year,
    AVG(CAST(DATEDIFF(DAY, order_date, shipping_date) AS DECIMAL(10,2))) AS avg_days_to_ship
FROM gold.fact_sales
WHERE order_date IS NOT NULL
  AND shipping_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY order_year;
