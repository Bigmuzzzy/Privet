# Privet 💬

WhatsApp-style iOS messenger with complete privacy. No phone numbers, no emails, no Firebase.

## 🔐 Key Features

- **Username-based authentication** - Register with just username + password
- **100% private** - Your own server, your data
- **Real-time messaging** - WebSocket for instant delivery
- **Media sharing** - Photos stored on your server
- **WhatsApp UI** - Familiar and beautiful design

## 🏗 Tech Stack

**iOS App:**
- SwiftUI + MVVM
- WebSocket for real-time
- JWT authentication
- PhotosUI for media

**Backend:**
- Node.js + Express
- PostgreSQL database
- WebSocket server
- APNs push notifications

## 🚀 Quick Start

### Prerequisites

- Xcode 15+
- Node.js 18+
- PostgreSQL (via Postgres.app)

### Setup Database

```bash
# Create database
/Applications/Postgres.app/Contents/Versions/latest/bin/psql -U postgres -c "CREATE DATABASE privet;"

# Apply schema
/Applications/Postgres.app/Contents/Versions/latest/bin/psql -U postgres -d privet -f server/src/db/schema.sql
```

### Run Server

```bash
cd server
npm install
cp .env.example .env
# Edit .env with your settings
npm run dev
```

Server runs at http://localhost:3000

### Run iOS App

1. Open `Privet.xcodeproj` in Xcode
2. Build and run (Cmd+R)
3. Register with username + password

## 📱 Features

✅ Username-based registration (no phone/email)
✅ 1-on-1 private messaging
✅ Real-time message delivery
✅ Online status & typing indicators
✅ Photo sharing
✅ Message status (sent/delivered/read)
✅ Push notifications (APNs)

🔜 Coming soon:
- Video messages
- Voice messages
- Voice/video calls (WebRTC)
- Group chats

## 🔒 Privacy

- No Firebase or Google services
- No phone number required
- All data on your server
- Open source

## 📖 Documentation

- [PLAN.md](PLAN.md) - Development plan (Russian)
- [CLAUDE.md](CLAUDE.md) - Technical documentation

## 🛠 API Endpoints

### Auth
- `POST /api/auth/register` - Register { username, password, displayName }
- `POST /api/auth/login` - Login { username, password }

### Chats
- `GET /api/chats` - Get all chats
- `POST /api/chats/private` - Create/get private chat

### Messages
- `GET /api/messages/chat/:chatId` - Get messages
- `POST /api/messages` - Send message

### Users
- `GET /api/users/search/username?username=` - Search users

## 🎨 Design

Inspired by WhatsApp with colors:
- Primary Green: `#25D366`
- Dark Green: `#128C7E`
- Light Green: `#DCF8C6`
- Background: `#ECE5DD`

## 📄 License

MIT

---

Built with privacy in mind 🔒
