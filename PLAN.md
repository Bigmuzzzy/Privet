# Privet Messenger - План разработки

## Обзор
iOS мессенджер в стиле WhatsApp для приватного использования.
**100% собственный бэкенд** - без Firebase/Google зависимостей.

### Особенности
- ✅ **Авторизация без номера телефона/email** - только username + password
- ✅ **Полная конфиденциальность** - никаких данных не уходит в Google/Firebase
- ✅ **Собственный сервер** - полный контроль над данными

## Технологический стек
- **UI**: SwiftUI
- **Архитектура**: MVVM
- **Бэкенд**: Node.js (Express) + PostgreSQL
- **Реал-тайм**: WebSocket
- **Авторизация**: JWT (username + password, без email/номера телефона)
- **Медиа**: PhotosUI, AVFoundation, собственный сервер
- **Push-уведомления**: APNs (напрямую, без FCM)
- **Звонки (планируется)**: WebRTC

---

## Структура проекта

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
│   ├── Calls/
│   │   ├── IncomingCallView.swift
│   │   └── ActiveCallView.swift
│   ├── Settings/
│   │   └── SettingsView.swift
│   └── Components/
│       └── AvatarView.swift
├── ViewModels/
│   ├── AuthViewModel.swift
│   ├── ChatsViewModel.swift
│   └── ConversationViewModel.swift
├── Services/
│   ├── APIClient.swift
│   ├── WebSocketService.swift
│   ├── AuthService.swift
│   ├── ChatService.swift
│   ├── MediaService.swift
│   ├── PushNotificationService.swift
│   ├── CallManager.swift          # WebRTC управление звонками
│   └── CallKitManager.swift       # CallKit интеграция
└── Extensions/
    ├── Color+Extensions.swift
    └── Date+Extensions.swift
```

### Server
```
server/
├── src/
│   ├── index.js
│   ├── db/
│   │   ├── index.js
│   │   └── schema.sql
│   ├── middleware/
│   │   └── auth.js
│   ├── routes/
│   │   ├── auth.js
│   │   ├── users.js
│   │   ├── chats.js
│   │   ├── messages.js
│   │   ├── media.js
│   │   └── push.js
│   └── services/
│       ├── websocket.js
│       └── apns.js
├── uploads/
├── certs/
└── package.json
```

---

## Выполненные задачи

### Авторизация
- [x] Модель User (id, username, password_hash, displayName, avatar, status, lastSeen)
- [x] LoginView - экран входа (username + password, без номера телефона)
- [x] RegisterView - экран регистрации (username минимум 3 символа)
- [x] AuthViewModel - логика авторизации
- [x] AuthService - JWT авторизация
- [x] Сохранение токена в UserDefaults
- [x] Поиск пользователей по username (вместо phone)

### Список чатов
- [x] Модель Chat (id, participants, lastMessage, unreadCount)
- [x] ChatsListView - список чатов в стиле WhatsApp
- [x] ChatRowView - ячейка чата (аватар, имя, последнее сообщение, время)
- [x] Поиск по чатам
- [x] Real-time обновления через WebSocket

### Переписка 1-на-1
- [x] Модель Message (id, chatId, senderId, content, type, status, createdAt)
- [x] ConversationView - экран переписки
- [x] MessageBubbleView - пузырьки сообщений (свои/чужие)
- [x] MessageInputView - поле ввода + кнопка отправки
- [x] Статусы сообщений (sent, delivered, read)
- [x] Скролл к последнему сообщению
- [x] Real-time получение сообщений

### Навигация
- [x] TabView (Чаты, Настройки)
- [x] NavigationStack для переходов

### Бэкенд
- [x] PostgreSQL база данных со схемой (username-based)
- [x] Express сервер с JWT авторизацией (username + password)
- [x] WebSocket для real-time обновлений
- [x] REST API для всех операций
- [x] Онлайн-статус пользователей
- [x] Индикатор набора текста
- [x] Поиск пользователей по username

### Отправка медиа
- [x] MediaPickerView - выбор фото из галереи
- [x] MediaService - загрузка на сервер
- [x] Отображение изображений в чате
- [x] Сжатие изображений перед отправкой

### Push-уведомления
- [x] APNs инфраструктура на сервере
- [x] PushNotificationService на iOS
- [x] Регистрация device token
- [x] Обработка входящих уведомлений

### Голосовые/видеозвонки (WebRTC)
- [x] WebRTC signaling на сервере (websocket.js)
- [x] CallManager с WebRTC peer connection
- [x] CallKit интеграция для нативного UI
- [x] IncomingCallView - экран входящего звонка
- [x] ActiveCallView - экран активного звонка
- [x] Кнопки звонков в ConversationView
- [x] Управление аудио (mute, speaker)
- [ ] Рендеринг видео (для видеозвонков)

---

## Запланированные задачи

### Отправка видео
- [ ] Выбор видео из галереи
- [ ] Загрузка видео на сервер
- [ ] Превью видео (thumbnail)
- [ ] Воспроизведение в чате

### Голосовые сообщения
- [ ] Запись голоса
- [ ] Визуализация аудио
- [ ] Воспроизведение в чате

### Голосовые и видеозвонки
- [x] WebRTC интеграция
- [x] Signaling через WebSocket
- [x] UI входящего звонка
- [x] UI активного звонка
- [x] Управление камерой/микрофоном (аудио)
- [x] CallKit интеграция
- [ ] Рендеринг видео для видеозвонков
- [ ] Переключение камер

### Групповые чаты
- [ ] Создание группы
- [ ] Добавление участников
- [ ] Админ-права
- [ ] Название и аватар группы

---

## Дизайн (WhatsApp стиль)

### Цветовая схема
- Primary Green: #25D366
- Dark Green: #128C7E
- Light Green: #DCF8C6 (свои сообщения)
- Background: #ECE5DD
- Blue: #34B7F1

### Элементы UI
- Круглые аватары
- Пузырьки сообщений с хвостиками
- Галочки статуса (✓ ✓)
- Время в правом нижнем углу пузырька
