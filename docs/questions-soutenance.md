# Questions/Réponses — Soutenance MatiMatch IoT

---

## MQTT

**Pourquoi MQTT et pas HTTP ?**

HTTP est un protocole requête/réponse : le client envoie une requête, le serveur répond. Pour de l'IoT, ça pose plusieurs problèmes : l'ESP32 devrait faire un serveur HTTP (lourd en RAM), ou Flutter devrait poller régulièrement (inefficace). MQTT est un protocole publish/subscribe : les deux parties s'abonnent à des topics et reçoivent les messages en temps réel. C'est léger, conçu pour les microcontrôleurs, et très efficace sur des connexions instables.

---

**Qu'est-ce qu'un broker MQTT ?**

Le broker est le serveur central qui reçoit tous les messages des publishers et les redistribue aux subscribers abonnés aux topics correspondants. Dans MatiMatch, c'est HiveMQ Cloud. Les clients (Flutter et ESP32) ne communiquent jamais directement entre eux : tout passe par le broker.

---

**Qu'est-ce que Publisher/Subscriber ?**

- **Publisher** : publie (envoie) un message sur un topic.
- **Subscriber** : s'abonne à un topic et reçoit tous les messages qui y sont publiés.
- Un même client peut être publisher ET subscriber sur des topics différents.
- Dans MatiMatch : Flutter publie sur `matimatch/device/match` et s'abonne à `matimatch/device/status` et `matimatch/device/button`.

---

**Qu'est-ce que QoS ?**

QoS (Quality of Service) définit le niveau de garantie de livraison d'un message :
- **QoS 0** : "fire and forget" — un seul envoi, aucune garantie.
- **QoS 1** : "at least once" — le message est renvoyé jusqu'à ce que le destinataire confirme la réception. C'est ce qu'on utilise dans MatiMatch.
- **QoS 2** : "exactly once" — mécanisme à 4 échanges pour garantir une livraison exactement une fois. Trop lourd pour notre usage.

---

**Qu'est-ce que Retain ?**

Un message Retain est conservé par le broker. Quand un nouveau client s'abonne à un topic, il reçoit immédiatement le dernier message retenu, même s'il a été publié il y a longtemps. On utilise Retain pour `matimatch/device/status` : si Flutter se connecte après l'ESP32, il reçoit immédiatement `ONLINE` ou `OFFLINE` sans attendre.

---

**Qu'est-ce que LWT (Last Will Testament) ?**

Le LWT est un message que le client dépose chez le broker lors de la connexion. Si ce client se déconnecte de façon non propre (perte WiFi, crash, coupure de courant), le broker publie automatiquement ce message. Dans MatiMatch, l'ESP32 configure le LWT : si l'ESP32 disparaît, le broker publie `OFFLINE` (avec Retain) sur `matimatch/device/status`. Flutter reçoit ce message et affiche "Objet hors ligne".

---

**Pourquoi TLS ? Pourquoi le port 8883 ?**

TLS chiffre les données en transit. Sans TLS, les credentials MQTT et les données de match seraient visibles en clair sur le réseau. Le port **1883** est le port MQTT standard (non chiffré). Le port **8883** est le port MQTT avec TLS/SSL, standardisé par l'IANA. HiveMQ Cloud n'accepte que les connexions sur le port 8883, ce qui force l'utilisation de TLS.

---

## Architecture Flutter

**Pourquoi Riverpod ?**

Riverpod est une bibliothèque de gestion d'état pour Flutter. Elle offre :
- La séparation UI/logique (les widgets ne font que lire des providers, pas de logique métier dedans)
- La gestion des états asynchrones avec `AsyncValue` (loading, data, error) sans écrire de code boilerplate
- La réactivité : un widget se rebuilde automatiquement quand son provider change
- La testabilité : les providers sont indépendants du BuildContext

---

**Pourquoi MVVM ?**

MVVM (Model-View-ViewModel) sépare :
- **Model** : les données et la logique métier (FootballMatch, Repository, Service)
- **View** : l'interface utilisateur (les Screens)
- **ViewModel** : fait le lien entre les deux (les providers Riverpod / AsyncNotifier)

Avantages : code testable, responsabilités claires, pas de logique dans les widgets.

---

**Comment fonctionne l'offline-first ?**

Quand Flutter demande les matchs :
1. On vérifie d'abord le cache Hive (TTL 30 min) → si valide, on l'utilise
2. Si le cache est expiré ou vide → on appelle l'API (timeout 10 s)
3. Si l'API répond → on met à jour le cache et on affiche les données
4. Si l'API échoue (pas d'internet, timeout) → on utilise le cache expiré s'il existe, avec une bannière "Données en cache"
5. Si aucun cache → message d'erreur + bouton Réessayer

---

## Robustesse

**Que se passe-t-il si HiveMQ tombe ?**

- `mqtt_client` dispose de `autoReconnect = true` : il tente de se reconnecter automatiquement
- L'UI Flutter affiche "MQTT non connecté" (le bouton "Afficher sur MatiMatch Display" est désactivé)
- L'app continue de fonctionner normalement pour les matchs (API + cache)
- La connexion MQTT se rétablit dès que HiveMQ est de nouveau disponible

---

**Que se passe-t-il si l'ESP32 se déconnecte ?**

- Le broker publie automatiquement le LWT : `OFFLINE` avec Retain sur `matimatch/device/status`
- Flutter reçoit ce message et affiche "Objet hors ligne" (rouge)
- Le bouton "Afficher sur MatiMatch Display" est désactivé
- Quand l'ESP32 redémarre, il publie `ONLINE` avec Retain → Flutter passe à "Objet connecté"

---

**Pourquoi Wokwi ?**

Wokwi est un simulateur d'ESP32 dans le navigateur, intégrable dans VS Code via l'extension. Il permet :
- De simuler l'ESP32 sans avoir le matériel réel
- De tester le code MQTT (il supporte le WiFi via "Wokwi-GUEST")
- De simuler des composants : OLED SSD1306, boutons, capteurs
- De faire tourner le même code C++ que sur un vrai ESP32
- De démontrer le projet en démo sans transporter de matériel
