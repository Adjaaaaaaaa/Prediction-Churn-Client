import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
from sqlalchemy import create_engine
import os
from dotenv import load_dotenv

# Charger les variables d'environnement
load_dotenv()

# Configuration de la page
st.set_page_config(
    page_title="Dashboard Client - Olist E-commerce",
    page_icon="📊",
    layout="wide"
)

# Fonction de connexion à la base de données
@st.cache_resource
def init_connection():
    try:
        db_host = os.getenv("DB_HOST", "localhost")
        db_port = os.getenv("DB_PORT", "5433")
        db_name = os.getenv("DB_NAME", "olist_db")
        db_user = os.getenv("DB_USER", "postgres")
        db_password = os.getenv("DB_PASSWORD", "")

        engine = create_engine(f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}")
        return engine
    except Exception as e:
        st.error(f"Erreur de connexion à la base de données: {e}")
        return None

# Fonction pour charger les données
@st.cache_data(ttl=600)
def load_data():
    engine = init_connection()
    if engine is None:
        return None
    
    try:
        query = "SELECT * FROM v_customer_features;"
        df = pd.read_sql(query, engine)
        return df
    except Exception as e:
        st.error(f"Erreur lors de la lecture des données: {e}")
        st.info("Assurez-vous que la vue 'v_customer_features' a bien été créée dans la base de données.")
        return None

# Interface utilisateur
st.title("📊 Dashboard Analytique - Comportement Client (Olist)")
st.markdown("Ce tableau de bord présente les caractéristiques RFM et d'engagement des clients de la plateforme E-commerce Olist.")

df = load_data()

if df is not None and not df.empty:
    st.sidebar.header("Filtres")
    
    # Filtre sur la fréquence
    freq_min, freq_max = int(df['frequency'].min()), int(df['frequency'].max())
    freq_filter = st.sidebar.slider("Fréquence d'achat (nombre de commandes)", freq_min, freq_max, (freq_min, freq_max))
    
    # Filtre sur la récence
    recency_min, recency_max = int(df['recency_days'].min()), int(df['recency_days'].max())
    recency_filter = st.sidebar.slider("Récence (jours depuis le dernier achat)", recency_min, recency_max, (recency_min, recency_max))
    
    # Application des filtres
    df_filtered = df[(df['frequency'] >= freq_filter[0]) & (df['frequency'] <= freq_filter[1]) & (df['recency_days'] >= recency_filter[0]) & (df['recency_days'] <= recency_filter[1])]
    
    # ------------------
    # KPIs Principaux
    # ------------------
    st.header("Indicateurs Clés de Performance (KPIs)")
    col1, col2, col3, col4, col5 = st.columns(5)
    
    with col1:
        st.metric(label="Total Clients", value=f"{len(df_filtered):,}")
    
    with col2:
        avg_basket = df_filtered['monetary_avg_basket'].mean()
        st.metric(label="Panier Moyen", value=f"{avg_basket:.2f} R$")
    
    with col3:
        avg_recency = df_filtered['recency_days'].mean()
        st.metric(label="Récence Moyenne", value=f"{avg_recency:.0f} jours")
        
    with col4:
        avg_score = df_filtered['avg_review_score'].mean()
        st.metric(label="Score Avis Moyen", value=f"{avg_score:.2f} / 5")
        
    with col5:
        avg_delay = df_filtered[df_filtered['avg_days_between_orders'] > 0]['avg_days_between_orders'].mean()
        st.metric(label="Délai Inter-commandes", value=f"{avg_delay:.0f} jours" if pd.notna(avg_delay) else "N/A")

    st.markdown("---")

    # ------------------
    # Graphiques
    # ------------------
    st.header("Analyse Visuelle")
    
    col_chart1, col_chart2 = st.columns(2)
    
    with col_chart1:
        # Distribution de la récence
        fig_recency = px.histogram(
            df_filtered, 
            x="recency_days", 
            nbins=50, 
            title="Distribution de la Récence (jours depuis le dernier achat)",
            color_discrete_sequence=['#3498db']
        )
        fig_recency.update_layout(xaxis_title="Jours", yaxis_title="Nombre de clients")
        st.plotly_chart(fig_recency, use_container_width=True)

    with col_chart2:
        # Relation Montant vs Fréquence
        fig_scatter = px.scatter(
            df_filtered, 
            x="frequency", 
            y="monetary_total", 
            title="Montant Total vs Fréquence d'Achat",
            opacity=0.5,
            color_discrete_sequence=['#e74c3c']
        )
        fig_scatter.update_layout(xaxis_title="Fréquence", yaxis_title="Montant Total (R$)")
        st.plotly_chart(fig_scatter, use_container_width=True)
        
    col_chart3, col_chart4 = st.columns(2)
    
    with col_chart3:
        # Score moyen des avis
        fig_reviews = px.histogram(
            df_filtered, 
            x="avg_review_score", 
            nbins=10, 
            title="Distribution des Scores d'Avis",
            color_discrete_sequence=['#f1c40f']
        )
        fig_reviews.update_layout(xaxis_title="Score Moyen", yaxis_title="Nombre de clients")
        st.plotly_chart(fig_reviews, use_container_width=True)
        
    with col_chart4:
        # Ratio d'avis négatifs vs Catégories distinctes
        fig_box = px.box(
            df_filtered, 
            x="nb_distinct_categories", 
            y="negative_review_ratio", 
            title="Ratio d'Avis Négatifs par Nombre de Catégories"
        )
        st.plotly_chart(fig_box, use_container_width=True)

    st.markdown("---")
    st.header("Analyse du Risque de Churn & Corrélations")
    
    col_chart5, col_chart6 = st.columns(2)
    
    with col_chart5:
        # Segmentation de risque de churn basée sur le délai inter-commandes
        df_repeat = df_filtered[df_filtered['frequency'] > 1].copy()
        if not df_repeat.empty:
            df_repeat['Statut'] = df_repeat.apply(
                lambda x: 'En Risque de Churn' if x['recency_days'] > (x['avg_days_between_orders'] * 1.5) else 'Actif',
                axis=1
            )
            fig_pie = px.pie(df_repeat, names='Statut', title="Statut des clients récurrents (Risque de Churn)",
                             color_discrete_sequence=['#e74c3c', '#2ecc71'])
            st.plotly_chart(fig_pie, use_container_width=True)
        else:
            st.info("Ajustez les filtres pour inclure des clients récurrents (Fréquence > 1) afin de visualiser cette analyse.")
            
    with col_chart6:
        # Matrice de corrélation pour préparer le Machine Learning
        numeric_cols = ['recency_days', 'frequency', 'monetary_total', 'monetary_avg_basket', 'avg_review_score', 'negative_review_ratio', 'nb_distinct_categories', 'avg_days_between_orders']
        corr = df_filtered[numeric_cols].corr()
        fig_corr = px.imshow(corr, text_auto='.2f', aspect="auto", title="Matrice de Corrélation des Features", color_continuous_scale='RdBu_r')
        st.plotly_chart(fig_corr, use_container_width=True)

    # Affichage des données brutes
    if st.checkbox("Afficher un aperçu des données brutes"):
        st.subheader("Aperçu des Données")
        st.dataframe(df_filtered.head(100))

else:
    if df is None:
        st.warning("Veuillez configurer la connexion à la base de données dans un fichier `.env` à la racine du projet.")
        st.code('''
# Exemple de fichier .env
DB_HOST=localhost
DB_PORT=5433
DB_NAME=olist_db
DB_USER=postgres
DB_PASSWORD=votre_mot_de_passe
        ''', language='env')
    else:
        st.warning("La vue 'v_customer_features' est vide. Veuillez exécuter les scripts SQL d'import et de création de vues.")
