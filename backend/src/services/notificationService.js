const { db, admin } = require('./firebase');
const { appendTimelineEvent } = require('./historyService');

function notificationsCollection(tontineId) {
  return db.collection('tontines').doc(tontineId).collection('notifications');
}

async function createNotification({ tontineId, type, title, message, recipientWallet = null, metadata = {}, severity = 'info' }) {
  const doc = await notificationsCollection(tontineId).add({
    type,
    title,
    message,
    recipientWallet: recipientWallet ? String(recipientWallet).toLowerCase() : null,
    metadata,
    severity,
    read: false,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  });

  await appendTimelineEvent({
    tontineId,
    type: `notification.${type}`,
    title,
    message,
    actor: recipientWallet ? String(recipientWallet).toLowerCase() : null,
    payload: { notificationId: doc.id, metadata },
    severity
  });

  return { id: doc.id, type, title, message };
}

async function queueContributionReminder(tontineId, wallet, metadata = {}) {
  return createNotification({
    tontineId,
    type: 'contribution_reminder',
    title: 'Rappel de cotisation',
    message: 'Votre cotisation arrive à échéance.',
    recipientWallet: wallet,
    metadata,
    severity: 'warning'
  });
}

async function queueLatePaymentAlert(tontineId, wallet, metadata = {}) {
  return createNotification({
    tontineId,
    type: 'late_payment',
    title: 'Retard de cotisation',
    message: 'Une cotisation est en retard.',
    recipientWallet: wallet,
    metadata,
    severity: 'danger'
  });
}

async function queueSuspensionAlert(tontineId, wallet, metadata = {}) {
  return createNotification({
    tontineId,
    type: 'suspension',
    title: 'Suspension appliquée',
    message: 'Votre compte a été suspendu.',
    recipientWallet: wallet,
    metadata,
    severity: 'danger'
  });
}

async function queueAllocationReadyAlert(tontineId, wallet, metadata = {}) {
  return createNotification({
    tontineId,
    type: 'allocation_ready',
    title: 'Allocation disponible',
    message: 'Votre allocation est maintenant disponible.',
    recipientWallet: wallet,
    metadata,
    severity: 'success'
  });
}

async function queueReserveUpdateAlert(tontineId, wallet, metadata = {}) {
  return createNotification({
    tontineId,
    type: 'reserve_update',
    title: 'Réserve mise à jour',
    message: 'La réserve de garantie a été mise à jour.',
    recipientWallet: wallet,
    metadata,
    severity: 'info'
  });
}

async function listNotifications(tontineId, { unreadOnly = false, limit = 100 } = {}) {
  let query = notificationsCollection(tontineId).orderBy('createdAt', 'desc').limit(limit);
  if (unreadOnly) {
    query = query.where('read', '==', false);
  }
  const snap = await query.get();
  return snap.docs.map((doc) => ({ id: doc.id, ...doc.data() }));
}

async function markNotificationRead(tontineId, notificationId) {
  await notificationsCollection(tontineId).doc(notificationId).set(
    {
      read: true,
      readAt: admin.firestore.FieldValue.serverTimestamp()
    },
    { merge: true }
  );
}

module.exports = {
  createNotification,
  queueContributionReminder,
  queueLatePaymentAlert,
  queueSuspensionAlert,
  queueAllocationReadyAlert,
  queueReserveUpdateAlert,
  listNotifications,
  markNotificationRead
};