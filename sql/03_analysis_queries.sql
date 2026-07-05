-- Olist E-Commerce Analysis: Business Analysis Queries
-- Q1: Monthly revenue trend | Q2: Category performance
-- Q3: Delivery by state | Q4: Late delivery vs reviews
-- Q5: Repeat rate + RFM | Q6: Funnel loss

-- Q1: Monthly revenue trend, AOV, MoM growth
WITH monthly AS (
    SELECT DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
           COUNT(DISTINCT o.order_id) AS orders,
           SUM(oi.price + oi.freight_value) AS revenue
    FROM v_orders_clean o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.in_analysis_window = 1
      AND o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1
)
SELECT month,
       orders,
       ROUND(revenue, 2) AS revenue,
       ROUND(revenue / orders, 2) AS avg_order_value,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY month))
             / LAG(revenue) OVER (ORDER BY month), 1) AS mom_growth_pct
FROM monthly
ORDER BY month;

-- Q2: Category performance (top 10 by revenue + share)
WITH cat AS (
    SELECT p.category,
           COUNT(DISTINCT oi.order_id) AS orders,
           SUM(oi.price + oi.freight_value) AS revenue,
           ROUND(AVG(oi.freight_value), 2) AS avg_freight,
           ROUND(AVG(oi.price), 2) AS avg_price
    FROM order_items oi
    JOIN v_products_clean p ON oi.product_id = p.product_id
    JOIN v_orders_clean o ON oi.order_id = o.order_id
    WHERE o.in_analysis_window = 1
      AND o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1
)
SELECT category, orders,
       ROUND(revenue, 2) AS revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 1) AS revenue_share_pct,
       avg_price, avg_freight,
       ROUND(100.0 * avg_freight / NULLIF(avg_price, 0), 1) AS freight_to_price_pct
FROM cat
ORDER BY revenue DESC
LIMIT 10;

-- Q3: Delivery performance by state
SELECT c.customer_state,
       COUNT(*) AS delivered_orders,
       ROUND(AVG(EXTRACT(EPOCH FROM (o.order_delivered_customer_date
             - o.order_purchase_timestamp)) / 86400), 1) AS avg_delivery_days,
       ROUND(100.0 * SUM(CASE WHEN o.order_delivered_customer_date
             > o.order_estimated_delivery_date THEN 1 ELSE 0 END)
             / COUNT(*), 1) AS late_pct
FROM v_orders_clean o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.is_corrupt_delivery = 0
  AND o.in_analysis_window = 1
GROUP BY 1
ORDER BY late_pct DESC;

-- Q4: Late delivery impact on review score
SELECT CASE WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date
            THEN 'late' ELSE 'on_time' END AS delivery_outcome,
       COUNT(*) AS orders,
       ROUND(AVG(r.review_score), 2) AS avg_review_score,
       ROUND(100.0 * SUM(CASE WHEN r.review_score <= 2 THEN 1 ELSE 0 END)
             / COUNT(*), 1) AS pct_1_2_star
FROM v_orders_clean o
JOIN v_reviews_clean r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.is_corrupt_delivery = 0
  AND o.in_analysis_window = 1
GROUP BY 1;

-- Q5a: Repeat purchase rate
SELECT COUNT(DISTINCT c.customer_unique_id) AS total_customers,
       COUNT(DISTINCT CASE WHEN cnt > 1 THEN c2 END) AS repeat_customers,
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN cnt > 1 THEN c2 END)
             / COUNT(DISTINCT c.customer_unique_id), 2) AS repeat_rate_pct
FROM customers c
LEFT JOIN (
    SELECT c.customer_unique_id AS c2, COUNT(DISTINCT o.order_id) AS cnt
    FROM v_orders_clean o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1
) x ON c.customer_unique_id = x.c2;

-- Q5b: RFM segmentation
WITH cust AS (
    SELECT c.customer_unique_id,
           MAX(o.order_purchase_timestamp) AS last_order,
           COUNT(DISTINCT o.order_id) AS frequency,
           SUM(oi.price + oi.freight_value) AS monetary
    FROM v_orders_clean o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1
),
rfm AS (
    SELECT customer_unique_id,
           NTILE(4) OVER (ORDER BY last_order DESC) AS r,
           frequency,
           NTILE(4) OVER (ORDER BY monetary) AS m,
           monetary
    FROM cust
)
SELECT CASE
         WHEN r = 1 AND frequency > 1 AND m = 4 THEN 'Champions'
         WHEN r = 1 AND m >= 3 THEN 'High-value recent'
         WHEN r >= 3 AND m = 4 THEN 'At-risk high spenders'
         WHEN r >= 3 THEN 'Lost / dormant'
         ELSE 'Regular'
       END AS segment,
       COUNT(*) AS customers,
       ROUND(SUM(monetary), 2) AS total_revenue,
       ROUND(AVG(monetary), 2) AS avg_revenue_per_customer
FROM rfm
GROUP BY 1
ORDER BY total_revenue DESC;

-- Q6: Funnel loss - canceled/unavailable orders and lost revenue
SELECT DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
       COUNT(*) FILTER (WHERE o.order_status = 'canceled') AS canceled,
       COUNT(*) FILTER (WHERE o.order_status = 'unavailable') AS unavailable,
       ROUND(SUM(oi.price + oi.freight_value), 2) AS lost_revenue
FROM v_orders_clean o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status IN ('canceled', 'unavailable')
  AND o.in_analysis_window = 1
GROUP BY 1
ORDER BY 1;
