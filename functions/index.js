const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

function asString(value) {
  if (value === null || value === undefined) return undefined;
  if (typeof value === 'string') return value;
  if (typeof value === 'boolean' || typeof value === 'number') {
    return String(value);
  }
  try {
    return JSON.stringify(value);
  } catch (_) {
    return String(value);
  }
}

function flatData(notification, notificationId) {
  const payload = {};
  const nested =
    notification.data && typeof notification.data === 'object'
      ? notification.data
      : {};
  for (const [key, value] of Object.entries(nested)) {
    const flat = asString(value);
    if (flat !== undefined) payload[key] = flat;
  }
  const fields = [
    'notificationId',
    'type',
    'targetType',
    'contentId',
    'postId',
    'communityId',
    'targetId',
    'fandomId',
  ];
  const source = { ...notification, notificationId };
  for (const field of fields) {
    const flat = asString(source[field]);
    if (flat !== undefined && flat !== '') payload[field] = flat;
  }
  payload.notificationId = notificationId;
  return payload;
}

async function pruneTokens(db, uid, tokens) {
  if (tokens.length === 0) return;
  const devices = db.collection('users').doc(uid).collection('devices');
  const snaps = await Promise.all(
    tokens.map((token) => devices.where('token', '==', token).get()),
  );
  const batch = db.batch();
  let deletes = 0;
  for (const snap of snaps) {
    for (const doc of snap.docs) {
      batch.delete(doc.ref);
      deletes += 1;
      if (deletes >= 400) break;
    }
    if (deletes >= 400) break;
  }
  if (deletes > 0) await batch.commit();
}

exports.deliverNotification = onDocumentCreated(
  {
    document: 'users/{uid}/notifications/{notificationId}',
    region: 'us-central1',
  },
  async (event) => {
    const uid = event.params.uid;
    const notificationId = event.params.notificationId;
    const notification = event.data.data();
    if (!notification) return null;

    const db = getFirestore();
    const devices = await db
      .collection('users')
      .doc(uid)
      .collection('devices')
      .where('isActive', '==', true)
      .get();
    const tokens = [
      ...new Set(
        devices.docs.map((doc) => doc.data().token).filter((t) => !!t),
      ),
    ];
    if (tokens.length === 0) return null;

    const title = notification.title || 'Fandom Verse';
    const body =
      notification.body || notification.preview || 'New activity on FandomVerse';

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title,
        body,
        ...(notification.imageUrl ? { image: notification.imageUrl } : {}),
      },
      data: flatData(notification, notificationId),
      android: {
        priority: 'high',
        notification: {
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          sound: 'default',
        },
      },
      webpush: {
        fcm_options: { link: '/' },
        notification: { title, body },
      },
    });

    const dead = [];
    response.responses.forEach((result, index) => {
      const error = result.error;
      if (!error) return;
      const code = error.code || '';
      if (
        code.includes('registration-token-not-registered') ||
        code.includes('invalid-registration-token') ||
        code.includes('invalid-argument')
      ) {
        dead.push(tokens[index]);
      }
    });
    if (dead.length > 0) {
      try {
        await pruneTokens(db, uid, dead);
      } catch (error) {
        console.error('token prune failed', error);
      }
    }
    return null;
  },
);
