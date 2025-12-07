const express = require('express');
const db = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

// Get messages for a chat (with pagination)
router.get('/chat/:chatId', async (req, res) => {
  try {
    const { chatId } = req.params;
    const { limit = 50, before } = req.query;

    // Verify user is participant
    const participant = await db.query(
      'SELECT 1 FROM chat_participants WHERE chat_id = $1 AND user_id = $2',
      [chatId, req.user.userId]
    );

    if (participant.rows.length === 0) {
      return res.status(403).json({ error: 'Not a participant of this chat' });
    }

    let query = `
      SELECT
        m.id,
        m.chat_id,
        m.sender_id,
        m.content,
        m.type,
        m.media_url,
        m.media_thumbnail_url,
        m.status,
        m.reply_to_id,
        m.created_at,
        json_build_object(
          'id', u.id,
          'displayName', u.display_name,
          'avatarUrl', u.avatar_url
        ) as sender
      FROM messages m
      JOIN users u ON u.id = m.sender_id
      WHERE m.chat_id = $1
    `;
    const params = [chatId];

    if (before) {
      query += ` AND m.created_at < $${params.length + 1}`;
      params.push(before);
    }

    query += ` ORDER BY m.created_at DESC LIMIT $${params.length + 1}`;
    params.push(parseInt(limit));

    const result = await db.query(query, params);

    const messages = result.rows.map(msg => ({
      id: msg.id,
      chatId: msg.chat_id,
      senderId: msg.sender_id,
      content: msg.content,
      type: msg.type,
      mediaUrl: msg.media_url,
      mediaThumbnailUrl: msg.media_thumbnail_url,
      status: msg.status,
      replyToId: msg.reply_to_id,
      sender: msg.sender,
      createdAt: msg.created_at
    }));

    // Return in chronological order
    res.json(messages.reverse());
  } catch (error) {
    console.error('Get messages error:', error);
    res.status(500).json({ error: 'Failed to get messages' });
  }
});

// Send a message
router.post('/', async (req, res) => {
  try {
    const { chatId, content, type = 'text', mediaUrl, mediaThumbnailUrl, replyToId } = req.body;

    if (!chatId) {
      return res.status(400).json({ error: 'chatId is required' });
    }

    if (!content && !mediaUrl) {
      return res.status(400).json({ error: 'content or mediaUrl is required' });
    }

    // Verify user is participant
    const participant = await db.query(
      'SELECT 1 FROM chat_participants WHERE chat_id = $1 AND user_id = $2',
      [chatId, req.user.userId]
    );

    if (participant.rows.length === 0) {
      return res.status(403).json({ error: 'Not a participant of this chat' });
    }

    // Create message
    const result = await db.query(
      `INSERT INTO messages (chat_id, sender_id, content, type, media_url, media_thumbnail_url, reply_to_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, chat_id, sender_id, content, type, media_url, media_thumbnail_url, status, reply_to_id, created_at`,
      [chatId, req.user.userId, content, type, mediaUrl, mediaThumbnailUrl, replyToId]
    );

    // Update chat's updated_at
    await db.query('UPDATE chats SET updated_at = NOW() WHERE id = $1', [chatId]);

    // Get sender info
    const senderResult = await db.query(
      'SELECT id, display_name, avatar_url FROM users WHERE id = $1',
      [req.user.userId]
    );

    const msg = result.rows[0];
    const sender = senderResult.rows[0];

    const message = {
      id: msg.id,
      chatId: msg.chat_id,
      senderId: msg.sender_id,
      content: msg.content,
      type: msg.type,
      mediaUrl: msg.media_url,
      mediaThumbnailUrl: msg.media_thumbnail_url,
      status: msg.status,
      replyToId: msg.reply_to_id,
      sender: {
        id: sender.id,
        displayName: sender.display_name,
        avatarUrl: sender.avatar_url
      },
      createdAt: msg.created_at
    };

    // Get WebSocket manager and broadcast to chat participants
    const wsManager = req.app.get('wsManager');
    if (wsManager) {
      wsManager.broadcastToChat(chatId, {
        type: 'new_message',
        message
      }, req.user.userId);

      // Send push notification to other participants
      const otherParticipants = await db.query(
        `SELECT u.id, u.device_token, u.display_name
         FROM chat_participants cp
         JOIN users u ON u.id = cp.user_id
         WHERE cp.chat_id = $1 AND cp.user_id != $2 AND u.device_token IS NOT NULL`,
        [chatId, req.user.userId]
      );

      // TODO: Send APNs notification
    }

    res.status(201).json(message);
  } catch (error) {
    console.error('Send message error:', error);
    res.status(500).json({ error: 'Failed to send message' });
  }
});

// Update message status (delivered/read)
router.patch('/:id/status', async (req, res) => {
  try {
    const { status } = req.body;

    if (!['delivered', 'read'].includes(status)) {
      return res.status(400).json({ error: 'Invalid status' });
    }

    // Get message and verify it's for current user
    const msgResult = await db.query(
      `SELECT m.id, m.chat_id, m.sender_id, m.status
       FROM messages m
       JOIN chat_participants cp ON cp.chat_id = m.chat_id AND cp.user_id = $2
       WHERE m.id = $1`,
      [req.params.id, req.user.userId]
    );

    if (msgResult.rows.length === 0) {
      return res.status(404).json({ error: 'Message not found' });
    }

    const msg = msgResult.rows[0];

    // Only update if new status is "higher" than current
    const statusOrder = { sent: 0, delivered: 1, read: 2 };
    if (statusOrder[status] <= statusOrder[msg.status]) {
      return res.json({ success: true, status: msg.status });
    }

    await db.query(
      'UPDATE messages SET status = $1 WHERE id = $2',
      [status, req.params.id]
    );

    // Notify sender via WebSocket
    const wsManager = req.app.get('wsManager');
    if (wsManager) {
      wsManager.sendToUser(msg.sender_id, {
        type: 'message_status',
        messageId: msg.id,
        chatId: msg.chat_id,
        status
      });
    }

    res.json({ success: true, status });
  } catch (error) {
    console.error('Update message status error:', error);
    res.status(500).json({ error: 'Failed to update message status' });
  }
});

// Delete message
router.delete('/:id', async (req, res) => {
  try {
    // Verify message belongs to user
    const result = await db.query(
      'DELETE FROM messages WHERE id = $1 AND sender_id = $2 RETURNING chat_id',
      [req.params.id, req.user.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Message not found or not yours' });
    }

    // Notify via WebSocket
    const wsManager = req.app.get('wsManager');
    if (wsManager) {
      wsManager.broadcastToChat(result.rows[0].chat_id, {
        type: 'message_deleted',
        messageId: req.params.id
      });
    }

    res.json({ success: true });
  } catch (error) {
    console.error('Delete message error:', error);
    res.status(500).json({ error: 'Failed to delete message' });
  }
});

module.exports = router;
