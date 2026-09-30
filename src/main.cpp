#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SH110X.h>
#include "credentials.h"

// ── WiFi ─────────────────────────────────────────────────────────────────────
#ifdef WOKWI
  const char* ssid     = "Wokwi-GUEST";
  const char* password = "";
#else
  const char* ssid     = WIFI_SSID;
  const char* password = WIFI_PASS;
#endif

// ── OLED SH1107 128x128 I2C ──────────────────────────────────────────────────
#define SCREEN_WIDTH  128
#define SCREEN_HEIGHT 128
Adafruit_SH1107 display(SCREEN_HEIGHT, SCREEN_WIDTH, &Wire);

// ── Bouton GPIO 15 (pull-up interne) ─────────────────────────────────────────
#define BUTTON_PIN 15
bool lastButtonState = HIGH;

// ── MQTT ─────────────────────────────────────────────────────────────────────
WiFiClientSecure espClient;
PubSubClient     mqttClient(espClient);

#define TOPIC_MATCH       "matimatch/device/match"
#define TOPIC_PREDICTION  "matimatch/device/prediction"
#define TOPIC_BUTTON      "matimatch/device/button"
#define TOPIC_STATUS      "matimatch/device/status"

String generateClientId() {
  uint8_t mac[6];
  WiFi.macAddress(mac);
  char id[32];
  snprintf(id, sizeof(id), "MatiMatch_%02X%02X%02X%02X%02X%02X",
           mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  return String(id);
}

unsigned long lastReconnectAttempt = 0;

// ── Données match en cours ────────────────────────────────────────────────────
struct MatchData {
  String homeTeam;
  String awayTeam;
  int    homeScore;
  int    awayScore;
  String status;
  String kickoff;
  bool   hasData;
};

// ── Données pronostic en cours ────────────────────────────────────────────────
struct PredictionData {
  String matchLabel;
  String selection;
  float  odds;
  int    confidence;
  bool   hasData;
};

MatchData      currentMatch      = {"", "", 0, 0, "", "", false};
PredictionData currentPrediction = {"", "", 0.0f, 0, false};

// ── Helpers OLED ──────────────────────────────────────────────────────────────
void oledHeader() {
  display.setTextSize(1);
  display.setTextColor(SH110X_WHITE);
  display.setCursor(37, 4);
  display.print("MATIMATCH");
  display.drawLine(0, 14, 127, 14, SH110X_WHITE);
}

void showWaiting() {
  display.clearDisplay();
  oledHeader();
  display.setCursor(12, 30);
  display.print("En attente d'un");
  display.setCursor(30, 42);
  display.print("prono...");
  display.display();
}

void showConnecting() {
  display.clearDisplay();
  oledHeader();
  display.setCursor(10, 30);
  display.print("Connexion WiFi");
  display.setCursor(20, 42);
  display.print("+ MQTT...");
  display.display();
}

void showMatch(const MatchData& m) {
  display.clearDisplay();
  oledHeader();

  bool finished = m.status.equalsIgnoreCase("FINISHED") ||
                  m.status.equalsIgnoreCase("FT");

  display.setTextSize(1);

  if (finished) {
    String line = m.homeTeam + " " + m.homeScore + " - " + m.awayScore + " " + m.awayTeam;
    display.setCursor(0, 28);
    display.print(line);
    display.setTextSize(2);
    display.setCursor(14, 52);
    display.print("TERMINE");
  } else {
    String teams = m.homeTeam + " - " + m.awayTeam;
    display.setCursor(0, 28);
    display.print(teams);
    display.setTextSize(2);
    display.setCursor(34, 52);
    display.print(m.kickoff);
  }

  display.display();
  Serial.println("[OLED] Match affiche");
}

// Affichage d'un pronostic sur l'OLED
// Layout (texte taille 1 = 6x8px → 21 chars/ligne) :
//  y=4  : header MATIMATCH
//  y=14 : ligne horizontale
//  y=18 : matchLabel ligne 1 (21 chars max)
//  y=28 : matchLabel ligne 2 si > 21 chars
//  y=42 : "Prono : " + selection
//  y=54 : "Cote  : " + odds
//  y=66 : "Conf  : " + étoiles (ex: ***--)
void showPrediction(const PredictionData& p) {
  display.clearDisplay();
  oledHeader();

  display.setTextSize(1);
  display.setTextColor(SH110X_WHITE);

  // Affichage du match (1 ou 2 lignes selon longueur)
  if (p.matchLabel.length() > 21) {
    display.setCursor(0, 18);
    display.print(p.matchLabel.substring(0, 21));
    display.setCursor(0, 28);
    String rest = p.matchLabel.substring(21);
    if (rest.length() > 21) rest = rest.substring(0, 21);
    display.print(rest);
  } else {
    display.setCursor(0, 23);
    display.print(p.matchLabel);
  }

  // Pronostic (1 / N / 2)
  display.setCursor(0, 42);
  display.print("Prono : ");
  display.print(p.selection);

  // Cote
  display.setCursor(0, 54);
  display.print("Cote  : ");
  display.print(p.odds, 2);

  // Confiance : étoiles ASCII (* = rempli, - = vide)
  display.setCursor(0, 66);
  display.print("Conf  : ");
  for (int i = 0; i < 5; i++) {
    display.print(i < p.confidence ? "*" : "-");
  }

  display.display();
  Serial.println("[OLED] Pronostic affiche");
}

// ── Callback MQTT ─────────────────────────────────────────────────────────────
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  Serial.printf("[MQTT] Message recu sur '%s' (%d octets)\n", topic, length);

  String msg;
  msg.reserve(length);
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];
  Serial.println("[MQTT] Payload : " + msg);

  String topicStr = String(topic);

  // ── Topic : match ──────────────────────────────────────────────────────────
  if (topicStr == TOPIC_MATCH) {
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, msg);
    if (err != DeserializationError::Ok) {
      Serial.print("[JSON] Erreur match : "); Serial.println(err.c_str());
      return;
    }

    const char* ht = doc["homeTeam"];
    const char* at = doc["awayTeam"];
    const char* st = doc["status"];
    const char* ko = doc["kickoff"];

    if (!ht || !at || !st || !ko) {
      Serial.println("[JSON] Champs match manquants");
      return;
    }

    currentMatch.homeTeam  = ht;
    currentMatch.awayTeam  = at;
    currentMatch.homeScore = doc["homeScore"] | 0;
    currentMatch.awayScore = doc["awayScore"] | 0;
    currentMatch.status    = st;
    currentMatch.kickoff   = ko;
    currentMatch.hasData   = true;

    Serial.printf("[MATCH] %s %d-%d %s  status=%s\n",
      ht, currentMatch.homeScore, currentMatch.awayScore, at, st);
    showMatch(currentMatch);
  }

  // ── Topic : pronostic ──────────────────────────────────────────────────────
  else if (topicStr == TOPIC_PREDICTION) {
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, msg);
    if (err != DeserializationError::Ok) {
      Serial.print("[JSON] Erreur prediction : "); Serial.println(err.c_str());
      return;
    }

    const char* ml  = doc["matchLabel"];
    const char* sel = doc["selection"];

    if (!ml || !sel) {
      Serial.println("[JSON] Champs prediction manquants");
      return;
    }

    currentPrediction.matchLabel = ml;
    currentPrediction.selection  = sel;
    currentPrediction.odds       = doc["odds"]       | 1.0f;
    currentPrediction.confidence = doc["confidence"] | 1;
    currentPrediction.hasData    = true;

    Serial.printf("[PRONO] %s | %s | %.2f | conf=%d\n",
      ml, sel, currentPrediction.odds, currentPrediction.confidence);
    showPrediction(currentPrediction);
  }

  else {
    Serial.println("[MQTT] Topic inattendu, ignore");
  }
}

// ── Connexion MQTT avec LWT ───────────────────────────────────────────────────
bool mqttConnect() {
  espClient.stop();
  delay(100);

  String clientId = generateClientId();
  Serial.print("[MQTT] Connexion [" + clientId + "]...");

  bool ok = mqttClient.connect(
    clientId.c_str(),
    MQTT_USER, MQTT_PASS,
    TOPIC_STATUS, 1, true, "OFFLINE"
  );

  if (!ok) {
    Serial.printf(" ERREUR rc=%d\n", mqttClient.state());
    return false;
  }

  Serial.println(" OK");
  mqttClient.publish(TOPIC_STATUS, "ONLINE", true);

  bool sub1 = mqttClient.subscribe(TOPIC_MATCH,      0);
  bool sub2 = mqttClient.subscribe(TOPIC_PREDICTION, 0);

  Serial.printf("[MQTT] Subscribe match=%s  prediction=%s\n",
    sub1 ? "OK" : "FAIL", sub2 ? "OK" : "FAIL");

  return true;
}

// ── SETUP ─────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);

  // OLED
  Wire.begin(21, 22);
  if (!display.begin(0x3C, true)) {
    Serial.println("[OLED] Erreur : ecran introuvable (0x3C) !");
    while (true) delay(1000);
  }
  display.setRotation(0);
  Serial.println("[OLED] Init OK");

  // Test visuel de démarrage
  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(SH110X_WHITE);
  display.setCursor(10, 40);
  display.print("MATIMATCH");
  display.setTextSize(1);
  display.setCursor(20, 70);
  display.print("OLED TEST OK");
  display.display();
  Serial.println("[OLED] Test rendu");
  delay(2000);

  showConnecting();

  // Bouton
  pinMode(BUTTON_PIN, INPUT_PULLUP);

  // WiFi
  WiFi.begin(ssid, password);
  Serial.print("[WiFi] Connexion");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println(" OK");

  // TLS sans vérification de certificat (Wokwi ne supporte pas les bundles CA)
  espClient.setInsecure();

  // MQTT
  mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setBufferSize(512);
  mqttClient.setKeepAlive(60);
  mqttClient.setSocketTimeout(30);

  if (mqttConnect()) showWaiting();
}

// ── LOOP ──────────────────────────────────────────────────────────────────────
void loop() {
  if (!mqttClient.connected()) {
    unsigned long now = millis();
    if (now - lastReconnectAttempt >= 5000) {
      lastReconnectAttempt = now;
      Serial.printf("[MQTT] Deconnecte (state=%d), tentative...\n", mqttClient.state());
      if (mqttConnect()) {
        lastReconnectAttempt = now;
        if (currentPrediction.hasData) showPrediction(currentPrediction);
        else if (currentMatch.hasData)  showMatch(currentMatch);
        else                            showWaiting();
      }
    }
    return;
  }

  mqttClient.loop();

  // Bouton : détection front descendant avec anti-rebond
  bool state = digitalRead(BUTTON_PIN);
  if (state == LOW && lastButtonState == HIGH) {
    delay(20);
    if (digitalRead(BUTTON_PIN) == LOW) {
      mqttClient.publish(TOPIC_BUTTON, "{\"pressed\":true}");
      Serial.println("[BTN] Publie sur " TOPIC_BUTTON);
    }
  }
  lastButtonState = state;
}
