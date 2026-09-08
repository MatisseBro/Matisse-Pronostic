#include <Arduino.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "credentials.h"

// ── WiFi Wokwi ───────────────────────────────────────────────────────────────
const char* ssid     = "Wokwi-GUEST";
const char* password = "";

// ── OLED SSD1306 128x64 I2C ──────────────────────────────────────────────────
#define SCREEN_WIDTH  128
#define SCREEN_HEIGHT  64
#define OLED_RESET     -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// ── Bouton GPIO 15 (pull-up interne) ─────────────────────────────────────────
#define BUTTON_PIN 15
bool lastButtonState = HIGH;

// ── MQTT ─────────────────────────────────────────────────────────────────────
WiFiClientSecure espClient;
PubSubClient     mqttClient(espClient);

#define TOPIC_MATCH  "matimatch/device/match"
#define TOPIC_BUTTON "matimatch/device/button"
#define TOPIC_STATUS "matimatch/device/status"
#define CLIENT_ID    "MatiMatch_ESP32_Wokwi"

unsigned long lastReconnectAttempt = 0;

// ── Données du match en cours ─────────────────────────────────────────────────
struct MatchData {
  String homeTeam;
  String awayTeam;
  int    homeScore;
  int    awayScore;
  String status;
  String kickoff;
  bool   hasData;
};

MatchData currentMatch = {"", "", 0, 0, "", "", false};

// ── Affichage OLED ────────────────────────────────────────────────────────────
void oledHeader() {
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(24, 0);
  display.print("MATIMATCH");
  display.drawLine(0, 10, 127, 10, SSD1306_WHITE);
}

void showWaiting() {
  display.clearDisplay();
  oledHeader();
  display.setCursor(12, 22);
  display.print("En attente d'un");
  display.setCursor(30, 34);
  display.print("match...");
  display.display();
}

void showConnecting() {
  display.clearDisplay();
  oledHeader();
  display.setCursor(10, 22);
  display.print("Connexion WiFi");
  display.setCursor(20, 34);
  display.print("+ MQTT...");
  display.display();
}

void showMatch(const MatchData& m) {
  display.clearDisplay();
  oledHeader();

  bool finished = m.status.equalsIgnoreCase("FINISHED") ||
                  m.status.equalsIgnoreCase("FT");

  if (finished) {
    // Exemple : PSG 3 - 1 LILLE
    String line = m.homeTeam + " " + m.homeScore + "-" + m.awayScore + " " + m.awayTeam;
    display.setTextSize(1);
    display.setCursor(0, 16);
    display.print(line);
    display.setTextSize(1);
    display.setCursor(34, 30);
    display.print("TERMINE");
  } else {
    // Exemple : PSG - LILLE / 20:45
    String teams = m.homeTeam + " - " + m.awayTeam;
    display.setTextSize(1);
    display.setCursor(0, 16);
    display.print(teams);
    display.setTextSize(2);
    display.setCursor(28, 30);
    display.print(m.kickoff);
  }

  display.display();
}

// ── Callback MQTT : réception d'un message ────────────────────────────────────
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  String msg;
  msg.reserve(length);
  for (unsigned int i = 0; i < length; i++) msg += (char)payload[i];

  if (String(topic) == TOPIC_MATCH) {
    JsonDocument doc;
    if (deserializeJson(doc, msg) != DeserializationError::Ok) return;

    currentMatch.homeTeam  = doc["homeTeam"].as<const char*>();
    currentMatch.awayTeam  = doc["awayTeam"].as<const char*>();
    currentMatch.homeScore = doc["homeScore"] | 0;
    currentMatch.awayScore = doc["awayScore"] | 0;
    currentMatch.status    = doc["status"].as<const char*>();
    currentMatch.kickoff   = doc["kickoff"].as<const char*>();
    currentMatch.hasData   = true;

    Serial.printf("Match reçu : %s vs %s\n",
      currentMatch.homeTeam.c_str(), currentMatch.awayTeam.c_str());

    showMatch(currentMatch);
  }
}

// ── Connexion MQTT avec LWT ───────────────────────────────────────────────────
bool mqttConnect() {
  Serial.print("Connexion MQTT...");

  // LWT : si l'ESP32 se déconnecte brusquement, le broker publie "OFFLINE" (retain)
  bool ok = mqttClient.connect(
    CLIENT_ID,
    MQTT_USER, MQTT_PASS,
    TOPIC_STATUS, 1, true, "OFFLINE"
  );

  if (ok) {
    Serial.println(" OK");
    // Publier ONLINE avec retain pour que Flutter voie l'état immédiatement
    mqttClient.publish(TOPIC_STATUS, "ONLINE", true);
    // S'abonner au topic match (QoS 1)
    mqttClient.subscribe(TOPIC_MATCH, 1);
    return true;
  }

  Serial.printf(" ERREUR rc=%d\n", mqttClient.state());
  return false;
}

// ── SETUP ─────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);

  // OLED
  Wire.begin(21, 22);
  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println("OLED introuvable !");
    while (true) delay(1000);
  }
  showConnecting();

  // Bouton
  pinMode(BUTTON_PIN, INPUT_PULLUP);

  // WiFi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) delay(500);
  Serial.println("WiFi OK");

  // TLS sans vérification de certificat (Wokwi ne supporte pas les bundles CA)
  espClient.setInsecure();

  // MQTT
  mqttClient.setServer(MQTT_SERVER, MQTT_PORT);
  mqttClient.setCallback(mqttCallback);
  mqttClient.setBufferSize(512);

  if (mqttConnect()) showWaiting();
}

// ── LOOP ──────────────────────────────────────────────────────────────────────
void loop() {
  // Reconnexion non-bloquante toutes les 5 secondes
  if (!mqttClient.connected()) {
    unsigned long now = millis();
    if (now - lastReconnectAttempt >= 5000) {
      lastReconnectAttempt = now;
      if (mqttConnect()) {
        lastReconnectAttempt = 0;
        if (!currentMatch.hasData) showWaiting();
        else showMatch(currentMatch);
      }
    }
    return;
  }

  mqttClient.loop();

  // Bouton : détection front descendant (appui) avec anti-rebond simple
  bool state = digitalRead(BUTTON_PIN);
  if (state == LOW && lastButtonState == HIGH) {
    delay(20); // anti-rebond
    if (digitalRead(BUTTON_PIN) == LOW) {
      mqttClient.publish(TOPIC_BUTTON, "{\"pressed\":true}");
      Serial.println("Bouton -> matimatch/device/button");
    }
  }
  lastButtonState = state;
}
