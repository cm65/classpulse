# Deployment Guide - Missed Class Notifier

Complete setup guide for deploying the Flutter app and Cloud Functions to production.

---

## Prerequisites

- [x] Flutter SDK installed (v3.38+)
- [x] Node.js 20+ installed
- [ ] Firebase CLI installed (`npm install -g firebase-tools`)
- [ ] Firebase project created (tutornotification)
- [ ] Twilio account (for WhatsApp/SMS)
- [ ] Java 11+ for Android builds
- [ ] Android Studio with SDK tools

---

## Secret & Key Management

### Service Account Keys
- **NEVER** commit `serviceAccountKey.json` to version control
- Download from Firebase Console > Project Settings > Service Accounts
- Store locally (gitignored) for development scripts only
- For CI/CD, use GitHub Secrets or equivalent
- Rotate keys periodically via Firebase Console

### Cloud Functions Secrets
All sensitive values are stored in Firebase Secret Manager:
```bash
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set MSG91_AUTH_KEY
```

### Environment Variables
Copy `.env.example` to `.env` and fill in non-secret config values.
See `.env.example` for all required variables.

---

## Step 1: Install Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

---

## Step 2: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **"Add Project"**
3. Name it (e.g., `tutor-notification`)
4. Enable/disable Google Analytics as preferred
5. Click **Create Project**

### Enable Required Services

In your Firebase project:

1. **Firestore Database**
   - Build → Firestore Database → Create database
   - Start in **test mode** for development
   - Select region: `asia-south1` (Mumbai) for India

2. **Authentication**
   - Build → Authentication → Get started
   - Sign-in method → Enable **Phone**

3. **Cloud Functions** (requires Blaze plan)
   - Build → Functions → Upgrade to Blaze plan

---

## Step 3: Configure Firebase in Flutter App

### Add Web App
1. Project settings → Your apps → Add app → **Web** `</>`
2. Register app nickname: `tutor-web`
3. Copy the config values

### Add Android App
1. Add app → **Android**
2. Package name: `com.example.missed_class_notifier`
3. Download `google-services.json`
4. Place in `android/app/google-services.json`

### Add iOS App
1. Add app → **iOS**
2. Bundle ID: `com.example.missedClassNotifier`
3. Download `GoogleService-Info.plist`
4. Place in `ios/Runner/GoogleService-Info.plist`

### Update firebase_options.dart

Edit `lib/firebase_options.dart` with your values:

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'YOUR_API_KEY',              // From Firebase Console
  appId: '1:xxx:web:xxx',              // From Firebase Console
  messagingSenderId: '123456789',       // Project number
  projectId: 'your-project-id',
  authDomain: 'your-project-id.firebaseapp.com',
  storageBucket: 'your-project-id.appspot.com',
);
```

---

## Step 4: Set Up Twilio (WhatsApp/SMS)

### Create Twilio Account
1. Go to [Twilio](https://www.twilio.com) → Sign up
2. Verify your phone number
3. Get a Twilio phone number

### Enable WhatsApp Sandbox (for testing)
1. Messaging → Try it out → Send a WhatsApp message
2. Follow the sandbox setup instructions
3. Note the sandbox number

### Get Credentials
From Twilio Console:
- Account SID: `ACXXXXXXXXX`
- Auth Token: `your-auth-token`
- WhatsApp Number: `+14155238886` (sandbox)
- SMS Number: Your Twilio number

---

## Step 5: Deploy Cloud Functions

### Initialize Firebase in Project

```bash
cd /Users/chandramahadevan/TutorNotification
firebase init

# Select:
# - Functions (press space to select)
# - Use existing project → select your project
# - TypeScript
# - Don't overwrite existing files
```

### Configure Twilio Secrets (using Secret Manager)

```bash
# Set each secret (you'll be prompted for the value)
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_PHONE_NUMBER
firebase functions:secrets:set TWILIO_WHATSAPP_NUMBER
```

### Deploy Functions

```bash
cd functions
npm install
npm run build
npm run deploy
# Or from project root: firebase deploy --only functions
```

### Verify Deployment
Check Firebase Console → Functions to see:
- `onAttendanceSubmit` - Triggers on new attendance
- `twilioWebhook` - Receives delivery status
- `retryNotification` - Retry failed notifications

---

## Step 6: Set Up Firestore Security Rules

In Firebase Console → Firestore → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }

    function isTeacher(instituteId) {
      return isAuthenticated() &&
        exists(/databases/$(database)/documents/institutes/$(instituteId)/teachers/$(request.auth.uid));
    }

    // Institutes
    match /institutes/{instituteId} {
      allow read: if isTeacher(instituteId);
      allow write: if false; // Admin only

      // Batches
      match /batches/{batchId} {
        allow read, write: if isTeacher(instituteId);
      }

      // Students
      match /students/{studentId} {
        allow read, write: if isTeacher(instituteId);
      }

      // Attendance
      match /attendance/{attendanceId} {
        allow read, write: if isTeacher(instituteId);

        match /records/{recordId} {
          allow read, write: if isTeacher(instituteId);
        }
      }

      // Teachers
      match /teachers/{teacherId} {
        allow read: if isTeacher(instituteId);
        allow write: if isAuthenticated() && request.auth.uid == teacherId;
      }

      // Audit logs
      match /auditLogs/{logId} {
        allow read: if isTeacher(instituteId);
        allow create: if isTeacher(instituteId);
      }
    }
  }
}
```

---

## Step 7: Run the App

### Web (Development)
```bash
flutter run -d chrome
```

### Android
```bash
flutter run -d android
```

### iOS
```bash
cd ios && pod install && cd ..
flutter run -d ios
```

### Build for Production

```bash
# Web
flutter build web

# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (requires Xcode)
flutter build ios --release
```

---

## Step 8: Android Release Signing

### 8.1 Create Upload Keystore
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA \
  -keysize 2048 -validity 10000 -alias upload
```
Move keystore to `android/upload-keystore.jks`

### 8.2 Configure key.properties
Create `android/key.properties` (see `key.properties.example`):
```properties
storePassword=your_keystore_password
keyPassword=your_key_password
keyAlias=upload
storeFile=../upload-keystore.jks
```

### 8.3 Build Signed Release
```bash
flutter clean
flutter pub get
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

---

## Step 9: Deploy Firestore Rules & Indexes

### 9.1 Deploy Security Rules
```bash
firebase deploy --only firestore:rules
```

### 9.2 Deploy Composite Indexes
```bash
firebase deploy --only firestore:indexes
```

The `firestore.indexes.json` includes all required composite indexes for:
- Attendance queries by batch and date
- Student queries by active status
- Teacher queries by institute
- Audit log queries by timestamp

---

## Step 10: Production Checklist

### Firebase Setup
- [ ] Firestore security rules deployed
- [ ] Firestore indexes deployed
- [ ] Cloud Functions deployed
- [ ] Twilio secrets configured in Secret Manager
- [ ] Test phone numbers removed (for production)

### Android Build
- [ ] Release keystore created and secured (NOT in version control)
- [ ] `key.properties` configured
- [ ] App bundle builds successfully
- [ ] Proguard rules tested

### Play Store
- [ ] App listing complete
- [ ] Privacy policy URL added
- [ ] Content rating completed
- [ ] App bundle uploaded
- [ ] Release reviewed and published

### Twilio Configuration
- [ ] WhatsApp Business API approved (or sandbox for testing)
- [ ] SMS sender number configured
- [ ] Message templates approved

---

## Test Phone Numbers (Development Only)

For Firebase Auth testing:
- Phone: `+91 9999999999`
- OTP: `123456`

Configure in Firebase Console → Authentication → Sign-in method → Phone → Phone numbers for testing

**Remove these before production deployment!**

---

## Troubleshooting

### Firebase not initializing
- Ensure `firebase_options.dart` has correct values
- Check that all Firebase services are enabled

### Phone auth not working
- Verify phone authentication is enabled in Firebase Console
- Add test phone numbers for development

### WhatsApp messages not sending
- Check Twilio sandbox is set up correctly
- Verify the recipient has joined the sandbox
- Check Cloud Functions logs: `firebase functions:log`

### Build errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run -d chrome
```

---

## Architecture Overview

```
┌─────────────────┐     ┌──────────────────┐
│   Flutter App   │────▶│    Firebase      │
│   (Web/Mobile)  │     │   - Auth         │
└─────────────────┘     │   - Firestore    │
                        └────────┬─────────┘
                                 │
                                 ▼
                        ┌──────────────────┐
                        │ Cloud Functions  │
                        │ onAttendanceSubmit│
                        └────────┬─────────┘
                                 │
                                 ▼
                        ┌──────────────────┐
                        │     Twilio       │
                        │ - WhatsApp API   │
                        │ - SMS Fallback   │
                        └──────────────────┘
```

---

---

## Step 11: iOS App Store Deployment

### 11.1 Prerequisites
- **Xcode 16+** (required for Swift 6 / Firebase SDK 11.15+)
- Apple Developer Account ($99/year)
- macOS with Xcode installed

### 11.2 Firebase iOS Setup
1. Go to Firebase Console → Project Settings → Your apps
2. Add iOS app with bundle ID: `com.missedClassNotifier`
3. Download `GoogleService-Info.plist`
4. Place in `ios/Runner/GoogleService-Info.plist`

### 11.3 Configure Code Signing in Xcode
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target → Signing & Capabilities
3. Set Team to your Apple Developer account
4. Enable "Automatically manage signing"

### 11.4 Build and Archive
```bash
# Install pods
cd ios && pod install && cd ..

# Build release
flutter build ios --release

# Or archive via Xcode:
# Product → Archive → Distribute App → App Store Connect
```

### 11.5 App Store Connect
1. Go to https://appstoreconnect.apple.com
2. Create new app with bundle ID `com.missedClassNotifier`
3. Complete app information, screenshots, privacy policy
4. Upload via Xcode or Transporter

### 11.6 iOS-Specific Info.plist Permissions
Already configured:
- `NSPhotoLibraryUsageDescription` - Photo library access
- `NSCameraUsageDescription` - Camera access
- `ITSAppUsesNonExemptEncryption` - Set to NO (no custom encryption)

### 11.7 ExportOptions.plist
Located at `ios/ExportOptions.plist`. Update `teamID` with your Apple Team ID before archiving.

---

## Step 12: iOS Production Checklist

### Apple Developer Setup
- [ ] Apple Developer Program enrollment active
- [ ] App ID registered in Apple Developer Portal
- [ ] Distribution certificate created
- [ ] Provisioning profile created

### Firebase iOS
- [ ] iOS app added to Firebase project
- [ ] `GoogleService-Info.plist` added to `ios/Runner/`
- [ ] Push Notifications capability enabled (for Firebase Messaging)
- [ ] APNs key uploaded to Firebase Console

### Xcode Configuration
- [ ] Xcode 16+ installed (Swift 6 required)
- [ ] Signing team selected
- [ ] Bundle identifier matches App Store Connect
- [ ] Build number incremented for each upload

### App Store Connect
- [ ] App created with matching bundle ID
- [ ] App Information completed
- [ ] Privacy policy URL added
- [ ] Screenshots uploaded (6.5", 5.5", iPad if supporting)
- [ ] App Review Information filled
- [ ] Build uploaded and processed
- [ ] Submit for review

---

## Support

For issues, check:
1. Firebase Console → Functions → Logs
2. Browser developer console
3. Flutter logs: `flutter logs`
4. Xcode console for iOS-specific issues
