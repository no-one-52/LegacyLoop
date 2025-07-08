Legacy Social App
A cross-platform social networking app built with Flutter and Firebase, supporting group creation, posts, comments, likes, and user profiles.
Features
•	- User authentication (Firebase Auth)
•	- Group creation and management (public/private)
•	- Group posts with images, likes, and comments
•	- Admin approval for group posts and members
•	- User profiles with avatars and nicknames
•	- Real-time updates using Firestore
•	- Notifications for likes and group activities
•	- Responsive UI for Android, iOS, Web, Windows, Linux, and macOS

Getting Started
Prerequisites
•	- Flutter: https://flutter.dev/docs/get-started/install
•	- Firebase CLI: https://firebase.google.com/docs/cli
•	- A Firebase project with Firestore, Auth, and Storage enabled
Installation
1.	Clone the repository:

   git clone https://github.com/yourusername/legacy.git
   cd legacy
2.	Install dependencies:

   flutter pub get
3.	Set up Firebase:
   - Add google-services.json (Android) and GoogleService-Info.plist (iOS) to respective directories.
   - Update lib/firebase_options.dart if using FlutterFire CLI.
4.	Run the app:

   flutter run
5.	Optional - Set up Firebase Cloud Functions:

   cd functions
   npm install
   firebase deploy --only functions
Project Structure

lib/
  screens/        UI screens (groups, posts, profile, etc.)
  services/       Business logic and Firebase interaction
  widgets/        Reusable UI components
  main.dart       App entry point

functions/        Firebase Cloud Functions (Node.js)
assets/           Images and static assets

Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss your ideas.
License
This project is licensed under the MIT License.
