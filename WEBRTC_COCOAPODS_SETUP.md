# Настройка WebRTC через CocoaPods

## Проблема

WebRTC пакет от `stasel/WebRTC.git` несовместим с Xcode 26.1 из-за проблем с explicit modules. Код WebRTC временно отключен, чтобы остальное приложение работало.

## Решение: Использовать CocoaPods

### Шаг 1: Установить CocoaPods (если ещё не установлен)

```bash
sudo gem install cocoapods
```

### Шаг 2: Создать Podfile

В корне проекта `/Users/mike/Dev/Privet`:

```bash
cd /Users/mike/Dev/Privet
cat > Podfile <<'EOF'
platform :ios, '17.6'

target 'Privet' do
  use_frameworks!

  # WebRTC from Google
  pod 'GoogleWebRTC', '~> 1.1'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.6'
    end
  end
end
EOF
```

### Шаг 3: Установить зависимости

```bash
pod install
```

### Шаг 4: Удалить старый WebRTC пакет из Xcode

1. Открой `Privet.xcworkspace` (ВАЖНО: не .xcodeproj!)
2. В Xcode выбери проект **Privet**
3. Перейди в **Package Dependencies**
4. Удали пакет **WebRTC** от stasel

### Шаг 5: Восстановить код WebRTC

```bash
cd /Users/mike/Dev/Privet/Privet/Services

# Восстановить CallManager
mv CallManager.swift.disabled CallManager.swift

# Восстановить CallKitManager
mv CallKitManager.swift.disabled CallKitManager.swift
```

### Шаг 6: Создать папку Calls views

```bash
mkdir -p /Users/mike/Dev/Privet/Privet/Views/Calls
```

### Шаг 7: Раскомментировать код

В следующих файлах нужно раскомментировать WebRTC код:

#### ContentView.swift
- Раскомментируй `@ObservedObject private var callManager = CallManager.shared`
- Раскомментируй весь блок `ZStack { ... }` с call overlays

#### ConversationView.swift
- Раскомментируй код в `startAudioCall()` и `startVideoCall()`

#### WebSocketService.swift
- Раскомментируй WebRTC Call Publishers
- Раскомментируй WebRTC Call Events в `handleMessage`

### Шаг 8: Пересоздать Call Views

Создай файлы:
- `/Users/mike/Dev/Privet/Privet/Views/Calls/IncomingCallView.swift`
- `/Users/mike/Dev/Privet/Privet/Views/Calls/ActiveCallView.swift`

Код для этих файлов есть в Git истории (commit WebRTC implementation).

### Шаг 9: Собрать проект

1. Закрой Xcode
2. Открой `Privet.xcworkspace`
3. ⌘+B - собрать
4. ⌘+R - запустить

## Альтернатива: Без звонков

Если не нужны звонки сейчас, оставь всё как есть:
- Приложение работает без WebRTC
- Кнопки звонков показывают "Feature coming soon"
- Можно добавить WebRTC позже

## Текущий статус

✅ Приложение компилируется успешно
✅ Сообщения работают
✅ Фото работают
✅ Push уведомления работают
⏳ Звонки отключены (ждут настройки WebRTC)

## Контакты серверной части

WebRTC signaling уже реализован на сервере:
- `server/src/services/websocket.js` - готов к работе
- Поддерживает: call_offer, call_answer, ice_candidate, call_end, call_reject

Когда WebRTC будет настроен на iOS, звонки заработают сразу! 📞
