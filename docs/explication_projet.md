# MatiMatch expliqué simplement — Guide pédagogique et préparation à la soutenance

Ce document décrit l'application telle qu'elle existe dans le projet `Matimatch` au 19 octobre 2026. Il distingue ce que le code fait réellement de ce qui reste à sécuriser ou à tester.

## 1. Le projet en une phrase

MatiMatch est une application Flutter de football : un utilisateur se connecte, consulte des matchs et leurs cotes, crée des pronostics, les partage avec ses amis et peut envoyer un match ou un pronostic par MQTT à un ESP32 simulé dans Wokwi, qui l'affiche sur un écran OLED. Le bouton de l'ESP32 renvoie un événement vers Flutter.

## 2. Vue d'ensemble de l'architecture

```text
Utilisateur
    │
    ▼
Application Flutter / Riverpod
    ├── Firebase Authentication : identité et session
    ├── Firestore : profils, amis et pronostics
    ├── API de football HTTPS : matchs, cotes, résultats, classements
    ├── Hive local : cache des matchs
    └── MQTT TLS : messages temps réel
              │
              ▼
        HiveMQ Cloud (broker)
              │
              ▼
       ESP32 simulé par Wokwi
          ├── écran OLED
          └── bouton GPIO 15
```

Le broker HiveMQ joue le rôle d'un facteur : Flutter lui confie un message, puis le broker le distribue à l'ESP32 abonné au bon topic. Dans l'autre sens, le bouton publie un message que Flutter reçoit.

Attention à deux noms proches :

- **HiveMQ Cloud** est le broker MQTT sur Internet.
- **Hive Flutter** est une petite base locale utilisée comme cache sur le téléphone. Ce ne sont pas les mêmes technologies.

## 3. Pourquoi Flutter et Dart ?

### Ce que cela apporte à l'utilisateur

Une interface mobile fluide et cohérente, avec les mêmes écrans et comportements sur plusieurs plateformes potentielles.

### Ce qui se passe techniquement

Flutter dessine l'interface avec des widgets. Quand un provider Riverpod change — liste des matchs, état MQTT, pronostics — seuls les widgets concernés sont reconstruits. Dart apporte le typage et surtout `Future`, `Stream`, `async` et `await`, adaptés aux appels réseau et aux mises à jour temps réel.

### Fichiers concernés

- Point de départ : `lib/main.dart:20-68`.
- État Riverpod : `lib/viewmodels/`.
- Écrans Flutter : `lib/screens/`.
- Dépendances : `pubspec.yaml:30-44`.

### Pourquoi ce choix

- Une seule base de code pour l'interface.
- Hot reload utile pendant le développement.
- Bons SDK Firebase et MQTT.
- Programmation asynchrone claire pour des données qui arrivent à des moments différents.

Limite actuelle : malgré la nature multiplateforme de Flutter, `lib/firebase_options.dart:18-51` n'a de configuration Firebase que pour Android. iOS, Web, macOS, Windows et Linux lèvent actuellement une erreur.

## 4. Organisation des dossiers

| Dossier/fichier | Rôle simple | Exemples |
|---|---|---|
| `lib/models/` | Forme des données | Match, pronostic, profil, ami, classement |
| `lib/services/` | Dialogue direct avec un système | Firebase Auth, Firestore, API HTTP, MQTT, Hive |
| `lib/repositories/` | Orchestration et stratégie de données | API puis cache ; messages MQTT métier |
| `lib/viewmodels/` | État observable par l'interface | Matchs sélectionnés, pronostics, connexion MQTT |
| `lib/screens/` | Ce que voit et manipule l'utilisateur | Connexion, matchs, amis, résultats, profil |
| `lib/storage/` | Ancien service SharedPreferences | Préférences et API de pronostics inutilisée |
| `android/` | Configuration de l'application Android | Manifest, Gradle, Firebase Android |
| `firestore.rules` | Autorisations de la base Firestore | Qui peut lire ou écrire quoi |
| `test/` | Tests Dart et règles Firestore | Modèles, autorisations, garde MQTT |
| `src/main.cpp` | Firmware ESP32 principal du projet racine | MQTT, OLED, bouton |
| `diagram.json` | Câblage Wokwi principal | ESP32, OLED SH1107, bouton |
| `platformio.ini` | Compilation du firmware principal | Environnements physique et Wokwi |
| `esp32/` | Deuxième variante/ancienne copie du firmware | OLED SSD1306, moins de fonctions |
| `docs/` | Documentation et soutenance | Dossier technique, démonstration, audit |

Le projet racine semble être la source ESP32 active : `.vscode/launch.json:18-47` pointe vers `.pio/build/esp32dev`, et `wokwi.toml:1-4` vers `.pio/build/wokwi`. La duplication `esp32/` doit être présentée comme une limite de maintenance.

## 5. Ce qui se passe au démarrage

1. Flutter initialise son moteur (`lib/main.dart:20-21`).
2. Il charge actuellement `.env` (`lib/main.dart:22`).
3. Il initialise Firebase avec la configuration Android (`lib/main.dart:24-30`).
4. Il tente de désactiver la persistance disque Firestore (`lib/main.dart:58-63`).
5. Il ouvre le cache Hive (`lib/main.dart:65-67`, `cache_service.dart:13-16`).
6. `MyApp` écoute l'état Firebase Auth. Un utilisateur absent voit `LoginScreen`; un utilisateur connecté voit `HomePage` (`lib/main.dart:71-149`).
7. `HomePage` crée le profil Firestore s'il manque, installe les listeners MQTT, puis se connecte au broker (`lib/main.dart:171-199`).
8. La navigation propose cinq onglets : matchs, pronostics, résultats, classements et profil (`lib/main.dart:161-168,206-242`).

## 6. Firebase Authentication

### 1. Ce que voit l'utilisateur

Il saisit son email et son mot de passe, puis appuie sur le bouton de connexion. Il peut aussi créer un compte. Après succès, l'écran principal apparaît automatiquement.

### 2. Ce qui se passe techniquement

`LoginScreen` valide le formulaire et appelle `AuthService.signIn` (`lib/screens/login_screen.dart:27-38`). Le service appelle `FirebaseAuth.signInWithEmailAndPassword` avec un délai maximum de 15 secondes (`lib/services/auth_service.dart:9-21`).

Firebase vérifie les identifiants et conserve la session. `authStateChanges()` émet alors un utilisateur. Riverpod transmet ce changement à `MyApp`, qui remplace l'écran de connexion par `HomePage` (`lib/viewmodels/auth_view_model.dart:6-9`, `lib/main.dart:143-149`).

L'inscription suit la même logique avec `createUserWithEmailAndPassword` (`auth_service.dart:24-32`). La déconnexion appelle `FirebaseAuth.signOut()` (`auth_service.dart:35-36`).

### 3. Fichiers concernés

- `lib/screens/login_screen.dart`
- `lib/screens/register_screen.dart`
- `lib/services/auth_service.dart`
- `lib/viewmodels/auth_view_model.dart`
- `lib/main.dart`

### 4. Pourquoi cette solution

Firebase Auth évite de développer soi-même le stockage des mots de passe, les jetons de session et les mécanismes cryptographiques. MatiMatch ne stocke pas le mot de passe Firebase dans ses propres modèles.

À préciser au professeur : aucune vérification d'email ou MFA n'est visible, et les erreurs inconnues peuvent être affichées presque brutes (`login_screen.dart:41-56`).

## 7. Firestore et les données stockées

### Collections réelles

```text
predictions/{predictionId}
users/{uid}
users/{uid}/friends/{friendUid}
users/{uid}/friendRequests/{senderUid}
users/{uid}/received/{predictionId}
```

### Contenu principal

- Un pronostic contient : identifiant, match, choix `1/N/2`, cote, mise facultative, commentaire, confiance, date, résultat, identifiant du match API, coup d'envoi et UID auteur (`lib/models/prediction.dart:1-27,64-94`).
- Un profil contient : UID, pseudo, email, appareil associé et date de création (`lib/models/user_profile.dart:1-13,28-44`).
- Une demande d'ami contient l'expéditeur, son nom, son email, le statut et la date (`lib/models/friend_request.dart:1-32`).
- Un pronostic reçu contient les données utiles et un état MQTT `pending` ou `sent` (`lib/models/shared_prediction.dart:1-55`).

### 1. Ce que voit l'utilisateur

Ses pronostics apparaissent en temps réel. Ses amis, demandes et pronostics reçus se mettent aussi à jour sans bouton « actualiser ».

### 2. Ce qui se passe techniquement

Firestore fournit des `snapshots()`, donc des streams. Quand un document change côté serveur, le provider reçoit la nouvelle liste et Flutter reconstruit l'écran. Exemple : `predictionsStream` filtre sur `authorUid` et trie par date (`lib/services/firestore_service.dart:15-33`).

Les règles côté serveur restent le vrai garde-barrière. Elles vérifient l'utilisateur authentifié, l'UID propriétaire et l'amitié (`firestore.rules:24-68,75-189`). L'interface seule n'est jamais une protection suffisante.

### 3. Fichiers concernés

- `lib/services/firestore_service.dart`
- `lib/services/user_service.dart`
- `lib/services/social_service.dart`
- `lib/models/`
- `firestore.rules`
- `firestore.indexes.json`

### 4. Pourquoi cette solution

Firestore convient aux petites données structurées et aux mises à jour temps réel. Il permet aussi d'écrire des règles d'accès indépendantes de l'application.

Limites actuelles importantes : un utilisateur peut modifier le résultat de son propre pronostic selon les règles actuelles, et tout utilisateur connecté peut lire les profils complets, y compris email et `deviceId`.

## 8. Récupération des matchs depuis l'API de football

Le code utilise actuellement l'API REST `api.5dollarfootballapi.com`, même si la variable s'appelle `API_FOOTBALL_KEY` (`lib/services/football_api_service.dart:9-18`). À l'oral, il est prudent de dire « une API REST de football » plutôt que de citer un fournisseur différent.

### 1. Ce que voit l'utilisateur

Une liste de matchs groupés par championnat, filtrables par date et ligue, avec heure, score, statut, logos et cotes. Il peut tirer pour actualiser et voit une bannière si des données de cache sont utilisées.

### 2. Ce qui se passe techniquement

1. `matchesProvider` observe la date sélectionnée (`lib/viewmodels/matches_view_model.dart:13-20`).
2. `FootballRepository` cherche d'abord un cache Hive encore valide (`lib/repositories/football_repository.dart:20-29`).
3. Sans cache frais, il appelle `FootballApiService.fetchMatchesFromApi` (`:31-35`).
4. Le service construit une URL avec le début et la fin de journée, puis envoie la clé dans un header Bearer HTTPS (`football_api_service.dart:108-125`).
5. Il conserve seulement cinq grands championnats (`:45-69,139-152`).
6. Il demande les cotes de chaque match en parallèle (`:72-105,154-172`).
7. Il transforme le JSON en objets `FootballMatch` (`lib/models/football_match.dart:85-123`).
8. Il sauvegarde les données dans Hive pendant 30 minutes (`cache_service.dart:5-7,54-67`).
9. Si l'API échoue, le repository peut montrer le cache expiré (`football_repository.dart:36-46`).

### 3. Fichiers concernés

- `lib/services/football_api_service.dart`
- `lib/repositories/football_repository.dart`
- `lib/services/cache_service.dart`
- `lib/models/football_match.dart`
- `lib/viewmodels/matches_view_model.dart`
- `lib/screens/matches_screen.dart`

### 4. Pourquoi cette solution

Le repository cache d'abord pour accélérer l'affichage, réduire les appels payants et rester utile lors d'une panne réseau. La couche service sait parler HTTP ; le repository choisit entre réseau et cache ; le provider expose le résultat à l'écran.

Point de vigilance : la clé fournisseur est actuellement embarquée dans l'APK. La bonne solution de production est un backend intermédiaire.

## 9. Création d'un pronostic

### 1. Ce que voit l'utilisateur

Depuis un match, il ouvre le formulaire, choisit domicile/nul/extérieur, voit la cote, saisit éventuellement une mise et un commentaire, règle sa confiance de 1 à 5 puis appuie sur « Enregistrer ». Les paris sont bloqués à moins de cinq minutes du coup d'envoi (`add_prediction_screen.dart:85-100`).

### 2. Ce qui se passe techniquement

Le formulaire crée un objet `Prediction` avec un identifiant basé sur l'heure (`add_prediction_screen.dart:103-114`). Le provider ajoute l'UID Firebase (`predictions_view_model.dart:58-75`), puis `FirestoreService` écrit le document dans une transaction (`firestore_service.dart:57-65`).

Le code effectue ensuite une seconde lecture REST avec le jeton Firebase pour confirmer que le document existe réellement sur le serveur (`firestore_service.dart:67-104`). Après l'écriture, si MQTT est connecté, le pronostic est aussi publié à l'ESP32 (`predictions_view_model.dart:77-84`).

### 3. Fichiers concernés

- `lib/screens/add_prediction_screen.dart`
- `lib/models/prediction.dart`
- `lib/viewmodels/predictions_view_model.dart`
- `lib/services/firestore_service.dart`
- `lib/repositories/mqtt_repository.dart`

### 4. Pourquoi cette solution

Firestore conserve durablement le pronostic et synchronise l'interface. MQTT sert à l'affichage temps réel sur l'objet ; si MQTT échoue, le pronostic reste enregistré dans Firestore.

## 10. Système d'amis et partage

### Ajouter un ami

#### 1. Ce que voit l'utilisateur

Dans « Mes amis », il recherche une adresse email, envoie une demande, puis le destinataire accepte ou refuse.

#### 2. Ce qui se passe techniquement

`UserService.findByEmail` cherche un profil (`lib/services/user_service.dart:52-59`). L'envoi écrit un document sous `users/{cible}/friendRequests/{expéditeur}` (`social_service.dart:24-33`). L'acceptation utilise un batch Firestore : elle ajoute l'amitié dans les deux sens puis supprime la demande (`social_service.dart:36-60`).

#### 3. Fichiers concernés

- `lib/screens/friends_screen.dart`
- `lib/services/user_service.dart`
- `lib/services/social_service.dart`
- `lib/viewmodels/social_provider.dart`
- `firestore.rules:107-151`

#### 4. Pourquoi cette solution

Le batch rend les trois écritures atomiques : elles réussissent ensemble ou échouent ensemble. Les deux utilisateurs obtiennent une liste d'amis symétrique.

### Exemple exact : « Quand je clique sur Partager »

1. Le pronostic vient d'être enregistré dans Firestore.
2. Une boîte de dialogue liste les amis (`add_prediction_screen.dart:143-185`).
3. L'utilisateur coche un ou plusieurs destinataires.
4. Le bouton « Partager » construit la liste choisie (`:191-205`).
5. `SocialService.sharePrediction` crée un `SharedPrediction` avec `mqttStatus: pending` (`social_service.dart:98-119`).
6. Pour chaque ami, il écrit `users/{amiUid}/received/{predictionId}` (`:121-123`).
7. Les règles Firestore vérifient que `fromUid` est l'utilisateur authentifié et qu'il est réellement ami du destinataire (`firestore.rules:161-171`).
8. Le service lit le profil du destinataire pour trouver son `deviceId` (`social_service.dart:125-127`).
9. Si un appareil est associé et que MQTT est connecté, il publie sur `matimatch/device/{deviceId}/prediction` (`:129-134`, `mqtt_repository.dart:105-118`). Le message est retenu pour que l'appareil puisse le recevoir après une reconnexion.
10. Le document Firestore passe de `pending` à `sent`. Sinon, il reste `pending` ; le code actuel ne contient pas de worker qui retente automatiquement plus tard.
11. Chez l'ami, le stream `receivedPredictionsProvider` met à jour l'onglet « Reçus » (`social_provider.dart:30-35`).
12. Sur son ESP32 associé, le firmware reconnaît le topic personnel, décode le JSON et affiche l'expéditeur, le match, le choix et la cote (`src/main.cpp:260-294`).

## 11. Résultats et statistiques

### 1. Ce que voit l'utilisateur

L'écran Résultats sépare les pronostics gagnés, perdus et en attente. Le profil montre le taux de réussite, le nombre de pronostics, la confiance moyenne, la répartition 1/N/2, les mises et le bilan net.

### 2. Ce qui se passe techniquement

- Gain potentiel : `mise × cote` (`lib/models/prediction.dart:30`).
- Bénéfice net gagné : `mise × (cote - 1)` (`:32-34`).
- Perte : `-mise` (`:34`).
- Taux de réussite : `gagnés / (gagnés + perdus) × 100` (`lib/screens/profile_screen.dart:28-32`).
- Total investi, récupéré et bilan : sommes calculées dans `profile_screen.dart:35-43`.

Le bouton « Vérifier » sélectionne les pronostics sans résultat dont le match a commencé depuis au moins 90 minutes. Pour chaque fixture, il demande le résultat à l'API ; si le résultat `1/N/2` correspond au choix, il écrit `won`, sinon `lost` (`predictions_view_model.dart:97-125`, `football_api_service.dart:189-220`).

### 3. Fichiers concernés

- `lib/screens/results_screen.dart`
- `lib/screens/profile_screen.dart`
- `lib/models/prediction.dart`
- `lib/viewmodels/predictions_view_model.dart`
- `lib/services/football_api_service.dart`

### 4. Pourquoi cette solution

Les calculs simples restent dans le modèle ou dans la présentation. La vérification distante utilise l'identifiant officiel du match et évite de demander à l'utilisateur de saisir manuellement le score.

Limite importante : les règles actuelles permettent au propriétaire de modifier son propre champ `result`, donc ces statistiques ne sont pas encore fiables contre un client modifié.

## 12. MQTT et HiveMQ Cloud

### 1. Ce que voit l'utilisateur

Un badge indique si l'objet est en ligne. Dans le détail d'un match, le bouton « Afficher sur MatiMatch Display » envoie le match à l'OLED. Un pronostic créé est envoyé automatiquement si MQTT est connecté.

### 2. Ce qui se passe techniquement

Flutter crée un client MQTT, active TLS, utilise le port configuré — 8883 par défaut — et s'authentifie auprès de HiveMQ (`lib/services/mqtt_service.dart:20-40`). Il s'abonne au statut et au bouton (`mqtt_repository.dart:32-58`).

Principaux topics :

| Topic | Direction | Contenu |
|---|---|---|
| `matimatch/device/match` | Flutter → ESP32 | Équipes, score, statut, heure |
| `matimatch/device/prediction` | Flutter → ESP32 | Pronostic personnel global |
| `matimatch/device/{deviceId}/prediction` | Flutter → appareil ciblé | Pronostic partagé |
| `matimatch/device/status` | ESP32 → Flutter | `ONLINE`/`OFFLINE` avec retain/LWT |
| `matimatch/device/button` | ESP32 → Flutter | `{"pressed":true}` |

Flutter publie avec QoS 1 (`mqtt_service.dart:60-69`). Le firmware principal s'abonne actuellement avec QoS 0 (`src/main.cpp:323-325`) et publie le bouton avec l'API simple de PubSubClient (`:413-419`). Il faut donc éviter d'affirmer que tous les échanges sont QoS 1.

### 3. Fichiers concernés

- `lib/services/mqtt_service.dart`
- `lib/repositories/mqtt_repository.dart`
- `lib/viewmodels/mqtt_provider.dart`
- `lib/main.dart:176-199`
- `src/main.cpp`

### 4. Pourquoi cette solution

MQTT est léger, événementiel et adapté aux objets connectés. HiveMQ Cloud évite d'héberger le broker soi-même et fournit une adresse Internet accessible à Flutter et Wokwi.

Sécurité à reconnaître honnêtement : Flutter vérifie le certificat avec le magasin système, mais l'ESP32 appelle actuellement `setInsecure()`. Les topics globaux et les ACL doivent aussi être durcis avant une utilisation multi-utilisateurs réelle.

## 13. Comment l'ESP32 reçoit et affiche un message

### 1. Ce que voit l'utilisateur

L'écran OLED affiche « En attente d'un prono », puis le match ou le pronostic reçu : équipes, heure/score, choix, cote et niveau de confiance. Pour un partage, il affiche aussi le nom de l'ami.

### 2. Ce qui se passe techniquement

1. L'ESP32 se connecte au Wi-Fi (`src/main.cpp:365-372`).
2. Il fabrique un identifiant à partir de sa MAC (`:38-48,374-379`).
3. Il se connecte à HiveMQ avec un LWT `OFFLINE`, publie `ONLINE` et s'abonne aux topics (`:302-331`).
4. `mqttCallback` copie le payload puis le décode avec ArduinoJson (`:218-300`).
5. Pour un match, il remplit `currentMatch` puis appelle `showMatch` (`:229-257`).
6. Pour un pronostic, il remplit `currentPrediction` puis appelle `showPrediction` ou `showSharedPrediction` (`:260-294`).
7. Les fonctions OLED positionnent les textes et appellent `display.display()` (`:76-215`).

### 3. Fichiers concernés

- `src/main.cpp`
- `platformio.ini`
- `diagram.json`
- `wokwi.toml`
- `include/credentials.h` local, non versionné

### 4. Pourquoi cette solution

ArduinoJson évite un parseur manuel fragile. PubSubClient est une bibliothèque MQTT légère. L'écran I2C n'utilise que deux lignes de données, et la structure `currentMatch/currentPrediction` permet de réafficher la dernière information après reconnexion.

## 14. Comment le bouton communique vers Flutter

### 1. Ce que voit l'utilisateur

Il appuie sur le bouton Wokwi. Dans le détail d'un match, Flutter affiche « Bouton Wokwi appuyé ! » (`match_detail_screen.dart:601-624`).

### 2. Ce qui se passe techniquement

Le bouton relie GPIO 15 à la masse (`diagram.json:20-25,35-36`). Le firmware utilise `INPUT_PULLUP`, détecte le front descendant, attend 20 ms pour l'anti-rebond puis publie un JSON sur le topic bouton (`src/main.cpp:362-363,413-419`).

Flutter est abonné à ce topic. `MqttRepository` transforme chaque message reçu en `true` (`mqtt_repository.dart:90-102`). `buttonEventProvider` l'expose à l'interface (`mqtt_provider.dart:32-36`).

### 3. Fichiers concernés

- `diagram.json`
- `src/main.cpp`
- `lib/repositories/mqtt_repository.dart`
- `lib/viewmodels/mqtt_provider.dart`
- `lib/screens/match_detail_screen.dart`

### 4. Pourquoi cette solution

Le bouton prouve que la communication est bidirectionnelle. La même infrastructure peut ensuite servir à confirmer une action ou demander une nouvelle information.

Limite actuelle : l'événement ne déclenche pas d'action métier ni d'accusé de réception ; le provider conserve simplement la dernière valeur `true`, donc le message peut rester affiché.

## 15. Wokwi : rôle et limites

### Ce que Wokwi apporte

- Simulation de l'ESP32 sans matériel physique.
- Reproduction du câblage OLED et bouton (`diagram.json`).
- Wi-Fi virtuel `Wokwi-GUEST` (`src/main.cpp:12-18`).
- Console série utile pour comprendre le firmware.
- Démonstration rapide et reproductible en cours.

### Ce que Wokwi ne prouve pas

- La consommation électrique, les parasites, le câblage réel ou les défauts d'alimentation.
- La sécurité physique d'une flash ESP32.
- Le comportement exact d'un vrai réseau Wi-Fi instable.
- La qualité d'un écran matériel précis.
- Le Secure Boot, le chiffrement eFuse/NVS ou une chaîne OTA réelle.
- La sécurité TLS actuelle : le code contourne la validation du certificat, même dans la variante physique.

## 16. Résumé oral en 1 minute

> MatiMatch est une application mobile Flutter qui centralise le suivi de matchs et la création de pronostics. L'utilisateur se connecte avec Firebase Authentication, récupère les matchs, cotes et classements depuis une API REST, puis enregistre ses pronostics dans Firestore. Il peut ajouter des amis et partager un pronostic ; les règles Firestore contrôlent les accès. La partie IoT utilise MQTT et HiveMQ Cloud : Flutter envoie un match ou un pronostic à un ESP32 simulé dans Wokwi, qui l'affiche sur un écran OLED. Le bouton de l'ESP32 publie un événement reçu par Flutter, ce qui démontre une communication bidirectionnelle. Riverpod gère l'état, Hive met les matchs en cache et MQTT gère le temps réel. Le prototype fonctionne architecturalement, mais l'audit de sécurité a identifié des corrections nécessaires : retirer les secrets de l'APK, activer une validation TLS stricte sur l'ESP32, centraliser les logs et ajouter une CI ainsi que des tests bout en bout.

## 17. Présentation technique en 5 minutes

### 0:00–0:40 — Besoin et expérience utilisateur

« MatiMatch réunit les matchs, les cotes, les pronostics personnels et le partage entre amis. Sa particularité est le lien avec un objet connecté : l'utilisateur peut envoyer l'information sur un écran OLED et recevoir l'appui d'un bouton. »

Montrer rapidement : connexion → liste des matchs → détail.

### 0:40–1:30 — Architecture Flutter

« Le projet est découpé en modèles, services, repositories, providers Riverpod et écrans. Les services parlent aux systèmes externes. Les repositories choisissent ou transforment les données. Les providers exposent un état réactif. Les écrans restent centrés sur l'affichage. »

Citer `FootballRepository` comme exemple : cache frais, sinon API, sinon cache périmé.

### 1:30–2:20 — Firebase et données

« Firebase Authentication gère la session email/mot de passe. Firestore stocke les profils, les relations d'amitié et les pronostics. Les règles contrôlent les UID et l'amitié, donc la sécurité ne repose pas seulement sur les boutons de l'interface. Les streams Firestore mettent l'application à jour en temps réel. »

Montrer un pronostic enregistré et l'onglet Reçus.

### 2:20–3:10 — API et calculs

« L'API HTTPS fournit matchs, cotes, résultats et classements. Hive garde un cache de 30 minutes. Un pronostic contient le choix, la cote, la mise et la confiance. Le gain potentiel est mise fois cote ; le bilan net additionne les bénéfices et les pertes. Après le match, l'application peut interroger l'API pour marquer gagné ou perdu. »

### 3:10–4:15 — MQTT et ESP32

« MQTT passe par HiveMQ Cloud. Flutter publie un JSON, l'ESP32 le décode avec ArduinoJson et dessine le contenu sur l'OLED. Le statut ONLINE est retenu et un Last Will publie OFFLINE en cas de coupure. Dans l'autre sens, le bouton GPIO 15 publie un événement que Riverpod affiche dans Flutter. »

Faire la démonstration OLED puis bouton.

### 4:15–5:00 — Sécurité, limites et suite

« L'audit Séance 12 montre que TLS et les règles Firestore sont déjà présents, mais le prototype n'est pas encore industrialisé. Les secrets sont embarqués dans l'APK, l'ESP32 désactive la validation du certificat, les logs ne sont pas centralisés et la CI manque. Mon plan est donc : rotation et retrait des secrets, SecureVault, CA ESP32, AppLogger, règles Firestore renforcées, ACL MQTT, GitHub Actions, tests end-to-end et audit MobSF du Release. »

Cette conclusion est plus crédible qu'une déclaration de sécurité parfaite non démontrée.

## 18. Vingt questions probables et réponses simples

### 1. Pourquoi Flutter ?

Parce qu'il permet de construire une interface réactive avec une seule base de code et possède de bons packages Firebase, HTTP et MQTT. Il accélère aussi le prototypage avec le hot reload.

### 2. Pourquoi Dart ?

Dart est typé et son modèle `Future`/`Stream` convient bien aux appels réseau, à Firebase temps réel et à MQTT.

### 3. Pourquoi Riverpod ?

Riverpod sépare l'état de l'interface. Un écran observe un provider et se met à jour automatiquement. Cela évite de transmettre manuellement les données entre tous les widgets.

### 4. Quelle différence entre service et repository ?

Un service parle directement à une technologie, par exemple HTTP ou Firestore. Un repository décide comment obtenir la donnée métier, par exemple « cache d'abord, sinon API ».

### 5. Comment le mot de passe Firebase est-il protégé ?

Il est envoyé au SDK Firebase Auth par HTTPS et n'est pas enregistré dans les modèles MatiMatch. Firebase gère la session. Le projet doit encore renforcer la vérification d'email et éventuellement la MFA.

### 6. Firestore est-il vraiment sécurisé si le client peut être modifié ?

La sécurité réelle vient des règles serveur. Un attaquant peut supprimer les boutons de l'interface, mais il ne peut pas contourner une bonne règle. Les règles actuelles isolent les lectures, mais doivent encore empêcher l'utilisateur de modifier son propre résultat.

### 7. Où sont stockés les pronostics ?

Dans la collection Firestore `predictions`. Ils sont filtrés par `authorUid`. Les pronostics reçus sont dans `users/{uid}/received`.

### 8. Pourquoi utiliser Hive ?

Hive met les matchs en cache localement pendant 30 minutes. L'affichage est plus rapide, l'API est moins sollicitée et un cache périmé peut dépanner quand le réseau échoue.

### 9. Hive et HiveMQ sont-ils liés ?

Non. Hive est un stockage local Flutter. HiveMQ est un broker MQTT sur Internet.

### 10. Pourquoi MQTT plutôt que HTTP pour l'ESP32 ?

MQTT est léger et fonctionne par publication/abonnement. L'ESP32 reçoit immédiatement un message sans interroger continuellement un serveur.

### 11. À quoi sert HiveMQ Cloud ?

Il reçoit les messages MQTT et les redistribue aux clients abonnés. Il relie le téléphone et l'ESP32 même s'ils ne sont pas sur le même réseau local.

### 12. À quoi servent QoS, retain et LWT ?

QoS fixe la garantie de livraison. `retain` garde la dernière valeur pour un client qui se reconnecte. Le LWT permet au broker de publier `OFFLINE` si l'ESP32 disparaît brutalement.

### 13. Le MQTT est-il sécurisé aujourd'hui ?

Côté Flutter, TLS et le magasin système sont utilisés. Côté ESP32, le transport est chiffré mais `setInsecure()` désactive la validation du serveur : c'est une non-conformité à corriger avec une CA. Les ACL doivent aussi être vérifiées dans HiveMQ.

### 14. Pourquoi le port 8883 ?

8883 est le port habituel de MQTT sur TLS. 1883 correspond généralement à MQTT sans chiffrement.

### 15. Que se passe-t-il exactement quand j'envoie un match à l'OLED ?

Flutter encode le match en JSON et le publie. HiveMQ le transmet à l'ESP32 abonné. L'ESP32 décode le JSON, remplit sa structure `MatchData` et redessine l'écran.

### 16. Comment le bouton remonte-t-il jusqu'à Flutter ?

L'ESP32 détecte GPIO 15 à l'état bas, publie un JSON sur le topic bouton, Flutter reçoit le message et le provider Riverpod actualise l'interface.

### 17. Comment fonctionne le partage entre amis ?

Le pronostic est copié dans la sous-collection `received` de chaque ami. Si cet ami a associé un appareil, le même contenu est publié sur le topic personnel de cet appareil.

### 18. Comment calculez-vous les statistiques ?

Le taux de réussite ignore les pronostics en attente et calcule gagnés divisés par gagnés plus perdus. Le bilan net additionne le bénéfice des gagnés et la mise négative des perdus.

### 19. Quels tests avez-vous ?

Il existe des tests de modèles, de logique d'autorisations et 64 scénarios Firebase Emulator écrits. Il n'existe pas encore de vrai test bout en bout Flutter–Firebase–MQTT–ESP32, et l'audit n'a pas exécuté les tests.

### 20. Quelle est la correction la plus urgente ?

Faire tourner les secrets exposés, retirer `.env` de l'APK et remplacer `setInsecure()` par une validation de certificat ESP32. Ensuite viennent AppLogger, les règles d'intégrité, les ACL MQTT, la CI et MobSF.

## 19. Difficultés rencontrées et solutions présentes

### Réseau/API indisponible

- Difficulté : distinguer une panne du fournisseur d'une vraie absence d'Internet.
- Solution : un second appel HTTPS vers un endpoint de connectivité (`football_api_service.dart:21-43`) et un repli sur le cache Hive (`football_repository.dart:36-46`).

### Données Firestore visibles localement avant confirmation serveur

- Difficulté : la compensation de latence de Firestore peut faire croire qu'une écriture est déjà distante.
- Solution actuelle : transaction puis lecture REST authentifiée du document (`firestore_service.dart:54-104`).

### Stream de l'ancien utilisateur après déconnexion

- Difficulté : conserver un listener avec un ancien UID provoque `permission-denied`.
- Solution : le provider observe `authStateProvider` et recrée le stream au changement d'utilisateur (`predictions_view_model.dart:23-44`).

### Réception MQTT avant installation des listeners

- Difficulté : perdre les messages si le stream n'existe pas encore.
- Solution : le contrôleur broadcast est créé dès le repository (`mqtt_repository.dart:21-27`) puis alimenté après connexion (`:42-58`).

### Coupures MQTT

- Difficulté : Wi-Fi ou broker peuvent disparaître.
- Solution : `autoReconnect` Flutter (`mqtt_service.dart:31-35`) et tentative ESP32 toutes les cinq secondes (`src/main.cpp:395-411`).

### Cohérence d'une amitié dans les deux sens

- Difficulté : trois écritures doivent réussir ensemble.
- Solution : batch Firestore (`social_service.dart:36-60`) et règles de self-insert contrôlées (`firestore.rules:107-133`).

### Paris trop proches du coup d'envoi

- Difficulté : empêcher un pronostic tardif.
- Solution côté interface : blocage à moins de cinq minutes (`add_prediction_screen.dart:85-100`, `football_match.dart:34-40`).
- Limite : la règle Firestore ne valide pas encore cette contrainte ; un client modifié peut la contourner.

## 20. Limites actuelles

- Secrets réellement présents dans l'APK Debug et dans les firmwares.
- Pas de `flutter_secure_storage` ni de coffre-fort.
- `setInsecure()` sur l'ESP32.
- Pas d'ACL MQTT prouvée et topics globaux non isolés.
- Identifiant client Flutter fixe, problématique avec plusieurs téléphones.
- Résultat et données d'un pronostic modifiables par son propriétaire.
- Profils complets lisibles par tous les comptes authentifiés.
- Pas d'AppLogger, logs contenant payloads et données personnelles.
- Pas de CI/CD GitHub Actions.
- Test widget du compteur obsolète.
- Pas de tests bout en bout.
- Pas d'APK Release, signature Release réelle ou rapport MobSF.
- Android autorise le trafic HTTP clair.
- Firebase n'est configuré que pour Android.
- Un partage MQTT `pending` n'est pas automatiquement réessayé plus tard.
- Le bouton Flutter garde seulement un booléen `true` et ne gère pas une suite d'événements horodatés.
- Deux variantes de firmware peuvent diverger.
- Wokwi ne remplace pas les essais sur ESP32 réel.
- Aucune OTA ; si elle est ajoutée, elle devra être signée avec A/B et rollback.

## 21. Améliorations possibles

### Sécurité

- Rotation immédiate des secrets exposés.
- Coffre-fort local pour les credentials provisionnés.
- Backend pour la clé de l'API de football.
- CA racine sur l'ESP32, ACL HiveMQ minimales et topics par utilisateur/appareil.
- Custom claims pour l'admin, App Check et règles Firestore avec schéma strict.
- Secure Boot, Flash Encryption et credentials uniques sur matériel physique.

### Fiabilité

- File d'attente/retry des partages MQTT `pending`.
- Accusés de réception MQTT avec identifiant de message.
- Client ID unique pour chaque instance Flutter.
- Gestion horodatée des événements bouton.
- Déduplication des firmwares.

### Qualité industrielle

- AppLogger assaini et aucun log Release.
- GitHub Actions pour analyse, tests, builds et scan de secrets.
- Tests Firebase Emulator réellement exécutés.
- Tests d'intégration Flutter avec Firebase Emulator et broker MQTT de test.
- Scénario Wokwi automatisé ou protocole de recette reproductible.
- APK Release signé, inspecté avec `strings` et audité par MobSF.

### Produit

- Vérification d'email et récupération de mot de passe.
- Notifications lors d'un partage.
- Suppression contrôlée des pronostics reçus et du compte.
- Configuration Firebase des autres plateformes si elles sont réellement visées.
- Historique d'événements de l'objet et état de livraison confirmé.

## 22. Phrase de conclusion pour la soutenance

> MatiMatch démontre une chaîne complète mobile–cloud–IoT : authentification, données temps réel, API externe, cache local et communication MQTT bidirectionnelle avec affichage matériel simulé. L'architecture fonctionnelle est en place ; l'étape suivante, clairement identifiée par l'audit Séance 12, est de transformer ce prototype en produit livrable en retirant les secrets des binaires, en imposant une validation TLS stricte, en renforçant les autorisations et en automatisant les preuves par la CI et les tests bout en bout.
