import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../core/logger/app_logger.dart';
import '../models/prediction.dart';

class FirestoreService {
  static const _tag = 'FIRESTORE';
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('predictions');

  static String get projectId => _db.app.options.projectId;

  static Stream<List<Prediction>> predictionsStream(String uid) {
    return _col
        .where('authorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) {
              try {
                return Prediction.fromJson(doc.data());
              } catch (e) {
                AppLogger.e(_tag, 'Parsing error ${doc.id}', e);
                return null;
              }
            })
            .whereType<Prediction>()
            .toList());
  }

  static Future<List<Prediction>> getPredictions(String uid) async {
    final snap = await _col
        .where('authorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map((doc) {
          try {
            return Prediction.fromJson(doc.data());
          } catch (e) {
            AppLogger.e(_tag, 'Parsing error ${doc.id}', e);
            return null;
          }
        })
        .whereType<Prediction>()
        .toList();
  }

  static Future<void> savePrediction(Prediction prediction) async {
    final docRef = _col.doc(prediction.id);
    final data = prediction.toJson();

    await _db.runTransaction((transaction) async {
      transaction.set(docRef, data);
    });
    AppLogger.d(_tag, 'Transaction terminée pour ${prediction.id}');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Vérification impossible : utilisateur non authentifié.');
    }

    final idToken = await user.getIdToken(true);
    final proj = _db.app.options.projectId;
    final restUri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$proj'
      '/databases/(default)/documents/predictions/${prediction.id}',
    );

    final response = await http.get(
      restUri,
      headers: {'Authorization': 'Bearer $idToken'},
    );

    AppLogger.d(_tag, 'REST GET → ${response.statusCode}');

    if (response.statusCode == 200) {
      AppLogger.d(_tag, '✓ Document ${prediction.id} confirmé côté serveur.');
      return;
    }

    throw Exception(
      'REST Firestore: document absent du serveur.\n'
      'Projet: $proj\n'
      'HTTP ${response.statusCode}',
    );
  }

  static Future<void> deletePrediction(String id) async {
    await _col.doc(id).delete();
  }

  static Future<void> updateResult(String id, String? result) async {
    await _col.doc(id).update({'result': result});
  }
}
