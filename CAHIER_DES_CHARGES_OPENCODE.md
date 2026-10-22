# Cahier des charges technique — Projet de tests `gymsaas-db-tests`

Destinataire : OpenCode. Rédigé le 22 octobre 2026.
Objet : reconstituer le schéma GymSaaS dans PGlite, y appliquer des privilèges minimaux et des policies RLS (étapes 2 et 3), puis les tester.

> **Règle d'or : aucun résultat n'est présumé.** Tu ne dois écrire « réussi » nulle part tant que `npm test` n'a pas réellement été exécuté et que les critères de la section 7 ne sont pas remplis. Si une règle métier n'est pas dans ce document, tu ne l'inventes pas : tu appliques la valeur par défaut indiquée en section 8, tu la signales dans le rapport, et tu continues.

---

## 0. Contraintes impératives

1. Projet **isolé** : un dossier `gymsaas-db-tests/` autonome, en dehors du dépôt GymSaaS. Ne pas l'initialiser avec `git init` dans le dépôt principal, ne pas modifier `web/`, `mobile/` ni `supabase/`.
2. **Gratuit, sans Docker**. Seule dépendance npm autorisée : `@electric-sql/pglite`. Test runner : `node:test` intégré à Node 20+.
3. **Aucune écriture distante.** Interdits : `supabase link`, `supabase db push|pull|diff|dump|reset`, tout appel au connecteur ou à l'API Supabase, `git push`, `git remote`, `git commit` dans le dépôt principal, lecture de fichiers `.env`. Aucun accès réseau sauf `npm install`.
4. Les fichiers `sql/01_schema.sql` et `sql/02_functions_triggers.sql` sont **copiés octet pour octet** depuis les fichiers fournis par l'utilisateur et **jamais modifiés** (les quatre RPC `record_payment`, `cancel_payment`, `issue_qr_token`, `verify_qr` ne doivent pas changer). Vérifier avec SHA-256 :
   - `001_schema.sql` → `45de8316b79d9a306addc20c286dd02518a584734a66e3c61a7484b97a566ba8`
   - `002_functions_triggers.sql` → `2155e9c889aec533176bc9433c21f24961cfad2350bcbb5aad498e1d0a6a09ab`
   Si les hash diffèrent, **arrête-toi** et signale-le (les fichiers ne représentent plus la production).
5. Nouveaux objets SQL autorisés uniquement dans `10_privileges.sql` et `20_policies.sql`.

---

## 1. Arborescence exacte

```text
gymsaas-db-tests/
├── package.json
├── README.md
├── sql/
│   ├── 00_supabase_stub.sql
│   ├── 01_schema.sql                 (copie de 001, inchangée)
│   ├── 02_functions_triggers.sql     (copie de 002, inchangée)
│   ├── 05_prod_baseline_grants.sql
│   ├── 10_privileges.sql
│   └── 20_policies.sql
├── snapshot/
│   └── prod_snapshot.json            (construit depuis l'annexe A)
├── tests/
│   ├── helpers.js
│   ├── fixtures.js
│   ├── manifest.json                 (liste des IDs de tests attendus)
│   ├── 00_smoke.test.js
│   ├── 01_schema_parity.test.js
│   ├── 10_isolation.test.js
│   ├── 20_payments.test.js
│   ├── 30_subscriptions.test.js
│   ├── 40_qr_visits.test.js
│   ├── 50_profiles_audit_notifications.test.js
│   ├── 60_permission_matrix.test.js
│   └── 90_mutation.test.js
├── docs/
│   └── permissions.md                (copie de la section 4)
└── reports/
    └── .gitkeep                      (rapports générés, voir section 7)
```

Ordre d'application SQL : `00 → 01 → 02 → 05` = état « baseline production » ; `→ 10 → 20` = état « complet ».

---

## 2. Contenu attendu de chaque fichier

### 2.1 `package.json`
- `"type": "module"`, `"private": true`, `"engines": {"node": ">=20"}`.
- Dépendance : `@electric-sql/pglite` uniquement.
- Scripts : `"test": "node --test"` ; `"test:report": "node --test > reports/last-run.txt 2>&1"`.

### 2.2 `sql/00_supabase_stub.sql` (simulation de l'environnement Supabase)
- Rôles `NOLOGIN` : `anon`, `authenticated`, `service_role` (ce dernier `BYPASSRLS`). `anon` et `authenticated` : `NOBYPASSRLS`, non superutilisateurs.
- Schéma `auth` : table `auth.users(id uuid primary key, email text, phone text, raw_user_meta_data jsonb not null default '{}', raw_app_meta_data jsonb not null default '{}')`.
- Fonctions `auth.jwt()` (lit `current_setting('request.jwt.claims', true)`, `{}` si vide), `auth.uid()` (champ `sub` en uuid, `null` si absent), `auth.role()`.
- Schéma `storage` minimal : `storage.buckets(id, name, public)`, `storage.objects(id uuid, bucket_id, name, owner)` avec RLS activée, `storage.foldername(text)`, `storage.filename(text)`. **Simulation, non fidèle.**
- `GRANT USAGE` sur `auth` et `public` à `anon` et `authenticated`, **sans** aucun droit sur `auth.users` pour eux.

### 2.3 `sql/05_prod_baseline_grants.sql`
Reproduit l'état de privilèges **observé en production** le 22/10/2026 : `GRANT SELECT, INSERT, UPDATE, DELETE` sur les 15 tables du schéma `public` à `authenticated` ; **aucun** droit à `anon`. C'est le point de départ avant `10_privileges.sql`.

### 2.4 `sql/10_privileges.sql` (nouveau)
1. `REVOKE ALL` sur toutes les tables de `public` à `anon`, `authenticated` et `PUBLIC`.
2. `GRANT` minimaux à `authenticated`, table par table, selon la colonne « Droits table » de la section 4. Les privilèges **par colonne** (`GRANT UPDATE (col, ...)`) sont obligatoires pour : `profiles`, `members`, `membership_plans`, `gym_users`, `notifications` (détail en section 4).
3. Fonctions : `REVOKE EXECUTE ... FROM PUBLIC, anon` sur toutes les fonctions du schéma `private`. `GRANT EXECUTE` à `authenticated` **uniquement** pour les fonctions appelées par les policies : `is_super_admin`, `gym_role`, `is_owner`, `has_perm`, `my_gym_ids`, `is_my_member`, `shares_gym_with`, plus les nouveaux helpers. Les fonctions de trigger (`audit_row`, `handle_new_user`, `payments_guard`, `subscriptions_set_end_date`) : `REVOKE EXECUTE` aussi à `authenticated`. **À vérifier par test** que les triggers continuent de fonctionner après cette révocation ; si un test échoue, rétablir le droit et le documenter.
4. Les droits `EXECUTE` des 4 RPC publiques restent inchangés (déjà révoqués pour `anon`).
5. `qr_tokens` : **aucun droit** pour `authenticated` (même pas SELECT).

### 2.5 `sql/20_policies.sql` (nouveau)
- Toutes les policies sont `TO authenticated`. Toujours `(select auth.uid())` plutôt que `auth.uid()` nu. Aucune policy `TO public`, aucun `USING (true)`.
- Nouveaux helpers `SECURITY DEFINER`, `STABLE`, `SET search_path = ''` (évitent la récursion de RLS) :
  - `private.is_my_plan(p_plan uuid)` : le plan est référencé par un abonnement d'un membre dont `profile_id = auth.uid()`.
  - `private.profile_in_gym(p_gym uuid, p_profile uuid)` : le profil est staff ou membre de la salle.
  - `private.ad_visible(p_ad uuid)` : publicité `status='active'`, date du jour entre `start_date` et `end_date`, ciblant au moins une salle de `private.my_gym_ids()`.
- Prédicats par table (`gym_role(g)` = rôle de l'appelant dans la salle `g`, `NULL` si absent ou salle suspendue) :

| Table | Opération | Prédicat |
|---|---|---|
| gyms | SELECT | `is_super_admin() OR id IN (SELECT my_gym_ids())` |
| gyms | INSERT, UPDATE | `is_super_admin()` (USING et WITH CHECK) |
| profiles | SELECT | `id = auth.uid() OR is_super_admin() OR shares_gym_with(id)` |
| profiles | UPDATE | `id = auth.uid()` |
| branches | SELECT | `gym_role(gym_id) IS NOT NULL` |
| branches | INSERT, UPDATE | `is_owner(gym_id)` |
| gym_users | SELECT | `profile_id = auth.uid() OR is_owner(gym_id) OR is_super_admin()` |
| gym_users | INSERT, UPDATE, DELETE | `is_owner(gym_id) OR is_super_admin()` |
| members | SELECT | `gym_role(gym_id) IS NOT NULL OR profile_id = auth.uid()` |
| members | INSERT, UPDATE | `has_perm(gym_id,'manage_members')` |
| members | DELETE | `is_owner(gym_id)` |
| membership_plans | SELECT | `gym_role(gym_id) IS NOT NULL OR is_my_plan(id)` |
| membership_plans | INSERT, UPDATE, DELETE | `is_owner(gym_id)` |
| subscriptions | SELECT | `gym_role(gym_id) IS NOT NULL OR is_my_member(member_id)` |
| subscriptions | écritures | **aucune policy** (voir section 8, point 5) |
| payments | SELECT | `has_perm(gym_id,'view_payments')` |
| payments | écritures | **aucune policy** (RPC uniquement) |
| qr_tokens | tout | **aucune policy, aucun droit** |
| visits | SELECT | `gym_role(gym_id) IS NOT NULL OR is_my_member(member_id)` |
| visits | écritures | **aucune policy** (RPC `verify_qr` uniquement) |
| notifications | SELECT, UPDATE | `recipient_id = auth.uid()` |
| notifications | INSERT | `is_owner(gym_id) AND profile_in_gym(gym_id, recipient_id)` |
| audit_logs | SELECT | `(is_super_admin() AND (gym_id IS NULL OR entity = 'gyms')) OR is_owner(gym_id) OR (actor_id = auth.uid() AND gym_role(gym_id) = 'receptionist')` |
| audit_logs | écritures | **aucune policy** |
| platform_subscriptions | SELECT | `is_super_admin() OR is_owner(gym_id)` |
| platform_subscriptions | INSERT, UPDATE | `is_super_admin()` |
| advertisements | SELECT | `is_super_admin() OR ad_visible(id)` |
| advertisements | INSERT, UPDATE | `is_super_admin()` |
| advertisement_gyms | SELECT | `is_super_admin() OR gym_id IN (SELECT my_gym_ids())` |
| advertisement_gyms | INSERT, DELETE | `is_super_admin()` |

### 2.6 `snapshot/prod_snapshot.json`
Construit à partir de l'**annexe A** : hash des 16 fonctions, signature des colonnes des 15 tables, noms des 55 contraintes, index, triggers. C'est la seule vérité sur la production (instantané lecture seule du 22/10/2026). Ne jamais le régénérer depuis Supabase.

### 2.7 `tests/helpers.js`
- `createDb(stage)` : nouvelle instance PGlite en mémoire, applique les fichiers SQL dans l'ordre. `stage = 'prod_baseline'` (00, 01, 02, 05) ou `'full'` (+ 10, 20). Charge `fixtures.js` pour `full`.
- `asActor(db, actorKey, fn)` : ouvre une transaction, exécute `SET LOCAL ROLE authenticated` (valeur en liste blanche, jamais concaténée depuis une entrée), puis `select set_config('request.jwt.claims', $1, true)` avec le JSON `{sub, role:'authenticated', app_metadata:{...}}`. **Vérifie ensuite** : `select rolsuper, rolbypassrls from pg_roles where rolname = current_user` doit retourner `false, false`, sinon le test échoue avec le message « RLS contournée : le test est invalide ». À la fin : **toujours `ROLLBACK`**.
- `asAnon(db, fn)` : idem avec le rôle `anon` et sans claims.
- `asSuper(db, fn)` : exécution en superutilisateur, **réservée** aux fixtures, aux tests témoins (canary) et aux vérifications d'état.
- `expectDenied(promise, kind)` avec `kind` parmi : `PRIVILEGE` (SQLSTATE 42501, message contenant « permission denied »), `RLS_WRITE` (42501, message contenant « row-level security »), `EXCEPTION` (message précis attendu), `CONSTRAINT` (code attendu : 23503, 23505, 23514). `expectFiltered(rows, n)` pour les lectures (0 ligne).
- **À vérifier au premier test** : que l'objet d'erreur de PGlite expose bien le SQLSTATE (`err.code`). Si non, comparer le message et le signaler dans le rapport.

### 2.8 `tests/fixtures.js`
UUID déterministes (`00000000-0000-4000-8000-0000000000NN`), insérés en superutilisateur. Les utilisateurs sont créés dans `auth.users` (le trigger `on_auth_user_created` crée les profils) ; `raw_app_meta_data = {"role":"super_admin"}` uniquement pour `sa`.

| Clé | Rôle fictif | Détail |
|---|---|---|
| gymA, gymB | salles actives | |
| gymC | salle **suspendue** | |
| sa | super admin | aucune appartenance à une salle |
| ownerA, ownerB, ownerC | propriétaires | `gym_users.role='gym_owner'` |
| staffA | personnel autorisé | permissions par défaut (manage_members, renew_subscriptions, record_payments à true ; cancel_payments, view_payments à false) |
| staffA_np | personnel sans permission | les 5 flags à false |
| staffB | personnel de B | permissions par défaut |
| memberA0 | membre sans compte | `members.profile_id = NULL` |
| memberA1 | membre actif, abonnement actif | |
| memberA2 | membre actif, abonnement `expired` | |
| memberA3 | membre `status='inactive'` | |
| memberB1, memberC1 | membres des salles B et C | |
| dualX | staff de A **et** membre de B | |
| outsider | profil sans salle | |

Données : branches `bA1` (active), `bA2` (inactive), `bB1`, `bC1` ; un plan par salle (30 jours, 1500.00) ; abonnements `subA1` active (début = aujourd'hui − 5 jours, fin = aujourd'hui + 25), `subA2` expired, `subA0` pending, `subB1` active ; paiements `payA1` (par staffA, cash, 1500, sur subA1) et `payB1` ; publicités `adActiveA` (ciblant A, fenêtre valide), `adDraft`, `adOnlyB`, `adExpiredWindow` ; `platform_subscriptions` pour A et B ; notifications `nA1` (memberA1), `nA2` (ownerA), `nB1` (memberB1).

---

## 3. Les 15 tables : nature et exposition

| Table | Contient `gym_id` | Écriture client |
|---|---|---|
| gyms, platform_subscriptions, advertisements, advertisement_gyms | oui sauf advertisements | super admin |
| branches, membership_plans, members, gym_users | oui | propriétaire (+ personnel pour members) |
| subscriptions, payments, qr_tokens, visits, audit_logs | oui | **aucune** (RPC ou triggers) |
| profiles | non | soi-même (2 colonnes) |
| notifications | oui | propriétaire (insertion), destinataire (`is_read`) |

---

## 4. Matrice des permissions (à copier dans `docs/permissions.md`)

Légende : **S** = SELECT, **I** = INSERT, **U** = UPDATE, **D** = DELETE, **—** = aucun accès, **RPC** = uniquement via une fonction contrôlée. « Personnel » = réceptionniste avec permissions par défaut (variantes sans permission détaillées en section 5).

| Table | Super admin | Propriétaire | Personnel | Membre | Droits table (authenticated) |
|---|---|---|---|---|---|
| gyms | S, I, U | S (la sienne) | S (la sienne) | S (la sienne) | S, I, U |
| profiles | S (tous) | S (salles partagées), U soi-même | S (salles partagées), U soi-même | S, U soi-même | S ; U (full_name, phone) |
| branches | — | S, I, U | S | — | S, I, U |
| gym_users | S, I, U, D | S, I, U, D (sa salle) | S (sa propre ligne) | — | S, I, U, D ; U (role, permissions) |
| members | — | S, I, U, D | S ; I, U si `manage_members` | S (sa ligne) | S, I, U, D ; I (gym_id, member_number, full_name, phone, photo_path, status) ; U (member_number, full_name, phone, photo_path, status) |
| membership_plans | — | S, I, U, D | S | S (plan de son abonnement) | S, I, U, D ; U (name, price, duration_days, is_active) |
| subscriptions | — | S ; écritures : RPC à créer | S | S (les siens) | S |
| payments | — | S ; RPC `record_payment`, `cancel_payment` | S si `view_payments` ; RPC `record_payment` si `record_payments` ; RPC `cancel_payment` si `cancel_payments` | — | S |
| qr_tokens | — | — | — | RPC `issue_qr_token` | aucun |
| visits | — | S | S | S (les siennes) ; écriture : RPC `verify_qr` (staff) | S |
| notifications | — | I (aux participants de sa salle), S, U (`is_read`) les siennes | S, U (`is_read`) les siennes | S, U (`is_read`) les siennes | S, I ; U (is_read) |
| audit_logs | S (plateforme) | S (sa salle) | S (ses propres actions) | — | S |
| platform_subscriptions | S, I, U | S (la sienne) | — | — | S, I, U |
| advertisements | S, I, U | S (actives, ciblées) | S (actives, ciblées) | S (actives, ciblées) | S, I, U |
| advertisement_gyms | S, I, D | S (ses salles) | S (ses salles) | S (ses salles) | S, I, D |

**Matrice des RPC**

| RPC | Super admin | Propriétaire | Personnel | Membre | anon |
|---|---|---|---|---|---|
| issue_qr_token | refus | refus (sauf s'il est aussi membre actif) | refus (idem) | oui, membre actif de la salle | refus |
| verify_qr | `wrong_gym` | oui | oui (même sans permission) | `wrong_gym` | refus |
| record_payment | refus | oui | si `record_payments` | refus | refus |
| cancel_payment | refus | oui | si `cancel_payments` | refus | refus |

Tout accès d'une salle à une autre : **refusé pour tous les rôles**, y compris pour un propriétaire connaissant les UUID.

---

## 5. Scénarios de test et résultats attendus

Vocabulaire des résultats : **FILTRÉ** (la requête réussit, 0 ligne), **REFUS-DROIT** (`permission denied for table`, 42501), **REFUS-RLS** (`new row violates row-level security policy`, 42501), **EXCEPTION** (message de la fonction), **CONTRAINTE** (23503/23505/23514). Chaque test porte l'ID ci-dessous, repris dans `tests/manifest.json`.

### 5.1 `00_smoke` — PGlite fait-il ce que le projet suppose ?
| ID | Scénario | Attendu |
|---|---|---|
| S01 | `select version()` | Enregistré dans le rapport ; pas d'assertion sur la valeur (prod : 17.11) |
| S02 | Témoin : superutilisateur lit une table avec RLS activée et sans policy | Voit les lignes (prouve que le superutilisateur contourne la RLS) |
| S03 | Même requête après `SET LOCAL ROLE authenticated` | 0 ligne ; `rolsuper=false`, `rolbypassrls=false` |
| S04 | `auth.uid()` avec claims, sans claims, avec claims invalides | uuid, `NULL`, erreur ou `NULL` (noter le comportement) |
| S05 | Fonction `SECURITY DEFINER` appelée par `authenticated` | Retourne un résultat alors que la lecture directe de `gym_users` est impossible pour cet acteur |
| S06 | Trigger `subscriptions_end_date` | `end_date` calculée si omise |
| S07 | Trigger `payments_immutable` | UPDATE du montant : EXCEPTION |
| S08 | `record_payment` avec méthode invalide dans une transaction | Aucun effet résiduel (paiement absent, abonnement inchangé) |
| S09 | `verify_qr` s'exécute (`%rowtype`, `FOR UPDATE`, jsonb) | Retourne un jsonb avec `ok` |
| S10 | Insertion dans `auth.users` | Profil créé avec `full_name`, email, téléphone ; `full_name=''` si métadonnées absentes |
| S11 | Après `10_privileges.sql` : les triggers fonctionnent toujours | Insertion d'abonnement et de paiement via RPC réussit |
| S12 | L'erreur PGlite expose-t-elle `code` ? | Résultat consigné |

### 5.2 `01_schema_parity` (sur l'état `prod_baseline`)
| ID | Scénario | Attendu |
|---|---|---|
| P-01 | 16 corps de fonctions, normalisés (espaces) puis hash MD5 | Égaux à l'annexe A |
| P-02 | Drapeaux des fonctions (secdef, volatilité, `search_path`) | Égaux à l'annexe A |
| P-03 | Colonnes des 15 tables | Égales à l'annexe B |
| P-04 | 55 contraintes (hors clés primaires) | Noms égaux à l'annexe C |
| P-05 | Index non-contraintes | Égaux à l'annexe D |
| P-06 | Triggers publics (8) | Égaux à l'annexe E |
| P-07 | Privilèges `authenticated` : CRUD sur 15 tables ; `anon` : aucun | Égaux à l'observation de production |

### 5.3 `10_isolation` (état `full`, deux salles)
Pour chaque test négatif, un **témoin** (`asSuper`) prouve d'abord que la donnée visée existe.

| ID | Acteur | Action | Attendu |
|---|---|---|---|
| I01 | ownerA | SELECT sur chaque table à `gym_id` | Uniquement des lignes de A (nombre exact par table) |
| I02 | ownerA | SELECT d'un membre/paiement/abonnement de B par UUID | FILTRÉ (0 ligne) |
| I03 | ownerA | UPDATE d'un membre de B | 0 ligne modifiée ; état de B inchangé (vérifié en super) |
| I04 | ownerA | INSERT membre avec `gym_id = B` | REFUS-RLS |
| I05 | ownerA | UPDATE `members.gym_id` vers B | REFUS-DROIT (colonne non autorisée) |
| I06 | ownerA | INSERT plan avec `gym_id = B` | REFUS-RLS |
| I07 | ownerA | INSERT `gym_users` pour B ; UPDATE `gym_id` | REFUS-RLS ; REFUS-DROIT |
| I08 | ownerA | RPC : `record_payment` (membre de B), `cancel_payment` (paiement de B), `issue_qr_token(B)` | EXCEPTION 42501 pour chacune |
| I09 | staffA | `verify_qr` sur un jeton de B | `{"ok":false,"reason":"wrong_gym"}`, aucune visite créée |
| I10 | staffA | `record_payment` avec un abonnement d'un autre membre | EXCEPTION « subscription not found for this member » |
| I11 | superuser | INSERT abonnement `member` de A et `gym_id` B | CONTRAINTE 23503 (clé composite, indépendante de la RLS) |
| I12 | dualX | Lecture des deux salles | Staff : voit A ; membre : voit seulement sa ligne dans B ; aucune écriture dans B |
| I13 | memberA1 | SELECT par UUID de chaque ligne de B, sur toutes les tables | FILTRÉ ou REFUS-DROIT |
| I14 | outsider | SELECT sur toutes les tables | 0 ligne partout (sauf sa ligne `profiles`) |
| I15 | anon | SELECT sur chaque table ; appel des 4 RPC | REFUS-DROIT / `permission denied for function` |
| I16 | staffA | SELECT/INSERT/UPDATE sur `gym_users` d'une autre salle ou de la sienne | Conforme à la matrice |

### 5.4 `20_payments`
| ID | Scénario | Attendu |
|---|---|---|
| PY01 | staffA `record_payment` sur subA0 (pending) | Paiement `recorded`, `recorded_by` = id `gym_users` de staffA, abonnement → `active`, lignes d'audit créées |
| PY02 | staffA_np `record_payment` | EXCEPTION 42501 |
| PY03 | ownerA `record_payment` sans abonnement | Paiement créé |
| PY04 | Méthode invalide ; montant 0 ; montant négatif | CONTRAINTE 23514 ; aucun effet résiduel |
| PY05 | Abonnement `cancelled` | EXCEPTION « subscription is cancelled » |
| PY06 | Écriture directe INSERT/UPDATE/DELETE par ownerA, staffA, memberA1, sa | REFUS-DROIT pour tous |
| PY07 | Superuser : UPDATE du montant, DELETE | EXCEPTION du trigger ; UPDATE `recorded`→`cancelled` autorisé ; deuxième changement de statut : EXCEPTION |
| PY08 | `cancel_payment` : staffA (sans `cancel_payments`) | EXCEPTION 42501 |
| PY09 | ownerA `cancel_payment` avec motif | Statut `cancelled` ; audit `CANCEL_PAYMENT` avec motif |
| PY10 | Motif vide, espaces, `NULL` ; double annulation | EXCEPTION chaque fois |
| PY11 | Visibilité : ownerA voit les paiements de A ; staffA (view_payments=false) voit 0 ; avec `view_payments=true` voit ceux de A ; jamais ceux de B | Comptes exacts |
| PY12 | **Exploration** : `record_payment` avec `NaN` puis `Infinity` | Consigner le résultat réel. Si accepté : **lacune connue**, ne pas corriger la RPC, la signaler |
| PY13 | **Lacune connue** : deux appels identiques de `record_payment` | Le test affirme le comportement actuel (2 paiements) et est étiqueté `KNOWN GAP` (pas d'idempotence) |
| PY14 | Annulation d'un paiement : effet sur l'abonnement lié | Affirme le comportement actuel (abonnement inchangé), étiquette `KNOWN GAP` |

### 5.5 `30_subscriptions`
| ID | Scénario | Attendu |
|---|---|---|
| SB01 | Insertion sans `end_date` (super) | `end_date = start_date + duration_days` |
| SB02 | `end_date` antérieure à `start_date` | CONTRAINTE 23514 |
| SB03 | Plan d'une autre salle | CONTRAINTE 23503 |
| SB04 | INSERT/UPDATE/DELETE directs par tous les rôles, y compris sa | REFUS-DROIT |
| SB05 | Lectures : memberA1 voit seulement le sien ; staffA tous ceux de A ; aucun de B | Comptes exacts |
| SB06 | Statut hors liste | CONTRAINTE 23514 |
| SB07 | Suppression d'un plan utilisé par un abonnement (ownerA) | CONTRAINTE 23503 |
| SB08 | Audit de l'insertion d'un abonnement | Ligne `audit_logs` avec `gym_id` correct |

### 5.6 `40_qr_visits`
| ID | Scénario | Attendu |
|---|---|---|
| Q01 | memberA1 `issue_qr_token(A)` | `nonce` de 64 caractères hexadécimaux ; `expires_at` ≈ maintenant + 30 s ; ne contient aucun UUID du membre |
| Q02 | 1000 jetons | 1000 valeurs distinctes |
| Q03 | memberA3 (inactif) ; memberB1 sur la salle A ; outsider | EXCEPTION 42501 |
| Q04 | staffA `verify_qr` valide, branche `bA1` | `ok:true`, `visit_id` ; `used_at` renseigné ; une visite avec `qr_token_id` ; clés : `full_name, member_number, photo_path, subscription_end` |
| Q05 | Même `nonce` rescanné | `ok:false, reason:already_used` ; toujours 1 visite |
| Q06 | Jeton expiré (`expires_at` dans le passé, ou égal à `now()`) | `reason:expired` ; aucune visite ; jeton non consommé |
| Q07 | `nonce` inconnu, vide, `NULL` | `reason:invalid_token` |
| Q08 | Jeton de B scanné par staffA ; staff d'une salle suspendue (C) | `reason:wrong_gym` |
| Q09 | Branche de B ; branche inactive `bA2` ; UUID inexistant | `reason:invalid_branch` |
| Q10 | memberA2 (abonnement expiré) | `reason:subscription_inactive` ; aucune visite ; jeton non consommé |
| Q11 | Membre `inactive` | `reason:member_inactive` |
| Q12 | `verify_qr` par memberA1 ; par anon | `wrong_gym` ; REFUS-DROIT |
| Q13 | Écriture directe sur `visits` par tous | REFUS-DROIT |
| Q14 | Lecture directe de `qr_tokens` par tous | REFUS-DROIT |
| Q15 | Deuxième visite avec le même `qr_token_id` (super) | CONTRAINTE 23505 |
| Q16 | ownerA et staffA_np scannent | Réussissent (aucune permission requise) |
| Q17 | Visibilité de `visits` | memberA1 voit les siennes ; staffA celles de A ; rien de B |
| M01 | **Concurrence** : deux scans simultanés du même jeton | **NON TESTABLE dans PGlite** (voir section 6). Test manuel documenté dans le rapport |

### 5.7 `50_profiles_audit_notifications`
| ID | Scénario | Attendu |
|---|---|---|
| R01 | Lecture de profils | staffA lit memberA1 et ownerA ; staffA ne lit pas memberB1 ; memberA1 lit seulement le sien ; sa lit tous |
| R02 | UPDATE profil | `full_name`, `phone` : OK ; `email` : REFUS-DROIT ; profil d'un autre : 0 ligne ; `id` : REFUS-DROIT |
| R03 | INSERT/DELETE sur `profiles` | REFUS-DROIT |
| R04 | `authenticated` lit `auth.users` | REFUS-DROIT |
| R05 | Claims avec `user_metadata.role='super_admin'` sans `app_metadata` | `is_super_admin()` faux ; avec `app_metadata.role='super_admin'` : vrai (signature **non vérifiable** dans PGlite) |
| R06 | Escalade : staffA UPDATE son `role` en `gym_owner` ; staffA INSERT `gym_users` ; memberA1 UPDATE `gym_users` | Tous refusés |
| R07 | ownerA crée un second propriétaire pour sa salle | Autorisé (comportement documenté) |
| R08 | Audit : une ligne par opération sur les 6 tables auditées ; `gym_id` correct (pour `gyms` : l'id) ; `actor_id` = auteur ; `old_values`/`new_values` corrects | Conforme |
| R09 | `audit_logs` : écritures directes | REFUS-DROIT |
| R10 | Visibilité de l'audit : ownerA = sa salle ; staffA = ses actions ; sa = entité `gyms` et `gym_id NULL` ; membre = rien ; B isolée | Comptes exacts |
| R11 | Notifications : chacun voit les siennes ; UPDATE de `is_read` OK, UPDATE de `title` REFUS-DROIT ; ownerA insère pour un participant de A OK ; pour un participant de B ou un étranger REFUS-RLS | Conforme |
| R12 | `platform_subscriptions` : sa lit et écrit ; ownerA lit la sienne seulement ; staffA et membres : 0 ligne | Conforme |
| R13 | Publicités : `adActiveA` visible pour owner, staff, membre de A ; invisible pour B ; `adDraft`, `adExpiredWindow` invisibles ; sa voit tout ; écriture refusée sauf sa | Conforme |

### 5.8 `60_permission_matrix`
Test piloté par une structure JS qui reprend la matrice de la section 4 : pour chaque combinaison `rôle × table × opération`, vérifier le résultat attendu (autorisé, FILTRÉ, REFUS-DROIT ou REFUS-RLS) et **distinguer** les trois types de refus. ID : `MX-<table>-<rôle>-<op>`. Cette matrice est la seule définition ; si le code et le document divergent, le document prévaut.

### 5.9 `90_mutation` (les tests sont-ils sensibles ?)
Dans une instance éphémère, introduire volontairement une faille et vérifier que les tests ciblés **échouent** :
| ID | Mutation | Tests qui doivent échouer |
|---|---|---|
| MU01 | Supprimer la policy SELECT de `members` | I01, I02 |
| MU02 | `GRANT INSERT ON payments TO authenticated` + policy permissive | PY06 |
| MU03 | Remplacer `has_perm` par une fonction qui retourne `true` | PY02, PY08, MX-* correspondants |
| MU04 | Accorder `UPDATE (gym_id)` sur `members` | I05 |
Une mutation qui ne fait échouer aucun test signale un test creux : à corriger.

---

## 6. Limites connues de PGlite (à reprendre dans le rapport)

1. **Le superutilisateur contourne la RLS.** PGlite démarre en mode mono-utilisateur avec une session superutilisateur ; la RLS ne s'applique à aucune requête exécutée ainsi. Parades obligatoires :
   - toute requête de test passe par `asActor` / `asAnon` qui exécute `SET LOCAL ROLE` ;
   - le helper vérifie `rolsuper` et `rolbypassrls` de `current_user` et échoue si l'un est vrai ;
   - le test S02/S03 prouve le contournement d'un côté et l'application de la RLS de l'autre ;
   - `asSuper` n'est autorisé que pour fixtures, témoins et vérifications d'état.
2. **Connexion unique : aucune vraie concurrence.** Le verrou `FOR UPDATE` de `verify_qr` ne peut pas être exercé. Test **M01 non testable**. Alternative gratuite : installer PostgreSQL officiel en local, ouvrir deux sessions `psql`, exécuter `begin; select public.verify_qr(...)` dans la première sans valider, lancer la seconde, puis valider la première ; la seconde doit répondre `already_used`. À consigner comme test manuel.
3. **Ce n'est pas Supabase.** Non couverts : GoTrue (signatures JWT, `app_metadata` signé), PostgREST (rôle `authenticator`, schémas exposés, codes HTTP), Storage (policies simulées seulement), Edge Functions, Realtime, e-mails, réglages Auth. Les rôles `anon`/`authenticated`/`service_role` et `auth.uid()`/`auth.jwt()` sont **simulés**.
4. **Superutilisateur ≠ rôle `postgres` de Supabase.** En production le rôle `postgres` n'est pas superutilisateur (il a `BYPASSRLS`). Les fonctions `SECURITY DEFINER` appartiennent à ce rôle ; dans PGlite elles appartiennent à un superutilisateur. Pour la RLS le comportement est équivalent ; d'autres privilèges peuvent différer.
5. **Version de Postgres** : à comparer avec la production (17.11) via S01 ; un écart de version est à noter.
6. **Privilèges par défaut Supabase** (événements, `ALTER DEFAULT PRIVILEGES`) non reproduits ; le fichier `05` reproduit seulement l'état observé.
7. **`now()` est figé dans une transaction** : les tests d'expiration manipulent `expires_at` plutôt que d'attendre.
8. **Erreurs** : comparaison par SQLSTATE et message, pas par code HTTP.

---

## 7. Critères pour qu'un test soit réellement réussi

Un test n'est **réussi** que si **toutes** les conditions suivantes sont vraies :
1. `npm test` s'est exécuté jusqu'au bout avec le code de sortie 0, sans test ignoré ni commenté, hors étiquettes déclarées (`KNOWN GAP`, `NOT TESTABLE`, `SIMULATED`).
2. Chaque ID de `tests/manifest.json` a été exécuté. Un ID manquant = échec global.
3. Il contient au moins une assertion explicite.
4. **Test négatif** : il assert le **type de refus précis** (REFUS-DROIT, REFUS-RLS, EXCEPTION, CONTRAINTE avec code), pas seulement « une erreur », **et** il vérifie en `asSuper` que l'état est inchangé.
5. **Test de filtrage** (0 ligne) : un témoin `asSuper` prouve d'abord que la ligne existe.
6. **Test positif** : il vérifie les effets de bord (lignes créées, statuts, audit).
7. Les tests sont indépendants : chacun dans une transaction annulée ; un second `npm test` donne le même résultat.
8. Le garde de `asActor` (rôle non superutilisateur, sans `BYPASSRLS`) est passé.
9. `90_mutation` : chaque mutation fait échouer au moins un test ciblé.
10. Aucune écriture distante n'a eu lieu (vérifier qu'aucune commande de la liste interdite n'a été lancée).

**Rapport final** : `reports/test-report.md`, écrit **après** l'exécution réelle, contenant : versions (Node, PGlite, `select version()`), sortie brute de `npm test` (ou lien vers `reports/last-run.txt`), tableau `ID | statut (PASSED / FAILED / KNOWN GAP / NOT TESTABLE / SIMULATED) | remarque`, résultats des tests exploratoires (PY12, S12, S04), liste des mutations, limites, et décisions en attente (section 8). Si un test échoue, ne pas modifier le test pour le faire passer : corriger `10_privileges.sql` ou `20_policies.sql`, ou signaler le désaccord. Ne jamais modifier `01`, `02` ni les 4 RPC sans justification écrite et approbation de l'utilisateur.

---

## 8. Informations manquantes — valeurs par défaut à signaler, non à inventer

| # | Question | Valeur par défaut appliquée |
|---|---|---|
| 1 | Le super admin peut-il lire membres, paiements, visites ? | Non |
| 2 | Le propriétaire peut-il renommer sa salle ou changer son statut ? | Non (super admin seulement) |
| 3 | Les membres d'une salle suspendue gardent-ils l'accès à leurs propres données ? | Oui en lecture ; le personnel perd l'accès (comportement actuel de `gym_role`/`has_perm`) |
| 4 | Le personnel peut-il voir le reçu d'un paiement qu'il vient d'enregistrer ? | Seulement avec `view_payments` (point à trancher) |
| 5 | Comment créer et activer un abonnement sans écriture directe ? | **Aucune écriture directe** ; une RPC (`create_subscription`) reste à concevoir. L'application ne pourra pas créer d'abonnement avant cela |
| 6 | Comment lier un membre à un compte (invitation) ? | `profile_id` exclu des écritures client ; chemin à définir |
| 7 | Départ d'un employé : `gym_users` n'a pas de statut et la suppression est bloquée par les paiements | Non traité ; signalé |
| 8 | Protection contre la suppression du dernier propriétaire | Non traitée ; signalée |
| 9 | Qui envoie les notifications ? | Le propriétaire, aux participants de sa salle |
| 10 | Que voit le super admin dans `audit_logs` ? | Entité `gyms` et `gym_id NULL` |
| 11 | Montant égal au prix du plan ? Remboursement (`refunded` n'a pas de fonction) ? Idempotence ? | Non gérés ; `KNOWN GAP` |
| 12 | `end_date = start_date + duration_days` : fin inclusive ? Fuseau horaire ? | Comportement actuel du trigger ; base en UTC |
| 13 | Les membres voient-ils les noms des branches ? | Non |
| 14 | Convention du chemin des photos (`<gym_id>/<member_id>.<ext>`) et policies Storage | Hors périmètre de ce projet (simulation uniquement) |
| 15 | Suppressions autorisées sur `gyms`, `branches`, `subscriptions`, `advertisements` | Aucune (utiliser les statuts) |

---

## Annexe A — Fonctions de production (instantané lecture seule du 22/10/2026)

Hash MD5 du corps (`prosrc` avec espaces de bord supprimés, puis toute suite d'espaces ramenée à un seul espace), drapeaux : tous `search_path=""`.

| Fonction | MD5 | secdef | volatilité |
|---|---|---|---|
| private.audit_row | 61ebd501b80bf5864d8b9ec3b074715a | oui | v |
| private.gym_role | 11791a9f7c44ac08f5934635d90b5b93 | oui | s |
| private.handle_new_user | 471106cee1cb94aab3e41c9ed90b84c6 | oui | v |
| private.has_perm | a97feca8a8f92b229e7f62752bd438a9 | oui | s |
| private.is_my_member | cb49eaca719a709f4cf9318658e256dc | oui | s |
| private.is_owner | 23d1f9fef4b973c985fd66d53ffe713e | oui | s |
| private.is_super_admin | c0946fe95267d18eddb2bf1529f12676 | oui | s |
| private.my_gym_ids | 8ff2fbe6dc46d4e4c307f03809b3467d | oui | s |
| private.payments_guard | df10db5e5d482e699472fda283c99c1c | non | v |
| private.shares_gym_with | bce7e03b4336e98a9da6bef3f8517d9e | oui | s |
| private.subscriptions_set_end_date | 8258588692b65a86b5587293f8dab119 | oui | v |
| private.try_uuid | 07bc6a5a4ba52035967577dee02947ba | non | i |
| public.cancel_payment | fa8cc0638a3086b95746081fe2e8f1ca | oui | v |
| public.issue_qr_token | a7e5db0ef0adf846c87a9bca78bb3219 | oui | v |
| public.record_payment | 5b2d3fe30edccd9f5311456009b04163 | oui | v |
| public.verify_qr | 736de0fcca28203a24288a57689b07cc | oui | v |

Calcul côté PGlite : `md5(regexp_replace(btrim(prosrc), '\s+', ' ', 'g'))`.

## Annexe B — Colonnes de production (nom:type[:nn][:d=défaut], dans l'ordre)

```text
advertisement_gyms: advertisement_id:uuid:nn | gym_id:uuid:nn
advertisements: id:uuid:nn:d=gen_random_uuid() | title:text:nn | content:text | start_date:date:nn | end_date:date:nn | status:text:nn:d='draft'::text
audit_logs: id:uuid:nn:d=gen_random_uuid() | gym_id:uuid | actor_id:uuid | action:text:nn | entity:text:nn | old_values:jsonb | new_values:jsonb | created_at:timestamp with time zone:nn:d=now()
branches: id:uuid:nn:d=gen_random_uuid() | gym_id:uuid:nn | name:text:nn | status:text:nn:d='active'::text
gym_users: id:uuid:nn:d=gen_random_uuid() | profile_id:uuid:nn | gym_id:uuid:nn | role:text:nn | permissions:jsonb:nn:d='{"view_payments": false, "manage_members": true, "cancel_payments": false, "record_payments": true, "renew_subscriptions": true}'::jsonb
gyms: id:uuid:nn:d=gen_random_uuid() | name:text:nn | status:text:nn:d='active'::text | created_at:timestamp with time zone:nn:d=now()
members: id:uuid:nn:d=gen_random_uuid() | gym_id:uuid:nn | profile_id:uuid | member_number:text:nn | photo_path:text | status:text:nn:d='active'::text | full_name:text:nn | phone:text
membership_plans: id:uuid:nn:d=gen_random_uuid() | gym_id:uuid:nn | name:text:nn | price:numeric(12,2):nn | duration_days:integer:nn | is_active:boolean:nn:d=true
notifications: id:uuid:nn:d=gen_random_uuid() | gym_id:uuid:nn | recipient_id:uuid:nn | title:text:nn | body:text:nn | is_read:boolean:nn:d=false | created_at:timestamp with time zone:nn:d=now()
payments: id:uuid:nn:d=gen_random_uuid() | gym_id:uuid:nn | member_id:uuid:nn | subscription_id:uuid | recorded_by:uuid:nn | amount:numeric(12,2):nn | method:text:nn | reference:text | status:text:nn:d='recorded'::text | created_at:timestamp with time zone:nn:d=now()
platform_subscriptions: id:uuid:nn:d=gen_random_uuid() | gym_id:uuid:nn | amount:numeric(12,2):nn | start_date:date:nn | end_date:date:nn | status:text:nn:d='pending'::text
profiles: id:uuid:nn | full_name:text:nn:d=''::text | phone:text | email:text
qr_tokens: id:uuid:nn:d=gen_random_uuid() | gym_id:uuid:nn | member_id:uuid:nn | nonce:text:nn | expires_at:timestamp with time zone:nn | used_at:timestamp with time zone
subscriptions: id:uuid:nn:d=gen_random_uuid() | gym_id:uuid:nn | member_id:uuid:nn | plan_id:uuid:nn | start_date:date:nn:d=CURRENT_DATE | end_date:date:nn | status:text:nn:d='pending'::text
visits: id:uuid:nn:d=gen_random_uuid() | gym_id:uuid:nn | member_id:uuid:nn | branch_id:uuid:nn | qr_token_id:uuid | checked_in_at:timestamp with time zone:nn:d=now() | verification_source:text:nn:d='qr'::text
```

## Annexe C — Contraintes de production (55, hors clés primaires)

```text
advertisement_gyms: advertisement_gyms_advertisement_id_fkey, advertisement_gyms_gym_id_fkey
advertisements: ads_dates_ck, advertisements_status_check
audit_logs: audit_logs_actor_id_fkey, audit_logs_gym_id_fkey
branches: branches_gym_id_fkey, branches_id_gym_uq, branches_status_check
gym_users: gym_users_gym_id_fkey, gym_users_id_gym_uq, gym_users_profile_gym_uq, gym_users_profile_id_fkey, gym_users_role_check
gyms: gyms_status_check
members: members_gym_id_fkey, members_id_gym_uq, members_number_uq, members_profile_gym_uq, members_profile_id_fkey, members_status_check
membership_plans: membership_plans_duration_days_check, membership_plans_gym_id_fkey, membership_plans_price_check, plans_id_gym_uq
notifications: notifications_gym_id_fkey, notifications_recipient_id_fkey
payments: pay_member_fk, pay_staff_fk, pay_sub_fk, payments_amount_check, payments_gym_id_fkey, payments_method_check, payments_status_check
platform_subscriptions: platform_subs_dates_ck, platform_subscriptions_amount_check, platform_subscriptions_gym_id_fkey, platform_subscriptions_status_check
profiles: profiles_id_fkey
qr_tokens: qr_id_gym_uq, qr_member_fk, qr_tokens_gym_id_fkey, qr_tokens_nonce_key
subscriptions: subs_dates_ck, subs_id_gym_uq, subs_member_fk, subs_plan_fk, subscriptions_gym_id_fkey, subscriptions_status_check
visits: visits_branch_fk, visits_gym_id_fkey, visits_member_fk, visits_one_per_token, visits_qr_fk, visits_verification_source_check
```
Les clés étrangères composites sont : `subs_member_fk (member_id,gym_id)`, `subs_plan_fk (plan_id,gym_id)`, `pay_member_fk`, `pay_sub_fk (subscription_id,gym_id)`, `pay_staff_fk (recorded_by,gym_id) → gym_users`, `qr_member_fk`, `visits_member_fk`, `visits_branch_fk`, `visits_qr_fk`.

## Annexe D — Index de production (hors contraintes)

```text
advertisement_gyms (gym_id)
audit_logs (actor_id) ; (gym_id, created_at)
branches (gym_id)
gym_users (gym_id) ; (profile_id)
members (gym_id, full_name) ; (profile_id)
membership_plans (gym_id)
notifications (recipient_id)
payments (gym_id, created_at) ; (member_id) ; (subscription_id)
platform_subscriptions (gym_id)
qr_tokens (member_id)
subscriptions (gym_id, status, end_date) ; (member_id) ; (plan_id)
visits (branch_id) ; (gym_id, checked_in_at) ; (member_id)
```

## Annexe E — Triggers de production

```text
public.gym_users          audit_gym_users          AFTER INSERT OR UPDATE OR DELETE  → private.audit_row()
public.gyms               audit_gyms               AFTER INSERT OR UPDATE OR DELETE  → private.audit_row()
public.members            audit_members            AFTER INSERT OR UPDATE OR DELETE  → private.audit_row()
public.membership_plans   audit_plans              AFTER INSERT OR UPDATE OR DELETE  → private.audit_row()
public.payments           audit_payments           AFTER INSERT OR UPDATE OR DELETE  → private.audit_row()
public.payments           payments_immutable       BEFORE UPDATE OR DELETE           → private.payments_guard()
public.subscriptions      audit_subscriptions      AFTER INSERT OR UPDATE OR DELETE  → private.audit_row()
public.subscriptions      subscriptions_end_date   BEFORE INSERT                     → private.subscriptions_set_end_date()
auth.users                on_auth_user_created     AFTER INSERT                      → private.handle_new_user()
```

## Annexe F — Privilèges observés en production (22/10/2026)

- `authenticated` : SELECT, INSERT, UPDATE, DELETE sur les 15 tables ; USAGE sur le schéma `private`.
- `anon` : aucun droit sur les tables ; pas d'USAGE sur `private` ; EXECUTE refusé sur les 4 RPC publiques.
- RLS activée sur les 15 tables, **0 policy** ; 0 utilisateur, 0 ligne de données, 0 bucket.
