# Missed Class Notifier - Setup Guide

## Prerequisites

- Flutter SDK 3.x
- Dart SDK (included with Flutter)
- Firebase CLI
- Node.js 18+ (for Cloud Functions)
- Android Studio or Xcode (for native builds)

## Quick Start

### 1. Clone and Install Dependencies

```bash
cd TutorNotification
flutter pub get
```

### 2. Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable these services:
   - Authentication (Phone)
   - Cloud Firestore
   - Cloud Functions
   - Cloud Messaging

3. Add Android app:
   - Package name: `com.missedclassnotifier`
   - Download `google-services.json`
   - Place in `android/app/google-services.json`

4. Add iOS app:
   - Bundle ID: `com.missedclassnotifier`
   - Download `GoogleService-Info.plist`
   - Place in `ios/Runner/GoogleService-Info.plist`

### 3. Android Configuration

Create `android/local.properties`:
```properties
sdk.dir=/path/to/android/sdk
flutter.sdk=/path/to/flutter
```

### 4. Cloud Functions Setup

```bash
cd functions
npm install
```

Create `.env` file in `functions/` directory:
```env
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_WHATSAPP_FROM=whatsapp:+14155238886
TWILIO_SMS_FROM=+1234567890
```

Deploy functions:
```bash
firebase deploy --only functions
```

### 5. Firestore Rules & Indexes

Deploy security rules and indexes:
```bash
firebase deploy --only firestore
```

### 6. Run the App

```bash
flutter run
```

## Project Structure

```
TutorNotification/
├── lib/
│   ├── main.dart              # App entry point
│   ├── models/                # Data models
│   │   ├── models.dart        # Barrel export
│   │   ├── institute.dart
│   │   ├── batch.dart
│   │   ├── student.dart
│   │   ├── attendance.dart
│   │   ├── teacher.dart
│   │   └── audit_log.dart
│   ├── services/              # Business logic
│   │   ├── services.dart      # Barrel export
│   │   ├── auth_service.dart
│   │   ├── firestore_service.dart
│   │   └── connectivity_service.dart
│   ├── screens/               # UI screens
│   │   ├── splash_screen.dart
│   │   ├── auth/
│   │   ├── dashboard/
│   │   ├── attendance/
│   │   ├── batches/
│   │   ├── students/
│   │   ├── reports/
│   │   └── settings/
│   ├── widgets/               # Reusable widgets
│   │   ├── widgets.dart       # Barrel export
│   │   └── common_widgets.dart
│   └── utils/                 # Helpers and theme
│       ├── utils.dart         # Barrel export
│       ├── theme.dart
│       ├── validators.dart
│       └── helpers.dart
├── functions/                 # Cloud Functions
│   ├── src/
│   │   └── index.ts          # Notification logic
│   └── package.json
├── android/                   # Android native code
├── ios/                       # iOS native code
├── firebase.json             # Firebase config
├── firestore.rules           # Security rules
└── firestore.indexes.json    # Composite indexes
```

## Key Features

1. **Phone OTP Authentication**: Secure login via SMS verification
2. **Offline-First**: Full offline support with Firestore persistence
3. **Tap-to-Mark Attendance**: Single tap cycles through status
4. **WhatsApp Notifications**: Primary channel with SMS fallback
5. **Multi-Teacher Support**: Role-based access (admin/teacher)
6. **Audit Logging**: Track all changes for accountability

## Environment Variables

### Firebase Functions

| Variable | Description |
|----------|-------------|
| `TWILIO_ACCOUNT_SID` | Twilio account identifier |
| `TWILIO_AUTH_TOKEN` | Twilio authentication token |
| `TWILIO_WHATSAPP_FROM` | WhatsApp sender number |
| `TWILIO_SMS_FROM` | SMS sender number |

Set via Firebase:
```bash
firebase functions:config:set twilio.account_sid="xxx" twilio.auth_token="xxx"
```

## Testing

```bash
# Run Flutter tests
flutter test

# Run with coverage
flutter test --coverage
```

## Build for Release

### Android
```bash
flutter build apk --release
# or for app bundle
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## Troubleshooting

### Firebase Auth Phone verification not working
- Ensure SHA-1/SHA-256 fingerprints are added in Firebase Console
- Check if phone number format includes country code (+91)

### Notifications not being sent
- Verify Twilio credentials in Cloud Functions config
- Check Cloud Functions logs: `firebase functions:log`

### Offline data not syncing
- Firestore persistence is enabled by default
- Check connectivity status in app settings
