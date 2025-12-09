# Добавление разрешений для камеры и микрофона

## Через Xcode (Recommended)

1. **Открой проект** в Xcode:
   ```bash
   open /Users/mike/Dev/Privet/Privet.xcodeproj
   ```

2. **В левой панели** выбери **Privet** (синяя иконка проекта сверху)

3. **Targets** → выбери **Privet**

4. **Info** таб

5. **Прокрути вниз** до секции **Custom iOS Target Properties**

6. **Добавь разрешения**:

   Нажми **+** и добавь:

   - **Key**: `Privacy - Microphone Usage Description`
   - **Type**: `String`
   - **Value**: `Privet needs microphone access for calls`

   Нажми **+** еще раз:

   - **Key**: `Privacy - Camera Usage Description`
   - **Type**: `String`
   - **Value**: `Privet needs camera access for video calls`

7. **Сохрани** (⌘+S)

---

## Вариант 2: Создать Info.plist вручную (если файла нет)

Если хочешь создать отдельный файл Info.plist:

1. В Xcode: **File** → **New** → **File**
2. Выбери **Property List**
3. Назови **Info.plist**
4. Сохрани в папку `Privet/`
5. Добавь ключи как в варианте 1

---

## Проверка

После добавления разрешений:

1. **Собери проект** (⌘+B)
2. **Запусти на симуляторе** или устройстве
3. При первом звонке iOS покажет диалог с запросом разрешений

## Примечание

Для iOS Simulator звонки работают с микрофоном Mac, но камера может не работать.
Для полного тестирования видео нужно реальное устройство.
