# WebRTC Setup Instructions

## Adding WebRTC SDK to Xcode Project

The `CallManager.swift` service requires the WebRTC framework. Follow these steps to add it to your project:

### Option 1: Swift Package Manager (Recommended)

1. Open `Privet.xcodeproj` in Xcode
2. Go to **File** → **Add Package Dependencies...**
3. Enter this URL in the search bar:
   ```
   https://github.com/stasel/WebRTC.git
   ```
4. Select version: **125.6422.04** (or latest stable)
5. Click **Add Package**
6. Select **WebRTC** library and click **Add Package**

### Option 2: CocoaPods

1. Create a `Podfile` in the project root if it doesn't exist:
   ```bash
   cd /Users/mike/Dev/Privet
   pod init
   ```

2. Edit the `Podfile`:
   ```ruby
   platform :ios, '15.0'

   target 'Privet' do
     use_frameworks!
     pod 'GoogleWebRTC', '~> 1.1'
   end
   ```

3. Install the pod:
   ```bash
   pod install
   ```

4. From now on, open `Privet.xcworkspace` instead of `Privet.xcodeproj`

## Required Permissions

Add these permissions to `Info.plist`:

1. **Camera Permission** (for video calls):
   - Key: `NSCameraUsageDescription`
   - Value: `Privet needs camera access for video calls`

2. **Microphone Permission** (for audio/video calls):
   - Key: `NSMicrophoneUsageDescription`
   - Value: `Privet needs microphone access for calls`

### Adding in Xcode:

1. Open project settings
2. Select **Privet** target
3. Go to **Info** tab
4. Click **+** to add new entries
5. Add both keys and values

## Audio Session Configuration

The `CallManager` automatically configures the audio session for calls using:
- Category: `.playAndRecord`
- Mode: `.voiceChat`
- Options: `.allowBluetooth`, `.defaultToSpeaker`

## ICE Servers (STUN)

The CallManager uses Google's public STUN servers:
- `stun:stun.l.google.com:19302`
- `stun:stun1.l.google.com:19302`

For production, consider:
- Adding TURN servers for better NAT traversal
- Using your own STUN/TURN infrastructure (e.g., coturn)
- Commercial services like Twilio STUN/TURN

## Testing

After adding the WebRTC SDK:

1. Build the project (⌘+B) to verify no errors
2. The CallManager will be ready to use
3. Next step: Create the call UI views

## Architecture

```
┌─────────────────┐
│   Call Views    │  ← UI layer (to be created)
└────────┬────────┘
         │
┌────────▼────────┐
│  CallManager    │  ← WebRTC peer connection management
└────────┬────────┘
         │
┌────────▼────────┐
│ WebSocketService│  ← Signaling (offer/answer/ICE)
└────────┬────────┘
         │
┌────────▼────────┐
│  Node.js Server │  ← WebSocket signaling relay
└─────────────────┘
```

## Current Implementation Status

✅ Server-side WebRTC signaling (websocket.js)
✅ WebSocketService publishers for call events
✅ CallManager service with full WebRTC support
✅ CallKit integration for native iOS call experience
✅ Call UI views:
   - IncomingCallView - Full-screen incoming call UI
   - ActiveCallView - Active call with controls
   - ConversationView - Call buttons integrated
✅ ContentView - Call overlays management
⏳ Video rendering views (for video calls)
⏳ Testing and debugging

## What's Implemented

### Audio Calls
- ✅ Outgoing audio calls
- ✅ Incoming audio calls
- ✅ Call controls (mute, speaker)
- ✅ CallKit integration (native iOS call screen)
- ✅ WebRTC peer-to-peer connection
- ✅ Real-time signaling via WebSocket

### Video Calls
- ✅ Basic infrastructure ready
- ⏳ Video rendering views needed
- ⏳ Camera switching controls

## Next Steps

1. **Add WebRTC SDK** using one of the options above
2. **Add permissions** to Info.plist
3. **Build project** to verify setup
4. **Test audio calls** between two devices
5. **Implement video rendering** for video calls
