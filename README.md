# Virtual Queue App

A modern, real-time virtual waiting room app built with **Flutter** and **Firebase**.

## Features

- **Google Sign-In** authentication
- **Create and join rooms** with a 6-digit code
- **Customizable queue forms** (name, contact, address)
- **Real-time updates** for queue position and notices
- **Room creator dashboard**: manage join requests, progress queue, update notices, end/reset room
- **Member details page**: see your position, current position, and leave room
- **Profile page**: view user info and sign out
- **Elegant, responsive UI** with Material Design
- **Firestore security rules** for safe data access

## Screenshots

> Add screenshots here for Home, Creator Dashboard, Member Details, Profile, etc.

## Getting Started

### 1. Clone the repository
```sh
git clone <your-repo-url>
cd virtual_queue
```

### 2. Install dependencies
```sh
flutter pub get
```

### 3. Firebase Setup
- Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
- Add Android/iOS app and download `google-services.json`/`GoogleService-Info.plist`
- Place them in the appropriate directories
- Enable **Google Authentication** and **Firestore Database**

### 4. Run the app
```sh
flutter run
```

## Project Structure
```
lib/
  main.dart
  providers/
    auth_provider.dart
    room_provider.dart
  models/
    room.dart
  pages/
    home_page.dart
    join_room_dialog.dart
    create_room_dialog.dart
    creator_dashboard_page.dart
    member_details_page.dart
    profile_page.dart
```

## Firestore Security Rules (example)
```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /rooms/{roomId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.resource.data.creatorId == request.auth.uid;
      match /joinRequests/{requestId} {
        allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
        allow read: if request.auth != null && (
          resource.data.userId == request.auth.uid ||
          get(/databases/$(database)/documents/rooms/$(roomId)).data.creatorId == request.auth.uid
        );
        allow update, delete: if request.auth != null &&
          get(/databases/$(database)/documents/rooms/$(roomId)).data.creatorId == request.auth.uid;
      }
      match /members/{memberId} {
        allow read: if request.auth != null;
        allow create: if request.auth != null &&
          get(/databases/$(database)/documents/rooms/$(roomId)).data.creatorId == request.auth.uid;
        allow delete: if request.auth != null && (
          resource.data.userId == request.auth.uid ||
          get(/databases/$(database)/documents/rooms/$(roomId)).data.creatorId == request.auth.uid
        );
      }
    }
  }
}
```

## License

MIT
