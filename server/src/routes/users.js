const express = require('express');
const db = require('../db');
const { authenticateToken } = require('../middleware/auth');

const router = express.Router();

// All routes require authentication
router.use(authenticateToken);

// Get user by ID
router.get('/:id', async (req, res) => {
  try {
    const result = await db.query(
      `SELECT id, username, display_name, avatar_url, status_text, is_online, last_seen, created_at
       FROM users WHERE id = $1`,
      [req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const user = result.rows[0];

    res.json({
      id: user.id,
      username: user.username,
      displayName: user.display_name,
      avatarUrl: user.avatar_url,
      statusText: user.status_text,
      isOnline: user.is_online,
      lastSeen: user.last_seen,
      createdAt: user.created_at
    });
  } catch (error) {
    console.error('Get user error:', error);
    res.status(500).json({ error: 'Failed to get user' });
  }
});

// Search users by username
router.get('/search/username', async (req, res) => {
  try {
    const { username } = req.query;

    if (!username) {
      return res.status(400).json({ error: 'Username query parameter is required' });
    }

    const result = await db.query(
      `SELECT id, username, display_name, avatar_url, status_text, is_online, last_seen
       FROM users
       WHERE username ILIKE $1 AND id != $2
       LIMIT 20`,
      [`%${username}%`, req.user.userId]
    );

    const users = result.rows.map(user => ({
      id: user.id,
      username: user.username,
      displayName: user.display_name,
      avatarUrl: user.avatar_url,
      statusText: user.status_text,
      isOnline: user.is_online,
      lastSeen: user.last_seen
    }));

    res.json(users);
  } catch (error) {
    console.error('Search users error:', error);
    res.status(500).json({ error: 'Failed to search users' });
  }
});

// Update current user profile
router.patch('/me', async (req, res) => {
  try {
    const { displayName, avatarUrl, statusText } = req.body;
    const updates = [];
    const values = [];
    let paramCount = 1;

    if (displayName !== undefined) {
      updates.push(`display_name = $${paramCount++}`);
      values.push(displayName);
    }

    if (avatarUrl !== undefined) {
      updates.push(`avatar_url = $${paramCount++}`);
      values.push(avatarUrl);
    }

    if (statusText !== undefined) {
      updates.push(`status_text = $${paramCount++}`);
      values.push(statusText);
    }

    if (updates.length === 0) {
      return res.status(400).json({ error: 'No fields to update' });
    }

    values.push(req.user.userId);

    const result = await db.query(
      `UPDATE users SET ${updates.join(', ')}
       WHERE id = $${paramCount}
       RETURNING id, username, display_name, avatar_url, status_text, is_online, last_seen, created_at`,
      values
    );

    const user = result.rows[0];

    res.json({
      id: user.id,
      username: user.username,
      displayName: user.display_name,
      avatarUrl: user.avatar_url,
      statusText: user.status_text,
      isOnline: user.is_online,
      lastSeen: user.last_seen,
      createdAt: user.created_at
    });
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json({ error: 'Failed to update user' });
  }
});

// Update device token for push notifications
router.post('/device-token', async (req, res) => {
  try {
    const { deviceToken } = req.body;

    if (!deviceToken) {
      return res.status(400).json({ error: 'Device token is required' });
    }

    await db.query(
      'UPDATE users SET device_token = $1 WHERE id = $2',
      [deviceToken, req.user.userId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Update device token error:', error);
    res.status(500).json({ error: 'Failed to update device token' });
  }
});

// Update online status
router.post('/online-status', async (req, res) => {
  try {
    const { isOnline } = req.body;

    await db.query(
      'UPDATE users SET is_online = $1, last_seen = NOW() WHERE id = $2',
      [isOnline, req.user.userId]
    );

    res.json({ success: true });
  } catch (error) {
    console.error('Update online status error:', error);
    res.status(500).json({ error: 'Failed to update online status' });
  }
});

module.exports = router;
