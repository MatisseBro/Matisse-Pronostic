import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/logger/app_logger.dart';
import '../models/user_profile.dart';

class UserService {
  static const _tag = 'USER';
  static final _db = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  static Future<void> ensureProfile(User user) async {
    final doc = await _users.doc(user.uid).get();
    if (doc.exists) return;

    final displayName = user.displayName?.isNotEmpty == true
        ? user.displayName!
        : user.email?.split('@').first ?? 'Utilisateur';

    final profile = UserProfile(
      uid: user.uid,
      displayName: displayName,
      email: user.email ?? '',
      createdAt: DateTime.now(),
    );
    await _users.doc(user.uid).set(profile.toJson());
    AppLogger.d(_tag, 'Profil créé pour $displayName');
  }

  static Future<UserProfile?> getProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromJson(doc.data()!);
  }

  static Stream<UserProfile?> profileStream(String uid) {
    return _users.doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromJson(snap.data()!);
    });
  }

  static Future<void> updateDisplayName(String uid, String displayName) async {
    await _users.doc(uid).update({'displayName': displayName.trim()});
  }

  static Future<void> updateDeviceId(String uid, String? deviceId) async {
    await _users.doc(uid).update({'deviceId': deviceId});
    AppLogger.d(_tag, 'deviceId mis à jour');
  }

  static Future<UserProfile?> findByEmail(String email) async {
    final query = await _users
        .where('email', isEqualTo: email.trim().toLowerCase())
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return UserProfile.fromJson(query.docs.first.data());
  }
}
