# MatiMatch

Application mobile Flutter de suivi des matchs de football avec affichage en temps réel sur un objet connecté ESP32 (écran OLED) via MQTT.

---

## Fonctionnalités

- Matchs du jour (Ligue 1, Premier League, Liga, Serie A, Bundesliga)
- Cotes 1/N/2 par match
- Détail d'un match avec option d'envoi sur l'écran OLED
- Classements des championnats
- Pronostics personnels
- Connexion Firebase (email/mot de passe)
- **IoT** : affichage d'un match sur un ESP32 Wokwi via MQTT TLS
- **Offline-first** : cache local Hive, bannière de données périmées

---

## Architecture

```
Flutter (Android/iOS)
        ↕  MQTT TLS port 8883
HiveMQ Cloud (broker MQTT)
        ↕  MQTT TLS port 8883
ESP32 simulé dans Wokwi
  ├── OLED SSD1306 (I2C — SDA=21, SCL=22)
  └── Bouton (GPIO 15)
```

### Structure Flutter

```
lib/
├── models/           FootballMatch, Prediction, StandingEntry
├── services/         FootballApiService, CacheService, AuthService, MqttService
├── repositories/     FootballRepository, MqttRepository
├── viewmodels/       MatchesViewModel, PredictionsViewModel, MqttProvider...
└── screens/          MatchesScreen, MatchDetailScreen, PredictionsScreen...
```

### Topics MQTT

| Topic | Direction | Description |
|-------|-----------|-------------|
| `matimatch/device/match` | Flutter → ESP32 | JSON du match à afficher |
| `matimatch/device/button` | ESP32 → Flutter | Appui sur le bouton |
| `matimatch/device/status` | ESP32 → Flutter | ONLINE / OFFLINE (Retain + LWT) |

---

## Installation Flutter

### Prérequis

- Flutter SDK ≥ 3.6
- Android Studio ou VS Code
- Un émulateur Android ou un téléphone physique

### Configuration

1. Copier `.env.example` en `.env` et remplir les valeurs :
   ```
   API_FOOTBALL_KEY=VOTRE_CLE
   MQTT_HOST=VOTRE_BROKER.s1.eu.hivemq.cloud
   MQTT_PORT=8883
   MQTT_USER=VOTRE_USER
   MQTT_PASSWORD=VOTRE_MOT_DE_PASSE
   ```

2. Installer les dépendances :
   ```bash
   flutter pub get
   ```

3. Lancer l'application :
   ```bash
   flutter run
   ```

---

## Lancement Wokwi / ESP32

### Prérequis

- VS Code avec les extensions **PlatformIO** et **Wokwi**
- Ouvrir le workspace `MatiMatch.code-workspace`

### Configuration

1. Copier `include/credentials.h.example` en `include/credentials.h` et remplir :
   ```cpp
   #define MQTT_SERVER "VOTRE_BROKER.s1.eu.hivemq.cloud"
   #define MQTT_PORT   8883
   #define MQTT_USER   "VOTRE_USER"
   #define MQTT_PASS   "VOTRE_MOT_DE_PASSE"
   ```

2. Compiler :
   ```bash
   pio run
   ```
   ou via le bouton Build de PlatformIO dans VS Code.

3. Lancer la simulation Wokwi : clic sur `diagram.json` → bouton Play.

---

## HiveMQ Cloud

1. Créer un compte sur [hivemq.com](https://hivemq.com)
2. Créer un cluster gratuit
3. Créer un utilisateur MQTT avec mot de passe
4. Utiliser l'URL du cluster, port 8883

---

## Sécurité

- La clé API Football et les credentials MQTT ne sont **jamais** commités dans Git
- Fichiers exclus : `.env` (Flutter), `include/credentials.h` (ESP32)
- Modèles fournis : `.env.example`, `include/credentials.h.example`
- MQTT sur TLS port 8883 uniquement

---

## Documentation

| Fichier | Contenu |
|---------|---------|
| `docs/dossier-technique.md` | Architecture, MQTT, offline-first, sécurité |
| `docs/demo-soutenance.md` | Script de démonstration 5 minutes |
| `docs/questions-soutenance.md` | Questions/réponses pour la soutenance |
| `docs/grille-evaluation.md` | Grille d'évaluation avec preuves |
