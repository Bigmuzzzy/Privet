const express = require('express');
const { sendPushNotification, sendMessageNotification } = require('../services/apns');

const router = express.Router();

// Store device tokens (in production, use database)
const deviceTokens = new Map(); // userId -> deviceToken

// Register device token
router.post('/register', async (req, res) => {
  try {
    const { userId, deviceToken } = req.body;

    if (!userId || !deviceToken) {
      return res.status(400).json({ error: 'userId and deviceToken are required' });
    }

    deviceTokens.set(userId, deviceToken);
    console.log(`📱 Device registered: userId=${userId}, token=${deviceToken.substring(0, 10)}...`);

    res.json({ success: true });
  } catch (error) {
    console.error('Register error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Unregister device token
router.post('/unregister', async (req, res) => {
  try {
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    deviceTokens.delete(userId);
    console.log(`📱 Device unregistered: userId=${userId}`);

    res.json({ success: true });
  } catch (error) {
    console.error('Unregister error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Send push notification for new message
router.post('/notify/message', async (req, res) => {
  try {
    const { recipientId, senderName, messageText, chatId } = req.body;

    if (!recipientId || !senderName) {
      return res.status(400).json({ error: 'recipientId and senderName are required' });
    }

    const deviceToken = deviceTokens.get(recipientId);

    if (!deviceToken) {
      console.log(`📵 No device token for user: ${recipientId}`);
      return res.json({ success: false, reason: 'No device token' });
    }

    const result = await sendMessageNotification(
      deviceToken,
      senderName,
      messageText,
      chatId
    );

    res.json(result);
  } catch (error) {
    console.error('Notify error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Send custom push notification
router.post('/send', async (req, res) => {
  try {
    const { userId, title, body, data } = req.body;

    if (!userId || !title || !body) {
      return res.status(400).json({ error: 'userId, title, and body are required' });
    }

    const deviceToken = deviceTokens.get(userId);

    if (!deviceToken) {
      return res.json({ success: false, reason: 'No device token' });
    }

    const result = await sendPushNotification(deviceToken, {
      title,
      body,
      data
    });

    res.json(result);
  } catch (error) {
    console.error('Send error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get registered devices count (for debugging)
router.get('/stats', (req, res) => {
  res.json({
    registeredDevices: deviceTokens.size
  });
});

module.exports = router;
