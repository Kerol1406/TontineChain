const { db, admin } = require('./firebase');

function timelineCollection(tontineId) {
  return db.collection('tontines').doc(tontineId).collection('timeline');
}

async function appendTimelineEvent({ tontineId, type, title, message, actor = null, payload = {}, severity = 'info' }) {
  await timelineCollection(tontineId).add({
    type,
    title,
    message,
    actor,
    payload,
    severity,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });
}

async function listTimelineEvents({ tontineId, limit = 100 }) {
  const snap = await timelineCollection(tontineId).orderBy('createdAt', 'desc').limit(limit).get();
  return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

module.exports = {
  appendTimelineEvent,
  listTimelineEvents
};