const express = require('express');
const db = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

// Get all chats for current user
router.get('/', async (req, res) => {
  try {
    const result = await db.query(
      `SELECT
        c.id,
        c.type,
        c.name,
        c.avatar_url,
        c.created_at,
        c.updated_at,
        -- Get other participant for private chats
        (
          SELECT json_build_object(
            'id', u.id,
            'username', u.username,
            'displayName', u.display_name,
            'avatarUrl', u.avatar_url,
            'isOnline', u.is_online,
            'lastSeen', u.last_seen
          )
          FROM chat_participants cp2
          JOIN users u ON u.id = cp2.user_id
          WHERE cp2.chat_id = c.id AND cp2.user_id != $1
          LIMIT 1
        ) as other_user,
        -- Get last message
        (
          SELECT json_build_object(
            'id', m.id,
            'content', m.content,
            'type', m.type,
            'senderId', m.sender_id,
            'createdAt', m.created_at
          )
          FROM messages m
          WHERE m.chat_id = c.id
          ORDER BY m.created_at DESC
          LIMIT 1
        ) as last_message,
        -- Count unread messages
        (
          SELECT COUNT(*)
          FROM messages m
          WHERE m.chat_id = c.id
            AND m.sender_id != $1
            AND m.created_at > COALESCE(cp.last_read_at, '1970-01-01')
        )::int as unread_count
      FROM chats c
      JOIN chat_participants cp ON cp.chat_id = c.id AND cp.user_id = $1
      ORDER BY c.updated_at DESC`,
      [req.user.userId]
    );

    const chats = result.rows.map(chat => ({
      id: chat.id,
      type: chat.type,
      name: chat.name,
      avatarUrl: chat.avatar_url,
      otherUser: chat.other_user,
      lastMessage: chat.last_message,
      unreadCount: chat.unread_count,
      createdAt: chat.created_at,
      updatedAt: chat.updated_at
    }));

    res.json(chats);
  } catch (error) {
    console.error('Get chats error:', error);
    res.status(500).json({ error: 'Failed to get chats' });
  }
});

// Get or create private chat with user
router.post('/private', async (req, res) => {
  try {
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    if (userId === req.user.userId) {
      return res.status(400).json({ error: 'Cannot create chat with yourself' });
    }

    // Check if private chat already exists between these users
    const existingChat = await db.query(
      `SELECT c.id
       FROM chats c
       WHERE c.type = 'private'
         AND EXISTS (SELECT 1 FROM chat_participants WHERE chat_id = c.id AND user_id = $1)
         AND EXISTS (SELECT 1 FROM chat_participants WHERE chat_id = c.id AND user_id = $2)`,
      [req.user.userId, userId]
    );

    if (existingChat.rows.length > 0) {
      // Return existing chat
      const chatId = existingChat.rows[0].id;
      return res.json(await getChatById(chatId, req.user.userId));
    }

    // Create new chat
    const chatResult = await db.query(
      `INSERT INTO chats (type) VALUES ('private') RETURNING id`
    );
    const chatId = chatResult.rows[0].id;

    // Add participants
    await db.query(
      `INSERT INTO chat_participants (chat_id, user_id) VALUES ($1, $2), ($1, $3)`,
      [chatId, req.user.userId, userId]
    );

    res.status(201).json(await getChatById(chatId, req.user.userId));
  } catch (error) {
    console.error('Create private chat error:', error);
    res.status(500).json({ error: 'Failed to create chat' });
  }
});

// Get chat by ID
router.get('/:id', async (req, res) => {
  try {
    // Verify user is participant
    const participant = await db.query(
      'SELECT 1 FROM chat_participants WHERE chat_id = $1 AND user_id = $2',
      [req.params.id, req.user.userId]
    );

    if (participant.rows.length === 0) {
      return res.status(403).json({ error: 'Not a participant of this chat' });
    }

    const chat = await getChatById(req.params.id, req.user.userId);
    if (!chat) {
      return res.status(404).json({ error: 'Chat not found' });
    }

    res.json(chat);
  } catch (error) {
    console.error('Get chat error:', error);
    res.status(500).json({ error: 'Failed to get chat' });
  }
});

// Mark chat as read
router.post('/:id/read', async (req, res) => {
  try {
    await db.query(
      `UPDATE chat_participants
       SET last_read_at = NOW()
       WHERE chat_id = $1 AND user_id = $2`,
      [req.params.id, req.user.userId]
    );

    // Update message statuses to 'read' for messages from other users
    await db.query(
      `UPDATE messages
       SET status = 'read'
       WHERE chat_id = $1 AND sender_id != $2 AND status != 'read'`,
      [req.params.id, req.user.userId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Mark read error:', error);
    res.status(500).json({ error: 'Failed to mark as read' });
  }
});

// Delete chat
router.delete('/:id', async (req, res) => {
  try {
    // Verify user is participant
    const participant = await db.query(
      'SELECT 1 FROM chat_participants WHERE chat_id = $1 AND user_id = $2',
      [req.params.id, req.user.userId]
    );

    if (participant.rows.length === 0) {
      return res.status(403).json({ error: 'Not a participant of this chat' });
    }

    // For private chats, just remove the participant (soft delete for this user)
    await db.query(
      'DELETE FROM chat_participants WHERE chat_id = $1 AND user_id = $2',
      [req.params.id, req.user.userId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Delete chat error:', error);
    res.status(500).json({ error: 'Failed to delete chat' });
  }
});

// Helper function to get chat with all details
async function getChatById(chatId, currentUserId) {
  const result = await db.query(
    `SELECT
      c.id,
      c.type,
      c.name,
      c.avatar_url,
      c.created_at,
      c.updated_at,
      (
        SELECT json_build_object(
          'id', u.id,
          'username', u.username,
          'displayName', u.display_name,
          'avatarUrl', u.avatar_url,
          'isOnline', u.is_online,
          'lastSeen', u.last_seen
        )
        FROM chat_participants cp2
        JOIN users u ON u.id = cp2.user_id
        WHERE cp2.chat_id = c.id AND cp2.user_id != $2
        LIMIT 1
      ) as other_user,
      (
        SELECT json_build_object(
          'id', m.id,
          'content', m.content,
          'type', m.type,
          'senderId', m.sender_id,
          'createdAt', m.created_at
        )
        FROM messages m
        WHERE m.chat_id = c.id
        ORDER BY m.created_at DESC
        LIMIT 1
      ) as last_message,
      (
        SELECT COUNT(*)
        FROM messages m
        JOIN chat_participants cp ON cp.chat_id = c.id AND cp.user_id = $2
        WHERE m.chat_id = c.id
          AND m.sender_id != $2
          AND m.created_at > COALESCE(cp.last_read_at, '1970-01-01')
      )::int as unread_count
    FROM chats c
    WHERE c.id = $1`,
    [chatId, currentUserId]
  );

  if (result.rows.length === 0) return null;

  const chat = result.rows[0];
  return {
    id: chat.id,
    type: chat.type,
    name: chat.name,
    avatarUrl: chat.avatar_url,
    otherUser: chat.other_user,
    lastMessage: chat.last_message,
    unreadCount: chat.unread_count,
    createdAt: chat.created_at,
    updatedAt: chat.updated_at
  };
}

module.exports = router;
