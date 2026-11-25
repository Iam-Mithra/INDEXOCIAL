# Release Notes — Indexocial QC v2.0.0+3

**Release Date / Date de sortie :** November / Novembre 2026  
**Repository :** [https://github.com/Iam-Mithra/INDEXOCIAL](https://github.com/Iam-Mithra/INDEXOCIAL)

---

## 🇫🇷 Notes de version (Français)

### 🚀 Nouveautés et Améliorations majeures (v2.0.0)
- **Refonte UI Moderne & Palette Civique** : Interface modernisée avec cartes à coins arrondis (24px), barre de navigation inférieure flottante (32px), badges de catégories en pilule et palette de couleurs civiques raffinées.
- **Fusion Accueil & Assistant** : L'Assistant d'orientation rapide (*Triage Wizard*) est maintenant intégré directement sur l'écran d'accueil avec un panneau de filtres rétractable (*Filtre des ressources*).
- **Client RSS/Atom XML Natif** : Analyse directe des flux XML/Atom sur l'appareil via le package `xml` avec mise en cache locale des données XML brutes dans le répertoire temporaire (`getTemporaryDirectory()`).
- **Fusion Intelligente des Flux RSS** : Regroupement automatique des flux RSS partageant le même attribut `source` (ex. Gazette du Canada Partie 1 et Partie 2) sous une source unifiée triée chronologiquement.
- **Export PDF des Favoris** : Génération et partage d'un document PDF multicellulaire formaté des contacts enregistrés grâce à `pdf` et `printing`.
- **Édition des Notes Personnelles** : Modification en place des mémos personnels et professionnels via un tiroir modale interactif avec synchronisation instantanée.
- **Menu Développeur (7-Taps)** : Déverrouillage sécurisé par 7 pressions consécutives sur la version dans l'onglet **Plus**, incluant sélecteur de branches JSON (`main`/`dev`), resynchronisation forcée, mode hors-ligne simulé, injecteur d'alertes météo factices et console de journalisation.
- **Mise à jour des Conditions d'utilisation** : Intégration des 12 articles révisés avec vérification automatique des modifications sur GitHub et pop-up d'acceptation obligatoire.

---

## 🇬🇧 Release Notes (English)

### 🚀 Major Features & Enhancements (v2.0.0)
- **Modern Civic UI & Palette**: Redesigned interface featuring rounded cards (24px), floating bottom navigation bar (32px), pill category badges, and refined civic styling.
- **Merged Home & Triage Assistant**: The rapid triage wizard is now embedded directly onto the Home screen (`directory` tab) behind a clean collapsible filter panel.
- **Native RSS/Atom XML Client Parsing**: Direct client-side XML/Atom feed parsing with raw XML caching stored locally via `getTemporaryDirectory()`.
- **Smart RSS Feed Merging**: Automatically merges multiple feeds sharing the same `source` property (e.g., Canada Gazette Part 1 and Part 2) into a unified chronologically sorted feed.
- **Favorites PDF Export**: Generates and shares a professional multi-page formatted PDF report of saved bookmarks using `pdf` and `printing`.
- **In-Place Personal Notes Editing**: Edit personal and voice memo notes directly via an interactive modal sheet.
- **Developer Mode (7-Taps)**: Secret dev menu unlocked via 7 consecutive taps on the version string in the **More** tab, featuring JSON branch switching (`main`/`dev`), forced resync, simulated offline mode, fake weather alert injector, and log console.
- **Updated Terms of Use**: Fully updated 12-section Terms of Use and Privacy Policy with automated GitHub diff checks and mandatory acceptance prompt upon updates.
