# Privet Server

Backend сервер для мессенджера Privet с username-based авторизацией. Хранение медиафайлов и push-уведомления через APNs.

## Особенности

- Username + password авторизация (без номера телефона/email)
- PostgreSQL база данных
- WebSocket для real-time сообщений
- JWT токены
- Собственное хранилище медиа
- APNs push-уведомления

## Установка

```bash
cd server
npm install
cp .env.example .env
# Отредактируйте .env
```

## Запуск

```bash
# Development
npm run dev

# Production
npm start
```

## API Endpoints

### Media

#### Upload Image
```
POST /api/media/upload/image
Content-Type: multipart/form-data

Fields:
- image: файл изображения
- chatId: ID чата
- messageId: ID сообщения

Response: { success: true, url: "http://..." }
```

#### Upload Video
```
POST /api/media/upload/video
Content-Type: multipart/form-data

Fields:
- video: файл видео
- chatId: ID чата
- messageId: ID сообщения
```

### Push Notifications

#### Register Device
```
POST /api/push/register
Content-Type: application/json

{ "userId": "...", "deviceToken": "..." }
```

#### Send Message Notification
```
POST /api/push/notify/message
Content-Type: application/json

{
  "recipientId": "...",
  "senderName": "...",
  "messageText": "...",
  "chatId": "..."
}
```

## Настройка APNs

1. Зайдите в Apple Developer Portal → Certificates, Identifiers & Profiles
2. Keys → Create a Key → Enable "Apple Push Notifications service (APNs)"
3. Скачайте .p8 файл и положите в `certs/AuthKey.p8`
4. Заполните в .env:
   - `APNS_KEY_ID` — Key ID из портала
   - `APNS_TEAM_ID` — Team ID (Account → Membership)
   - `APNS_BUNDLE_ID` — Bundle ID вашего приложения

## Деплой

Сервер можно развернуть на любом хостинге:
- VPS (DigitalOcean, Hetzner, Timeweb)
- Docker
- Heroku, Railway, Render

Рекомендуется использовать nginx как reverse proxy и настроить HTTPS.
