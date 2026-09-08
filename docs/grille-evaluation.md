# Grille d'évaluation — MatiMatch IoT

> Dernière mise à jour : 2026-09-08
> Règle : ✅ = réellement implémenté et vérifiable | ⚠️ = partiel | ❌ = absent

---

## 1. Architecture IoT

| Critère | Implémentation MatiMatch | Fichier / preuve | État |
|---------|--------------------------|------------------|------|
| Objet connecté simulé (ESP32) | Wokwi + PlatformIO | `PlatformIO/Projects/Matimatch/` | ✅ |
| Protocole IoT adapté | MQTT via PubSubClient | `src/main.cpp` | ✅ |
| Broker cloud | HiveMQ Cloud (gratuit) | `credentials.h`, `.env` | ✅ |
| Communication bidirectionnelle | Flutter ↔ ESP32 | Topics `match` et `button` | ✅ |
| Composant d'affichage | OLED SSD1306 128x64 I2C | `diagram.json`, `main.cpp` | ✅ |
| Composant d'interaction | Bouton GPIO 15 | `diagram.json`, `main.cpp` | ✅ |

---

## 2. Protocole MQTT

| Critère | Implémentation MatiMatch | Fichier / preuve | État |
|---------|--------------------------|------------------|------|
| MQTT TLS (port 8883) | `WiFiClientSecure`, port 8883 | `main.cpp`, `mqtt_service.dart` | ✅ |
| Subscribe (ESP32) | `matimatch/device/match` | `main.cpp` l.116 | ✅ |
| Publish (ESP32) | `matimatch/device/status`, `matimatch/device/button` | `main.cpp` | ✅ |
| Subscribe (Flutter) | `matimatch/device/status`, `matimatch/device/button` | `mqtt_repository.dart` | ✅ |
| Publish (Flutter) | `matimatch/device/match` | `mqtt_repository.dart:sendMatch()` | ✅ |
| QoS 1 | Tous les topics en QoS atLeastOnce | `main.cpp`, `mqtt_service.dart` | ✅ |
| Retain | `matimatch/device/status` retain=true | `main.cpp:mqttConnect()` | ✅ |
| LWT (Last Will Testament) | OFFLINE sur `matimatch/device/status` | `main.cpp:mqttConnect()` | ✅ |
| Reconnexion automatique ESP32 | Non-bloquante, toutes les 5 s | `main.cpp:loop()` | ✅ |
| Reconnexion automatique Flutter | `autoReconnect = true` | `mqtt_service.dart` | ✅ |

---

## 3. Application Flutter

| Critère | Implémentation MatiMatch | Fichier / preuve | État |
|---------|--------------------------|------------------|------|
| Architecture MVVM | Screen / ViewModel / Repository / Service | `lib/` | ✅ |
| Riverpod (gestion d'état) | `AsyncNotifier`, `StateProvider`, `Provider` | `viewmodels/` | ✅ |
| États loading / data / error | `AsyncValue.when(...)` dans tous les screens | `matches_screen.dart` | ✅ |
| Séparation UI / logique | Aucune logique réseau dans les widgets | Architecture | ✅ |
| Layer MQTT dédié | `mqtt_service.dart`, `mqtt_repository.dart`, `mqtt_provider.dart` | `lib/services/`, `lib/repositories/`, `lib/viewmodels/` | ✅ |
| Statut objet dans l'UI | Badge "Objet connecté / hors ligne" | `matches_screen.dart:_DeviceStatusBadge` | ✅ |
| Envoi d'un match à l'OLED | Section "MatiMatch Display" dans le détail match | `match_detail_screen.dart:_MatiMatchDisplay` | ✅ |
| Réception événement bouton | `buttonEventProvider` + affichage dans l'UI | `mqtt_provider.dart`, `match_detail_screen.dart` | ✅ |

---

## 4. Offline-first

| Critère | Implémentation MatiMatch | Fichier / preuve | État |
|---------|--------------------------|------------------|------|
| Cache local (Hive) | Matchs du jour, TTL 30 min | `cache_service.dart` | ✅ |
| Fallback cache si API échoue | Cache expiré utilisé si API timeout/erreur | `football_repository.dart:getMatchesForDate()` | ✅ |
| Timeout réseau | 10 secondes sur tous les `http.get` | `football_api_service.dart` | ✅ |
| Indicateur données périmées | Bannière orangée "Données en cache — il y a X min" | `matches_screen.dart:_CacheBanner` | ✅ |
| Bouton Réessayer | Dans la bannière cache ET dans l'état d'erreur | `matches_screen.dart` | ✅ |
| Pull-to-refresh | `RefreshIndicator` avec invalidation du provider | `matches_screen.dart` | ✅ |
| Pas de crash sans réseau | Gestion `NoInternetException` | `football_api_service.dart`, `football_repository.dart` | ✅ |

---

## 5. Sécurité

| Critère | Implémentation MatiMatch | Fichier / preuve | État |
|---------|--------------------------|------------------|------|
| MQTT TLS | Port 8883, `setInsecure()` (Wokwi) / `SecurityContext` (Flutter) | `main.cpp`, `mqtt_service.dart` | ✅ |
| HTTPS pour l'API | `https://api.5dollarfootballapi.com` | `football_api_service.dart` | ✅ |
| Clé API hors Git (Flutter) | `.env` dans `.gitignore`, `.env.example` fourni | `.gitignore`, `.env.example` | ✅ |
| Credentials MQTT hors Git (ESP32) | `credentials.h` dans `.gitignore PlatformIO` | `.gitignore` PlatformIO | ✅ |
| Credentials MQTT hors Git (Flutter) | Dans `.env` (non commité) | `.env`, `.env.example` | ✅ |
| Firebase Auth | Email/password Firebase | `auth_service.dart` | ✅ |

---

## 6. ESP32 / Wokwi

| Critère | Implémentation MatiMatch | Fichier / preuve | État |
|---------|--------------------------|------------------|------|
| Code compilé sans erreur | `pio run` → SUCCESS | `platformio.ini`, `src/main.cpp` | ✅ |
| Connexion WiFi Wokwi-GUEST | `WiFi.begin("Wokwi-GUEST", "")` | `main.cpp` | ✅ |
| Connexion MQTT TLS HiveMQ | `WiFiClientSecure`, port 8883 | `main.cpp` | ✅ |
| Publication ONLINE + Retain | Au démarrage, après connexion | `main.cpp:mqttConnect()` | ✅ |
| LWT OFFLINE configuré | Lors de la connexion MQTT | `main.cpp:mqttConnect()` | ✅ |
| Subscribe au topic match | `matimatch/device/match` | `main.cpp:mqttConnect()` | ✅ |
| Callback MQTT + parsing JSON | `mqttCallback()` avec ArduinoJson | `main.cpp` | ✅ |
| Affichage OLED | Titre, équipes, heure / score | `main.cpp:showMatch()` | ✅ |
| Détection bouton + publication | GPIO 15, anti-rebond, publish JSON | `main.cpp:loop()` | ✅ |
| Reconnexion non-bloquante | `millis()` + délai 5 s | `main.cpp:loop()` | ✅ |

---

## 7. Qualité du code

| Critère | Implémentation MatiMatch | Fichier / preuve | État |
|---------|--------------------------|------------------|------|
| `flutter analyze` 0 erreur | Vérifié | — | ✅ |
| `pio run` SUCCESS | Vérifié | — | ✅ |
| `.gitignore` propre | `.env` et `credentials.h` exclus | `.gitignore` | ✅ |
| README à jour | Présentation, installation, architecture | `README.md` | ✅ |
| Documentation technique | Architecture, MQTT, offline-first, sécurité | `docs/dossier-technique.md` | ✅ |

---

## Résumé

| Catégorie | ✅ | ⚠️ | ❌ |
|-----------|----|----|-----|
| Architecture IoT | 6 | 0 | 0 |
| Protocole MQTT | 10 | 0 | 0 |
| Application Flutter | 8 | 0 | 0 |
| Offline-first | 7 | 0 | 0 |
| Sécurité | 6 | 0 | 0 |
| ESP32 / Wokwi | 10 | 0 | 0 |
| Qualité code | 5 | 0 | 0 |
| **Total** | **52** | **0** | **0** |
