-- Analysis 1: Who are our most valuable customers?
SELECT 
    c.customer_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.acquisition_chanel,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(o.total_amount), 2) AS total_revenue,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_status != 'Cancelled'
GROUP BY c.customer_id, c.first_name, c.last_name, c.acquisition_chanel
ORDER BY total_revenue DESC
LIMIT 10;

-- Analysis 2: Which marketing channels deliver the highest value customers?
SELECT 
    c.acquisition_chanel,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(o.total_amount), 2) AS total_revenue,
    ROUND(SUM(o.total_amount) / COUNT(DISTINCT c.customer_id), 2) AS avg_customer_ltv,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.order_status != 'Cancelled'
GROUP BY c.acquisition_chanel
ORDER BY avg_customer_ltv DESC;

-- Analysis 3: Which customers haven't purchased in 6+ months?
WITH customer_last_order AS (
    SELECT 
        c.customer_id,
        c.first_name || ' ' || c.last_name AS customer_name,
        c.email,
        MAX(o.order_date) AS last_order_date,
        COUNT(DISTINCT o.order_id) AS total_orders,
        ROUND(SUM(o.total_amount), 2) AS total_spent,
        CURRENT_DATE - MAX(o.order_date)::date AS days_since_last_order
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status != 'Cancelled'
    GROUP BY c.customer_id, c.first_name, c.last_name, c.email
)
SELECT 
    customer_name,
    email,
    last_order_date,
    days_since_last_order,
    total_orders,
    total_spent,
    CASE 
        WHEN days_since_last_order >= 365 THEN 'Critical'
        ELSE 'High Risk'
    END AS churn_risk
FROM customer_last_order
WHERE days_since_last_order >= 180
ORDER BY total_spent DESC
LIMIT 10;

-- Analysis 4: Which product categories are most profitable?
SELECT 
    cat.category_name,
    COUNT(DISTINCT p.product_id) AS num_products,
    COUNT(DISTINCT oi.order_id) AS num_orders,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.subtotal), 2) AS total_revenue,
    ROUND(SUM(oi.quantity * p.unit_cost), 2) AS total_cost,
    ROUND(SUM(oi.subtotal) - SUM(oi.quantity * p.unit_cost), 2) AS gross_profit,
    ROUND(100.0 * (SUM(oi.subtotal) - SUM(oi.quantity * p.unit_cost)) / NULLIF(SUM(oi.subtotal), 0), 1) AS profit_margin_pct,
    ROUND(SUM(oi.subtotal) / COUNT(DISTINCT oi.order_id), 2) AS avg_revenue_per_order
FROM categories cat
JOIN products p ON cat.category_id = p.category_id
JOIN order_items oi ON p.product_id = oi.product_id
GROUP BY cat.category_name
ORDER BY gross_profit DESC;

-- Analysis 5: What are our star products by revenue and volume?
SELECT 
    p.product_id,
    p.product_name,
    cat.category_name,
    SUM(oi.quantity) AS units_sold,
    COUNT(DISTINCT oi.order_id) AS num_orders,
    ROUND(SUM(oi.subtotal), 2) AS total_revenue,
    ROUND(AVG(oi.unit_price), 2) AS avg_selling_price,
    COUNT(DISTINCT r.review_id) AS num_reviews
FROM products p
JOIN categories cat ON p.category_id = cat.category_id
JOIN suppliers s ON p.supplier_id = s.supplier_id
JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN reviews r ON p.product_id = r.product_id
GROUP BY p.product_id, p.product_name, cat.category_name
ORDER BY total_revenue DESC
LIMIT 10;

-- Analysis 6: Which categories drive highest order values?
WITH category_orders AS (
    SELECT 
        cat.category_name,
        o.order_id,
        o.total_amount AS order_total
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    JOIN categories cat ON p.category_id = cat.category_id
    WHERE o.order_status != 'Cancelled'
    GROUP BY cat.category_name, o.order_id, o.total_amount
)
SELECT 
    category_name,
    COUNT(DISTINCT order_id) AS num_orders,
    ROUND(AVG(order_total), 2) AS avg_order_value,
    ROUND(MIN(order_total), 2) AS min_order_value,
    ROUND(MAX(order_total), 2) AS max_order_value
FROM category_orders
GROUP BY category_name
ORDER BY avg_order_value DESC;

-- Analysis 7: Which products have quality or expectation issues?
WITH product_returns AS (
    SELECT 
        p.product_id,
        p.product_name,
        cat.category_name,
        COUNT(DISTINCT oi.order_item_id) AS items_sold,
        COUNT(DISTINCT r.return_id) AS items_returned,
        ROUND(100.0 * COUNT(DISTINCT r.return_id) / 
              NULLIF(COUNT(DISTINCT oi.order_item_id), 0), 2) AS return_rate_pct,
        ROUND(SUM(r.refund_amount), 2) AS total_refunded
    FROM products p
    JOIN categories cat ON p.category_id = cat.category_id
    JOIN order_items oi ON p.product_id = oi.product_id
    LEFT JOIN returns r ON oi.order_item_id = r.order_item_id
    GROUP BY p.product_id, p.product_name, cat.category_name
    HAVING COUNT(DISTINCT oi.order_item_id) >= 20
)
SELECT 
    product_name,
    category_name,
    items_sold,
    items_returned,
    return_rate_pct,
    total_refunded
FROM product_returns
WHERE items_returned > 0
ORDER BY return_rate_pct DESC
LIMIT 10;

-- Analysis 8: What cross-sell opportunities exist?
WITH order_categories AS (
    SELECT DISTINCT
        o.order_id,
        cat.category_name
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    JOIN categories cat ON p.category_id = cat.category_id
    WHERE o.order_status != 'Cancelled'
)
SELECT 
    oc1.category_name AS category_1,
    oc2.category_name AS category_2,
    COUNT(DISTINCT oc1.order_id) AS times_bought_together,
    ROUND(100.0 * COUNT(DISTINCT oc1.order_id) / 
          (SELECT COUNT(DISTINCT order_id) FROM orders WHERE order_status != 'Cancelled'), 2) 
          AS pct_of_all_orders
FROM order_categories oc1
JOIN order_categories oc2 ON oc1.order_id = oc2.order_id 
    AND oc1.category_name < oc2.category_name
GROUP BY oc1.category_name, oc2.category_name
HAVING COUNT(DISTINCT oc1.order_id) >= 50
ORDER BY times_bought_together DESC
LIMIT 10;

-- Analysis 9: Which supplier the best products?
SELECT 
    s.supplier_name,
    s.country,
    COUNT(DISTINCT p.product_id) AS num_products,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.subtotal), 2) AS total_revenue,
    ROUND(AVG(pr.rating), 2) AS avg_product_rating,
    ROUND(100.0 * COUNT(DISTINCT r.return_id) / 
          NULLIF(COUNT(DISTINCT oi.order_item_id), 0), 2) AS return_rate_pct
FROM suppliers s
JOIN products p ON s.supplier_id = p.supplier_id
JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN reviews pr ON p.product_id = pr.product_id
LEFT JOIN returns r ON oi.order_item_id = r.order_item_id
GROUP BY s.supplier_id, s.supplier_name, s.country
ORDER BY total_revenue DESC
LIMIT 10;

-- Analysis 10: What are our sales patterns over time?
WITH monthly_sales AS (
    SELECT 
        TO_CHAR(order_date, 'YYYY-MM') AS year_month,
        DATE_TRUNC('month', order_date) AS month_start,
        COUNT(DISTINCT order_id) AS num_orders,
        COUNT(DISTINCT customer_id) AS unique_customers,
        ROUND(SUM(total_amount), 2) AS total_revenue,
        ROUND(AVG(total_amount), 2) AS avg_order_value
    FROM orders
    WHERE order_status != 'Cancelled'
      AND order_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY year_month, month_start
)
SELECT 
    year_month,
    num_orders,
    unique_customers,
    total_revenue,
    avg_order_value,
    ROUND(100.0 * (total_revenue - LAG(total_revenue) OVER (ORDER BY month_start)) / 
          NULLIF(LAG(total_revenue) OVER (ORDER BY month_start), 0), 1) AS pct_change_mom
FROM monthly_sales
ORDER BY month_start DESC;