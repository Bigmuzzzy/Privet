const apn = require('apn');
const path = require('path');

let apnProvider = null;

function initializeAPNs() {
  const keyPath = process.env.APNS_KEY_PATH;
  const keyId = process.env.APNS_KEY_ID;
  const teamId = process.env.APNS_TEAM_ID;

  if (!keyPath || !keyId || !teamId) {
    console.warn('⚠️ APNs not configured. Push notifications disabled.');
    console.warn('   Set APNS_KEY_PATH, APNS_KEY_ID, APNS_TEAM_ID in .env');
    return null;
  }

  try {
    const options = {
      token: {
        key: path.resolve(keyPath),
        keyId: keyId,
        teamId: teamId
      },
      production: process.env.APNS_ENVIRONMENT === 'production'
    };

    apnProvider = new apn.Provider(options);
    console.log('✅ APNs initialized successfully');
    return apnProvider;
  } catch (error) {
    console.error('❌ Failed to initialize APNs:', error.message);
    return null;
  }
}

async function sendPushNotification(deviceToken, payload) {
  if (!apnProvider) {
    apnProvider = initializeAPNs();
  }

  if (!apnProvider) {
    console.log('📵 Push skipped (APNs not configured)');
    return { success: false, reason: 'APNs not configured' };
  }

  const notification = new apn.Notification();

  notification.expiry = Math.floor(Date.now() / 1000) + 3600; // 1 hour
  notification.badge = payload.badge || 1;
  notification.sound = payload.sound || 'default';
  notification.alert = {
    title: payload.title,
    body: payload.body
  };
  notification.topic = process.env.APNS_BUNDLE_ID;
  notification.payload = payload.data || {};

  try {
    const result = await apnProvider.send(notification, deviceToken);

    if (result.failed.length > 0) {
      console.error('❌ Push failed:', result.failed[0].response);
      return { success: false, reason: result.failed[0].response };
    }

    console.log('✅ Push sent successfully to:', deviceToken.substring(0, 10) + '...');
    return { success: true };
  } catch (error) {
    console.error('❌ Push error:', error);
    return { success: false, reason: error.message };
  }
}

async function sendMessageNotification(deviceToken, senderName, messageText, chatId) {
  return sendPushNotification(deviceToken, {
    title: senderName,
    body: messageText || '📷 Фото',
    sound: 'default',
    badge: 1,
    data: {
      type: 'message',
      chatId: chatId
    }
  });
}

module.exports = {
  initializeAPNs,
  sendPushNotification,
  sendMessageNotification
};
