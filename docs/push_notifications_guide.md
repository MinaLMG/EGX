# EGX Portfolio: Push Notifications Guide (Zero to Hero)

This guide documents the full implementation of the automated wallet rebalancing notification system for the EGX platform.

---

## 1. System Architecture
The system follows a 3-layer architecture:
1.  **Backend (Node.js)**: Runs a background cron job that monitors wallet suggestions. When a change is detected, it sends a payload to Firebase Cloud Messaging (FCM).
2.  **Infrastructure (Firebase)**: Acts as the "Post Office." It receives messages from our server and routes them to registered devices (Android) or Browser Service Workers (Web).
3.  **Frontend (Flutter)**: Handles token registration, permissions, and displaying notifications (foreground vs. background).

---

## 2. Backend Implementation (Node.js)

### Initial Setup
1.  Install `firebase-admin`.
2.  Generate a **Service Account JSON** from Firebase Console > Project Settings > Service Accounts.
3.  **Security**: The JSON must be `.gitignored`. We pass it to the server as a JSON string via the `FIREBASE_SERVICE_ACCOUNT` environment variable.

### Essential Services
- **NotificationService**: Handles the logic of comparing `lastPendingSuggestions` with current ones to avoid spamming the same notification.
- **Notification Model**: Saves a history of alerts so the user can see them in the app even if they dismiss the push.

### ⚠️ Critical Problem: Mongoose `VersionError`
**Problem**: When the cron job tried to save the `fcmToken` while the user was active, MongoDB threw a `VersionError` because the document version changed between the `find()` and the `save()`.
**Solution**: Switched from `.save()` to **Atomic Updates**:
```javascript
await User.findByIdAndUpdate(userId, { $set: { lastPendingSuggestions: newSugs } });
```

---

## 3. Android Implementation

### Configuration
1.  Place `google-services.json` in `android/app/`.
2.  **Multi-Flavor Support**: If using package names like `com.example.egx_mobile` and `com.example.egx_mobile.admin`, ensure BOTH are registered in the Firebase console and included in the same `google-services.json`.

### Gradle Requirements
Because the Firebase and Notification plugins use modern Java features, we had to enable **Core Library Desugaring** in `build.gradle.kts`:
```kotlin
multiDexEnabled = true
isCoreLibraryDesugaringEnabled = true
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}
```

---

## 4. Web Implementation (Chrome / Vercel)

Web Push is fundamentally different because it relies on **Service Workers**.

### 1. The VAPID Handshake
Web browsers require a VAPID key pair. 
- **Setup**: Generate the key in Firebase Console > Cloud Messaging.
- **Usage**: Pass it to `getToken(vapidKey: '...')` in Flutter.

### 2. The Service Worker (`firebase-messaging-sw.js`)
This file must be in the `web/` folder. It runs in the background even when the tab is closed. It imports the Firebase scripts and listens for `onBackgroundMessage`.

### 3. `index.html`
You must include the Firebase JS SDKs in the `<head>` of your `index.html` and initialize the app there as well as in Dart.

---

## 5. Potential Problems & Troubleshooting

### ❌ Problem: "Connection Refused" on Physical Phone
- **Cause**: Using `localhost:5000` in the Flutter code. The phone thinks "localhost" is itself, not your PC.
- **Solution**: Use your PC's local IP (e.g., `192.168.1.10:5000`).

### ❌ Problem: Web Token Not Updating in DB
- **Cause**: Timing. The app was trying to register the token before the user logged in. 
- **Solution**: Call `NotificationService().updateToken()` immediately after a successful Login or Registration.

### ❌ Problem: Notifications Not Appearing in Foreground
- **Cause**: FCM messages are handled by the System Tray when in background, but ignored when in foreground.
- **Solution**: Use the `flutter_local_notifications` package to manually trigger a heads-up alert when a message is received while the app is open.

### ❌ Problem: Browser Blocks Notifications
- **Cause**: Security rules.
- **Solution**: Web Push **requires HTTPS**. Testing on Vercel is fine, but local testing must use `localhost` (which browsers trust) or a secure tunnel.

---

## 7. iOS Implementation (Apple)

iOS implementation is stricter and requires a physical device (no simulators) and an Apple Developer account.

### 1. Configuration
1.  **Register App**: Use Bundle ID `com.example.egxMobile` in Firebase Console.
2.  **Config File**: Download `GoogleService-Info.plist` and place it in `ios/Runner/`.

### 2. Xcode Capabilities
You MUST enable these in Xcode for notifications to arrive:
- **Push Notifications**: Adds the entitlement to your app.
- **Background Modes**: Check "Remote notifications".

### 3. APNs Integration
Firebase acts as a wrapper for **APNs** (Apple Push Notification service).
- Generate an **APNs Auth Key (.p8)** in Apple Developer Portal.
- Upload this `.p8` file to Firebase Console > Project Settings > Cloud Messaging > Apple app connection.

### 4. Foreground Handling (Darwin)
Unlike Android, iOS uses "Darwin" settings for technical details. The `NotificationService` now includes `DarwinNotificationDetails` to ensure that even when the app is open, the user sees the alert.

---

## 8. Maintenance Checklist
- [ ] **Rotate Keys**: If `FIREBASE_SERVICE_ACCOUNT` is ever leaked, revoke it in Google Cloud Console.
- [ ] **Market Hours**: The cron job in `app.js` is guarded by `isMarketHour`. To test at night, you must temporarily bypass this check.
- [ ] **VAPID Key**: Ensure the VAPID key in Flutter matches the one in the Firebase Console perfectly.
- [ ] **iOS certificates**: Ensure the APNs certificate/key hasn't expired (usually lasts 1 year for certificates, keys are permanent).
