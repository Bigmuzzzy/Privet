const WebSocket = require('ws');
const jwt = require('jsonwebtoken');
const db = require('../db');

class WebSocketManager {
  constructor(server) {
    this.wss = new WebSocket.Server({ server, path: '/ws' });
    this.clients = new Map(); // userId -> Set of WebSocket connections

    this.wss.on('connection', (ws, req) => {
      this.handleConnection(ws, req);
    });

    console.log('🔌 WebSocket server initialized');
  }

  async handleConnection(ws, req) {
    // Get token from query string
    const url = new URL(req.url, 'ws://localhost');
    const token = url.searchParams.get('token');

    if (!token) {
      ws.close(4001, 'Authentication required');
      return;
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET || 'development-secret-key');
      const userId = decoded.userId;

      // Store connection
      if (!this.clients.has(userId)) {
        this.clients.set(userId, new Set());
      }
      this.clients.get(userId).add(ws);

      ws.userId = userId;
      ws.isAlive = true;

      console.log(`📱 User ${userId} connected via WebSocket`);

      // Update online status
      await db.query(
        'UPDATE users SET is_online = true, last_seen = NOW() WHERE id = $1',
        [userId]
      );

      // Notify contacts about online status
      this.broadcastOnlineStatus(userId, true);

      // Handle messages
      ws.on('message', (data) => {
        this.handleMessage(ws, data);
      });

      // Handle pong for heartbeat
      ws.on('pong', () => {
        ws.isAlive = true;
      });

      // Handle close
      ws.on('close', () => {
        this.handleClose(ws);
      });

      // Send confirmation
      ws.send(JSON.stringify({ type: 'connected', userId }));

    } catch (error) {
      console.error('WebSocket auth error:', error);
      ws.close(4003, 'Invalid token');
    }
  }

  handleMessage(ws, data) {
    try {
      const message = JSON.parse(data);

      switch (message.type) {
        case 'ping':
          ws.send(JSON.stringify({ type: 'pong' }));
          break;

        case 'typing':
          // Broadcast typing indicator to chat
          this.broadcastToChat(message.chatId, {
            type: 'typing',
            chatId: message.chatId,
            userId: ws.userId,
            isTyping: message.isTyping
          }, ws.userId);
          break;

        case 'message_read':
          // Handle batch read receipts
          this.handleReadReceipts(ws.userId, message.messageIds);
          break;

        // WebRTC Signaling
        case 'call_offer':
          this.handleCallOffer(ws.userId, message);
          break;

        case 'call_answer':
          this.handleCallAnswer(ws.userId, message);
          break;

        case 'ice_candidate':
          this.handleIceCandidate(ws.userId, message);
          break;

        case 'call_end':
          this.handleCallEnd(ws.userId, message);
          break;

        case 'call_reject':
          this.handleCallReject(ws.userId, message);
          break;

        default:
          console.log('Unknown message type:', message.type);
      }
    } catch (error) {
      console.error('WebSocket message error:', error);
    }
  }

  async handleClose(ws) {
    const userId = ws.userId;
    if (!userId) return;

    // Remove this connection
    const userConnections = this.clients.get(userId);
    if (userConnections) {
      userConnections.delete(ws);

      // If no more connections, mark as offline
      if (userConnections.size === 0) {
        this.clients.delete(userId);

        await db.query(
          'UPDATE users SET is_online = false, last_seen = NOW() WHERE id = $1',
          [userId]
        );

        this.broadcastOnlineStatus(userId, false);
        console.log(`📴 User ${userId} disconnected`);
      }
    }
  }

  async handleReadReceipts(userId, messageIds) {
    if (!messageIds || !messageIds.length) return;

    try {
      // Update message statuses
      await db.query(
        `UPDATE messages SET status = 'read'
         WHERE id = ANY($1) AND sender_id != $2`,
        [messageIds, userId]
      );

      // Get unique sender IDs to notify
      const result = await db.query(
        `SELECT DISTINCT sender_id, chat_id FROM messages WHERE id = ANY($1)`,
        [messageIds]
      );

      // Notify senders
      for (const row of result.rows) {
        this.sendToUser(row.sender_id, {
          type: 'messages_read',
          chatId: row.chat_id,
          messageIds,
          readBy: userId
        });
      }
    } catch (error) {
      console.error('Read receipts error:', error);
    }
  }

  async broadcastOnlineStatus(userId, isOnline) {
    try {
      // Get all chats this user is in
      const chats = await db.query(
        'SELECT chat_id FROM chat_participants WHERE user_id = $1',
        [userId]
      );

      // Get all other participants
      const chatIds = chats.rows.map(r => r.chat_id);
      if (chatIds.length === 0) return;

      const participants = await db.query(
        `SELECT DISTINCT user_id FROM chat_participants
         WHERE chat_id = ANY($1) AND user_id != $2`,
        [chatIds, userId]
      );

      // Notify each participant
      for (const row of participants.rows) {
        this.sendToUser(row.user_id, {
          type: 'user_online_status',
          userId,
          isOnline,
          lastSeen: new Date().toISOString()
        });
      }
    } catch (error) {
      console.error('Broadcast online status error:', error);
    }
  }

  // Send to specific user (all their connections)
  sendToUser(userId, data) {
    const connections = this.clients.get(userId);
    if (!connections) return;

    const message = JSON.stringify(data);
    for (const ws of connections) {
      if (ws.readyState === WebSocket.OPEN) {
        ws.send(message);
      }
    }
  }

  // Broadcast to all participants in a chat (except sender)
  async broadcastToChat(chatId, data, excludeUserId = null) {
    try {
      const participants = await db.query(
        'SELECT user_id FROM chat_participants WHERE chat_id = $1',
        [chatId]
      );

      const message = JSON.stringify(data);

      for (const row of participants.rows) {
        if (row.user_id === excludeUserId) continue;

        const connections = this.clients.get(row.user_id);
        if (!connections) continue;

        for (const ws of connections) {
          if (ws.readyState === WebSocket.OPEN) {
            ws.send(message);
          }
        }
      }
    } catch (error) {
      console.error('Broadcast to chat error:', error);
    }
  }

  // WebRTC Signaling handlers
  handleCallOffer(callerId, message) {
    const { recipientId, offer, callType, chatId } = message;

    console.log(`📞 Call offer from ${callerId} to ${recipientId} (${callType})`);

    this.sendToUser(recipientId, {
      type: 'incoming_call',
      callerId,
      offer,
      callType, // 'audio' or 'video'
      chatId
    });
  }

  handleCallAnswer(answerId, message) {
    const { callerId, answer } = message;

    console.log(`✅ Call answered by ${answerId} to ${callerId}`);

    this.sendToUser(callerId, {
      type: 'call_answered',
      answerId,
      answer
    });
  }

  handleIceCandidate(userId, message) {
    const { recipientId, candidate } = message;

    this.sendToUser(recipientId, {
      type: 'ice_candidate',
      senderId: userId,
      candidate
    });
  }

  handleCallEnd(userId, message) {
    const { recipientId, reason } = message;

    console.log(`📵 Call ended by ${userId}, reason: ${reason || 'normal'}`);

    this.sendToUser(recipientId, {
      type: 'call_ended',
      userId,
      reason: reason || 'normal'
    });
  }

  handleCallReject(userId, message) {
    const { callerId, reason } = message;

    console.log(`❌ Call rejected by ${userId}`);

    this.sendToUser(callerId, {
      type: 'call_rejected',
      userId,
      reason: reason || 'busy'
    });
  }

  // Heartbeat to detect dead connections
  startHeartbeat() {
    setInterval(() => {
      this.wss.clients.forEach((ws) => {
        if (ws.isAlive === false) {
          return ws.terminate();
        }
        ws.isAlive = false;
        ws.ping();
      });
    }, 30000);
  }
}

module.exports = WebSocketManager;
