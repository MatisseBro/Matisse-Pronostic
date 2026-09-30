'use strict';

const { initializeTestEnvironment, assertFails, assertSucceeds } =
  require('@firebase/rules-unit-testing');
const {
  doc, setDoc, updateDoc, deleteDoc, getDoc,
} = require('firebase/firestore');
const fs   = require('fs');
const path = require('path');

// ── Identifiants simulés ──────────────────────────────────────────────────────
const ADMIN_UID   = 'uFiFjKTYUzSDlPITAC7gx9ElPcC3';
const ALICE_UID   = 'uid-alice';
const BOB_UID     = 'uid-bob';
const CHARLIE_UID = 'uid-charlie';

const ALICE_EMAIL   = 'alice@test.com';
const BOB_EMAIL     = 'bob@test.com';
const CHARLIE_EMAIL = 'charlie@test.com';
const ADMIN_EMAIL   = 'admin@test.com';

// ── Environnement & instances Firestore ───────────────────────────────────────
// Instances créées UNE SEULE FOIS — évite "Firestore has already been started".
let testEnv;
let aliceDb, bobDb, charlieDb, adminDb, anonDb;

before(async () => {
  const rulesPath = path.resolve(__dirname, '../../firestore.rules');
  testEnv = await initializeTestEnvironment({
    projectId: 'matimatch-test',
    firestore: {
      rules: fs.readFileSync(rulesPath, 'utf8'),
      host:  '127.0.0.1',
      port:  8080,
    },
  });

  aliceDb   = testEnv.authenticatedContext(ALICE_UID,   { email: ALICE_EMAIL   }).firestore();
  bobDb     = testEnv.authenticatedContext(BOB_UID,     { email: BOB_EMAIL     }).firestore();
  charlieDb = testEnv.authenticatedContext(CHARLIE_UID, { email: CHARLIE_EMAIL }).firestore();
  adminDb   = testEnv.authenticatedContext(ADMIN_UID,   { email: ADMIN_EMAIL   }).firestore();
  anonDb    = testEnv.unauthenticatedContext().firestore();
});

after(async () => { await testEnv.cleanup(); });
afterEach(async () => { await testEnv.clearFirestore(); });

// ── Helpers ───────────────────────────────────────────────────────────────────

async function createLegacyPrediction(id) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'predictions', id), {
      matchLabel: 'Monaco - PSG', selection: '1',
      odds: 2.10, confidence: 3, createdAt: new Date().toISOString(),
    });
  });
}

async function createPrediction(id, ownerUid) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'predictions', id), {
      matchLabel: 'Lyon - Rennes', selection: '2',
      odds: 3.00, confidence: 4, createdAt: new Date().toISOString(),
      authorUid: ownerUid,
    });
  });
}

async function createProfile(uid, email) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', uid), {
      uid, email, displayName: email.split('@')[0],
      createdAt: new Date().toISOString(),
    });
  });
}

async function createFriendship(uidA, nameA, emailA, uidB, nameB, emailB) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', uidA, 'friends', uidB),
      { uid: uidB, displayName: nameB, email: emailB });
    await setDoc(doc(db, 'users', uidB, 'friends', uidA),
      { uid: uidA, displayName: nameA, email: emailA });
  });
}

async function createAliceBobFriendship() {
  await createFriendship(ALICE_UID, 'Alice', ALICE_EMAIL, BOB_UID, 'Bob', BOB_EMAIL);
}

async function createFriendRequest(fromUid, fromName, fromEmail, toUid) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', toUid, 'friendRequests', fromUid), {
      fromUid, fromName, fromEmail, status: 'pending',
      createdAt: new Date().toISOString(),
    });
  });
}

async function createReceived(recipientUid, predId, fromUid, status = 'pending') {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', recipientUid, 'received', predId), {
      id: predId, fromUid, fromName: 'Expéditeur',
      matchLabel: 'PSG - Lyon', selection: '1',
      odds: 1.65, confidence: 4, comment: '',
      createdAt: new Date().toISOString(), mqttStatus: status,
    });
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// predictions — LECTURE
// ═════════════════════════════════════════════════════════════════════════════
describe('predictions — read', () => {
  beforeEach(async () => { await createPrediction('p1', ALICE_UID); });

  it('propriétaire lit son propre pronostic', async () => {
    await assertSucceeds(getDoc(doc(aliceDb, 'predictions', 'p1')));
  });

  it('autre utilisateur ne peut pas lire le prono d\'Alice', async () => {
    await assertFails(getDoc(doc(bobDb, 'predictions', 'p1')));
  });

  it('admin lit n\'importe quel pronostic', async () => {
    await assertSucceeds(getDoc(doc(adminDb, 'predictions', 'p1')));
  });

  it('non authentifié ne peut pas lire', async () => {
    await assertFails(getDoc(doc(anonDb, 'predictions', 'p1')));
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// predictions — CREATE
// ═════════════════════════════════════════════════════════════════════════════
describe('predictions — create', () => {
  const base = {
    matchLabel: 'Nantes - Metz', selection: '1',
    odds: 1.80, confidence: 3, createdAt: new Date().toISOString(),
  };

  it('propriétaire crée avec son propre authorUid', async () => {
    await assertSucceeds(
      setDoc(doc(aliceDb, 'predictions', 'new1'), { ...base, authorUid: ALICE_UID })
    );
  });

  it('refusé si authorUid est null', async () => {
    await assertFails(
      setDoc(doc(aliceDb, 'predictions', 'new2'), { ...base, authorUid: null })
    );
  });

  it('refusé si authorUid appartient à un autre utilisateur', async () => {
    await assertFails(
      setDoc(doc(aliceDb, 'predictions', 'new3'), { ...base, authorUid: BOB_UID })
    );
  });

  it('refusé si non authentifié', async () => {
    await assertFails(
      setDoc(doc(anonDb, 'predictions', 'new4'), { ...base, authorUid: ALICE_UID })
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
    await assertSucceeds(updateDoc(doc(aliceDb, 'predictions', 'pu1'), { confidence: 5 }));
  });

  it('propriétaire ne peut pas changer authorUid', async () => {
    await assertFails(updateDoc(doc(aliceDb, 'predictions', 'pu1'), { authorUid: BOB_UID }));
  });

  it('admin modifie uniquement result sur le prono d\'un autre', async () => {
    await assertSucceeds(updateDoc(doc(adminDb, 'predictions', 'pu1'), { result: 'won' }));
  });

  it('admin ne peut pas modifier d\'autres champs sur le prono d\'un autre', async () => {
    await assertFails(updateDoc(doc(adminDb, 'predictions', 'pu1'), { confidence: 5 }));
  });

  it('admin modifie un prono legacy (authorUid absent)', async () => {
    await assertSucceeds(updateDoc(doc(adminDb, 'predictions', 'plegacy'), { result: 'lost' }));
  });

  it('tiers ne peut pas modifier le prono d\'un autre', async () => {
    await assertFails(updateDoc(doc(bobDb, 'predictions', 'pu1'), { result: 'won' }));
  });

  it('non authentifié refusé', async () => {
    await assertFails(updateDoc(doc(anonDb, 'predictions', 'pu1'), { result: 'won' }));
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
    await assertSucceeds(deleteDoc(doc(aliceDb, 'predictions', 'pd1')));
  });

  it('tiers ne peut pas supprimer le prono d\'un autre', async () => {
    await assertFails(deleteDoc(doc(charlieDb, 'predictions', 'pd1')));
  });

  it('admin supprime un prono legacy', async () => {
    await assertSucceeds(deleteDoc(doc(adminDb, 'predictions', 'pdlegacy')));
  });

  it('admin ne peut pas supprimer le prono d\'un autre utilisateur', async () => {
    await assertFails(deleteDoc(doc(adminDb, 'predictions', 'pd1')));
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// users — PROFIL
// ═════════════════════════════════════════════════════════════════════════════
describe('users — create profile', () => {
  it('création valide : uid et email cohérents avec le token', async () => {
    await assertSucceeds(setDoc(doc(aliceDb, 'users', ALICE_UID), {
      uid: ALICE_UID, email: ALICE_EMAIL,
      displayName: 'Alice', createdAt: new Date().toISOString(),
    }));
  });

  it('refusé si uid dans le document ≠ uid dans le chemin', async () => {
    await assertFails(setDoc(doc(aliceDb, 'users', ALICE_UID), {
      uid: BOB_UID, email: ALICE_EMAIL,
      displayName: 'Alice', createdAt: new Date().toISOString(),
    }));
  });

  it('refusé si email dans le document ≠ email du token Firebase Auth', async () => {
    await assertFails(setDoc(doc(aliceDb, 'users', ALICE_UID), {
      uid: ALICE_UID, email: BOB_EMAIL,
      displayName: 'Alice', createdAt: new Date().toISOString(),
    }));
  });

  it('refusé si on écrit dans le profil d\'un autre', async () => {
    await assertFails(setDoc(doc(aliceDb, 'users', BOB_UID), {
      uid: BOB_UID, email: BOB_EMAIL, displayName: 'Alice',
    }));
  });
});

describe('users — update profile', () => {
  beforeEach(async () => { await createProfile(ALICE_UID, ALICE_EMAIL); });

  it('propriétaire modifie son displayName', async () => {
    await assertSucceeds(updateDoc(doc(aliceDb, 'users', ALICE_UID), {
      displayName: 'Alice Pro',
    }));
  });

  it('propriétaire associe un deviceId au bon format', async () => {
    await assertSucceeds(updateDoc(doc(aliceDb, 'users', ALICE_UID), {
      deviceId: 'MatiMatch_AABBCCDDEEFF',
    }));
  });

  it('propriétaire dissocie son appareil (deviceId null)', async () => {
    await assertSucceeds(updateDoc(doc(aliceDb, 'users', ALICE_UID), {
      deviceId: null,
    }));
  });

  it('refusé si deviceId ne respecte pas le format MatiMatch_*', async () => {
    await assertFails(updateDoc(doc(aliceDb, 'users', ALICE_UID), {
      deviceId: 'esp32-device-123',
    }));
  });

  it('refusé si on tente de changer l\'email', async () => {
    await assertFails(updateDoc(doc(aliceDb, 'users', ALICE_UID), {
      email: 'newalice@test.com',
    }));
  });

  it('refusé si on tente de changer l\'uid', async () => {
    await assertFails(updateDoc(doc(aliceDb, 'users', ALICE_UID), {
      uid: BOB_UID,
    }));
  });

  it('tiers ne peut pas modifier le profil d\'un autre', async () => {
    await assertFails(updateDoc(doc(bobDb, 'users', ALICE_UID), {
      displayName: 'Hacker',
    }));
  });
});

describe('users — read profile', () => {
  beforeEach(async () => { await createProfile(ALICE_UID, ALICE_EMAIL); });

  it('tout utilisateur authentifié peut lire un profil (findByEmail)', async () => {
    await assertSucceeds(getDoc(doc(bobDb, 'users', ALICE_UID)));
  });

  it('non authentifié ne peut pas lire un profil', async () => {
    await assertFails(getDoc(doc(anonDb, 'users', ALICE_UID)));
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// users/friendRequests — DEMANDES D'AMITIÉ
// ═════════════════════════════════════════════════════════════════════════════
describe('users/friendRequests — create', () => {
  it('Alice envoie une demande à Bob', async () => {
    await assertSucceeds(setDoc(
      doc(aliceDb, 'users', BOB_UID, 'friendRequests', ALICE_UID),
      { fromUid: ALICE_UID, fromName: 'Alice', fromEmail: ALICE_EMAIL,
        status: 'pending', createdAt: new Date().toISOString() }
    ));
  });

  it('refusé si fromUid ≠ auth.uid (usurpation)', async () => {
    await assertFails(setDoc(
      doc(aliceDb, 'users', BOB_UID, 'friendRequests', ALICE_UID),
      { fromUid: BOB_UID, fromName: 'Alice', fromEmail: ALICE_EMAIL,
        status: 'pending', createdAt: new Date().toISOString() }
    ));
  });

  it('refusé si status ≠ pending', async () => {
    await assertFails(setDoc(
      doc(aliceDb, 'users', BOB_UID, 'friendRequests', ALICE_UID),
      { fromUid: ALICE_UID, fromName: 'Alice', fromEmail: ALICE_EMAIL,
        status: 'accepted', createdAt: new Date().toISOString() }
    ));
  });

  it('refusé si non authentifié', async () => {
    await assertFails(setDoc(
      doc(anonDb, 'users', BOB_UID, 'friendRequests', ALICE_UID),
      { fromUid: ALICE_UID, fromName: 'Alice', fromEmail: ALICE_EMAIL,
        status: 'pending', createdAt: new Date().toISOString() }
    ));
  });
});

describe('users/friendRequests — lecture et suppression', () => {
  beforeEach(async () => {
    await createFriendRequest(ALICE_UID, 'Alice', ALICE_EMAIL, BOB_UID);
  });

  it('destinataire (Bob) lit ses demandes entrantes', async () => {
    await assertSucceeds(getDoc(
      doc(bobDb, 'users', BOB_UID, 'friendRequests', ALICE_UID)
    ));
  });

  it('tiers ne peut pas lire les demandes d\'un autre', async () => {
    await assertFails(getDoc(
      doc(charlieDb, 'users', BOB_UID, 'friendRequests', ALICE_UID)
    ));
  });

  it('destinataire (Bob) refuse la demande', async () => {
    await assertSucceeds(deleteDoc(
      doc(bobDb, 'users', BOB_UID, 'friendRequests', ALICE_UID)
    ));
  });

  it('expéditeur (Alice) annule sa demande', async () => {
    await assertSucceeds(deleteDoc(
      doc(aliceDb, 'users', BOB_UID, 'friendRequests', ALICE_UID)
    ));
  });

  it('tiers ne peut pas supprimer la demande d\'un autre', async () => {
    await assertFails(deleteDoc(
      doc(charlieDb, 'users', BOB_UID, 'friendRequests', ALICE_UID)
    ));
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// users/friends — AMIS
// ═════════════════════════════════════════════════════════════════════════════
describe('users/friends — écriture', () => {
  it('propriétaire ajoute un ami dans sa propre liste', async () => {
    await assertSucceeds(setDoc(
      doc(aliceDb, 'users', ALICE_UID, 'friends', BOB_UID),
      { uid: BOB_UID, displayName: 'Bob', email: BOB_EMAIL }
    ));
  });

  it('self-insert accepté après demande préalable d\'Alice', async () => {
    // Alice a envoyé une demande à Bob → users/BOB/friendRequests/ALICE existe
    await createFriendRequest(ALICE_UID, 'Alice', ALICE_EMAIL, BOB_UID);
    await assertSucceeds(setDoc(
      doc(bobDb, 'users', ALICE_UID, 'friends', BOB_UID),
      { uid: BOB_UID, displayName: 'Bob', email: BOB_EMAIL }
    ));
  });

  it('self-insert refusé sans demande préalable', async () => {
    // Pas de friendRequest → Bob ne peut pas s'insérer seul dans la liste d\'Alice
    await assertFails(setDoc(
      doc(bobDb, 'users', ALICE_UID, 'friends', BOB_UID),
      { uid: BOB_UID, displayName: 'Bob', email: BOB_EMAIL }
    ));
  });

  it('self-insert refusé si uid dans le document ≠ auth.uid (usurpation)', async () => {
    await assertFails(setDoc(
      doc(aliceDb, 'users', BOB_UID, 'friends', CHARLIE_UID),
      { uid: CHARLIE_UID, displayName: 'Charlie', email: CHARLIE_EMAIL }
    ));
  });

  it('tiers ne peut pas écrire dans la liste d\'amis d\'un autre (cas général)', async () => {
    await assertFails(setDoc(
      doc(charlieDb, 'users', BOB_UID, 'friends', ALICE_UID),
      { uid: ALICE_UID, displayName: 'Alice', email: ALICE_EMAIL }
    ));
  });

  it('self-remove : Bob se retire de la liste d\'Alice', async () => {
    await createAliceBobFriendship();
    await assertSucceeds(deleteDoc(
      doc(bobDb, 'users', ALICE_UID, 'friends', BOB_UID)
    ));
  });
});

describe('users/friends — lecture', () => {
  beforeEach(createAliceBobFriendship);

  it('propriétaire lit sa liste', async () => {
    await assertSucceeds(getDoc(doc(aliceDb, 'users', ALICE_UID, 'friends', BOB_UID)));
  });

  it('tiers ne peut pas lire la liste d\'amis d\'un autre', async () => {
    await assertFails(getDoc(doc(charlieDb, 'users', ALICE_UID, 'friends', BOB_UID)));
  });
});

// ═════════════════════════════════════════════════════════════════════════════
// users/received — PRONOSTICS REÇUS
// ═════════════════════════════════════════════════════════════════════════════
describe('users/received — lecture', () => {
  beforeEach(async () => {
    await createAliceBobFriendship();
    await createReceived(BOB_UID, 'r1', ALICE_UID);
  });

  it('destinataire lit ses pronostics reçus', async () => {
    await assertSucceeds(getDoc(doc(bobDb, 'users', BOB_UID, 'received', 'r1')));
  });

  it('tiers ne peut pas lire les pronostics reçus d\'un autre', async () => {
    await assertFails(getDoc(doc(charlieDb, 'users', BOB_UID, 'received', 'r1')));
  });
});

describe('users/received — create (partage)', () => {
  const sharedPred = {
    id: 'rtest', fromUid: ALICE_UID, fromName: 'Alice',
    matchLabel: 'PSG - Lyon', selection: '1',
    odds: 1.65, confidence: 4, comment: '',
    createdAt: new Date().toISOString(), mqttStatus: 'pending',
  };

  beforeEach(createAliceBobFriendship);

  it('ami partage un pronostic avec un ami', async () => {
    await assertSucceeds(setDoc(
      doc(aliceDb, 'users', BOB_UID, 'received', 'rtest'),
      sharedPred
    ));
  });

  it('refusé si mqttStatus ≠ pending à la création', async () => {
    await assertFails(setDoc(
      doc(aliceDb, 'users', BOB_UID, 'received', 'rsentcreate'),
      { ...sharedPred, mqttStatus: 'sent' }
    ));
  });

  it('refusé si fromUid ≠ auth.uid (usurpation d\'identité)', async () => {
    await assertFails(setDoc(
      doc(aliceDb, 'users', BOB_UID, 'received', 'rusurp'),
      { ...sharedPred, fromUid: CHARLIE_UID }
    ));
  });

  it('refusé si l\'expéditeur n\'est pas ami du destinataire', async () => {
    await assertFails(setDoc(
      doc(charlieDb, 'users', BOB_UID, 'received', 'rnonfriend'),
      { ...sharedPred, fromUid: CHARLIE_UID, fromName: 'Charlie' }
    ));
  });

  it('refusé si non authentifié', async () => {
    await assertFails(setDoc(
      doc(anonDb, 'users', BOB_UID, 'received', 'ranon'),
      sharedPred
    ));
  });
});

describe('users/received — update (mqttStatus uniquement)', () => {
  beforeEach(async () => {
    await createAliceBobFriendship();
    await createReceived(BOB_UID, 'ru1',    ALICE_UID, 'pending');
    await createReceived(BOB_UID, 'ru_sent', ALICE_UID, 'sent');
  });

  it('expéditeur met à jour mqttStatus pending → sent', async () => {
    await assertSucceeds(updateDoc(
      doc(aliceDb, 'users', BOB_UID, 'received', 'ru1'),
      { mqttStatus: 'sent' }
    ));
  });

  it('refusé si on tente de modifier un autre champ (ex. matchLabel)', async () => {
    await assertFails(updateDoc(
      doc(aliceDb, 'users', BOB_UID, 'received', 'ru1'),
      { matchLabel: 'Nouveau match' }
    ));
  });

  it('refusé si on tente de modifier mqttStatus ET un autre champ simultanément', async () => {
    await assertFails(updateDoc(
      doc(aliceDb, 'users', BOB_UID, 'received', 'ru1'),
      { mqttStatus: 'sent', odds: 9.99 }
    ));
  });

  it('refusé si transition inverse : sent → pending', async () => {
    await assertFails(updateDoc(
      doc(aliceDb, 'users', BOB_UID, 'received', 'ru_sent'),
      { mqttStatus: 'pending' }
    ));
  });

  it('tiers ne peut pas mettre à jour received', async () => {
    await assertFails(updateDoc(
      doc(charlieDb, 'users', BOB_UID, 'received', 'ru1'),
      { mqttStatus: 'sent' }
    ));
  });

  it('destinataire ne peut pas modifier ses received', async () => {
    await assertFails(updateDoc(
      doc(bobDb, 'users', BOB_UID, 'received', 'ru1'),
      { mqttStatus: 'sent' }
    ));
  });
});

describe('users/received — delete interdit', () => {
  beforeEach(async () => {
    await createAliceBobFriendship();
    await createReceived(BOB_UID, 'rd1', ALICE_UID);
  });

  it('destinataire ne peut pas supprimer ses received', async () => {
    await assertFails(deleteDoc(doc(bobDb, 'users', BOB_UID, 'received', 'rd1')));
  });

  it('expéditeur ne peut pas supprimer un received', async () => {
    await assertFails(deleteDoc(doc(aliceDb, 'users', BOB_UID, 'received', 'rd1')));
  });
});
