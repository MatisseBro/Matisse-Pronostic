# Script de démonstration — MatiMatch IoT (5 minutes)

## Avant la démo (préparation)

- [ ] Lancer l'émulateur Android (ou connecter un téléphone)
- [ ] Ouvrir VS Code avec le workspace MatiMatch
- [ ] Ouvrir le projet Wokwi (onglet Matimatch dans VS Code)
- [ ] Avoir MQTT Explorer ouvert et connecté à HiveMQ
- [ ] S'assurer que Flutter est compilé et prêt

---

## 1. Présenter l'application Flutter (30 s)

> "Voici MatiMatch, une application de suivi des matchs de football avec une fonctionnalité IoT : les matchs peuvent être affichés sur un écran OLED connecté."

- Montrer l'écran des matchs
- Pointer le badge de statut dans l'app bar : "Pour l'instant l'objet n'est pas connecté"

---

## 2. Démarrer l'ESP32 dans Wokwi (30 s)

> "Je lance l'objet simulé dans Wokwi."

- Cliquer sur Play dans Wokwi
- Montrer le Serial Monitor : "WiFi OK", "Connexion MQTT... OK"
- Montrer l'OLED : "MATIMATCH / En attente d'un match..."
- Dans Flutter : le badge passe à **"Objet connecté"** (vert)

> "L'ESP32 a publié 'ONLINE' sur le topic matimatch/device/status avec le flag Retain. Flutter l'a reçu et affiche le statut."

---

## 3. Choisir un match et l'envoyer (60 s)

> "Je sélectionne un match dans l'application."

- Taper sur un match (ex: PSG - Lille)
- Faire défiler jusqu'à la section **MATIMATCH DISPLAY**
- Montrer l'aperçu OLED dans l'UI Flutter

> "On voit en noir l'aperçu de ce qui va s'afficher sur l'écran."

- Cliquer sur **"Afficher sur MatiMatch Display"**

> "Flutter publie un message JSON sur le topic matimatch/device/match."

- Montrer dans **MQTT Explorer** le message reçu sur `matimatch/device/match`
- Montrer l'OLED Wokwi qui affiche le match

> "L'ESP32 a reçu le message, l'a parsé avec ArduinoJson, et l'affiche sur l'OLED SSD1306."

---

## 4. Appuyer sur le bouton Wokwi (30 s)

> "L'ESP32 a aussi un bouton. Quand on appuie dessus, il publie un événement vers Flutter."

- Cliquer sur le bouton vert dans Wokwi
- Montrer dans MQTT Explorer le message sur `matimatch/device/button`
- Montrer dans Flutter (section MatiMatch Display) : **"Bouton Wokwi appuyé !"**

> "C'est la communication dans le sens inverse : ESP32 → Flutter, toujours via MQTT."

---

## 5. Simuler la déconnexion de l'ESP32 (30 s)

> "Que se passe-t-il si l'objet se déconnecte ?"

- Arrêter la simulation Wokwi (bouton Stop)
- Attendre ~30 secondes (délai keepAlive du broker)
- Montrer Flutter : le badge passe à **"Objet hors ligne"** (rouge)

> "C'est le Last Will Testament : quand l'ESP32 se déconnecte, HiveMQ publie automatiquement 'OFFLINE' avec le flag Retain sur matimatch/device/status. Flutter reçoit ça et met à jour l'interface."

---

## 6. Démontrer l'offline-first (60 s)

> "Maintenant, l'offline-first. Que se passe-t-il si on coupe le réseau ?"

- Couper le WiFi ou activer le mode avion sur le téléphone
- Revenir à l'écran des matchs
- Rafraîchir (pull-to-refresh)
- Montrer la **bannière orangée** : "Données en cache — dernière mise à jour il y a X min"

> "L'application ne plante pas. Elle utilise les données mises en cache par Hive et affiche une indication claire à l'utilisateur. Il y a aussi un timeout de 10 secondes et un bouton Réessayer."

- Rétablir le réseau, cliquer Réessayer
- Les données se rechargent depuis l'API

---

## Récapitulatif (30 s)

> "Pour résumer :
> - Communication bidirectionnelle Flutter ↔ ESP32 via MQTT TLS
> - Broker cloud HiveMQ
> - LWT pour détecter la déconnexion de l'objet
> - Retain pour connaître l'état de l'objet dès la connexion
> - Architecture MVVM avec Riverpod
> - Offline-first avec cache Hive
> - Secrets hors du code source"
