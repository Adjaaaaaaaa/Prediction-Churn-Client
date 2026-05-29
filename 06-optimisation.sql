-- Ce script crée les index stratégiques pour optimiser les requêtes sur la base de données,
-- notamment celles utilisées par la vue `v_customer_features`.

-- Justification générale :
-- L'analyse de performance (EXPLAIN ANALYZE) sur la requête de la vue révèle des "Sequential Scans"
-- sur les grandes tables. Pour accélérer les jointures et les filtres, nous créons des index
-- sur les clés étrangères et les colonnes fréquemment utilisées dans les clauses WHERE.

-- Le mot-clé `IF NOT EXISTS` évite les erreurs si le script est exécuté plusieurs fois.

-- Index pour la jointure customers -> orders
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders(customer_id);
-- Justification: Accélère la recherche des commandes pour un `customer_id` donné.

-- Index partiel pour le filtre principal sur les commandes livrées
CREATE INDEX IF NOT EXISTS idx_orders_status_delivered ON orders(order_status) WHERE order_status = 'delivered';
-- Justification: Index partiel plus efficace que l'index global lorsque seules les commandes livrées
-- sont pertinentes pour le calcul des features.

-- Index pour les jointures vers orders
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_reviews_order_id ON order_reviews(order_id);
-- Justification: Accélère la recherche des articles et des avis pour un `order_id` donné.

-- Index pour la jointure order_items -> products
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON order_items(product_id);
-- Justification: Accélère la jointure pour récupérer les informations du produit.

-- Index sur la colonne de regroupement principale
CREATE INDEX IF NOT EXISTS idx_customers_customer_unique_id ON customers(customer_unique_id);
-- Justification: Accélère les regroupements (`GROUP BY`) et les jointures finales sur `customer_unique_id`.

-- Index utile pour la diversité produit
CREATE INDEX IF NOT EXISTS idx_products_category_name ON products(product_category_name);
-- Justification: Améliore les agrégations de diversité de catégorie via products.

-- =============================================================================
-- Comment pour mesurer l'impact des index?
-- =============================================================================
-- Ce bloc explique comment valider que les index améliorent les performances.
--
-- 1. Créer les index définis dans ce fichier.
-- 2. Exécuter `EXPLAIN ANALYZE SELECT * FROM v_customer_features;`
-- 3. Si besoin de comparer avec l'état sans index, supprimer les index,
--    exécuter de nouveau la requête, puis recréer les index.
-- 4. Comparer les coûts et les temps d'exécution pour confirmer l'impact.

