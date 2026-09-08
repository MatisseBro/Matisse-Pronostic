# Dossier Technique — MatiMatch IoT

## 1. Architecture générale

```
Flutter (Android/iOS)
        ↕  MQTT TLS port 8883
HiveMQ Cloud (broker MQTT)
        ↕  MQTT TLS port 8883
ESP32 simulé dans Wokwi
  ├── Écran OLED SSD1306 (I2C)
  └── Bouton poussoir (GPIO 15)
```

L'application Flutter communique avec un objet connecté simulé (ESP32 dans Wokwi) via le protocole MQTT, en passant par le broker cloud HiveMQ. La communication est bidirectionnelle :

- **Flutter → ESP32** : envoyer un match à afficher sur l'écran OLED
- **ESP32 → Flutter** : notifier qu'un bouton a été pressé

---

## 2. Pourquoi MQTT ?

MQTT (Message Queuing Telemetry Transport) est le protocole de référence pour l'IoT car :

- **Léger** : headers minuscules, parfait pour les microcontrôleurs avec peu de RAM
- **Publish/Subscribe** : découplage entre producteur et consommateur — l'ESP32 n'a pas besoin de connaître l'adresse IP de Flutter
- **Fiable** : niveaux de QoS (0, 1, 2) pour garantir la livraison
- **Retain** : le broker conserve le dernier message d'un topic — utile pour connaître l'état de l'objet même si Flutter se connecte après l'ESP32
- **LWT** (Last Will Testament) : le broker publie automatiquement un message prédéfini si l'ESP32 se déconnecte de façon brutale

HTTP aurait nécessité un serveur sur l'ESP32 et aurait consommé plus de ressources. MQTT est beaucoup plus adapté aux contraintes IoT.

---

## 3. Pourquoi HiveMQ ?

HiveMQ Cloud propose un plan gratuit avec :
- Broker MQTT managé (pas besoin d'installer Mosquitto)
- TLS/SSL sur le port 8883
- Interface web pour monitorer les messages (MQTT Explorer intégré)
- Support MQTT 3.1.1 et 5.0

---

## 4. Pourquoi TLS ?

TLS (Transport Layer Security) chiffre les communications entre l'ESP32/Flutter et le broker. Sans TLS :
- Les credentials MQTT seraient visibles en clair sur le réseau
- Les données de match seraient interceptables
- Port 1883 (non chiffré) vs port 8883 (TLS)

Sur l'ESP32 (Wokwi), on utilise `WiFiClientSecure` avec `setInsecure()` car le simulateur Wokwi ne dispose pas d'un bundle CA. En production réelle, on utiliserait un vrai bundle CA.

Sur Flutter, on utilise `SecurityContext.defaultContext` qui utilise le bundle CA du système — HiveMQ dispose de certificats CA signés (Let's Encrypt).

---

## 5. Topics MQTT

| Topic | Direction | QoS | Retain | Description |
|-------|-----------|-----|--------|-------------|
| `matimatch/device/match` | Flutter → ESP32 | 1 | Non | Données du match à afficher |
| `matimatch/device/button` | ESP32 → Flutter | 1 | Non | Appui sur le bouton |
| `matimatch/device/status` | ESP32 → Flutter | 1 | **Oui** | ONLINE / OFFLINE |

---

## 6. Payload du topic `matimatch/device/match`

```json
{
  "homeTeam": "PSG",
  "awayTeam": "Lille",
  "homeScore": 3,
  "awayScore": 1,
  "status": "FINISHED",
  "kickoff": "20:45"
}
```

L'ESP32 parse ce JSON avec ArduinoJson et affiche les données sur l'OLED.

---

## 7. Publisher / Subscriber

**Publisher** : publie un message sur un topic.
**Subscriber** : s'abonne à un topic et reçoit tous les messages publiés dessus.
**Broker** : intermédiaire qui reçoit les messages des publishers et les redistribue aux subscribers.

Dans MatiMatch :
- Flutter est **publisher** sur `matimatch/device/match`
- Flutter est **subscriber** sur `matimatch/device/status` et `matimatch/device/button`
- L'ESP32 est **publisher** sur `matimatch/device/status` et `matimatch/device/button`
- L'ESP32 est **subscriber** sur `matimatch/device/match`
- HiveMQ est le **broker**

---

## 8. Retain

Un message **Retain** est conservé par le broker. Quand un nouveau client s'abonne au topic, il reçoit immédiatement le dernier message retenu, sans attendre une nouvelle publication.

Utilisation dans MatiMatch :
- L'ESP32 publie `ONLINE` avec `retain=true` sur `matimatch/device/status`
- Flutter se connecte plus tard → il reçoit immédiatement `ONLINE` sans avoir à attendre
- Si l'ESP32 se déconnecte (LWT), le broker publie `OFFLINE` avec `retain=true`
- Tout nouveau client Flutter sait immédiatement que l'objet est hors ligne

---

## 9. LWT (Last Will Testament)

Le LWT est un message que l'ESP32 "dépose" chez le broker au moment de la connexion. Si l'ESP32 se déconnecte brutalement (perte WiFi, coupure de courant, crash), le broker publie automatiquement ce message.

Configuration dans `main.cpp` :
```cpp
mqttClient.connect(
  CLIENT_ID,
  MQTT_USER, MQTT_PASS,
  "matimatch/device/status", 1, true, "OFFLINE"  // LWT : topic, QoS, retain, message
);
```

---

## 10. QoS (Quality of Service)

| QoS | Garantie | Utilisation |
|-----|----------|-------------|
| 0 | Au plus une fois (fire and forget) | Données non critiques |
| 1 | Au moins une fois (avec acknowledgement) | **Notre usage** — match, statut, bouton |
| 2 | Exactement une fois (4-way handshake) | Transactions financières |

Nous utilisons QoS 1 pour garantir que l'ESP32 reçoit bien le match à afficher.

---

## 11. Offline-first

Stratégie implémentée dans `FootballRepository` :

```
Internet disponible :
  API Football → CacheService (Hive) → UI

Internet indisponible :
  CacheService (cache chaud, TTL 30 min) → UI   [prioritaire]
  CacheService (cache expiré, fallback) → UI + bannière "données en cache"
  Aucun cache → message d'erreur + bouton Réessayer
```

La date de dernière synchronisation est affichée dans une bannière orangée ("Données en cache — dernière mise à jour il y a X min") avec un bouton Réessayer.

Timeout HTTP : 10 secondes pour éviter de bloquer l'UI indéfiniment.

---

## 12. Riverpod et architecture MVVM

```
Screen (ConsumerWidget)
    ↓  ref.watch(...)
ViewModel / Provider (AsyncNotifier, StateProvider)
    ↓  ref.read(repository)
Repository (FootballRepository, MqttRepository)
    ↓  appels
Services (FootballApiService, MqttService, CacheService)
```

**Riverpod** gère :
- Les états asynchrones (`AsyncValue` : loading / data / error)
- La réactivité (le widget se rebuild automatiquement quand l'état change)
- L'injection de dépendances (chaque service est un Provider)
- La durée de vie des objets (`ref.onDispose`)

---

## 13. Sécurité

| Mesure | Implémentation |
|--------|---------------|
| MQTT TLS | Port 8883, `WiFiClientSecure` / `SecurityContext.defaultContext` |
| Secrets Flutter hors Git | `.env` dans `.gitignore`, `.env.example` pour la doc |
| Secrets ESP32 hors Git | `include/credentials.h` dans `.gitignore PlatformIO` |
| HTTPS pour l'API | `https://api.5dollarfootballapi.com` |
| Firebase Auth | Email/password avec Firebase Authentication |

---

## 14. Stockage local

| Donnée | Technologie | Durée |
|--------|-------------|-------|
| Matchs du jour | Hive (cache TTL 30 min) | 30 min |
| Pronostics utilisateur | SharedPreferences | Persistant |
| Thème clair/sombre | SharedPreferences | Persistant |

---

## 15. Composants matériels simulés (Wokwi)

| Composant | Brochage | Rôle |
|-----------|----------|------|
| ESP32 DevKit C V4 | — | Microcontrôleur principal |
| OLED SSD1306 128x64 | SDA=21, SCL=22, VCC=3.3V | Affichage du match |
| Bouton poussoir | GPIO 15 (pull-up interne) | Interaction utilisateur |

---

## 16. Bibliothèques PlatformIO

| Bibliothèque | Version | Usage |
|---|---|---|
| `knolleary/PubSubClient` | 2.8 | Client MQTT |
| `bblanchon/ArduinoJson` | 7.x | Parsing JSON |
| `adafruit/Adafruit SSD1306` | 2.x | Driver OLED |
| `adafruit/Adafruit GFX Library` | 1.x | Graphiques OLED |
