/// Tests de la logique d'autorisation Firestore.
///
/// Ces fonctions pures reproduisent EXACTEMENT les règles de firestore.rules.
/// Si une règle change, le test correspondant doit changer aussi.
/// Aucune dépendance Firebase — exécution en millisecondes.
///
/// Les tests d'intégration réels avec le Firebase Emulator se trouvent dans
/// test/emulator/firestore.rules.test.js (JavaScript, @firebase/rules-unit-testing).
library;

import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Miroir exact des règles Firestore (firestore.rules)
// ─────────────────────────────────────────────────────────────────────────────

/// Helper : lecture robuste d'un champ potentiellement absent.
/// Miroir de la fonction field() dans firestore.rules.
T? _field<T>(Map<String, dynamic> data, String key) =>
    data.containsKey(key) ? data[key] as T? : null;

// ── predictions — create ──────────────────────────────────────────────────────
bool canCreatePrediction({
  required String? authUid,
  required String? documentAuthorUid,
}) {
  if (authUid == null) return false;
  return documentAuthorUid == authUid;
}

// ── predictions — update ──────────────────────────────────────────────────────
/// [existingData] : document actuel (peut ne pas contenir 'authorUid')
/// [newAuthorUid] : valeur de authorUid dans la version mise à jour
/// [onlyResultChanged] : true si le diff n'affecte que 'result'
bool canUpdatePrediction({
  required String? authUid,
  required String? adminUid,
  required Map<String, dynamic> existingData,
  required String? newAuthorUid,
  required bool onlyResultChanged,
}) {
  if (authUid == null) return false;

  final existingAuthorUid = _field<String>(existingData, 'authorUid');
  final isAdmin = adminUid != null && authUid == adminUid;

  // Règle (1) : authorUid immuable
  if (newAuthorUid != existingAuthorUid) return false;

  // Règle (2a) : propriétaire
  if (authUid == existingAuthorUid) return true;
  // Règle (2b) : admin → uniquement 'result'
  if (isAdmin && onlyResultChanged) return true;
  // Règle (2c) : admin → legacy (authorUid absent ou null)
  if (isAdmin && existingAuthorUid == null) return true;

  return false;
}

// ── predictions — delete ──────────────────────────────────────────────────────
bool canDeletePrediction({
  required String? authUid,
  required String? adminUid,
  required Map<String, dynamic> existingData,
}) {
  if (authUid == null) return false;
  final existingAuthorUid = _field<String>(existingData, 'authorUid');
  if (authUid == existingAuthorUid) return true;
  if (adminUid != null && authUid == adminUid && existingAuthorUid == null) {
    return true;
  }
  return false;
}

// ── users — create profile ────────────────────────────────────────────────────
bool canCreateProfile({
  required String? authUid,
  required String? authEmail,
  required String? pathUid,
  required String? documentUid,
  required String? documentEmail,
}) {
  if (authUid == null) return false;
  if (authUid != pathUid) return false;
  if (documentUid != authUid) return false;
  if (documentEmail != authEmail) return false;
  return true;
}

// ── users — update profile ────────────────────────────────────────────────────
bool canUpdateProfile({
  required String? authUid,
  required String? pathUid,
  required String? existingUid,
  required String? newUid,
  required String? existingEmail,
  required String? newEmail,
  required String? newDeviceId,    // null = dissociation
}) {
  if (authUid == null || authUid != pathUid) return false;
  if (newUid != existingUid) return false;
  if (newEmail != existingEmail) return false;
  // deviceId doit être null ou respecter le format MatiMatch_XXXXXXXXXXXX
  if (newDeviceId != null &&
      !RegExp(r'^MatiMatch_[0-9A-Fa-f]{12}$').hasMatch(newDeviceId)) {
    return false;
  }
  return true;
}

// ── users/friends — écriture ──────────────────────────────────────────────────
/// [uid] : propriétaire de la liste
/// [friendUid] : clé du document dans la liste
/// [documentUid] : champ 'uid' dans le document à créer
bool canAddToFriendList({
  required String? authUid,
  required String uid,
  required String friendUid,
  required String? documentUid,
}) {
  if (authUid == null) return false;
  // Règle owner
  if (authUid == uid) return true;
  // Règle self-insert : l'utilisateur représenté par friendUid s'ajoute
  // lui-même, et le document contient son propre uid
  if (authUid == friendUid && documentUid == authUid) return true;
  return false;
}

bool canRemoveFromFriendList({
  required String? authUid,
  required String uid,
  required String friendUid,
}) {
  if (authUid == null) return false;
  if (authUid == uid) return true;      // owner supprime
  if (authUid == friendUid) return true; // self-remove
  return false;
}

// ── users/received — create ───────────────────────────────────────────────────
bool canSharePrediction({
  required String? senderUid,
  required String documentFromUid,
  required bool senderIsFriendOfRecipient,
}) {
  if (senderUid == null) return false;
  return documentFromUid == senderUid && senderIsFriendOfRecipient;
}

// ── users/received — update ───────────────────────────────────────────────────
/// Seule transition autorisée : mqttStatus 'pending' → 'sent'.
/// [changedFields] : ensemble des champs modifiés par l'update.
bool canUpdateReceivedMqttStatus({
  required String? senderUid,
  required String existingFromUid,
  required bool senderIsFriendOfRecipient,
  required Set<String> changedFields,
  required String existingMqttStatus,
  required String newMqttStatus,
}) {
  if (senderUid == null) return false;
  if (existingFromUid != senderUid) return false;
  if (!senderIsFriendOfRecipient) return false;
  // Seul mqttStatus peut changer
  if (!changedFields.containsAll({'mqttStatus'}) || changedFields.length != 1) {
    return false;
  }
  // Transition pending → sent uniquement
  if (existingMqttStatus != 'pending') return false;
  if (newMqttStatus != 'sent') return false;
  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// TESTS
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  const alice = 'uid-alice';
  const bob   = 'uid-bob';
  const admin = 'uid-admin';
  const other = 'uid-other';

  // ── predictions — create ───────────────────────────────────────────────────
  group('canCreatePrediction', () {
    test('propriétaire crée avec son propre uid', () {
      expect(canCreatePrediction(authUid: alice, documentAuthorUid: alice), isTrue);
    });
    test('refusé si authorUid est null', () {
      expect(canCreatePrediction(authUid: alice, documentAuthorUid: null), isFalse);
    });
    test('refusé si authorUid appartient à un autre', () {
      expect(canCreatePrediction(authUid: alice, documentAuthorUid: bob), isFalse);
    });
    test('refusé si non authentifié', () {
      expect(canCreatePrediction(authUid: null, documentAuthorUid: alice), isFalse);
    });
  });

  // ── predictions — update ───────────────────────────────────────────────────
  group('canUpdatePrediction', () {
    final aliceDoc  = {'authorUid': alice, 'matchLabel': 'A-B'};
    final legacyDoc = {'matchLabel': 'A-B'}; // authorUid ABSENT

    test('propriétaire modifie ses propres champs', () {
      expect(canUpdatePrediction(
        authUid: alice, adminUid: admin, existingData: aliceDoc,
        newAuthorUid: alice, onlyResultChanged: false), isTrue);
    });

    test('propriétaire ne peut pas changer authorUid', () {
      expect(canUpdatePrediction(
        authUid: alice, adminUid: admin, existingData: aliceDoc,
        newAuthorUid: bob, onlyResultChanged: false), isFalse);
    });

    test('admin modifie uniquement result sur le prono d\'un autre', () {
      expect(canUpdatePrediction(
        authUid: admin, adminUid: admin, existingData: aliceDoc,
        newAuthorUid: alice, onlyResultChanged: true), isTrue);
    });

    test('admin ne peut pas modifier d\'autres champs sur le prono d\'un autre', () {
      expect(canUpdatePrediction(
        authUid: admin, adminUid: admin, existingData: aliceDoc,
        newAuthorUid: alice, onlyResultChanged: false), isFalse);
    });

    test('admin modifie un prono legacy (authorUid ABSENT)', () {
      expect(canUpdatePrediction(
        authUid: admin, adminUid: admin, existingData: legacyDoc,
        newAuthorUid: null, onlyResultChanged: false), isTrue);
    });

    test('admin ne peut pas changer authorUid sur un legacy', () {
      // newAuthorUid=admin ≠ existingAuthorUid=null → règle (1) bloque
      expect(canUpdatePrediction(
        authUid: admin, adminUid: admin, existingData: legacyDoc,
        newAuthorUid: admin, onlyResultChanged: false), isFalse);
    });

    test('tiers non autorisé', () {
      expect(canUpdatePrediction(
        authUid: other, adminUid: admin, existingData: aliceDoc,
        newAuthorUid: alice, onlyResultChanged: true), isFalse);
    });

    test('non authentifié refusé', () {
      expect(canUpdatePrediction(
        authUid: null, adminUid: admin, existingData: aliceDoc,
        newAuthorUid: alice, onlyResultChanged: false), isFalse);
    });
  });

  // ── predictions — delete ───────────────────────────────────────────────────
  group('canDeletePrediction', () {
    final aliceDoc  = {'authorUid': alice};
    final legacyDoc = <String, dynamic>{};

    test('propriétaire supprime son prono', () {
      expect(canDeletePrediction(
        authUid: alice, adminUid: admin, existingData: aliceDoc), isTrue);
    });

    test('tiers ne peut pas supprimer le prono d\'un autre', () {
      expect(canDeletePrediction(
        authUid: other, adminUid: admin, existingData: aliceDoc), isFalse);
    });

    test('admin supprime un prono legacy', () {
      expect(canDeletePrediction(
        authUid: admin, adminUid: admin, existingData: legacyDoc), isTrue);
    });

    test('admin ne peut pas supprimer le prono d\'un autre utilisateur', () {
      expect(canDeletePrediction(
        authUid: admin, adminUid: admin, existingData: aliceDoc), isFalse);
    });

    test('non authentifié refusé', () {
      expect(canDeletePrediction(
        authUid: null, adminUid: admin, existingData: aliceDoc), isFalse);
    });
  });

  // ── users — create profile ─────────────────────────────────────────────────
  group('canCreateProfile', () {
    test('création valide', () {
      expect(canCreateProfile(
        authUid: alice, authEmail: 'alice@t.com',
        pathUid: alice,
        documentUid: alice, documentEmail: 'alice@t.com'), isTrue);
    });

    test('refusé si uid dans le document ≠ uid du chemin', () {
      expect(canCreateProfile(
        authUid: alice, authEmail: 'alice@t.com',
        pathUid: alice,
        documentUid: bob, documentEmail: 'alice@t.com'), isFalse);
    });

    test('refusé si email ≠ email du token', () {
      expect(canCreateProfile(
        authUid: alice, authEmail: 'alice@t.com',
        pathUid: alice,
        documentUid: alice, documentEmail: 'eve@t.com'), isFalse);
    });

    test('refusé si on écrit dans le profil d\'un autre (pathUid ≠ authUid)', () {
      expect(canCreateProfile(
        authUid: alice, authEmail: 'alice@t.com',
        pathUid: bob,
        documentUid: bob, documentEmail: 'bob@t.com'), isFalse);
    });
  });

  // ── users — update profile ─────────────────────────────────────────────────
  group('canUpdateProfile', () {
    test('modification du displayName — uid et email inchangés', () {
      expect(canUpdateProfile(
        authUid: alice, pathUid: alice,
        existingUid: alice, newUid: alice,
        existingEmail: 'alice@t.com', newEmail: 'alice@t.com',
        newDeviceId: null), isTrue);
    });

    test('association d\'un deviceId au bon format', () {
      expect(canUpdateProfile(
        authUid: alice, pathUid: alice,
        existingUid: alice, newUid: alice,
        existingEmail: 'alice@t.com', newEmail: 'alice@t.com',
        newDeviceId: 'MatiMatch_AABBCCDDEEFF'), isTrue);
    });

    test('dissociation de l\'appareil (deviceId null)', () {
      expect(canUpdateProfile(
        authUid: alice, pathUid: alice,
        existingUid: alice, newUid: alice,
        existingEmail: 'alice@t.com', newEmail: 'alice@t.com',
        newDeviceId: null), isTrue);
    });

    test('refusé si deviceId au mauvais format', () {
      expect(canUpdateProfile(
        authUid: alice, pathUid: alice,
        existingUid: alice, newUid: alice,
        existingEmail: 'alice@t.com', newEmail: 'alice@t.com',
        newDeviceId: 'esp32-device'), isFalse);
    });

    test('refusé si tentative de changement d\'email', () {
      expect(canUpdateProfile(
        authUid: alice, pathUid: alice,
        existingUid: alice, newUid: alice,
        existingEmail: 'alice@t.com', newEmail: 'eve@t.com',
        newDeviceId: null), isFalse);
    });

    test('refusé si tentative de changement d\'uid', () {
      expect(canUpdateProfile(
        authUid: alice, pathUid: alice,
        existingUid: alice, newUid: bob,
        existingEmail: 'alice@t.com', newEmail: 'alice@t.com',
        newDeviceId: null), isFalse);
    });

    test('tiers ne peut pas modifier le profil d\'un autre', () {
      expect(canUpdateProfile(
        authUid: bob, pathUid: alice,
        existingUid: alice, newUid: alice,
        existingEmail: 'alice@t.com', newEmail: 'alice@t.com',
        newDeviceId: null), isFalse);
    });
  });

  // ── users/friends — écriture ───────────────────────────────────────────────
  group('canAddToFriendList', () {
    test('propriétaire ajoute un ami dans sa liste', () {
      expect(canAddToFriendList(
        authUid: alice, uid: alice, friendUid: bob, documentUid: bob), isTrue);
    });

    test('self-insert : Bob s\'ajoute à la liste d\'Alice avec son propre uid', () {
      expect(canAddToFriendList(
        authUid: bob, uid: alice, friendUid: bob, documentUid: bob), isTrue);
    });

    test('self-insert refusé si documentUid ≠ auth.uid (usurpation)', () {
      // Alice essaie d'insérer Charlie dans la liste de Bob
      expect(canAddToFriendList(
        authUid: alice, uid: bob, friendUid: other, documentUid: other), isFalse);
    });

    test('tiers ne peut pas écrire dans la liste d\'un autre', () {
      expect(canAddToFriendList(
        authUid: other, uid: alice, friendUid: bob, documentUid: bob), isFalse);
    });
  });

  group('canRemoveFromFriendList', () {
    test('propriétaire supprime de sa liste', () {
      expect(canRemoveFromFriendList(
        authUid: alice, uid: alice, friendUid: bob), isTrue);
    });

    test('self-remove : Bob se retire de la liste d\'Alice', () {
      expect(canRemoveFromFriendList(
        authUid: bob, uid: alice, friendUid: bob), isTrue);
    });

    test('tiers ne peut pas supprimer depuis la liste d\'un autre', () {
      expect(canRemoveFromFriendList(
        authUid: other, uid: alice, friendUid: bob), isFalse);
    });
  });

  // ── users/received — create ────────────────────────────────────────────────
  group('canSharePrediction', () {
    test('ami partage avec un ami', () {
      expect(canSharePrediction(
        senderUid: alice, documentFromUid: alice,
        senderIsFriendOfRecipient: true), isTrue);
    });

    test('refusé si non ami', () {
      expect(canSharePrediction(
        senderUid: other, documentFromUid: other,
        senderIsFriendOfRecipient: false), isFalse);
    });

    test('refusé si fromUid ≠ senderUid (usurpation)', () {
      expect(canSharePrediction(
        senderUid: alice, documentFromUid: bob,
        senderIsFriendOfRecipient: true), isFalse);
    });

    test('refusé si non authentifié', () {
      expect(canSharePrediction(
        senderUid: null, documentFromUid: alice,
        senderIsFriendOfRecipient: true), isFalse);
    });
  });

  // ── users/received — update (mqttStatus) ──────────────────────────────────
  group('canUpdateReceivedMqttStatus', () {
    test('transition valide : pending → sent', () {
      expect(canUpdateReceivedMqttStatus(
        senderUid: alice, existingFromUid: alice,
        senderIsFriendOfRecipient: true,
        changedFields: {'mqttStatus'},
        existingMqttStatus: 'pending', newMqttStatus: 'sent'), isTrue);
    });

    test('refusé si on modifie un autre champ en plus de mqttStatus', () {
      expect(canUpdateReceivedMqttStatus(
        senderUid: alice, existingFromUid: alice,
        senderIsFriendOfRecipient: true,
        changedFields: {'mqttStatus', 'odds'},
        existingMqttStatus: 'pending', newMqttStatus: 'sent'), isFalse);
    });

    test('refusé si on ne modifie pas mqttStatus du tout', () {
      expect(canUpdateReceivedMqttStatus(
        senderUid: alice, existingFromUid: alice,
        senderIsFriendOfRecipient: true,
        changedFields: {'odds'},
        existingMqttStatus: 'pending', newMqttStatus: 'pending'), isFalse);
    });

    test('refusé : transition inverse sent → pending', () {
      expect(canUpdateReceivedMqttStatus(
        senderUid: alice, existingFromUid: alice,
        senderIsFriendOfRecipient: true,
        changedFields: {'mqttStatus'},
        existingMqttStatus: 'sent', newMqttStatus: 'pending'), isFalse);
    });

    test('refusé si l\'amitié a été supprimée après le partage', () {
      expect(canUpdateReceivedMqttStatus(
        senderUid: alice, existingFromUid: alice,
        senderIsFriendOfRecipient: false,
        changedFields: {'mqttStatus'},
        existingMqttStatus: 'pending', newMqttStatus: 'sent'), isFalse);
    });

    test('tiers ne peut pas mettre à jour received', () {
      expect(canUpdateReceivedMqttStatus(
        senderUid: other, existingFromUid: alice,
        senderIsFriendOfRecipient: true,
        changedFields: {'mqttStatus'},
        existingMqttStatus: 'pending', newMqttStatus: 'sent'), isFalse);
    });

    test('non authentifié refusé', () {
      expect(canUpdateReceivedMqttStatus(
        senderUid: null, existingFromUid: alice,
        senderIsFriendOfRecipient: true,
        changedFields: {'mqttStatus'},
        existingMqttStatus: 'pending', newMqttStatus: 'sent'), isFalse);
    });
  });
}
