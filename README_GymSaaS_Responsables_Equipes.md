# GymSaaS --- Guide de démarrage pour les responsables d'équipe

## 1. Objet du dossier

Ce document accompagne l'archive **`GymSaaS_Backend_Guide_Teams.zip`**
et aide les responsables des équipes **Web**, **Mobile** et **QA/Tests**
à démarrer l'intégration.

Le projet utilise **Supabase** pour le backend et la base de données. Le
ZIP contient des documents de référence sur les membres, les plans et
abonnements, les salles/agences et le personnel, les paiements, les
présences, les QR codes, les tableaux de bord, les notifications, les
annonces, les tests et le déploiement.

**Important :** le guide sert de base de travail. Il ne signifie pas que
toutes les fonctionnalités sont terminées ou validées pour la
production.

## 2. Comment utiliser le ZIP

1.  Décompressez `GymSaaS_Backend_Guide_Teams.zip`.
2.  Lisez d'abord le document présentant l'état actuel du backend.
3.  Consultez ensuite les contrats d'intégration et les notes de votre
    équipe.
4.  Confirmez les tables, fonctions RPC, paramètres, réponses et
    autorisations avec le responsable backend avant de dépendre d'un
    comportement précis.

## 3. Responsabilités des équipes

### Équipe Web

-   Intégrer l'interface avec les contrats backend documentés.
-   Gérer les chargements, erreurs, sessions expirées et réponses vides.
-   Ne pas exposer de secrets dans le frontend.
-   Ne pas considérer le masquage d'un bouton comme un contrôle d'accès
    suffisant : les permissions doivent être vérifiées côté backend.

### Équipe Mobile

-   Suivre les mêmes contrats et règles d'autorisation que l'équipe Web.
-   Gérer les erreurs réseau et les sessions expirées.
-   Faire valider par le backend les opérations sensibles liées aux QR
    codes.
-   Ne jamais intégrer une clé `service_role` dans l'application mobile.

### Équipe QA / Tests

-   Vérifier les parcours normaux et les cas d'erreur.
-   Tester l'isolation des données entre différentes salles/sociétés.
-   Tester les rôles, abonnements expirés, paiements, présences et
    opérations QR.
-   Documenter les étapes de reproduction, les résultats et la gravité
    des anomalies.
-   Ne pas déclarer le projet prêt pour la production tant que les
    contrôles critiques ne sont pas validés.

## 4. Règles de sécurité

-   **Ne jamais utiliser la clé Supabase `service_role` dans le frontend
    Web, l'application Mobile ou le dépôt Git.** Elle contourne les
    protections RLS.
-   Utiliser des variables d'environnement adaptées à chaque
    environnement. Ne partagez pas de clés ni de mots de passe dans les
    messages d'équipe.
-   Les tables utilisant Row Level Security (RLS) doivent avoir des
    politiques d'accès adaptées et vérifiées. **Activer RLS sans définir
    les politiques nécessaires peut bloquer les accès légitimes ; cela
    ne suffit pas à prouver que la sécurité est correctement
    configurée.**
-   Tester l'isolation multi-salle/multi-société et les permissions de
    chaque rôle.
-   Ne pas modifier la base de production sans validation, sauvegarde et
    procédure de retour arrière.

## 5. Points à vérifier avant la production

Selon l'état décrit dans le dossier de référence : - les politiques RLS
des tables doivent encore être définies et/ou vérifiées ; - les tests
end-to-end ne sont pas tous terminés ; - la tâche planifiée liée à
`expire_subscriptions` n'est pas encore configurée ; - les contrats
API/RPC et les permissions doivent être vérifiés dans le projet Supabase
actuel.

Ces points doivent avoir un responsable et un statut confirmé avant la
mise en production.

## 6. Processus d'intégration conseillé

1.  Lire les documents pertinents du ZIP.
2.  Identifier les fonctionnalités et leurs dépendances backend.
3.  Confirmer les contrats API/RPC et les règles d'autorisation.
4.  Implémenter sans contourner les contrôles d'accès.
5.  Tester les cas normaux, les erreurs et les limites de permissions.
6.  Documenter les résultats et signaler les écarts.
7.  Obtenir la validation du responsable backend et de QA avant la mise
    en production.

## 7. Checklist de prise en charge

-   [ ] J'ai décompressé et lu le guide.
-   [ ] J'ai identifié les documents utiles à mon équipe.
-   [ ] J'ai confirmé les contrats backend et les autorisations.
-   [ ] Aucun secret n'est stocké dans le code ou le dépôt Git.
-   [ ] Les tests d'isolation multi-salle/multi-société sont prévus.
-   [ ] Les erreurs et les sessions expirées sont gérées.
-   [ ] Les tests et anomalies sont documentés.
-   [ ] Les points bloquants ont un responsable et un statut.

## 8. Règle en cas de divergence

Si le guide ne correspond pas au projet Supabase réel, vérifiez le
schéma, les fonctions, les politiques et les contrats actuellement
déployés, puis signalez la divergence au responsable backend avant de
poursuivre.

**Statut :** document d'orientation pour les équipes --- ce n'est pas
une approbation de mise en production.
