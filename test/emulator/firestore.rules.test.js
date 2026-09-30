/**
 * Tests des règles Firestore — Firebase Emulator
 *
 * Prérequis :
 *   npm install  (dans ce dossier)
 *   firebase-tools CLI : npm install -g firebase-tools
 *
 * Lancer les tests :
 *   Depuis la racine du projet Flutter :
 *     firebase emulators:exec --only firestore "cd test/emulator && npm test"
 *
 *   Ou en deux terminaux :
 *     [1] firebase emulators:start --only firestore
 *     [2] cd test/emulator && npm test
 */

'use strict';

const { initializeTestEnvironment, assertFails, assertSucceeds } =
  require('@firebase/rules-unit-testing');
const {
  doc, setDoc, updateDoc, deleteDoc, getDoc,
  collection, addDoc,
} = require('firebase/firestore');
const fs   = require('fs');
const path = require('path');
const assert = require('assert');

// ── Identifiants simulés ──────────────────────────────────────────────────────
const ADMIN_UID   = 'uFiFjKTYUzSDlPITAC7gx9ElPcC3';
const ALICE_UID   = 'uid-alice';
const BOB_UID     = 'uid-bob';
const CHARLIE_UID = 'uid-charlie';

const ALICE_EMAIL   = 'alice@test.com';
const BOB_EMAIL     = 'bob@test.com';
const CHARLIE_EMAIL = 'charlie@test.com';
const ADMIN_EMAIL   = 'admin@test.com';

// ── Environnement ─────────────────────────────────────────────────────────────
let testEnv;

before(async () => {
  const rulesPath = path.resolve(__dirname, '../../firestore.rules');
  testEnv = await initializeTestEnvironment({
    projectId:  'matimatch-test',
    firestore: {
      rules: fs.readFileSync(rulesPath, 'utf8'),
      host:  '127.0.0.1',
      port:  8080,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Contexte Firebase authentifié */
function auth(uid, email) {
  return testEnv.authenticatedContext(uid, { email });
}

/** Contexte Firebase non authentifié */
function anon() {
  return testEnv.unauthenticatedContext();
}

/** Crée un pronostic legacy (sans authorUid) via le bypass admin Firestore */
async function createLegacyPrediction(id) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'predictions', id), {
      matchLabel: 'Monaco - PSG', selection: '1',
      odds: 2.10, confidence: 3,
      createdAt: new Date().toISOString(),
      // authorUid intentionnellement absent
    });
  });
}

/** Crée un pronostic standard (avec authorUid) */
async function createPrediction(id, ownerUid) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'predictions', id), {
      matchLabel: 'Lyon - Rennes', selection: '2',
      odds: 3.00, confidence: 4,
      createdAt: new Date().toISOString(),
      authorUid: ownerUid,
    });
  });
}

/** Crée le profil d'un utilisateur */
async function createProfile(uid, email) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', uid), {
      uid, email, displayName: email.split('@')[0],
      createdAt: new Date().toISOString(),
    });
  });
}

/** Crée une relation d'amitié bidirectionnelle */
async function createFriendship(uidA, nameA, emailA, uidB, nameB, emailB) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(
      doc(ctx.firestore(), 'users', uidA, 'friends', uidB),
      { uid: uidB, displayName: nameB, email: emailB }
    );
    await setDoc(
      doc(ctx.firestore(), 'users', uidB, 'friends', uidA),
      { uid: uidA, displayName: nameA, email: emailA }
    );
  });
}

/** Crée un pronostic reçu */
async function createReceived(recipientUid, predId, fromUid, status = 'pending') {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(
      doc(ctx.firestore(), 'users', recipientUid, 'received', predId),
      {
        id: predId, fromUid, fromName: 'Expéditeur',
        matchLabel: 'PSG - Lyon', selection: '1',
        odds: 1.65, confidence: 4, comment: '',
        createdAt: new Date().toISOString(),
        mqttStatus: status,
      }
    );
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// predictions — LECTURE
// ═════════════════════════════════════════════════════════════════════════════
describe('predictions — read', () => {
  before(async () => { await createPrediction('p1', ALICE_UID); });

  it('utilisateur authentifié peut lire', async () => {
    const db = auth(BOB_UID, BOB_EMAIL).firestore();
    await assertSucceeds(getDoc(doc(db, 'predictions', 'p1')));
  });

  it('non authentifié ne peut pas lire', async () => {
    const db = anon().firestore();
    await assertFails(getDoc(doc(db, 'predictions', 'p1')));
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// predictions — CREATE
// ═════════════════════════════════════════════════════════════════════════════
describe('predictions — create', () => {
  const base = {
    matchLabel: 'Nantes - Metz', selection: '1',
    odds: 1.80, confidence: 3,
    createdAt: new Date().toISOString(),
  };

  it('propriétaire crée avec son propre authorUid', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertSucceeds(
      setDoc(doc(db, 'predictions', 'new1'), { ...base, authorUid: ALICE_UID })
    );
  });

  it('refusé si authorUid est null', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertFails(
      setDoc(doc(db, 'predictions', 'new2'), { ...base, authorUid: null })
    );
  });

  it('refusé si authorUid appartient à un autre utilisateur', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertFails(
      setDoc(doc(db, 'predictions', 'new3'), { ...base, authorUid: BOB_UID })
    );
  });

  it('refusé si non authentifié', async () => {
    const db = anon().firestore();
    await assertFails(
      setDoc(doc(db, 'predictions', 'new4'), { ...base, authorUid: ALICE_UID })
    );
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// predictions — UPDATE
// ═════════════════════════════════════════════════════════════════════════════
describe('predictions — update', () => {
  beforeEach(async () => {
    await createPrediction('pu1', ALICE_UID);
    await createLegacyPrediction('plegacy');
  });

  it('propriétaire modifie ses propres champs', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertSucceeds(updateDoc(doc(db, 'predictions', 'pu1'), { confidence: 5 }));
  });

  it('propriétaire ne peut pas changer authorUid', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertFails(updateDoc(doc(db, 'predictions', 'pu1'), { authorUid: BOB_UID }));
  });

  it('admin modifie uniquement result sur le prono d\'un autre', async () => {
    const db = auth(ADMIN_UID, ADMIN_EMAIL).firestore();
    await assertSucceeds(updateDoc(doc(db, 'predictions', 'pu1'), { result: 'won' }));
  });

  it('admin ne peut pas modifier d\'autres champs sur le prono d\'un autre', async () => {
    const db = auth(ADMIN_UID, ADMIN_EMAIL).firestore();
    await assertFails(updateDoc(doc(db, 'predictions', 'pu1'), { confidence: 5 }));
  });

  it('admin modifie un prono legacy (authorUid absent)', async () => {
    const db = auth(ADMIN_UID, ADMIN_EMAIL).firestore();
    await assertSucceeds(updateDoc(doc(db, 'predictions', 'plegacy'), { result: 'lost' }));
  });

  it('tiers ne peut pas modifier le prono d\'un autre', async () => {
    const db = auth(BOB_UID, BOB_EMAIL).firestore();
    await assertFails(updateDoc(doc(db, 'predictions', 'pu1'), { result: 'won' }));
  });

  it('non authentifié refusé', async () => {
    const db = anon().firestore();
    await assertFails(updateDoc(doc(db, 'predictions', 'pu1'), { result: 'won' }));
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// predictions — DELETE
// ═════════════════════════════════════════════════════════════════════════════
describe('predictions — delete', () => {
  beforeEach(async () => {
    await createPrediction('pd1', ALICE_UID);
    await createPrediction('pd2', BOB_UID);
    await createLegacyPrediction('pdlegacy');
  });

  it('propriétaire supprime son propre prono', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertSucceeds(deleteDoc(doc(db, 'predictions', 'pd1')));
  });

  it('tiers ne peut pas supprimer le prono d\'un autre', async () => {
    const db = auth(CHARLIE_UID, CHARLIE_EMAIL).firestore();
    await assertFails(deleteDoc(doc(db, 'predictions', 'pd1')));
  });

  it('admin supprime un prono legacy', async () => {
    const db = auth(ADMIN_UID, ADMIN_EMAIL).firestore();
    await assertSucceeds(deleteDoc(doc(db, 'predictions', 'pdlegacy')));
  });

  it('admin ne peut pas supprimer le prono d\'un autre utilisateur', async () => {
    const db = auth(ADMIN_UID, ADMIN_EMAIL).firestore();
    await assertFails(deleteDoc(doc(db, 'predictions', 'pd1')));
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// users — PROFIL
// ═════════════════════════════════════════════════════════════════════════════
describe('users — create profile', () => {
  it('création valide : uid et email cohérents avec le token', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertSucceeds(setDoc(doc(db, 'users', ALICE_UID), {
      uid: ALICE_UID, email: ALICE_EMAIL,
      displayName: 'Alice', createdAt: new Date().toISOString(),
    }));
  });

  it('refusé si uid dans le document ≠ uid dans le chemin', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertFails(setDoc(doc(db, 'users', ALICE_UID), {
      uid: BOB_UID, email: ALICE_EMAIL,
      displayName: 'Alice', createdAt: new Date().toISOString(),
    }));
  });

  it('refusé si email dans le document ≠ email du token Firebase Auth', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertFails(setDoc(doc(db, 'users', ALICE_UID), {
      uid: ALICE_UID, email: BOB_EMAIL,
      displayName: 'Alice', createdAt: new Date().toISOString(),
    }));
  });

  it('refusé si on écrit dans le profil d\'un autre', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertFails(setDoc(doc(db, 'users', BOB_UID), {
      uid: BOB_UID, email: BOB_EMAIL, displayName: 'Alice',
    }));
  });
});

describe('users — update profile', () => {
  beforeEach(async () => {
    await createProfile(ALICE_UID, ALICE_EMAIL);
  });

  it('propriétaire modifie son displayName', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertSucceeds(updateDoc(doc(db, 'users', ALICE_UID), {
      displayName: 'Alice Pro',
    }));
  });

  it('propriétaire associe un deviceId au bon format', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertSucceeds(updateDoc(doc(db, 'users', ALICE_UID), {
      deviceId: 'MatiMatch_AABBCCDDEEFF',
    }));
  });

  it('propriétaire dissocie son appareil (deviceId null)', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertSucceeds(updateDoc(doc(db, 'users', ALICE_UID), {
      deviceId: null,
    }));
  });

  it('refusé si deviceId ne respecte pas le format MatiMatch_*', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertFails(updateDoc(doc(db, 'users', ALICE_UID), {
      deviceId: 'esp32-device-123',
    }));
  });

  it('refusé si on tente de changer l\'email', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertFails(updateDoc(doc(db, 'users', ALICE_UID), {
      email: 'newalice@test.com',
    }));
  });

  it('refusé si on tente de changer l\'uid', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertFails(updateDoc(doc(db, 'users', ALICE_UID), {
      uid: BOB_UID,
    }));
  });

  it('tiers ne peut pas modifier le profil d\'un autre', async () => {
    const db = auth(BOB_UID, BOB_EMAIL).firestore();
    await assertFails(updateDoc(doc(db, 'users', ALICE_UID), {
      displayName: 'Hacker',
    }));
  });
});

describe('users — read profile', () => {
  before(async () => { await createProfile(ALICE_UID, ALICE_EMAIL); });

  it('tout utilisateur authentifié peut lire un profil (findByEmail)', async () => {
    const db = auth(BOB_UID, BOB_EMAIL).firestore();
    await assertSucceeds(getDoc(doc(db, 'users', ALICE_UID)));
  });

  it('non authentifié ne peut pas lire un profil', async () => {
    const db = anon().firestore();
    await assertFails(getDoc(doc(db, 'users', ALICE_UID)));
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// users/friends — AMIS
// ═════════════════════════════════════════════════════════════════════════════
describe('users/friends — écriture', () => {
  it('propriétaire ajoute un ami dans sa propre liste', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertSucceeds(setDoc(
      doc(db, 'users', ALICE_UID, 'friends', BOB_UID),
      { uid: BOB_UID, displayName: 'Bob', email: BOB_EMAIL }
    ));
  });

  it('self-insert : Bob s\'ajoute à la liste d\'Alice (uid du doc == auth.uid)', async () => {
    const db = auth(BOB_UID, BOB_EMAIL).firestore();
    await assertSucceeds(setDoc(
      doc(db, 'users', ALICE_UID, 'friends', BOB_UID),
      { uid: BOB_UID, displayName: 'Bob', email: BOB_EMAIL }
    ));
  });

  it('self-insert refusé si uid dans le document ≠ auth.uid (usurpation)', async () => {
    // Alice essaie d'ajouter Charlie dans la liste de Bob en se faisant passer pour Charlie
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertFails(setDoc(
      doc(db, 'users', BOB_UID, 'friends', CHARLIE_UID),
      { uid: CHARLIE_UID, displayName: 'Charlie', email: CHARLIE_EMAIL }
    ));
  });

  it('tiers ne peut pas écrire dans la liste d\'amis d\'un autre (cas général)', async () => {
    // Charlie essaie d'écrire dans la liste de Bob, en créant un doc avec uid=Alice
    const db = auth(CHARLIE_UID, CHARLIE_EMAIL).firestore();
    await assertFails(setDoc(
      doc(db, 'users', BOB_UID, 'friends', ALICE_UID),
      { uid: ALICE_UID, displayName: 'Alice', email: ALICE_EMAIL }
    ));
  });

  it('self-remove : Bob se retire de la liste d\'Alice', async () => {
    await createFriendship(ALICE_UID, 'Alice', ALICE_EMAIL, BOB_UID, 'Bob', BOB_EMAIL);
    const db = auth(BOB_UID, BOB_EMAIL).firestore();
    await assertSucceeds(deleteDoc(
      doc(db, 'users', ALICE_UID, 'friends', BOB_UID)
    ));
  });
});

describe('users/friends — lecture', () => {
  before(async () => {
    await createFriendship(ALICE_UID, 'Alice', ALICE_EMAIL, BOB_UID, 'Bob', BOB_EMAIL);
  });

  it('propriétaire lit sa liste', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertSucceeds(getDoc(doc(db, 'users', ALICE_UID, 'friends', BOB_UID)));
  });

  it('tiers ne peut pas lire la liste d\'amis d\'un autre', async () => {
    const db = auth(CHARLIE_UID, CHARLIE_EMAIL).firestore();
    await assertFails(getDoc(doc(db, 'users', ALICE_UID, 'friends', BOB_UID)));
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// users/received — PRONOSTICS REÇUS
// ═════════════════════════════════════════════════════════════════════════════
describe('users/received — lecture', () => {
  before(async () => {
    await createFriendship(ALICE_UID, 'Alice', ALICE_EMAIL, BOB_UID, 'Bob', BOB_EMAIL);
    await createReceived(BOB_UID, 'r1', ALICE_UID);
  });

  it('destinataire lit ses pronostics reçus', async () => {
    const db = auth(BOB_UID, BOB_EMAIL).firestore();
    await assertSucceeds(getDoc(doc(db, 'users', BOB_UID, 'received', 'r1')));
  });

  it('tiers ne peut pas lire les pronostics reçus d\'un autre', async () => {
    const db = auth(CHARLIE_UID, CHARLIE_EMAIL).firestore();
    await assertFails(getDoc(doc(db, 'users', BOB_UID, 'received', 'r1')));
  });
});

describe('users/received — create (partage)', () => {
  const sharedPred = {
    id: 'rtest', fromUid: ALICE_UID, fromName: 'Alice',
    matchLabel: 'PSG - Lyon', selection: '1',
    odds: 1.65, confidence: 4, comment: '',
    createdAt: new Date().toISOString(), mqttStatus: 'pending',
  };

  beforeEach(async () => {
    await createFriendship(ALICE_UID, 'Alice', ALICE_EMAIL, BOB_UID, 'Bob', BOB_EMAIL);
  });

  it('ami partage un pronostic avec un ami', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertSucceeds(setDoc(
      doc(db, 'users', BOB_UID, 'received', 'rtest'),
      sharedPred
    ));
  });

  it('refusé si fromUid ≠ auth.uid (usurpation d\'identité)', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertFails(setDoc(
      doc(db, 'users', BOB_UID, 'received', 'rusurp'),
      { ...sharedPred, fromUid: CHARLIE_UID }
    ));
  });

  it('refusé si l\'expéditeur n\'est pas ami du destinataire', async () => {
    const db = auth(CHARLIE_UID, CHARLIE_EMAIL).firestore();
    await assertFails(setDoc(
      doc(db, 'users', BOB_UID, 'received', 'rnonfriend'),
      { ...sharedPred, fromUid: CHARLIE_UID, fromName: 'Charlie' }
    ));
  });

  it('refusé si non authentifié', async () => {
    const db = anon().firestore();
    await assertFails(setDoc(
      doc(db, 'users', BOB_UID, 'received', 'ranon'),
      sharedPred
    ));
  });
});

describe('users/received — update (mqttStatus uniquement)', () => {
  beforeEach(async () => {
    await createFriendship(ALICE_UID, 'Alice', ALICE_EMAIL, BOB_UID, 'Bob', BOB_EMAIL);
    await createReceived(BOB_UID, 'ru1', ALICE_UID, 'pending');
    await createReceived(BOB_UID, 'ru_sent', ALICE_UID, 'sent');
  });

  it('expéditeur met à jour mqttStatus pending → sent', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertSucceeds(updateDoc(
      doc(db, 'users', BOB_UID, 'received', 'ru1'),
      { mqttStatus: 'sent' }
    ));
  });

  it('refusé si on tente de modifier un autre champ (ex. matchLabel)', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertFails(updateDoc(
      doc(db, 'users', BOB_UID, 'received', 'ru1'),
      { matchLabel: 'Nouveau match' }
    ));
  });

  it('refusé si on tente de modifier mqttStatus ET un autre champ simultanément', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertFails(updateDoc(
      doc(db, 'users', BOB_UID, 'received', 'ru1'),
      { mqttStatus: 'sent', odds: 9.99 }
    ));
  });

  it('refusé si transition inverse : sent → pending', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertFails(updateDoc(
      doc(db, 'users', BOB_UID, 'received', 'ru_sent'),
      { mqttStatus: 'pending' }
    ));
  });

  it('tiers ne peut pas mettre à jour received', async () => {
    const db = auth(CHARLIE_UID, CHARLIE_EMAIL).firestore();
    await assertFails(updateDoc(
      doc(db, 'users', BOB_UID, 'received', 'ru1'),
      { mqttStatus: 'sent' }
    ));
  });

  it('destinataire ne peut pas modifier ses received', async () => {
    const db = auth(BOB_UID, BOB_EMAIL).firestore();
    await assertFails(updateDoc(
      doc(db, 'users', BOB_UID, 'received', 'ru1'),
      { mqttStatus: 'sent' }
    ));
  });
});

describe('users/received — delete interdit', () => {
  beforeEach(async () => {
    await createFriendship(ALICE_UID, 'Alice', ALICE_EMAIL, BOB_UID, 'Bob', BOB_EMAIL);
    await createReceived(BOB_UID, 'rd1', ALICE_UID);
  });

  it('destinataire ne peut pas supprimer ses received', async () => {
    const db = auth(BOB_UID, BOB_EMAIL).firestore();
    await assertFails(deleteDoc(doc(db, 'users', BOB_UID, 'received', 'rd1')));
  });

  it('expéditeur ne peut pas supprimer un received', async () => {
    const db = auth(ALICE_UID, ALICE_EMAIL).firestore();
    await assertFails(deleteDoc(doc(db, 'users', BOB_UID, 'received', 'rd1')));
  });
});
