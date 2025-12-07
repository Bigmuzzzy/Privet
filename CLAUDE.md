# Privet - WhatsApp-style iOS Messenger

## Project Overview
iOS messenger app built with SwiftUI, styled like WhatsApp. For personal/private use.
**100% custom backend** - No Firebase/Google dependencies. Uses PostgreSQL + custom Node.js server.

### Key Features
- ✅ **Username-based auth** - No phone number or email required, just username + password
- ✅ **Complete privacy** - All data stays on your own server
- ✅ **Real-time messaging** - WebSocket for instant delivery
- ✅ **Media sharing** - Photos stored on your server, not cloud services

## Tech Stack
- **UI**: SwiftUI, MVVM architecture
- **Backend**: Custom Node.js server (Express)
- **Database**: PostgreSQL
- **Real-time**: WebSocket (ws)
- **Auth**: JWT (JSON Web Tokens)
- **Media Storage**: Custom server (Express + Multer + Sharp)
- **Push Notifications**: APNs (Apple Push Notification Service) - direct, no FCM
- **Language**: Swift (iOS 17+), Node.js (server)

## Project Structure

### iOS App
```
Privet/
├── Models/
│   ├── User.swift
│   ├── Chat.swift
│   └── Message.swift
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── RegisterView.swift
│   ├── Chats/
│   │   ├── ChatsListView.swift
│   │   └── ChatRowView.swift
│   ├── Conversation/
│   │   ├── ConversationView.swift
│   │   ├── MessageBubbleView.swift
│   │   ├── MessageInputView.swift
│   │   └── MediaPickerView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Components/
│       └── AvatarView.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── ChatsViewModel.swift
│   └── ConversationViewModel.swift
├── Services/
│   ├── APIClient.swift              # HTTP client with JWT
│   ├── WebSocketService.swift       # Real-time updates
│   ├── AuthService.swift            # Authentication
│   ├── ChatService.swift            # Chats & messages
│   ├── MediaService.swift           # Upload to server
│   └── PushNotificationService.swift # APNs
├── Extensions/
│   ├── Color+Extensions.swift
│   └── Date+Extensions.swift
├── PrivetApp.swift
└── ContentView.swift
```

### Server
```
server/
├── src/
│   ├── index.js              # Express + WebSocket entry
│   ├── db/
│   │   ├── index.js          # PostgreSQL connection pool
│   │   └── schema.sql        # Database schema
│   ├── middleware/
│   │   └── auth.js           # JWT middleware
│   ├── routes/
│   │   ├── auth.js           # Register, login, logout
│   │   ├── users.js          # User profile, search
│   │   ├── chats.js          # Chat CRUD
│   │   ├── messages.js       # Messages CRUD
│   │   ├── media.js          # Image/video upload
│   │   └── push.js           # Push notification endpoints
│   └── services/
│       ├── websocket.js      # WebSocket manager
│       └── apns.js           # APNs provider
├── uploads/
│   ├── images/
│   └── videos/
├── certs/                    # APNs .p8 key file
├── package.json
├── .env.example
└── README.md
```

## Database Schema (PostgreSQL)

- **users** - User accounts (username, password_hash, display_name, avatar, status, online)
- **chats** - Chat rooms (type: private/group)
- **chat_participants** - Links users to chats
- **messages** - Messages with status tracking
- **message_receipts** - Read/delivered receipts
- **contacts** - User contacts

## Server API

### Auth Endpoints
- `POST /api/auth/register` - Register { username, password, displayName }
- `POST /api/auth/login` - Login { username, password }
- `POST /api/auth/logout` - Logout (requires auth)
- `GET /api/auth/me` - Get current user (requires auth)

### Users Endpoints
- `GET /api/users/:id` - Get user by ID
- `GET /api/users/search/username?username=` - Search by username
- `PATCH /api/users/me` - Update profile
- `POST /api/users/device-token` - Register push token
- `POST /api/users/online-status` - Update online status

### Chats Endpoints
- `GET /api/chats` - Get all chats
- `POST /api/chats/private` - Create/get private chat { userId }
- `GET /api/chats/:id` - Get chat by ID
- `POST /api/chats/:id/read` - Mark as read
- `DELETE /api/chats/:id` - Leave chat

### Messages Endpoints
- `GET /api/messages/chat/:chatId` - Get messages (pagination: limit, before)
- `POST /api/messages` - Send message { chatId, content, type, mediaUrl }
- `PATCH /api/messages/:id/status` - Update status { status }
- `DELETE /api/messages/:id` - Delete message

### Media Endpoints
- `POST /api/media/upload/image` - Upload image
- `POST /api/media/upload/video` - Upload video
- `DELETE /api/media/:chatId/:filename` - Delete media
- `GET /uploads/images/:chatId/:filename` - Serve image

### WebSocket
- Connect: `ws://localhost:3000/ws?token=JWT_TOKEN`
- Messages:
  - `new_message` - New message received
  - `message_status` - Message status updated
  - `typing` - Typing indicator
  - `user_online_status` - Online status changed
  - `message_deleted` - Message was deleted

## Configuration

### iOS App
In `APIClient.swift`:
```swift
#if DEBUG
private let baseURL = "http://localhost:3000"
private let wsURL = "ws://localhost:3000/ws"
#else
private let baseURL = "https://your-server.com"
private let wsURL = "wss://your-server.com/ws"
#endif
```

### Server
Copy `.env.example` to `.env` and configure:
```
PORT=3000
HOST=0.0.0.0
BASE_URL=http://localhost:3000

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=privet
DB_USER=postgres
DB_PASSWORD=

# JWT
JWT_SECRET=your-super-secret-key
JWT_EXPIRES_IN=30d

# APNs
APNS_KEY_ID=YOUR_KEY_ID
APNS_TEAM_ID=YOUR_TEAM_ID
APNS_BUNDLE_ID=com.yourcompany.Privet
APNS_KEY_PATH=./certs/AuthKey.p8
```

## Running

### Prerequisites
- PostgreSQL installed (via Postgres.app or Homebrew)
- Node.js 18+
- Xcode 15+

### Database Setup
```bash
# Create database
psql -U postgres -c "CREATE DATABASE privet;"

# Apply schema
psql -U postgres -d privet -f server/src/db/schema.sql
```

### Server (Development)
```bash
cd server
npm install
cp .env.example .env
# Edit .env with your settings
npm run dev
```

### iOS App
1. Open `Privet.xcodeproj` in Xcode
2. Build and run on simulator or device
3. Make sure server is running on localhost:3000

## Current Status

### Completed
- [x] User registration/login with JWT (username + password)
- [x] PostgreSQL database with full schema
- [x] Chat list with real-time WebSocket updates
- [x] 1-on-1 private messaging
- [x] Message status indicators (sent, delivered, read)
- [x] Online status tracking
- [x] Typing indicators
- [x] WhatsApp-style UI
- [x] Custom media server (image upload)
- [x] Push notification infrastructure (APNs)
- [x] Photo sending via custom server
- [x] Username-based authentication (no phone/email required)

### Pending
- [ ] Video sending
- [ ] Voice messages
- [ ] Voice/video calls (WebRTC)
- [ ] Group chats

## Deployment

Server can be deployed to any hosting:
- VPS (DigitalOcean, Hetzner, Timeweb, etc.)
- Docker
- Railway, Render, etc.

Recommended: nginx reverse proxy + Let's Encrypt SSL + managed PostgreSQL

## WhatsApp Colors
```swift
Color.whatsAppGreen      // #25D366
Color.whatsAppDarkGreen  // #128C7E
Color.whatsAppLight      // #DCF8C6
Color.whatsAppChatBackground // #ECE5DD
Color.whatsAppBlue       // #34B7F1
```
