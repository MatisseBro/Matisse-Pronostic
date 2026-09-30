/// Tests des règles d'autorisation pour les collections Firestore.
///
/// Ces fonctions pures reproduisent exactement la logique des règles
/// Firestore définies dans firestore.rules. Si une règle change, le test
/// correspondant doit changer aussi — et vice-versa.
///
/// Aucune dépendance Firebase : les tests tournent en millisecondes.
library;

import 'package:flutter_test/flutter_test.dart';

// ── Miroir exact des règles Firestore ─────────────────────────────────────────

/// predictions/{predId} — create
bool canCreatePrediction({
  required String? authUid,
  required String? documentAuthorUid,
}) {
  if (authUid == null) return false;
  return documentAuthorUid == authUid;
}

/// predictions/{predId} — update
/// [onlyResultChanged] : true si le diff ne touche que le champ 'result'
bool canUpdatePrediction({
  required String? authUid,
  required String? adminUid,
  required String? existingAuthorUid,
  required String? newAuthorUid,
  required bool onlyResultChanged,
}) {
  if (authUid == null) return false;
  // La règle 1 : authorUid ne peut pas changer
  if (newAuthorUid != existingAuthorUid) return false;

  final isAdmin = adminUid != null && authUid == adminUid;

  // Règle 2a : propriétaire peut tout modifier
  if (authUid == existingAuthorUid) return true;
  // Règle 2b : admin peut modifier uniquement 'result' sur n'importe quel prono
  if (isAdmin && onlyResultChanged) return true;
  // Règle 2c : admin peut tout faire sur les pronos legacy (authorUid == null)
  if (isAdmin && existingAuthorUid == null) return true;

  return false;
}

/// predictions/{predId} — delete
bool canDeletePrediction({
  required String? authUid,
  required String? adminUid,
  required String? existingAuthorUid,
}) {
  if (authUid == null) return false;
  // Propriétaire peut supprimer le sien
  if (authUid == existingAuthorUid) return true;
  // Admin peut supprimer les legacy (authorUid == null)
  if (adminUid != null && authUid == adminUid && existingAuthorUid == null) {
    return true;
  }
  return false;
}

/// users/{uid}/received/{predId} — create
bool canSharePrediction({
  required String? senderUid,
  required String documentFromUid,
  required bool senderIsFriendOfRecipient,
}) {
  if (senderUid == null) return false;
  return documentFromUid == senderUid && senderIsFriendOfRecipient;
}

/// users/{uid}/received/{predId} — update (ex. mqttStatus: 'sent')
bool canUpdateReceived({
  required String? senderUid,
  required String existingFromUid,
  required bool senderIsFriendOfRecipient,
}) {
  if (senderUid == null) return false;
  return existingFromUid == senderUid && senderIsFriendOfRecipient;
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  const alice    = 'uid-alice';
  const bob      = 'uid-bob';
  const stranger = 'uid-stranger';
  const admin    = 'uid-admin';

  // ── predictions — create ──────────────────────────────────────────────────
  group('canCreatePrediction', () {
    test('propriétaire crée avec son propre uid', () {
      expect(
        canCreatePrediction(authUid: alice, documentAuthorUid: alice),
        isTrue,
      );
    });

    test('refusé si authorUid est null (clé manquante)', () {
      expect(
        canCreatePrediction(authUid: alice, documentAuthorUid: null),
        isFalse,
      );
    });

    test('refusé si authorUid appartient à quelqu\'un d\'autre', () {
      expect(
        canCreatePrediction(authUid: alice, documentAuthorUid: bob),
        isFalse,
      );
    });

    test('refusé si non authentifié', () {
      expect(
        canCreatePrediction(authUid: null, documentAuthorUid: alice),
        isFalse,
      );
    });
  });

  // ── predictions — update ──────────────────────────────────────────────────
  group('canUpdatePrediction', () {
    test('propriétaire modifie ses propres champs (hors authorUid)', () {
      expect(
        canUpdatePrediction(
          authUid: alice, adminUid: admin,
          existingAuthorUid: alice, newAuthorUid: alice,
          onlyResultChanged: false,
        ),
        isTrue,
      );
    });

    test('propriétaire ne peut pas changer authorUid', () {
      expect(
        canUpdatePrediction(
          authUid: alice, adminUid: admin,
          existingAuthorUid: alice, newAuthorUid: bob, // tentative d'usurpation
          onlyResultChanged: false,
        ),
        isFalse,
      );
    });

    test('admin met à jour uniquement result sur le prono d\'un autre', () {
      expect(
        canUpdatePrediction(
          authUid: admin, adminUid: admin,
          existingAuthorUid: alice, newAuthorUid: alice,
          onlyResultChanged: true,
        ),
        isTrue,
      );
    });

    test('admin ne peut pas modifier d\'autres champs sur le prono d\'un autre', () {
      expect(
        canUpdatePrediction(
          authUid: admin, adminUid: admin,
          existingAuthorUid: alice, newAuthorUid: alice,
          onlyResultChanged: false,
        ),
        isFalse,
      );
    });

    test('admin peut tout modifier sur un prono legacy (authorUid null)', () {
      expect(
        canUpdatePrediction(
          authUid: admin, adminUid: admin,
          existingAuthorUid: null, newAuthorUid: null,
          onlyResultChanged: false,
        ),
        isTrue,
      );
    });

    test('admin ne peut pas modifier authorUid même sur un legacy', () {
      // Le diff détecterait authorUid null→valeur : newAuthorUid != existingAuthorUid
      expect(
        canUpdatePrediction(
          authUid: admin, adminUid: admin,
          existingAuthorUid: null, newAuthorUid: admin,
          onlyResultChanged: false,
        ),
        isFalse,
      );
    });

    test('tiers non autorisé', () {
      expect(
        canUpdatePrediction(
          authUid: stranger, adminUid: admin,
          existingAuthorUid: alice, newAuthorUid: alice,
          onlyResultChanged: true,
        ),
        isFalse,
      );
    });

    test('non authentifié refusé', () {
      expect(
        canUpdatePrediction(
          authUid: null, adminUid: admin,
          existingAuthorUid: alice, newAuthorUid: alice,
          onlyResultChanged: false,
        ),
        isFalse,
      );
    });
  });

  // ── predictions — delete ──────────────────────────────────────────────────
  group('canDeletePrediction', () {
    test('propriétaire supprime son prono', () {
      expect(
        canDeletePrediction(
          authUid: alice, adminUid: admin, existingAuthorUid: alice),
        isTrue,
      );
    });

    test('tiers ne peut pas supprimer le prono d\'un autre', () {
      expect(
        canDeletePrediction(
          authUid: stranger, adminUid: admin, existingAuthorUid: alice),
        isFalse,
      );
    });

    test('admin supprime un prono legacy (authorUid null)', () {
      expect(
        canDeletePrediction(
          authUid: admin, adminUid: admin, existingAuthorUid: null),
        isTrue,
      );
    });

    test('admin ne peut pas supprimer le prono d\'un autre utilisateur', () {
      expect(
        canDeletePrediction(
          authUid: admin, adminUid: admin, existingAuthorUid: alice),
        isFalse,
      );
    });

    test('non authentifié refusé', () {
      expect(
        canDeletePrediction(
          authUid: null, adminUid: admin, existingAuthorUid: alice),
        isFalse,
      );
    });
  });

  // ── received — create (partage) ───────────────────────────────────────────
  group('canSharePrediction', () {
    test('ami partage avec un ami', () {
      expect(
        canSharePrediction(
          senderUid: alice, documentFromUid: alice,
          senderIsFriendOfRecipient: true),
        isTrue,
      );
    });

    test('refusé si l\'expéditeur n\'est pas ami du destinataire', () {
      expect(
        canSharePrediction(
          senderUid: stranger, documentFromUid: stranger,
          senderIsFriendOfRecipient: false),
        isFalse,
      );
    });

    test('refusé si fromUid ne correspond pas à l\'identité de l\'expéditeur', () {
      // Tentative d'usurpation : Alice essaie d'envoyer sous le nom de Bob
      expect(
        canSharePrediction(
          senderUid: alice, documentFromUid: bob,
          senderIsFriendOfRecipient: true),
        isFalse,
      );
    });

    test('refusé si non authentifié', () {
      expect(
        canSharePrediction(
          senderUid: null, documentFromUid: alice,
          senderIsFriendOfRecipient: true),
        isFalse,
      );
    });
  });

  // ── received — update (mqttStatus) ───────────────────────────────────────
  group('canUpdateReceived', () {
    test('expéditeur met à jour mqttStatus', () {
      expect(
        canUpdateReceived(
          senderUid: alice, existingFromUid: alice,
          senderIsFriendOfRecipient: true),
        isTrue,
      );
    });

    test('tiers ne peut pas mettre à jour received', () {
      expect(
        canUpdateReceived(
          senderUid: stranger, existingFromUid: alice,
          senderIsFriendOfRecipient: true),
        isFalse,
      );
    });

    test('refusé si l\'amitié a été supprimée après le partage', () {
      expect(
        canUpdateReceived(
          senderUid: alice, existingFromUid: alice,
          senderIsFriendOfRecipient: false),
        isFalse,
      );
    });

    test('non authentifié refusé', () {
      expect(
        canUpdateReceived(
          senderUid: null, existingFromUid: alice,
          senderIsFriendOfRecipient: true),
        isFalse,
      );
    });
  });
}
