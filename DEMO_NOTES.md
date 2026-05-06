# Notes de Demonstration - TontineChain

Fait par la Team BJ-23 (Creative Team)

## 1. Objet de la demonstration
Cette demonstration presente les fonctionnalites principales de l'application TontineChain dans un scenario complet de gestion de tontine.

Objectifs de la session :
- Montrer la creation d'un compte test et la connexion.
- Montrer la creation d'une tontine.
- Montrer le partage et les suggestions de comptes actifs.
- Montrer le parcours de paiement/cotisation.
- Montrer les ecrans Contrats, Contrat intelligent et Notifications.

## 2. Contexte technique
- Application mobile Flutter.
- Architecture modulaire avec gestion d'etat via Provider.
- Navigation complete entre les ecrans principaux.
- Parcours fonctionnel complet pour la creation, l'invitation, la cotisation et le suivi.

## 3. Acteurs de demonstration
Comptes tests utilises :
- Admin Test (compte organisateur)
- Utilisateur A
- Utilisateur B

Etat des comptes pour la demonstration :
- Comptes actifs pour suggestions d'invitation : Admin Test, Utilisateur A.
- Le compte courant est exclu des suggestions (si je suis connecte avec Admin Test, il ne se suggere pas lui-meme).

## 4. Flux demontre (pas a pas)

### 4.1 Connexion
1. Ouvrir l'application.
2. Se connecter avec un compte test.
3. Arriver sur l'accueil et verifier l'acces aux onglets principaux.

### 4.2 Creation de tontine
1. Aller dans l'onglet Creer.
2. Saisir nom, montant, nombre de membres et frequence.
3. Activer l'option Appel a membres pour rendre la tontine visible dans Decouvrir.
4. Valider la creation.

Resultat attendu :
- La tontine est creee.
- Le dialogue de partage s'affiche.

### 4.3 Partage et comptes actifs
1. Dans le dialogue de partage, observer la section Comptes actifs a notifier.
2. Verifier la presence des comptes actifs.
3. Verifier l'absence du compte courant dans cette liste.

### 4.4 Ecran Decouvrir
1. Aller dans Explorer/Decouvrir.
2. Verifier que la tontine creee avec Appel a membres apparait.
3. Verifier qu'elle n'apparait qu'une seule fois.

### 4.5 Details tontine et contrat
1. Ouvrir la tontine depuis la liste.
2. Acceder aux details de tontine.
3. Ouvrir Voir le contrat.
4. Montrer l'ecran Contrat intelligent, les regles, la confiance technique et le registre visuel.

### 4.6 Paiement/Cotisation
1. Depuis les details, lancer le parcours de cotisation.
2. Effectuer un paiement.
3. Revenir dans les ecrans de suivi.

### 4.7 Notifications et profil
1. Ouvrir l'ecran Notifications.
2. Ouvrir le Profil.
3. Activer/desactiver le Mode actif.

Resultat attendu :
- Le mode actif influence les suggestions dans le dialogue de partage.


## 6. Valeur fonctionnelle de la demonstration
- Parcours utilisateur complet de la creation au suivi de contrat.
- Gestion du recrutement via Appel a membres et Decouvrir.
- Qualite d'experience amelioree (navigation, stabilite, cohérence des ecrans).
- Disponibilite immediate pour une presentation produit.

## 7. Message de cloture
La demonstration valide les parcours principaux de l'application :
- creation,
- invitation,
- decouverte,
- contrat,
- cotisation,
- notifications,
- profil/mode actif.