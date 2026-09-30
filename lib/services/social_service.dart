import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/prediction.dart';
import '../models/shared_prediction.dart';
import '../models/user_profile.dart';
import '../repositories/mqtt_repository.dart';

class SocialService {
  static final _db = FirebaseFirestore.instance;

  // ── Collections ─────────────────────────────────────────────────────────────
  static CollectionReference<Map<String, dynamic>> _friends(String uid) =>
      _db.collection('users').doc(uid).collection('friends');

  static CollectionReference<Map<String, dynamic>> _received(String uid) =>
      _db.collection('users').doc(uid).collection('received');

  // ── Amis ─────────────────────────────────────────────────────────────────────

  /// Ajoute une relation d'amitié bidirectionnelle.
  static Future<void> addFriend(UserProfile me, UserProfile friend) async {
    final batch = _db.batch();
    batch.set(
      _friends(me.uid).doc(friend.uid),
      {'uid': friend.uid, 'displayName': friend.displayName, 'email': friend.email, 'since': DateTime.now().toUtc().toIso8601String()},
    );
    batch.set(
      _friends(friend.uid).doc(me.uid),
      {'uid': me.uid, 'displayName': me.displayName, 'email': me.email, 'since': DateTime.now().toUtc().toIso8601String()},
    );
    await batch.commit();
    debugPrint('[SOCIAL] Amitié créée : ${me.uid} ↔ ${friend.uid}');
  }

  static Future<void> removeFriend(String myUid, String friendUid) async {
    final batch = _db.batch();
    batch.delete(_friends(myUid).doc(friendUid));
    batch.delete(_friends(friendUid).doc(myUid));
    await batch.commit();
  }

  static Stream<List<UserProfile>> friendsStream(String uid) {
    return _friends(uid).snapshots().map((snap) => snap.docs
        .map((d) => UserProfile(
              uid: d.data()['uid'] as String? ?? d.id,
              displayName: d.data()['displayName'] as String? ?? '',
              email: d.data()['email'] as String? ?? '',
              createdAt: DateTime.now(),
            ))
        .toList());
  }

  // ── Partage ───────────────────────────────────────────────────────────────────

  /// Partage un pronostic avec plusieurs amis.
  /// 1. Écrit dans Firestore (users/{recipientUid}/received/{predId})
  /// 2. Si l'ami a un appareil associé et que MQTT est connecté → publie sur son topic
  static Future<void> sharePrediction({
    required Prediction prediction,
    required String senderName,
    required List<UserProfile> recipients,
    required MqttRepository mqtt,
  }) async {
    for (final recipient in recipients) {
      final shared = SharedPrediction(
        id: prediction.id,
        fromUid: prediction.authorUid ?? '',
        fromName: senderName,
        matchLabel: prediction.matchLabel,
        selection: prediction.selection,
        odds: prediction.odds,
        confidence: prediction.confidence,
        comment: prediction.comment,
        createdAt: prediction.createdAt,
        mqttStatus: 'pending',
      );

      // 1. Firestore — idempotent (set écrase si déjà existant)
      await _received(recipient.uid).doc(prediction.id).set(shared.toJson());
      debugPrint('[SOCIAL] Pronostic partagé avec ${recipient.displayName}');

      // 2. MQTT — cherche l'appareil associé au destinataire
      final userDoc = await _db.collection('users').doc(recipient.uid).get();
      final deviceId = userDoc.data()?['deviceId'] as String?;

      if (deviceId != null && deviceId.isNotEmpty && mqtt.isConnected) {
        mqtt.sendToDevice(deviceId, shared);
        await _received(recipient.uid)
            .doc(prediction.id)
            .update({'mqttStatus': 'sent'});
        debugPrint('[SOCIAL] MQTT envoyé à $deviceId');
      } else {
        debugPrint(
          '[SOCIAL] MQTT différé : deviceId=$deviceId connected=${mqtt.isConnected}',
        );
      }
    }
  }

  // ── Pronostics reçus ──────────────────────────────────────────────────────────

  static Stream<List<SharedPrediction>> receivedStream(String uid) {
    return _received(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) {
              try {
                return SharedPrediction.fromJson(d.data());
              } catch (e) {
                debugPrint('[SOCIAL] Erreur parsing ${d.id}: $e');
                return null;
              }
            })
            .whereType<SharedPrediction>()
            .toList());
  }
}
