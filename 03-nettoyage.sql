-- Ce script effectue des tâches de nettoyage de données basées sur l'exploration initiale.

-- Anomalie 1 : `product_category_name` manquant
-- Choix : remplacer les valeurs NULL par une catégorie explicite afin d'inclure ces produits dans les agrégations de diversité.
UPDATE products
SET product_category_name = 'unknown'
WHERE product_category_name IS NULL;

COMMENT ON COLUMN products.product_category_name IS 'Valeurs NULL remplacées par "unknown" pour garantir la présence d''une catégorie dans les agrégations de diversité.';

-- Anomalie 2 : Incohérence entre le statut de la commande et les dates de livraison
-- Certaines commandes sont marquées comme 'delivered' mais n'ont pas de `order_delivered_customer_date`.
-- Choix : considérer le statut 'delivered' comme indicateur principal de livraison.
-- Action : remplir `order_delivered_customer_date` avec `order_estimated_delivery_date` lorsque la première est manquante.
UPDATE orders
SET order_delivered_customer_date = order_estimated_delivery_date
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL
  AND order_estimated_delivery_date IS NOT NULL;

COMMENT ON TABLE orders IS 'Nettoyage des dates de livraison manquantes pour les commandes livrées lorsque cela est possible, en utilisant la date estimée.';

-- Anomalie 3 : Plusieurs avis peuvent être associés à une même commande.
-- Choix : conserver un seul avis par commande pour éviter des doublons artificiels dans les métriques de satisfaction.
-- Action : sélectionner l'avis le plus récent lorsque plusieurs avis existent pour une même commande.

WITH review_ranked AS (
    SELECT
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_answer_timestamp DESC NULLS LAST) AS rn
    FROM order_reviews
)
DELETE FROM order_reviews
WHERE (review_id, order_id) IN (
    SELECT review_id, order_id FROM review_ranked WHERE rn > 1
);

COMMENT ON TABLE order_reviews IS 'Nettoyage des avis via suppression des entrées multiples par commande ; on conserve l''avis le plus récent.';

-- Anomalie 4 : Gestion des identifiants clients réels.
-- Observation : `customer_unique_id` représente le client réel tandis que `customer_id` est un identifiant de commande.
-- Choix : agréger les features sur `customer_unique_id` pour éviter de fragmenter un même client.
COMMENT ON COLUMN customers.customer_unique_id IS 'Identifiant client réel à utiliser pour l''agrégation des features métier.';