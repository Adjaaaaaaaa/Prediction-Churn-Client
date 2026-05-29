-- Ce script importe les données des fichiers CSV dans la base de données Olist.
-- Les chemins sont configurés pour la structure du projet.

-- Note : \copy est une commande psql, pas une commande SQL. Elle s'exécute avec les privilèges de l'utilisateur qui lance psql.
-- L'option NULL '' gère correctement les chaînes de caractères vides dans les CSV comme des valeurs NULL dans la base de données.
-- La base de données est créée avec l'encodage ISO-8859-1 pour gérer les caractères spéciaux du dataset Olist.

\copy customers FROM 'Data/olist_customers_dataset.csv' WITH (FORMAT CSV, HEADER, NULL '');
\copy orders FROM 'Data/olist_orders_dataset.csv' WITH (FORMAT CSV, HEADER, NULL '');
\copy sellers FROM 'Data/olist_sellers_dataset.csv' WITH (FORMAT CSV, HEADER, NULL '');
\copy product_category_translation FROM 'Data/product_category_name_translation.csv' WITH (FORMAT CSV, HEADER, NULL '');
\copy products FROM 'Data/olist_products_dataset.csv' WITH (FORMAT CSV, HEADER, NULL '');
\copy order_items FROM 'Data/olist_order_items_dataset.csv' WITH (FORMAT CSV, HEADER, NULL '');
\copy order_payments FROM 'Data/olist_order_payments_dataset.csv' WITH (FORMAT CSV, HEADER, NULL '');
-- Le fichier order_reviews contient des séquences d'octets invalides pour UTF8
-- (caractères spéciaux/emoji partiellement corrompus). On utilise LATIN1 pour importer.
\copy order_reviews FROM 'Data/olist_order_reviews_dataset.csv' WITH (FORMAT CSV, HEADER, ENCODING 'LATIN1', NULL '');