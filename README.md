# ⚜️ INDEXOCIAL QC — Répertoire d'Aide Sociale & d'Urgence du Québec

INDEXOCIAL QC est une application mobile et multiplateforme bilingue (Français / Anglais) d'orientation sociale et d'assistance d'urgence au Québec. Conçue avec une approche **100 % hors-ligne (Offline-First)** et axée sur la confidentialité, l'application permet de trouver instantanément des organismes communautaires, des refuges, des lignes d'urgence, du soutien psychosocial et des fiches juridiques/médicales.

---

## 📱 Aperçu des Fonctionnalités Principales

### 🏠 1. Répertoire d'Aide & Assistant d'Orientation Intégré
- **Assistant de Triage Rapide** : Filtrage combiné par besoins spécifiques (logement, nourriture, santé mentale, dépendances, aînés, jeunesse...) et détection automatique de la région administrative du Québec par GPS (`geolocator`).
- **Recherche Intelligente & Tri Alphabétique** : Recherche instantanée dans les noms, descriptions, adresses et étiquettes. Les résultats sont présentés en ordre alphabétique strict.
- **Fiche d'Assistance 211** : En cas de recherche sans résultat, une carte d'assistance directe invite l'utilisateur à contacter gratuitement le **211 Québec** (service 24/7).
- **Glisser-pour-rafraîchir (Pull-to-Refresh)** : Mettre à jour en un geste le répertoire `resources.json` directement depuis GitHub.

### 🚨 2. Lignes d'Urgence & Mode « Urgence Discrète » (✕ HIDE)
- **Accès 1-Tap aux Numéros d'Urgence** : Boutons directs pour le **911** (Urgence), **811** (Info-Santé / Info-Social), **988** (Ligne de crise du suicide) et **211** (Soutien communautaire).
- **Mode Urgence Discrète (✕ HIDE)** : Bouton rouge en en-tête et **détection de secousse du téléphone** (`sensors_plus`) redirigeant immédiatement l'utilisateur vers `Google.ca` pour masquer l'application en cas de besoin de confidentialité ou de sécurité personnelle.

### ⭐ 3. Favoris, Exportation PDF & Code QR vCard
- **Gestion des Contacts** : Sauvegarde locale de vos organismes favoris.
- **Exportation PDF Multi-Pages** : Génération d'un document PDF formaté A4 (`pdf` & `printing`) prêt à être imprimé ou partagé hors-ligne.
- **Génération de Code QR vCard** : Génération hors-ligne d'un code QR vCard (`qr_flutter`) scannable avec l'appareil photo d'un téléphone pour enregistrer une ressource directement dans ses contacts système.

### 🎙️ 4. Carnet de Notes & Dictaphone Privé
- **Mémos Vocaux Confidentiels** : Enregistreur vocal intégré (`record` & `audioplayers`) stockant les fichiers audio localement sur l'appareil.
- **Notes Écrites & Édition** : Prise de notes (rendez-vous, numéros de dossier) avec possibilité de modifier le titre et les détails à tout moment.
- **Exportation Presse-Papier** : Copie intégrale de toutes les notes en un seul clic.

### 📚 5. Guides, Fiches Pratiques & Flux RSS/Atom XML en Direct
- **Guides Juridiques et Logement** : Fiches pratiques synthétiques pour Éducaloi, le Tribunal administratif du logement (TAL), le Protecteur du citoyen, etc.
- **Flux RSS / Atom XML en Direct avec Cache Hors-Ligne** : Analyseur XML client léger (`xml`) téléchargeant et mettant en cache les chaînes XML brutes dans `SharedPreferences` pour les sources clés (Éducaloi, Québec.ca, Protecteur du citoyen, INSPQ) afin de permettre la lecture d'actualités même sans connexion Internet.

### 🌤️ 6. Alertes Météorologiques Extrêmes ECCC
- **Intégration GeoMet d'Environnement Canada** : Détection et affichage en temps réel des avertissements météo graves (froid extrême, vagues de chaleur, tempêtes, verglas) filtrés selon la position GPS de l'utilisateur.

### ⚡ 7. Menu Développeur & Outils de Diagnostic (Dev Mode)
- **Accès Sécurisé** : Déverrouillage exclusif par **7 clics consécutifs** sur le numéro de version (`INDEXOCIAL QC v1.0.0+2`).
- **Sélecteur de Branche GitHub** : Basculement entre les branches `main` (prod) et `dev` (test).
- **Simulation Hors-Ligne HTTP** : Blocage simulé des requêtes réseau pour valider les comportements du cache.
- **Injecteur de Fausses Alertes Météo** : Tests en direct des composants d'alerte.
- **Bouton de Masquage & Reset** : Bouton `[DÉSACTIVER & MASQUER LE MODE DEV]` réinitialisant l'état dev et purgeant les données de test.

---

## 🛠️ Architecture & Stack Technique

| Composant | Technologie / Paquet | Rôle / Description |
| :--- | :--- | :--- |
| **Framework** | Flutter 3.x / Dart 3.14+ | Développement UI multiplateforme réactif |
| **Design System** | Material 3 (`material_ui`) | Palette civique (Jaune Signal `#FFE600`, Vermillon `#FF3B30`, Sombre/Clair) |
| **Persistance Locale** | `shared_preferences`, `path_provider` | Stockage hors-ligne des favoris, notes, réglages et chaînes XML/JSON brutes |
| **Réseau & XML** | `http`, `xml` | Synchro GitHub, alertes ECCC et analyse RSS/Atom XML directe sur l'appareil |
| **Audio & Dictaphone** | `record`, `audioplayers` | Enregistrement et lecture de mémos vocaux confidentiels |
| **Capteurs & GPS** | `geolocator`, `sensors_plus` | Géolocalisation pour le triage/météo et détection de secousse (Quick Hide) |
| **Exportation & Partage** | `pdf`, `printing`, `qr_flutter`, `share_plus` | Export PDF A4, codes QR vCard et partage système |

---

## 📄 Structure du Fichier `resources.json`

Les ressources officielles de l'application sont synchronisées depuis le fichier `resources.json`. Voici la structure d'une ressource :

```json
{
  "id": "QC-01",
  "nameFr": "211 QUÉBEC - CENTRE D'ASSISTANCE COMMUNAUTAIRE",
  "nameEn": "211 QUEBEC - COMMUNITY ASSISTANCE CENTER",
  "categoryIds": ["FOOD", "HOUSING", "SENIORS", "HEALTH"],
  "region": "PROVINCIAL (TOUT LE QUÉBEC)",
  "phone": "211",
  "website": "https://www.211qc.ca",
  "address": "Québec, QC",
  "descFr": "Service d'information et de référence gratuit, confidentiel et disponible 24/7 vers les organismes communautaires et sociaux du Québec.",
  "descEn": "Free, confidential 24/7 information and referral service connecting citizens to Quebec community and social support.",
  "tags": ["211", "urgence", "répertoire", "communautaire"]
}
```

---

## 🚀 Installation & Lancement du Projet

### Prérequis
- Flutter SDK v3.14 ou supérieur
- Dart SDK v3.14 ou supérieur
- Android Studio ou Visual Studio Code
- JDK 17+

### Procédure de Lancement

1. **Cloner le dépôt** :
   ```bash
   git clone https://github.com/Iam-Mithra/INDEXOCIAL.git
   cd Alt-INDEXOCIAL
   ```

2. **Installer les dépendances** :
   ```bash
   flutter pub get
   ```

3. **Vérifier l'analyse statique du code** :
   ```bash
   flutter analyze
   ```

4. **Exécuter les tests unitaires et composants** :
   ```bash
   flutter test
   ```

5. **Lancer l'application** :
   ```bash
   flutter run
   ```

---

## 🔒 Confidentialité & Indépendance

- **Initiative Indépendante** : INDEXOCIAL est un outil d'orientation citoyen indépendant et non gouvernemental. Il n'est affilié à aucun ministère ni gouvernement (Québec ou Canada).
- **Respect Absolu de la Vie Privée** : Aucun suivi, aucun cookie de pistage, aucune collecte de données analytiques. Toutes les notes, favoris et enregistrements vocaux restent strictement confinés sur la mémoire locale de l'appareil de l'utilisateur.

---

## ✉️ Support & Contacts

- **Courriel de l'équipe** : `IamMithra@proton.me`
- **Dépôt GitHub** : `https://github.com/Iam-Mithra/INDEXOCIAL`
