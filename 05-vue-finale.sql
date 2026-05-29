-- Ce script crée la vue finale `v_customer_features` qui consolide toutes les features.

CREATE OR REPLACE VIEW v_customer_features AS

WITH delivered_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),

order_values AS (
    SELECT
        del.customer_unique_id,
        oi.order_id,
        MAX(del.order_purchase_timestamp) AS order_purchase_timestamp,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM delivered_orders del
    JOIN order_items oi ON del.order_id = oi.order_id
    GROUP BY del.customer_unique_id, oi.order_id
),

customer_rfm AS (
    SELECT
        customer_unique_id,
        DATE_PART('day', (SELECT MAX(order_purchase_timestamp) FROM orders WHERE order_status = 'delivered') - MAX(order_purchase_timestamp)) AS recency_days,
        COUNT(DISTINCT order_id) AS frequency,
        SUM(order_value) AS monetary_total,
        AVG(order_value) AS monetary_avg_basket
    FROM order_values
    GROUP BY customer_unique_id
),

customer_reviews AS (
    SELECT
        c.customer_unique_id,
        AVG(r.review_score) AS avg_review_score,
        COUNT(r.review_score) FILTER (WHERE r.review_score <= 2) AS negative_review_count,
        COUNT(r.review_score) AS total_review_count
    FROM delivered_orders c
    JOIN order_reviews r ON c.order_id = r.order_id
    WHERE r.review_score IS NOT NULL
    GROUP BY c.customer_unique_id
),

customer_diversity AS (
    SELECT
        del.customer_unique_id,
        COUNT(DISTINCT COALESCE(p.product_category_name, 'unknown')) AS nb_distinct_categories
    FROM delivered_orders del
    JOIN order_items oi ON del.order_id = oi.order_id
    LEFT JOIN products p ON oi.product_id = p.product_id
    GROUP BY del.customer_unique_id
),

customer_inter_order_time AS (
    SELECT
        customer_unique_id,
        AVG(DATE_PART('day', order_purchase_timestamp - previous_order_timestamp)) AS avg_days_between_orders
    FROM (
        SELECT
            customer_unique_id,
            order_purchase_timestamp,
            LAG(order_purchase_timestamp) OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp) AS previous_order_timestamp
        FROM delivered_orders
    ) orders_with_lag
    WHERE previous_order_timestamp IS NOT NULL
    GROUP BY customer_unique_id
)

SELECT
    rfm.customer_unique_id,
    rfm.recency_days,
    rfm.frequency,
    rfm.monetary_total,
    rfm.monetary_avg_basket,
    COALESCE(rev.avg_review_score, 0) AS avg_review_score,
    COALESCE(rev.negative_review_count * 1.0 / NULLIF(rev.total_review_count, 0), 0) AS negative_review_ratio,
    COALESCE(div.nb_distinct_categories, 0) AS nb_distinct_categories,
    COALESCE(io.avg_days_between_orders, -1) AS avg_days_between_orders
FROM customer_rfm rfm
LEFT JOIN customer_reviews rev ON rfm.customer_unique_id = rev.customer_unique_id
LEFT JOIN customer_diversity div ON rfm.customer_unique_id = div.customer_unique_id
LEFT JOIN customer_inter_order_time io ON rfm.customer_unique_id = io.customer_unique_id;