# TontineChain

Application Flutter de gestion de tontines et de démonstration blockchain.

## État actuel du projet

Le projet est dans un état avancé de présentation. Les écrans principaux sont en place, la navigation est branchée et plusieurs parcours de démo fonctionnent déjà de bout en bout.

### Fonctionnalités déjà implémentées

- Authentification et comptes de test.
- Tableau de bord principal avec accès aux parcours clés.
- Création de tontine avec choix de fréquence.
- Option `Appel à membres` pour rendre une tontine visible dans l’écran Découvrir.
- Dialogue de partage après création avec comptes actifs suggérés.
- Filtrage des suggestions pour ne pas proposer le compte connecté.
- Écran Découvrir avec filtres de recherche.
- Écran Détails Tontine avec calendrier des allocations et membres.
- Écran Contrat Intelligent avec registre blockchain visuel.
- Écran `Mes contrats` avec cartes, recherche et tri.
- Écran Notifications.
- Navigation par bottom bar dans l’app principale.
- Flux de démonstration pour la réception de cagnotte.

### Comportements de démo déjà préparés

- Création d’une tontine depuis le formulaire.
- Affichage du partage après création.
- Suggestion automatique des comptes marqués actifs.
- Mise en visibilité dans Découvrir quand `Appel à membres` est activé.
- Scénario de réception et consultation des contrats.

### Ce qui reste encore partiellement simulé

- Registre blockchain réel.
- Historique transactionnel complet avec hash et dates réels.
- Filtrage avancé et branchement complet de certains écrans secondaires.
- Tests widget automatisés pour `ContractsListScreen`.
- Récupération d’un backend réel via un service distant.

## Structure utile

- `lib/screens/` : écrans principaux de l’application.
- `lib/providers/` : gestion d’état avec Provider.
- `lib/services/` : services mock et logique de données.
- `lib/models/` : modèles `Tontine`, `Member`, `Payment`.
- `lib/widgets/` : composants réutilisables comme le dialogue de partage.

## Lancer le projet

```powershell
flutter pub get
flutter run
```

## Vérifications récentes

- `flutter analyze` a été lancé et les erreurs bloquantes du projet ont été corrigées.
- Les parcours de démo principaux sont navigables sans crash sur les fichiers modifiés.

## Notes de démo

Le projet est surtout pensé pour une présentation fonctionnelle. Certaines parties sont volontairement simulées pour montrer le comportement de l’application sans backend complet.