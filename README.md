<p align="center">
  <img src="DropIn/Assets/Logo-Transparent.png" alt="DropIn logo" width="120">
</p>

<h1 align="center">DropIn</h1>

<p align="center">
  <strong>Casual micro-plans for friends.</strong><br>
  Share what you're already up to, and let friends drop in if they're free.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-iOS-23345C" alt="Platform: iOS">
  <img src="https://img.shields.io/badge/SwiftUI-E2735A" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Firebase-Auth%20%2B%20Firestore-AFC2A5" alt="Firebase">
</p>

---

> **Note:** This is just a fun personal project; it's not actually a real/published app.

---

## About

Making plans with busy friends usually means group chats, calendars, and a lot of "maybe next week." DropIn skips all that. Instead of planning an event, you post what you're **already doing**, like *"Grabbing coffee at Starbucks"* or *"Studying at the library"*. Friends see it in a live feed and can tap **I'm Coming!** if they're free.

No pressure to reply and no awkward "no." Plans disappear on their own once they expire.

## Screenshots

<p align="center">
  <img width="1920" height="1080" alt="Live Feed" src="https://github.com/user-attachments/assets/a6619fd0-97a1-4f5c-9040-203744896b01" />
  <img width="1920" height="1080" alt="5" src="https://github.com/user-attachments/assets/79bd7424-5b59-4ac2-9be5-ebee8f9da1fd" />
</p>

## Features

### Plans
- **Live feed** of friends' plans, updated in real time with Firestore
- **Right now or plan ahead.** Post something that's happening now, or schedule it to start later. Upcoming plans show in a separate "Starting Soon" section
- **Auto-expiring.** Each plan has a timer and disappears when it ends
- **Categories** (coffee, study, walk, food), each with its own icon and card color
- **Search** through what friends are up to

### Dropping in
- Friends tap **I'm Coming!** (or **I'm In** for upcoming plans) and can undo with **Can't Make It**
- The person who made the plan **can't drop in on their own plan**. They get a **"who's dropping in"** list instead

### Privacy
- **Choose friends.** Share a plan with everyone, or only with selected friends
- **Pause.** Hide your plan from everyone without deleting it and without notifying anyone

### Avatars
- **Build-your-own avatar** with skin tone, face shape, build, hair, facial hair, eyes, brows, mouth, outfit, hats, glasses, earrings, and background
- Every option is open to everyone, with no gender step
- Avatars are drawn in code with SwiftUI `Canvas`, so there are no image assets and they stay sharp at any size
- Includes shuffle, reset, and quick-start looks

## Tech Stack

| | |
|---|---|
| **Language** | Swift |
| **UI** | SwiftUI (`@Observable`, `Canvas`) |
| **Architecture** | MVVM |
| **Backend** | Firebase Authentication (email/password) and Cloud Firestore |
| **Dependencies** | [Firebase iOS SDK](https://github.com/firebase/firebase-ios-sdk) via Swift Package Manager |
| **Notifications** | `UserNotifications` (local notifications for now) |
| **Fonts** | [Raleway](https://fonts.google.com/specimen/Raleway) (logo) and [Open Sans](https://fonts.google.com/specimen/Open+Sans) (everything else) |

## Project Structure

```text
DropIn/
├── App/
│   └── DropInApp.swift # entry point, switches between Login and Home
├── Models/
│   ├── User.swift # user profile (Firestore "users")
│   ├── Status.swift # A plan (Firestore "statuses")
│   ├── AvatarConfig.swift # rvery avatar choice + save format
│   └── MockData.swift # sample data for Xcode Previews
├── ViewModels/
│   ├── AuthViewModel.swift # sign in / sign up / session
│   └── HomeViewModel.swift # ;ive feed, posting, RSVPs, pausing
├── Views/
│   ├── Auth/LoginView.swift
│   ├── Home/
│   │   ├── HomeFeedView.swift # live feed + search
│   │   └── StatusRowView.swift # plan card + "who's dropping in" sheet
│   ├── Component/
│   │   ├── CreateStatusSheet.swift # "What are you up to?"
│   │   └── AvatarView.swift
│   ├── Avatar/
│   │   ├── AvatarBuilderView.swift # avatar customization screen
│   │   └── AvatarRenderer.swift # draws avatars w/ Canvas
│   └── Profile/ProfileView.swift
├── Services/
│   ├── FirebaseBootstrap.swift
│   ├── FirestoreService.swift
│   └── NotificationService.swift
├── Theme/
│   ├── Theme.swift # Colors, fonts, spacing, shared styles
│   └── AppBackground.swift
└── Resources/Fonts/
```

## Getting Started

### Requirements
- A Mac with a recent version of **Xcode**
- A free **[Firebase](https://console.firebase.google.com/)** account

### 1. Clone the repo
```bash
git clone https://github.com/<your-username>/DropIn.git
cd DropIn
open DropIn.xcodeproj
```
Xcode downloads the Firebase packages automatically the first time you open the project.

### 2. Set up Firebase
1. Create a new project in the [Firebase console](https://console.firebase.google.com/).
2. Add an **iOS app** using the same bundle identifier as the Xcode project.
3. Download **`GoogleService-Info.plist`** and put it in the `DropIn/` folder (next to `README.md` inside the app folder).
4. Under **Authentication → Sign-in method**, turn on **Email/Password**.
5. Under **Firestore Database**, create a database.

### 3. Run
Choose an iPhone simulator and press **⌘R**.

On the login screen, enter a username, email, and password, then tap **Get Started**. If there's no account for that email yet, one is created for you.

## Design

| Color | Hex | Used for |
|---|---|---|
| Warm Coral | `#E2735A` | Main buttons and highlights |
| Indigo Blue | `#23345C` | Headings and text |
| Cream | `#FFFCFA` | Backgrounds |
| Soft Sage Green | `#AFC2A5` | Cards and accents |
| Pale Pink | `#F2C9CE` | Cards and accents |

Colors, fonts, and spacing all live in [`Theme/Theme.swift`](DropIn/Theme/Theme.swift), so every screen uses the same values.

## Roadmap

- [ ] Real friend list and friend requests (friend names and avatars in the attendee list currently come from sample data)
- [ ] Push notifications to friends' devices when a plan goes live (currently local notifications only)
- [ ] Firestore security rules
- [ ] Home screen widgets
- [ ] Haptic feedback on "I'm Coming!"

## Credits

- Fonts: [Raleway](https://fonts.google.com/specimen/Raleway) and [Open Sans](https://fonts.google.com/specimen/Open+Sans), both under the [SIL Open Font License](https://openfontlicense.org/). License files are in `Resources/Fonts`.
- Built with [Firebase](https://firebase.google.com/).
