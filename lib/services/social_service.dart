import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/logger/app_logger.dart';
import '../models/friend_request.dart';
import '../models/prediction.dart';
import '../models/shared_prediction.dart';
import '../models/user_profile.dart';
import '../repositories/mqtt_repository.dart';

class SocialService {
  static const _tag = 'SOCIAL';
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _friends(String uid) =>
      _db.collection('users').doc(uid).collection('friends');

  static CollectionReference<Map<String, dynamic>> _friendRequests(String uid) =>
      _db.collection('users').doc(uid).collection('friendRequests');

  static CollectionReference<Map<String, dynamic>> _received(String uid) =>
      _db.collection('users').doc(uid).collection('received');

  static Future<void> sendFriendRequest(UserProfile me, UserProfile target) async {
    final request = FriendRequest(
      fromUid:   me.uid,
      fromName:  me.displayName,
      fromEmail: me.email,
      createdAt: DateTime.now(),
    );
    await _friendRequests(target.uid).doc(me.uid).set(request.toJson());
    AppLogger.d(_tag, 'Demande envoyée → ${target.uid}');
  }

  static Future<void> acceptFriendRequest(
      UserProfile me, FriendRequest request) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final batch = _db.batch();

    batch.set(
      _friends(me.uid).doc(request.fromUid),
      {'uid': request.fromUid, 'displayName': request.fromName,
       'email': request.fromEmail, 'since': now},
    );
    batch.set(
      _friends(request.fromUid).doc(me.uid),
      {'uid': me.uid, 'displayName': me.displayName,
       'email': me.email, 'since': now},
    );
    batch.delete(_friendRequests(me.uid).doc(request.fromUid));

    await batch.commit();
    AppLogger.d(_tag, 'Amitié acceptée avec ${request.fromUid}');
  }

  static Future<void> declineFriendRequest(
      String myUid, String requesterUid) async {
    await _friendRequests(myUid).doc(requesterUid).delete();
    AppLogger.d(_tag, 'Demande déclinée de $requesterUid');
  }

  static Stream<List<FriendRequest>> friendRequestsStream(String uid) {
    return _friendRequests(uid).snapshots().map((snap) => snap.docs
        .map((d) => FriendRequest.fromJson(d.data()))
        .toList());
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

      await _received(recipient.uid).doc(prediction.id).set(shared.toJson());
      AppLogger.d(_tag, 'Partagé avec ${recipient.displayName}');

      final userDoc = await _db.collection('users').doc(recipient.uid).get();
      final deviceId = userDoc.data()?['deviceId'] as String?;

      if (deviceId != null && deviceId.isNotEmpty && mqtt.isConnected) {
        mqtt.sendToDevice(deviceId, shared);
        await _received(recipient.uid)
            .doc(prediction.id)
            .update({'mqttStatus': 'sent'});
        AppLogger.d(_tag, 'MQTT envoyé à device $deviceId');
      } else {
        AppLogger.d(_tag, 'MQTT différé — device absent ou déconnecté');
      }
    }
  }

  static Stream<List<SharedPrediction>> receivedStream(String uid) {
    return _received(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) {
              try {
                return SharedPrediction.fromJson(d.data());
              } catch (e) {
                AppLogger.e(_tag, 'Erreur parsing ${d.id}', e);
                return null;
              }
            })
            .whereType<SharedPrediction>()
            .toList());
  }
}
