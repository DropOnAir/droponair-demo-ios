# DropOnAir Demo - iOS

SwiftUI demo app showing how to integrate the [DropOnAir iOS SDK](https://github.com/DropOnAir/droponair-sdk-ios-binary) for end-to-end encrypted messaging.

## What it demonstrates

- Login via the [demo backend](https://github.com/DropOnAir/droponair-demo-backend) (JWT issued on `/api/auth/login`)
- Initialising `DropOnAir` with a token-exchange URL
- Connecting as a user and receiving the `isConnected` callback
- Sending and receiving end-to-end-encrypted text messages in a chat UI
- Group messaging with create/join/send
- Voice/video call signaling (start, accept, reject, end)

## Requirements

- Xcode 15+
- macOS 13+ (for local development / run in simulator)
- The [demo backend](https://github.com/DropOnAir/droponair-demo-backend) running on `localhost:8180`

## Getting Started

1. Clone this repo and the [demo backend](https://github.com/DropOnAir/droponair-demo-backend)
2. Create a free account at [panel.droponair.com](https://panel.droponair.com) and create an app
3. Edit `Sources/DropOnAirDemo/Config.swift` with your credentials:

```swift
let backendURL            = "http://localhost:8180"
let droponairAppId        = "YOUR_APP_ID"          // From the DropOnAir dashboard
let droponairPublicApiKey = "YOUR_PUBLIC_API_KEY"   // From the DropOnAir dashboard
```

## Run

1. Start the backend: `cd droponair-demo-backend && ./mvnw spring-boot:run`
2. Open this package in Xcode (**File > Open…**, select the folder)
3. Select the **DropOnAirDemo** scheme and a simulator
4. Build & Run (⌘R)

## Architecture

```
DropOnAirDemoApp     , @main, owns AuthService + ChatViewModel state
  ├── LoginView      , user ID / display name form → triggers connect()
  └── ChatView       , message bubbles + input bar
        └── ChatViewModel , ObservableObject, DropOnAirDelegate
```
