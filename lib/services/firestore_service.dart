import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/prediction.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('predictions');

  static String get projectId => _db.app.options.projectId;

  // Flux temps réel filtré par propriétaire (trié du plus récent au plus ancien).
  // Le filtre authorUid est cohérent avec la règle allow read du propriétaire.
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
                debugPrint('[FIRESTORE] Parsing error ${doc.id}: $e');
                return null;
              }
            })
            .whereType<Prediction>()
            .toList());
  }

  // Chargement initial filtré par propriétaire.
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
            debugPrint('[FIRESTORE] Parsing error ${doc.id}: $e');
            return null;
          }
        })
        .whereType<Prediction>()
        .toList();
  }

  /// Enregistre un pronostic et vérifie via l'API REST Firestore que le
  /// document est bien présent côté serveur. L'appel REST est complètement
  /// indépendant du SDK Flutter et du cache local (pas de latency-compensation).
  static Future<void> savePrediction(Prediction prediction) async {
    final docRef = _col.doc(prediction.id);
    final data = prediction.toJson();

    // 1. Écriture via transaction (attend la confirmation du serveur avec MemoryCacheSettings)
    await _db.runTransaction((transaction) async {
      transaction.set(docRef, data);
    });
    debugPrint('[FIRESTORE] Transaction terminée pour ${prediction.id}');

    // 2. Vérification REST — bypasse totalement le SDK Flutter et le cache local.
    //    Source.server est insuffisant car Firestore applique la "latency compensation"
    //    (les writes locaux en attente sont visibles même avec Source.server).
    //    Seul un appel HTTP direct prouve que le document est sur le serveur.
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception(
          'Vérification impossible : utilisateur non authentifié.');
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

    debugPrint('[FIRESTORE REST] GET $restUri → ${response.statusCode}');
    debugPrint('[FIRESTORE REST] Body: ${response.body}');

    if (response.statusCode == 200) {
      debugPrint('[FIRESTORE] ✓ Document ${prediction.id} confirmé sur le serveur REST.');
      return;
    }

    // Erreur côté serveur : on lève une exception explicite avec le détail HTTP
    // pour qu'elle remonte jusqu'au snackbar rouge de l'écran.
    throw Exception(
      'REST Firestore: document absent du serveur.\n'
      'Projet: $proj\n'
      'HTTP ${response.statusCode}\n'
      '${response.body}',
    );
  }

  static Future<void> deletePrediction(String id) async {
    await _col.doc(id).delete();
  }

  static Future<void> updateResult(String id, String? result) async {
    await _col.doc(id).update({'result': result});
  }
}
