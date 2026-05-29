-- Ce script contient les requêtes de feature engineering pour chaque feature construite.
-- Chaque requête est indépendante et peut être exécutée pour vérifier la logique de calcul.
-- NOTE: Ce script est destiné à la documentation et à la vérification. Il n'est pas nécessaire de l'exécuter
-- dans le pipeline final, car sa logique est intégrée dans `05-vue-finale.sql`.

-- =============================================================================
-- Feature 1 : RFM (Récence, Fréquence, Montant)
-- =============================================================================
-- Justification: Le modèle RFM est un standard pour segmenter les clients
-- en fonction de leur comportement d'achat.
-- - Récence: Quand ont-ils acheté pour la dernière fois ?
-- - Fréquence: À quelle fréquence achètent-ils ?
-- - Montant: Combien dépensent-ils ?
-- =============================================================================

WITH delivered_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        oi.price,
        oi.freight_value
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
),
order_values AS (
    SELECT
        customer_unique_id,
        order_id,
        MAX(order_purchase_timestamp) AS order_purchase_timestamp,
        SUM(price + freight_value) AS order_value
    FROM delivered_orders
    GROUP BY customer_unique_id, order_id
)
SELECT
    customer_unique_id,
    DATE_PART('day', (SELECT MAX(order_purchase_timestamp) FROM orders WHERE order_status = 'delivered') - MAX(order_purchase_timestamp)) AS recency_days,
    COUNT(DISTINCT order_id) AS frequency,
    SUM(order_value) AS monetary_total,
    AVG(order_value) AS monetary_avg_basket
FROM order_values
GROUP BY customer_unique_id
LIMIT 10;


-- =============================================================================
-- Feature 2 : Satisfaction client (Score moyen, ratio d'avis négatifs)
-- =============================================================================
-- Justification: La satisfaction est un signal direct de risque de churn.
-- =============================================================================

WITH delivered_reviews AS (
    SELECT DISTINCT
        c.customer_unique_id,
        r.order_id,
        r.review_score
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_reviews r ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
      AND r.review_score IS NOT NULL
)
SELECT
    customer_unique_id,
    AVG(review_score) AS avg_review_score,
    COUNT(*) FILTER (WHERE review_score <= 2) AS negative_review_count,
    COUNT(*) AS total_review_count,
    COUNT(*) FILTER (WHERE review_score <= 2) * 1.0 / NULLIF(COUNT(*), 0) AS negative_review_ratio
FROM delivered_reviews
GROUP BY customer_unique_id
LIMIT 10;


-- =============================================================================
-- Feature 3 : Diversité des catégories de produits achetées
-- =============================================================================
-- Justification: Les clients qui achètent sur plusieurs catégories sont souvent plus engagés.
-- =============================================================================

WITH delivered_category_orders AS (
    SELECT
        c.customer_unique_id,
        p.product_category_name
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    LEFT JOIN products p ON oi.product_id = p.product_id
    WHERE o.order_status = 'delivered'
)
SELECT
    customer_unique_id,
    COUNT(DISTINCT COALESCE(product_category_name, 'unknown')) AS nb_distinct_categories
FROM delivered_category_orders
GROUP BY customer_unique_id
LIMIT 10;


-- =============================================================================
-- Feature 4 : Délai moyen entre les commandes (Window Function LAG)
-- =============================================================================
-- Justification: La tendance temporelle du délai entre commandes peut indiquer un désengagement.
-- =============================================================================

WITH customer_order_timestamps AS (
    SELECT DISTINCT
        c.customer_unique_id,
        o.order_purchase_timestamp
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
),
customer_order_lag AS (
    SELECT
        customer_unique_id,
        order_purchase_timestamp,
        LAG(order_purchase_timestamp) OVER (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp) AS previous_order_timestamp
    FROM customer_order_timestamps
)
SELECT
    customer_unique_id,
    AVG(DATE_PART('day', order_purchase_timestamp - previous_order_timestamp)) AS avg_days_between_orders
FROM customer_order_lag
WHERE previous_order_timestamp IS NOT NULL
GROUP BY customer_unique_id
LIMIT 10;


-- =============================================================================
-- Feature 5 : Médiane du panier par commande (percentile_cont)
-- =============================================================================
-- Justification: La médiane est plus robuste que la moyenne contre les outliers.
-- =============================================================================

WITH order_values AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id, o.order_id
)
SELECT
    customer_unique_id,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY order_value) AS median_basket
FROM order_values
GROUP BY customer_unique_id
LIMIT 10;


-- =============================================================================
-- Feature 6 : Déciles de valeur client (NTILE)
-- =============================================================================
-- Justification: Le décile place chaque client dans une hiérarchie de valeur relative.
-- =============================================================================

WITH customer_monetary AS (
    SELECT
        c.customer_unique_id,
        SUM(oi.price + oi.freight_value) AS monetary_total
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    customer_unique_id,
    monetary_total,
    NTILE(10) OVER (ORDER BY monetary_total DESC) AS monetary_decile
FROM customer_monetary
ORDER BY monetary_total DESC
LIMIT 10;


-- Remarque :
-- Les CTE permettent de structurer des requêtes complexes et de les rendre
-- plus lisibles que des sous-requêtes imbriquées. Un CTE est souvent plus facile
-- à relire et à réutiliser dans plusieurs étapes de transformation.
-- Le `PARTITION BY` s'utilise dans les Window Functions pour appliquer une
-- opération de fenêtre par groupe, alors que `GROUP BY` agrège les lignes en une seule sortie par groupe.