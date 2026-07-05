-- Olist E-Commerce Analysis: Data Cleaning Views
-- Cleaning decisions:
--   1. Deduplicate reviews (814 duplicate review_ids; keep latest per order)
--   2. Flag 8 corrupt orders marked delivered but missing delivery date
--   3. Impute 610 missing product categories as 'unknown', join English names
--   4. Restrict analysis window to complete months (Jan 2017 - Aug 2018)

-- 1. Deduped reviews: keep latest review per order
CREATE VIEW v_reviews_clean AS
SELECT *
FROM (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY order_id
               ORDER BY review_answer_timestamp DESC
           ) AS rn
    FROM order_reviews
) t
WHERE rn = 1;

-- 2. Cleaned orders: corrupt-row flag + analysis window flag
CREATE VIEW v_orders_clean AS
SELECT *,
       CASE
           WHEN order_status = 'delivered'
                AND order_delivered_customer_date IS NULL
           THEN 1 ELSE 0
       END AS is_corrupt_delivery,
       CASE
           WHEN order_purchase_timestamp >= '2017-01-01'
                AND order_purchase_timestamp < '2018-09-01'
           THEN 1 ELSE 0
       END AS in_analysis_window
FROM orders;

-- 3. Products with English category names, missing = 'unknown'
CREATE VIEW v_products_clean AS
SELECT p.product_id,
       COALESCE(t.product_category_name_english,
                p.product_category_name,
                'unknown') AS category,
       p.product_weight_g,
       p.product_length_cm,
       p.product_height_cm,
       p.product_width_cm
FROM products p
LEFT JOIN product_category_translation t
       ON p.product_category_name = t.product_category_name;
