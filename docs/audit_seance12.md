# Audit Séance 12 — Sécurité, Observabilité & Industrialisation

Date de l'audit : 19 octobre 2026  
Projet audité : `C:\Users\matis\Documents\PlatformIO\Projects\Matimatch`  
Référence : PDF « Séance 12 — Sécurité, Observabilité & Industrialisation », 17 pages, lu intégralement avant l'audit.

> Cet audit porte uniquement sur le projet **Matimatch**. L'ancien projet `flutter_application_1` n'a pas été recherché ni audité. Le nom technique `flutter_application_1` encore présent dans `pubspec.yaml` et dans l'identifiant Android appartient au projet Matimatch actuel : c'est un reliquat de nommage, pas le dossier de l'ancien projet.

## 1. Cadre et méthode

### Statuts utilisés

- **CONFORME** : l'implémentation est visible et vérifiable dans le code ou dans un artefact existant.
- **PARTIEL** : une partie existe, mais une exigence importante manque ou n'est pas démontrée.
- **NON CONFORME** : absent, incorrect, ou contournement de sécurité constaté.
- **NON VÉRIFIÉ** : un test, un accès externe ou une exécution est nécessaire pour conclure.

### Limites volontaires de l'audit

L'audit initial a été effectué en lecture seule. Seuls les deux rapports demandés ont ensuite été créés. Je n'ai pas exécuté :

- `flutter analyze` ;
- `flutter test` ;
- les tests Firebase Emulator ;
- `flutter build apk --release` ;
- un build PlatformIO ;
- MobSF ;
- un test réel contre Firebase, l'API de football, HiveMQ Cloud ou Wokwi.

Ces commandes peuvent mettre à jour `build/`, `.dart_tool/`, `.pio/`, des caches ou des journaux. Leur résultat est donc indiqué **NON VÉRIFIÉ** lorsqu'aucune preuve actuelle suffisante n'existe.

Le dépôt comportait déjà deux modifications utilisateur au début de l'audit : `lib/services/football_api_service.dart` et `scripts/run_android.ps1`. Elles ont été conservées sans modification.

### Contrôles réellement effectués

- Lecture des sources Flutter/Dart, Android, Firebase, MQTT et ESP32.
- Lecture des règles et des tests Firestore.
- Inventaire Git et recherche de fichiers CI.
- Recherche statique des usages de `print()` et `debugPrint()`.
- Recherche de secrets dans les fichiers suivis, sans afficher leurs valeurs.
- Vérification que `.env` et `include/credentials.h` sont ignorés et absents de l'historique Git sous ces chemins.
- Inspection en mémoire de l'APK Debug existant, sans extraire ni afficher les secrets.
- Recherche des valeurs confidentielles dans les firmwares binaires existants, avec résultat `FOUND/NOT_FOUND` uniquement.
- Recherche de rapports MobSF et d'un APK Release.

## 2. Résumé exécutif

MatiMatch est fonctionnellement bien structuré : séparation modèles/services/repositories/providers/écrans, Firebase Authentication, règles Firestore détaillées, cache Hive, MQTT TLS côté Flutter, reconnexion, LWT, OLED et bouton ESP32.

Il n'est cependant **pas conforme à la séance 12 dans son état actuel**. Les écarts principaux sont :

1. `.env` est embarqué comme asset Flutter (`pubspec.yaml:68-69`). L'APK Debug existant contient réellement la clé API, l'utilisateur et le mot de passe MQTT, ainsi que les autres valeurs de `.env`.
2. `flutter_secure_storage` et `SecureVaultService` sont absents (`pubspec.yaml:30-44`).
3. Les deux firmwares désactivent la validation TLS avec `setInsecure()` (`src/main.cpp:381-382`, `esp32/src/main.cpp:177-178`).
4. Les firmwares compilés existants contiennent réellement les identifiants HiveMQ ; le firmware physique contient aussi les identifiants Wi-Fi.
5. Aucun `AppLogger` n'existe et au moins 34 appels Dart à `print()`/`debugPrint()` subsistent, dont des charges MQTT, un email, un UID et un corps de réponse Firestore.
6. `.github/workflows/` est absent : aucun analyseur, test ou APK automatique.
7. Aucun test `integration_test` ni scénario bout en bout n'existe.
8. Aucun APK Release ni rapport MobSF n'existe. La configuration Release utilise encore la clé de signature Debug (`android/app/build.gradle:36-40`).
9. Les règles Firestore isolent les pronostics en lecture, mais leur propriétaire peut modifier tous leurs champs sauf `authorUid`, donc aussi `result` (`firestore.rules:44-57`). Un client modifié peut falsifier ses victoires et statistiques.
10. Les topics MQTT globaux et l'identifiant client Flutter fixe ne séparent pas les utilisateurs/appareils. Les ACL HiveMQ ne sont pas présentes dans le dépôt et ne peuvent pas être confirmées.

## 3. Ce que le PDF exige explicitement

| Élément du PDF | Nature | Pages |
|---|---|---:|
| Ne pas utiliser de mot de passe par défaut ; conserver l'intégrité des mises à jour | Exigence sécurité IoT / cadre ETSI | 4 |
| Réserver `shared_preferences` aux préférences non sensibles | Règle explicite | 5 |
| Utiliser `flutter_secure_storage` et un `SecureVaultService` | TP obligatoire | 6, 7, 10 |
| Stocker le mot de passe HiveMQ dans le coffre-fort | TP obligatoire MQTT | 10 |
| MQTT TLS, port 8883, magasin de certificats système | TP obligatoire MQTT | 8, 10 |
| Rejeter un certificat invalide ; ne jamais contourner sa validation | Exigence explicite | 8, 10 |
| Construire un binaire Release et l'auditer avec MobSF | Exercice d'audit | 11 à 14 |
| Rechercher les secrets dans `libapp.so` avec `strings` | Exercice d'audit Flutter | 14 |
| Créer `AppLogger`, couper les logs en Release et masquer les secrets | TP obligatoire | 15 à 17 |
| Remplacer tous les `print()` résiduels | TP obligatoire | 17 |
| Tester un secret JSON et vérifier `password=***` | TP obligatoire | 17 |
| Tester automatiquement à chaque commit avec GitHub Actions | Objectif de séance/TP 3 annoncé | 2 |
| OTA A/B, signature et rollback | Modèle de sécurité si une OTA est proposée | 3, 4, 9 |

### Recommandations supplémentaires de cet audit

Les points suivants ne sont pas détaillés comme TP dans les 17 pages, mais découlent des risques constatés : Firebase App Check, custom claims administrateur, validation de schéma Firestore, séparation des profils publics/privés, ACL MQTT par utilisateur/appareil, identifiants client uniques, désactivation du trafic HTTP clair, signature Release privée, rotation des secrets exposés, Secure Boot/Flash Encryption sur ESP32 et tests d'intégration automatisés.

## 4. Audit détaillé

### 4.1 Sécurité des secrets

#### `flutter_secure_storage` et coffre-fort

**Statut : NON CONFORME — CRITIQUE**

- `pubspec.yaml:30-44` liste les dépendances, sans `flutter_secure_storage`.
- Aucun fichier `lib/core/security/secure_vault_service.dart` ni classe équivalente n'existe.
- `android/app/build.gradle:30` utilise `minSdk = 21`, alors que le TP indique `minSdkVersion >= 23` pour cette mise en œuvre.
- `lib/services/mqtt_service.dart:21-24` lit directement l'utilisateur et le mot de passe MQTT depuis `dotenv`.

#### Présence de secrets dans l'APK

**Statut : NON CONFORME — CRITIQUE, preuve binaire obtenue**

- `pubspec.yaml:68-69` déclare `.env` comme asset Flutter.
- `lib/main.dart:20-22` charge ce fichier au démarrage.
- L'APK existant `build/app/outputs/flutter-apk/app-debug.apk` contient une entrée `assets/flutter_assets/.env`.
- Une comparaison binaire, sans affichage des valeurs, confirme dans cet asset la présence de `API_FOOTBALL_KEY`, `MQTT_HOST`, `MQTT_PORT`, `MQTT_USER`, `MQTT_PASSWORD` et `ADMIN_EMAIL`.
- Aucun APK Release n'existe : la fuite est confirmée en Debug et très probablement reproductible en Release tant que `.env` reste un asset.

Un fichier `.env` ignoré par Git évite sa publication dans le dépôt, mais **n'empêche pas son inclusion dans l'APK**.

#### Secrets dans Git

**Statut : PARTIEL — IMPORTANT**

Points positifs :

- `.gitignore:1-2` ignore `.env`.
- `.gitignore:50-55` ignore les fichiers ESP32 de credentials.
- `.env`, `include/credentials.h` et `esp32/include/credentials.h` ne sont pas suivis actuellement et n'apparaissent pas dans l'historique sous ces chemins.
- `.env.example:1-5` et `include/credentials.h.example:3-11` utilisent des valeurs factices.
- La recherche des valeurs actuelles n'a pas retrouvé le mot de passe MQTT ni la clé API Football dans l'historique Git.

Limites :

- `android/app/google-services.json:1-29` et `lib/firebase_options.dart:55-60` contiennent la configuration cliente Firebase. La clé API Firebase cliente n'est normalement pas un secret d'autorisation ; ce sont les règles Firebase qui assurent la sécurité. Elle doit néanmoins être restreinte côté Google Cloud quand cela est possible.
- Aucun outil spécialisé comme Gitleaks/TruffleHog n'est intégré à la CI.

#### Secrets dans le firmware ESP32

**Statut : NON CONFORME — CRITIQUE**

- `src/main.cpp:9` et `esp32/src/main.cpp:9` incluent `credentials.h`.
- `src/main.cpp:309-312` et `esp32/src/main.cpp:138-141` transmettent les identifiants statiques au broker.
- Les firmwares existants `.pio/build/esp32dev/firmware.bin` et `.pio/build/wokwi/firmware.bin` contiennent réellement le mot de passe, l'utilisateur et l'hôte MQTT.
- Le firmware `esp32dev` contient aussi le SSID et le mot de passe Wi-Fi.

Les fichiers sources de credentials ne sont pas versionnés, ce qui est positif, mais leurs valeurs sont nécessairement intégrées au binaire actuel. Un accès physique ou un dump de flash peut donc les révéler.

#### Séparation préférences/données confidentielles

**Statut : PARTIEL — IMPORTANT**

- `lib/storage/preferences_service.dart:17-24` réserve bien une clé au thème, donnée non sensible.
- Le même service propose toutefois de stocker des pronostics dans `SharedPreferences` (`lib/storage/preferences_service.dart:3-15`), contrairement à la règle de la page 5.
- Ce service semble actuellement inutilisé ; les pronostics actifs sont dans Firestore et le cache Hive ne contient que les matchs (`lib/services/cache_service.dart:5-67`).
- Aucun stockage sécurisé n'existe pour les secrets.

### 4.2 Sécurité réseau

#### Flutter vers HiveMQ

**Statut : PARTIEL — IMPORTANT**

Preuves positives :

- Port par défaut 8883 : `lib/services/mqtt_service.dart:21-22`.
- TLS activé : `lib/services/mqtt_service.dart:28-30`.
- Magasin de confiance système : `SecurityContext.defaultContext`, ligne 30.
- Authentification utilisateur/mot de passe : `lib/services/mqtt_service.dart:37-40`.
- Reconnexion automatique : `lib/services/mqtt_service.dart:31-35`.

Limites :

- Le code ne fixe pas explicitement `onBadCertificate = (_) => false` comme demandé dans le PDF. Dans la version locale de `mqtt_client`, le callback reste `null` par défaut, ce qui laisse `SecureSocket` refuser normalement les certificats invalides. Aucun test avec faux certificat n'a cependant été exécuté.
- Le port vient de `.env` et n'est pas forcé à 8883 ; `secure` reste vrai, mais la configuration n'échoue pas explicitement si un autre port est fourni.
- L'identifiant client fixe `MatiMatch_Flutter` (`lib/services/mqtt_service.dart:28,38`) provoquera des déconnexions croisées si plusieurs instances se connectent avec le même identifiant.

#### ESP32 vers HiveMQ

**Statut : NON CONFORME — CRITIQUE**

- Le transport utilise bien `WiFiClientSecure` (`src/main.cpp:2-3,30-31`) et le port 8883 vient du fichier de credentials modèle (`include/credentials.h.example:8-11`).
- Mais `espClient.setInsecure()` désactive l'authentification du serveur (`src/main.cpp:381-382`, `esp32/src/main.cpp:177-178`).
- La connexion peut donc être chiffrée tout en restant vulnérable à un attaquant Man-in-the-Middle présentant son propre certificat.
- La documentation reconnaît ce contournement (`docs/dossier-technique.md:53`) alors que la grille le marque conforme (`docs/grille-evaluation.md:71`). Pour la séance 12, ce point est explicitement non conforme.

#### Autorisations MQTT

**Statut : NON VÉRIFIÉ — CRITIQUE**

- L'authentification est visible des deux côtés (`lib/services/mqtt_service.dart:37-40`, `src/main.cpp:309-313`).
- Aucune configuration ACL HiveMQ Cloud n'est présente dans le dépôt : impossible de confirmer les droits réels de publication/abonnement.
- Les topics `match`, `prediction`, `status` et `button` sont globaux (`lib/repositories/mqtt_repository.dart:14-19`, `src/main.cpp:33-36`). Avec des identifiants partagés ou des ACL larges, un utilisateur peut recevoir/publier les messages d'un autre.
- Seul le partage utilise un topic ciblé `matimatch/device/{deviceId}/prediction` (`lib/repositories/mqtt_repository.dart:105-118`). Le `deviceId` est dérivé de la MAC (`src/main.cpp:38-48`) et lisible dans les profils Firestore par tout utilisateur authentifié.

#### Firebase et API de football

**Statut : PARTIEL — CRITIQUE pour la clé API**

- Tous les endpoints visibles sont HTTPS : API de football (`lib/services/football_api_service.dart:9-18`), contrôle de connectivité (`:11-12`) et REST Firestore (`lib/services/firestore_service.dart:77-87`).
- Firebase SDK utilise son canal sécurisé et la vérification REST envoie un jeton Firebase Bearer (`lib/services/firestore_service.dart:71-87`).
- Aucun contournement TLS n'est visible dans le code Dart HTTP.
- La clé de l'API de football est néanmoins distribuée dans l'APK (`lib/services/football_api_service.dart:14-18` et asset `.env`). `flutter_secure_storage` protégerait une valeur provisionnée après installation, mais ne peut pas rendre secrète une clé que chaque APK doit recevoir. Une passerelle serveur est nécessaire.
- `android/app/src/main/AndroidManifest.xml:7` autorise globalement le trafic HTTP en clair. Les URLs actuelles sont HTTPS, mais cette option affaiblit la politique réseau de l'application.

### 4.3 Sécurité Firebase

#### Règles et isolation des pronostics

**Statut : PARTIEL — IMPORTANT**

Points conformes :

- Règles Firestore versionnées : `firebase.json:21-23`, `firestore.rules:1-193`.
- Lecture d'un pronostic limitée à son propriétaire ou à l'admin : `firestore.rules:24-35`.
- `authorUid` est imposé à la création et rendu immuable : `firestore.rules:32-46`.
- Les requêtes clientes filtrent par UID : `lib/services/firestore_service.dart:15-40`.
- Les pronostics reçus ne sont lisibles que par leur destinataire : `firestore.rules:154-159`.
- Le partage vérifie l'identité de l'expéditeur et l'amitié : `firestore.rules:161-186`.
- 64 scénarios de règles Firebase Emulator sont écrits dans `test/emulator/firestore.rules.test.js`, mais ils n'ont pas été exécutés pendant cet audit.

Faiblesse d'intégrité :

- Le propriétaire peut modifier tous les champs de son pronostic sauf `authorUid` (`firestore.rules:44-57`). Il peut donc changer `result`, `odds`, `stake`, `selection`, `fixtureId` ou `kickoffUtc` avec un client modifié.
- La création n'impose ni schéma, ni `result == null`, ni plage de confiance, ni date serveur (`firestore.rules:34-35`).
- Les statistiques reposent ensuite directement sur ces données (`lib/models/prediction.dart:30-35`, `lib/screens/profile_screen.dart:28-43`).

#### Comptes et profils

**Statut : PARTIEL — IMPORTANT**

- Firebase Authentication email/mot de passe est bien utilisé (`lib/services/auth_service.dart:12-32`).
- Les écrans masquent visuellement le mot de passe (`lib/screens/login_screen.dart:105-115`, `lib/screens/register_screen.dart:84-108`).
- Les profils ne peuvent être créés/modifiés que par leur propriétaire et UID/email restent cohérents (`firestore.rules:75-102`).
- En revanche, tout utilisateur authentifié peut lire tous les documents `users`, y compris email et `deviceId` (`firestore.rules:77-79`, modèle `lib/models/user_profile.dart:28-40`). Cette règle facilite la recherche d'amis, mais expose plus de données que nécessaire.
- Aucune vérification d'email, MFA, App Check, limitation métier des tentatives ou politique de suppression de compte n'est visible. Ce sont des recommandations supplémentaires, pas les TP explicites du PDF.

#### Droits administrateur

**Statut : PARTIEL — IMPORTANT**

- Le vrai contrôle serveur est dans les règles Firestore et compare un UID (`firestore.rules:5-11`). Il ne dépend donc pas uniquement de l'interface Flutter.
- L'interface détermine toutefois l'admin avec une adresse email extraite de `.env` (`lib/viewmodels/auth_view_model.dart:11-18`). Cette donnée est extractible de l'APK.
- Les deux mécanismes peuvent diverger : l'interface peut montrer ou masquer des boutons sans correspondre à l'UID autorisé par Firestore.
- Un UID codé en dur est difficile à faire évoluer. Des custom claims Firebase contrôlés côté serveur seraient plus robustes.

### 4.4 Audit de sécurité et binaire

#### APK Release

**Statut : NON VÉRIFIÉ — IMPORTANT**

- Seul un APK Debug existe dans `build/app/outputs/` ; aucun `app-release.apk` n'a été trouvé.
- Le build Release n'a pas été lancé.
- La configuration Release signe encore avec la clé Debug (`android/app/build.gradle:36-40`). Ce n'est pas une configuration de livraison acceptable.
- Aucun `minifyEnabled`, `shrinkResources` ou mécanisme d'obfuscation/symboles séparés n'est configuré. Ce sont des durcissements supplémentaires ; ils ne remplacent jamais la suppression des secrets.

#### Permissions Android

**Statut : PARTIEL — IMPORTANT**

- Permission principale visible : `INTERNET` (`android/app/src/main/AndroidManifest.xml:1-2`). Elle est nécessaire à Firebase, HTTPS et MQTT.
- Aucun accès localisation, caméra, micro, stockage ou Bluetooth n'est demandé dans le manifeste principal.
- `android:usesCleartextTraffic="true"` est inutile pour les endpoints actuels et doit être supprimé ou mis à `false` (`AndroidManifest.xml:3-7`).
- `MainActivity` est exportée pour le launcher (`AndroidManifest.xml:8-28`), ce qui est normal.
- Le manifeste ne fixe pas explicitement `allowBackup=false`; une vérification du manifeste fusionné Release serait nécessaire.

#### Recherche binaire de secrets

**Statut : NON CONFORME — CRITIQUE**

- APK Debug : `.env` et toutes ses valeurs configurées sont présents.
- Firmware `esp32dev` : identifiants MQTT et Wi-Fi présents.
- Firmware `wokwi` : identifiants MQTT présents.
- Aucun `libapp.so` Release n'existe ; la commande `strings` du PDF ne peut donc pas être validée sur une version Release.

#### MobSF et protections natives

**Statut : NON VÉRIFIÉ — IMPORTANT**

- Aucun rapport MobSF n'est présent.
- Docker est installé mais son moteur était indisponible ou arrêté lors du contrôle.
- Aucun scan MobSF n'a été lancé.
- Sans APK Release et sans `libapp.so` Release, les protections NX, PIE, canary, symbol stripping et autres éléments de la page 13 n'ont pas été vérifiés.

#### OTA ESP32

**Statut : NON VÉRIFIÉ (fonctionnalité absente) — AMÉLIORATION**

- Aucune utilisation d'`ArduinoOTA`, `Update`, `HTTPUpdate`, partition A/B, signature ou rollback n'a été trouvée dans `src/`, `esp32/src/` ou les fichiers PlatformIO.
- Il n'existe donc pas actuellement de surface OTA à auditer.
- Si l'OTA est ajoutée, les pages 4 et 9 imposent signature, partition inactive et rollback vérifié.

### 4.5 Observabilité

#### Logger centralisé et logs Release

**Statut : NON CONFORME — CRITIQUE**

- Aucun `lib/core/logger/app_logger.dart`, `AppLogger` ou `LogLevel` n'existe.
- Au moins 34 appels Dart à `print()`/`debugPrint()` ont été trouvés.
- Un `print()` explicitement ignoré par le linter subsiste dans `lib/models/football_match.dart:105-106`.
- Les `debugPrint()` ne sont pas protégés par `kReleaseMode`; ils ne répondent donc pas à la règle « aucun log en Release » du PDF.

#### Données sensibles dans les logs

**Statut : NON CONFORME — CRITIQUE**

Exemples :

- Payload MQTT complet reçu : `lib/repositories/mqtt_repository.dart:47-55`.
- Payloads de match/pronostic/partage envoyés : `lib/repositories/mqtt_repository.dart:63-87,105-118`.
- UID et email Firebase : `lib/viewmodels/predictions_view_model.dart:58-60`.
- Corps complet de la réponse REST Firestore : `lib/services/firestore_service.dart:84-93`.
- UIDs, noms et `deviceId` : `lib/services/social_service.dart:24-67,121-138`, `lib/services/user_service.dart:11-49`.
- Payload MQTT complet sur le port série ESP32 : `src/main.cpp:218-224`.

Un message MQTT contenant `{"password":"..."}` serait logué sans masque.

#### Test de masquage JSON

**Statut : NON CONFORME — IMPORTANT**

- Aucun test contenant `AppLogger`, `password=***` ou le crash-test `monSuperSecret` n'existe.
- Aucun mécanisme de sanitization n'est présent.

### 4.6 CI/CD et industrialisation

#### GitHub Actions

**Statut : NON CONFORME — IMPORTANT**

- `.github/workflows/` est absent.
- Aucun déclenchement sur `push`/`pull_request`.
- Aucun `flutter analyze`, `flutter test`, test de règles Firebase, build APK ou build PlatformIO automatique.
- Aucun contrôle de secrets ou audit de dépendances automatique.

#### Tests et build dans le pipeline

**Statut : NON CONFORME — IMPORTANT**

- `docs/grille-evaluation.md:101` affirme « flutter analyze 0 erreur », mais aucun journal ou workflow ne permet de vérifier cette affirmation, et le code comporte depuis des modifications locales.
- Le test widget est encore le test compteur du template (`test/widget_test.dart:13-29`) alors que MatiMatch n'est pas une application compteur ; il est très probablement obsolète.
- Les tests Dart présents sont surtout des tests de modèles et des simulations de règles. Le test MQTT ne teste qu'un retour silencieux hors connexion (`test/mqtt_publish_guard_test.dart:11-39`).
- Les tests Firebase Emulator sont substantiels, mais ne sont pas appelés par une CI (`test/emulator/package.json:5-11`).

#### Documentation de livraison

**Statut : PARTIEL — AMÉLIORATION**

- `README.md:53-107` explique l'installation, les fichiers de configuration, le lancement Flutter et le build PlatformIO.
- Il ne documente pas une livraison Release signée, le versionnement, les secrets CI, MobSF, le déploiement des règles Firebase, la distribution de l'APK, le rollback ou une checklist de validation.

### 4.7 Tests de bout en bout

Le dépôt contient 89 cas de tests Dart détectés et 64 tests de règles Firestore Emulator, mais aucun dossier `integration_test/` ni `test_driver/`. Aucun scénario ne traverse réellement Flutter → Firebase/API → HiveMQ → ESP32/OLED → bouton → Flutter.

| Parcours demandé | Statut | Preuve existante | Manque principal |
|---|---|---|---|
| Connexion utilisateur | NON CONFORME | Implémentation `login_screen.dart:27-38`, `auth_service.dart:12-21` | Aucun test d'intégration Firebase Auth/UI |
| Chargement des matchs | NON CONFORME | `football_repository.dart:20-47`, `matches_view_model.dart:13-20` | Aucun test HTTP/cache/UI réel |
| Création d'un pronostic | NON CONFORME | `add_prediction_screen.dart:90-139` | Aucun test formulaire → Firestore → UI |
| Partage d'un pronostic | NON CONFORME | `add_prediction_screen.dart:143-228`, `social_service.dart:98-140` | Aucun test multi-utilisateurs + Firestore + MQTT |
| Réception MQTT par ESP32 | NON CONFORME | `src/main.cpp:218-300` | Aucun broker de test ni assertion firmware |
| Affichage OLED | NON CONFORME | `src/main.cpp:76-215` | Aucun test visuel/automatisé Wokwi |
| Bouton ESP32 vers Flutter | NON CONFORME | `src/main.cpp:413-419`, `mqtt_repository.dart:95-98`, `match_detail_screen.dart:601-624` | Aucun test de la chaîne complète |
| Déconnexion/reconnexion | NON CONFORME | Flutter `mqtt_service.dart:31-35,91-97`; ESP32 `src/main.cpp:395-411` | Aucun test de coupure broker/Wi-Fi et reprise |

## 5. Tableau de conformité global

| Exigence du cours | Statut | Preuve dans le code/artefact | Ce qui manque | Priorité |
|---|---|---|---|---|
| `flutter_secure_storage` | NON CONFORME | Absent de `pubspec.yaml:30-44` | Dépendance et configuration Android/iOS | CRITIQUE |
| `SecureVaultService` | NON CONFORME | Aucun service équivalent | Service, API de lecture/écriture/suppression | CRITIQUE |
| Mot de passe HiveMQ dans le coffre | NON CONFORME | `mqtt_service.dart:21-24` lit `.env` | Provisionnement puis lecture sécurisée | CRITIQUE |
| Secrets absents de l'APK | NON CONFORME | `.env` présent dans l'APK Debug | Retirer l'asset et faire tourner les secrets | CRITIQUE |
| Secrets absents de Git | PARTIEL | `.gitignore:1-2,50-55`, fichiers réels non suivis | Scanner spécialisé en CI ; restrictions de clés | IMPORTANT |
| Secrets absents du firmware | NON CONFORME | Credentials retrouvés dans les deux `.bin` | Provisionnement/NVS chiffré/secure boot | CRITIQUE |
| SharedPreferences non sensible uniquement | PARTIEL | Thème lignes 17-24, mais pronostics lignes 3-15 | Supprimer l'API de stockage des pronostics ou documenter son abandon | IMPORTANT |
| MQTT Flutter TLS/8883 | CONFORME | `mqtt_service.dart:21-30` prouve l'activation TLS, le port par défaut et le magasin système | Test réseau réel encore souhaitable | IMPORTANT |
| Rejet strict certificat Flutter | PARTIEL | Contexte système, aucun callback permissif | Rejet explicite + test faux certificat | IMPORTANT |
| Rejet strict certificat ESP32 | NON CONFORME | `setInsecure()` dans les deux firmwares | CA racine/pinning contrôlé | CRITIQUE |
| HTTPS Firebase/API | PARTIEL | URLs HTTPS et Bearer Firebase | Retirer clé API de l'APK, App Check, interdire cleartext | CRITIQUE |
| Authentification MQTT | CONFORME | `mqtt_service.dart:37-40` et `src/main.cpp:309-313` passent bien des identifiants au broker | Test réel et rotation credentials encore nécessaires | IMPORTANT |
| Autorisations/ACL MQTT | NON VÉRIFIÉ | Aucune config HiveMQ dans le dépôt | ACL minimales et topics isolés | CRITIQUE |
| Règles Firestore présentes | CONFORME | `firebase.json:21-23` référence `firestore.rules:1-193` | Vérifier leur déploiement réel | IMPORTANT |
| Isolation lecture des pronostics | CONFORME | `firestore.rules:24-35` impose propriétaire ou admin et le client filtre l'UID | Exécuter les tests Emulator sur la version déployée | IMPORTANT |
| Intégrité des pronostics/résultats | NON CONFORME | Propriétaire modifie tous les champs sauf UID | Schéma, immutabilité, résultat serveur | IMPORTANT |
| Contrôle admin côté serveur | PARTIEL | UID dans `firestore.rules:5-11` | Custom claim et alignement UI/serveur | IMPORTANT |
| Protection des profils | PARTIEL | Écriture propriétaire, lecture globale authentifiée | Séparer données publiques/privées | IMPORTANT |
| APK Release constructible | NON VÉRIFIÉ | Aucun APK Release | Lancer le build et corriger si nécessaire | IMPORTANT |
| Signature Release | NON CONFORME | Signature Debug `build.gradle:36-40` | Keystore Release protégé | IMPORTANT |
| Permissions Android minimales | PARTIEL | Seulement INTERNET | Supprimer `usesCleartextTraffic=true`, vérifier manifeste fusionné | IMPORTANT |
| Audit MobSF | NON VÉRIFIÉ | Aucun rapport | Build Release + scan MobSF | IMPORTANT |
| Protections natives | NON VÉRIFIÉ | Aucun `libapp.so` Release audité | MobSF et outils binaires | IMPORTANT |
| OTA signée A/B | NON VÉRIFIÉ | OTA absente | À appliquer uniquement si OTA ajoutée | AMÉLIORATION |
| `AppLogger` centralisé | NON CONFORME | Classe absente | Implémenter logger assaini | CRITIQUE |
| Aucun `print()` résiduel | NON CONFORME | 34+ appels ; `football_match.dart:105-106` | Remplacer tous les logs Dart | CRITIQUE |
| Logs sensibles masqués | NON CONFORME | Payloads, email, UID, corps REST logués | Sanitization et réduction des données | CRITIQUE |
| Logs coupés en Release | NON CONFORME | Aucun `kReleaseMode` central | Coupure vérifiée sur APK Release | CRITIQUE |
| Test JSON de masquage | NON CONFORME | Aucun test | Test unitaire attendu `password=***` | IMPORTANT |
| GitHub Actions | NON CONFORME | `.github/workflows` absent | Workflow `push`/`pull_request` | IMPORTANT |
| `flutter analyze` automatique | NON CONFORME | Aucun workflow | Job bloquant | IMPORTANT |
| `flutter test` automatique | NON CONFORME | Aucun workflow | Job bloquant, corriger test template | IMPORTANT |
| APK automatique | NON CONFORME | Aucun workflow | Build Release/artefact | IMPORTANT |
| Gestion des échecs | NON CONFORME | Aucun pipeline | Statuts bloquants, logs et artefacts | IMPORTANT |
| Documentation livraison | PARTIEL | Installation dans `README.md:53-107` | Procédure Release complète | AMÉLIORATION |
| Tests bout en bout | NON CONFORME | Aucun `integration_test/` | Les huit parcours demandés | IMPORTANT |

## 6. Points positifs à défendre en soutenance

- Architecture lisible avec séparation des responsabilités (`lib/models`, `services`, `repositories`, `viewmodels`, `screens`).
- Firebase Authentication réellement utilisé, pas simulé (`lib/services/auth_service.dart`).
- Règles Firestore détaillées et tests Emulator nombreux.
- Isolation en lecture des pronostics et vérification d'amitié lors du partage.
- MQTT Flutter chiffré avec le magasin de certificats système.
- QoS 1 côté publication Flutter, LWT et reconnexion.
- Cache Hive avec TTL de 30 minutes et repli sur cache périmé (`cache_service.dart:5-67`, `football_repository.dart:20-47`).
- Identifiant ESP32 dérivé de la MAC et topic ciblé pour un appareil.
- Chaîne fonctionnelle bidirectionnelle prévue : Flutter publie, ESP32 affiche, bouton ESP32 publie, Flutter affiche l'événement.

Il faut cependant présenter honnêtement que la conformité Séance 12 n'est pas encore finalisée.

## 7. Plan d'action priorisé

### Priorité 0 — mesures immédiates après exposition

1. **Faire tourner les secrets déjà présents dans les artefacts.**
   - Fichiers concernés : `.env`, `include/credentials.h` et consoles API/HiveMQ.
   - Changement : révoquer l'ancien mot de passe HiveMQ et l'ancienne clé API, créer de nouvelles valeurs avec droits minimaux.
   - Vérification : les anciens credentials doivent échouer ; ne jamais imprimer les nouveaux.

2. **Retirer `.env` des assets Flutter.**
   - Fichiers : `pubspec.yaml:68-69`, `lib/main.dart:20-22`, services consommant `dotenv`.
   - Changement : ne plus embarquer les secrets. Garder uniquement des paramètres non sensibles ou utiliser un mécanisme de provisionnement.
   - Vérification : construire un APK Release, lister son archive et confirmer l'absence de `assets/flutter_assets/.env`; rechercher chaque secret par nom/empreinte sans afficher sa valeur.

3. **Supprimer le contournement TLS ESP32.**
   - Fichiers : `src/main.cpp:381-382`, `esp32/src/main.cpp:177-178`.
   - Changement : charger la CA racine HiveMQ avec `setCACert()` ou une stratégie de pinning maintenable ; ne jamais utiliser `setInsecure()`.
   - Vérification : connexion réussie avec le certificat valide et échec obligatoire avec un serveur/certificat frauduleux.

### Priorité 1 — obligations directes de la séance 12

4. **Créer le coffre-fort local.**
   - Fichiers : `pubspec.yaml`, `android/app/build.gradle`, nouveau `lib/core/security/secure_vault_service.dart`, `lib/services/mqtt_service.dart`.
   - Changement : ajouter `flutter_secure_storage`, passer le minSdk au niveau requis, stocker/lire/supprimer le mot de passe MQTT via le coffre.
   - Vérification : test unitaire du service, absence dans SharedPreferences et dans l'APK, connexion MQTT après provisionnement.

5. **Ne pas traiter la clé API Football comme un secret client stockable.**
   - Fichiers : `lib/services/football_api_service.dart`, nouvelle passerelle serveur/Cloud Function.
   - Changement : l'application appelle un backend authentifié ; le backend détient la clé API. Ajouter quotas et App Check.
   - Vérification : aucune clé fournisseur dans l'APK ; requête refusée sans utilisateur/App Check valide.

6. **Créer `AppLogger` et assainir tous les logs.**
   - Fichiers : nouveau `lib/core/logger/app_logger.dart`, tous les fichiers listés en section 4.5.
   - Changement : couper les logs en Release, masquer `password`, `token`, `secret`, `pwd` et Bearer, éviter les payloads/PII complets.
   - Vérification : test JSON du PDF, recherche `rg -n "print\\s*\\(|debugPrint\\s*\\(" lib`, puis contrôle Logcat Debug et Release.

7. **Ajouter GitHub Actions.**
   - Fichier : nouveau `.github/workflows/ci.yml`.
   - Changement : jobs bloquants pour format/analyse, tests Flutter, tests Firebase Emulator, build APK Release et éventuellement build PlatformIO.
   - Vérification : ouvrir une pull request volontairement fautive, confirmer l'échec ; corriger et confirmer le passage au vert.

8. **Construire et auditer le Release.**
   - Fichiers : `android/app/build.gradle`, fichiers de signature ignorés, documentation.
   - Changement : keystore Release distinct, build, inspection archive, `strings` sur `libapp.so`, MobSF.
   - Vérification : rapport MobSF archivé, absence de secrets, permissions attendues, protections natives documentées.

### Priorité 2 — intégrité et isolation

9. **Durcir Firestore.**
   - Fichiers : `firestore.rules`, `test/emulator/firestore.rules.test.js`.
   - Changement : imposer le schéma et les plages, `result == null` à la création, rendre les champs métier immuables, réserver `result` à une fonction serveur/admin avec custom claim.
   - Vérification : ajouter des tests négatifs de falsification de résultat/cote/mise/date, puis exécuter Firebase Emulator.

10. **Séparer les profils publics et privés.**
    - Fichiers : `firestore.rules`, `user_service.dart`, modèles Firestore.
    - Changement : ne pas exposer `deviceId` et email dans une collection lisible globalement ; utiliser un index public minimal ou une recherche serveur.
    - Vérification : Alice trouve Bob avec le flux prévu, mais ne peut pas lire son `deviceId` ni ses champs privés.

11. **Mettre en place des ACL MQTT par identité et des topics isolés.**
    - Fichiers : `mqtt_repository.dart`, `mqtt_service.dart`, `src/main.cpp`, configuration HiveMQ Cloud externe.
    - Changement : namespace par utilisateur/appareil, credentials distincts, lecture/écriture minimales, client ID Flutter unique.
    - Vérification : un compte A ne peut ni lire ni publier sur les topics de B ; deux téléphones restent connectés simultanément.

12. **Interdire le trafic clair Android.**
    - Fichier : `android/app/src/main/AndroidManifest.xml:3-7`.
    - Changement : supprimer l'attribut ou utiliser `android:usesCleartextTraffic="false"` avec une configuration réseau restrictive.
    - Vérification : tous les services HTTPS/MQTTS fonctionnent ; une URL HTTP de test est refusée.

### Priorité 3 — qualité, tests et livraison

13. **Corriger le test widget du template.**
    - Fichier : `test/widget_test.dart:13-29`.
    - Changement : remplacer le scénario compteur par un test MatiMatch avec Firebase/providers simulés.
    - Vérification : `flutter test` passe réellement.

14. **Ajouter les tests bout en bout.**
    - Fichiers : nouveau dossier `integration_test/`, environnement Firebase Emulator, broker MQTT de test et scénario Wokwi documenté.
    - Changement : couvrir connexion, matchs, création, partage, MQTT, OLED, bouton et reconnexion.
    - Vérification : rapport horodaté et captures/logs assainis pour chaque étape.

15. **Documenter la livraison.**
    - Fichiers : `README.md` ou nouveau `docs/release.md`.
    - Changement : version, secrets CI, signature, analyse/test/build, règles Firebase, audit MobSF, publication et rollback.
    - Vérification : une autre personne doit pouvoir produire le même artefact à partir d'un clone propre.

16. **Réduire la duplication firmware.**
    - Fichiers : projet racine `src/`/`platformio.ini` et sous-projet `esp32/`.
    - Changement : désigner une seule source officielle ou expliquer clairement les variantes. Aujourd'hui les écrans SH1107 et SSD1306 et les fonctionnalités diffèrent.
    - Vérification : Wokwi et le build physique utilisent la version documentée.

17. **Préparer la sécurité du matériel physique.**
    - Fichiers/configuration ESP32 : partition, NVS, eFuse et procédure de provisionnement.
    - Changement : credentials uniques par appareil, NVS chiffré, Secure Boot et Flash Encryption si le matériel réel le permet.
    - Vérification : dump de flash ne révélant pas les secrets en clair et appareil refusant un firmware non signé.

18. **Si une OTA est ajoutée, imposer A/B signé et rollback.**
    - Fichiers futurs : table de partitions et module OTA.
    - Changement : téléchargement HTTPS strict, signature, partition inactive, validation de démarrage et rollback watchdog.
    - Vérification : firmware valide accepté, firmware altéré rejeté, panne au démarrage restaurée automatiquement.

## 8. Conclusion

La base applicative et fonctionnelle est sérieuse, mais les exigences centrales de la séance 12 restent à implémenter. La première démonstration à faire après correction est simple : aucun secret dans l'APK, certificat frauduleux rejeté par Flutter et l'ESP32, log JSON masqué, pipeline GitHub vert, puis rapport MobSF du Release. Tant que ces preuves n'existent pas, il ne faut pas annoncer une conformité complète.
