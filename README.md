# LegacyLoop

A social media app built with Flutter and Firebase.

## Features

### Authentication
- **Persistent Login**: Users stay logged in until they explicitly log out, just like Instagram and Facebook
- Email/password authentication
- User profile management
- Admin panel for user management

### Social Features
- Create and share posts with text, images, and videos
- Like and comment on posts
- Friend requests and connections
- Real-time messaging
- Group creation and management
- User status (online/offline)
- Notifications

### Admin Features
- User management (view, delete users)
- Content moderation
- Group management
- Admin actions logging

## Persistent Authentication

The app implements persistent authentication using Firebase Auth's `authStateChanges()` stream. This means:

- Users remain logged in when they close and reopen the app
- Users stay logged in when the app is backgrounded and foregrounded
- Users only need to log in once per device
- Users must explicitly log out to end their session

### How it works:

1. **AuthWrapper**: The main app uses an `AuthWrapper` that listens to Firebase Auth state changes
2. **Automatic Routing**: When the app starts, it automatically checks if a user is already authenticated
3. **Seamless Experience**: If authenticated, users go directly to the home screen; if not, they see the login screen
4. **Session Persistence**: Firebase Auth handles token storage and refresh automatically

This provides a smooth user experience similar to popular social media apps like Instagram and Facebook.

## Getting Started

1. Clone the repository
2. Install dependencies: `flutter pub get`
3. Configure Firebase (add your `google-services.json` and `GoogleService-Info.plist`)
4. Run the app: `flutter run`

## Dependencies

- Flutter
- Firebase (Auth, Firestore, Storage)
- Image picker
- File picker
- Badges

## License

This project is licensed under the MIT License.
