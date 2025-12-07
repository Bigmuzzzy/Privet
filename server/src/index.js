require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const path = require('path');
const http = require('http');

const db = require('./db');
const WebSocketManager = require('./services/websocket');

// Routes
const authRoutes = require('./routes/auth');
const usersRoutes = require('./routes/users');
const chatsRoutes = require('./routes/chats');
const messagesRoutes = require('./routes/messages');
const mediaRoutes = require('./routes/media');
const pushRoutes = require('./routes/push');

const app = express();
const server = http.createServer(app);
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';

// Initialize WebSocket
const wsManager = new WebSocketManager(server);
wsManager.startHeartbeat();
app.set('wsManager', wsManager);

// Middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: "cross-origin" }
}));
app.use(cors());
app.use(express.json());

// Serve uploaded files statically
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/users', usersRoutes);
app.use('/api/chats', chatsRoutes);
app.use('/api/messages', messagesRoutes);
app.use('/api/media', mediaRoutes);
app.use('/api/push', pushRoutes);

// Health check
app.get('/health', async (req, res) => {
  try {
    await db.query('SELECT 1');
    res.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      database: 'connected',
      websocket: 'running'
    });
  } catch (error) {
    res.status(500).json({
      status: 'error',
      timestamp: new Date().toISOString(),
      database: 'disconnected'
    });
  }
});

// Error handling
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(500).json({ error: err.message || 'Internal server error' });
});

// Start server
server.listen(PORT, HOST, async () => {
  console.log(`🚀 Privet server running at http://${HOST}:${PORT}`);
  console.log(`📁 Media uploads: http://${HOST}:${PORT}/uploads`);
  console.log(`🔌 WebSocket: ws://${HOST}:${PORT}/ws`);
  console.log(`🔔 Push notifications: APNs ready`);

  // Test database connection
  try {
    await db.query('SELECT NOW()');
    console.log('📦 PostgreSQL connected');
  } catch (error) {
    console.error('❌ PostgreSQL connection failed:', error.message);
  }
});
