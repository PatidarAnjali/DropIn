<p align="center">
  <img width="120" alt="DropIn logo" src="https://github.com/user-attachments/assets/81862ff6-1074-437d-b0b4-f0494c975e73" />
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
  <img src="https://img.shields.io/badge/Apple%20Intelligence-on--device-B79CE0" alt="Apple Intelligence">
  <br>
  <a href="https://github.com/PatidarAnjali/DropIn/actions/workflows/tests.yml"><img src="https://github.com/PatidarAnjali/DropIn/actions/workflows/tests.yml/badge.svg" alt="Tests"></a>
</p>

---

> **Note:** This is just a fun personal project; it's not actually a real/published app :)

---

## About

Making plans with busy friends usually means group chats, calendars, and a lot of "maybe next week." DropIn skips all that. Instead of planning an event, you post what you're **already doing**, like *"Grabbing coffee at Starbucks"* or *"Studying at the library"*. Friends see it in a live feed and can tap **I'm Coming!** if they're free.

No pressure to reply and no awkward "no." Plans disappear on their own once they expire.

## Screenshots

<p align="center">
<img width="1920" height="1080" alt="Live Feed 1" src="https://github.com/user-attachments/assets/2ad34a49-2dc5-4592-ab00-f60b1f4b164a" />
<img width="1920" height="1080" alt="Live Feed 2" src="https://github.com/user-attachments/assets/c04583ab-3196-44c4-9e89-4289eb5651a2" />
<img width="1920" height="1080" alt="Live Feed 3" src="https://github.com/user-attachments/assets/65a6f80d-43a3-4d72-907d-26e75775d5ae" />
<img width="1920" height="1080" alt="Live Feed 4" src="https://github.com/user-attachments/assets/16c63c45-8e7e-4c0a-a3b7-4a726d068c83" />
</p>

## Features

### Plans
- **Live feed** of friends' plans, updated in real time with Firestore
- **Right now or plan ahead.** Post something that's happening now, or schedule it to start later. Upcoming plans show in a separate "Starting Soon" section
- **Auto-expiring.** Each plan has a timer and disappears when it ends
- **Categories** (coffee, study, walk, food), each with its own icon and card color
- **Search** through what friends are up to

### Friends
- Every account gets a short **friend code** (like `K7Q-2MX`) with a **QR code** to scan in person
- Add friends by typing a code, **scanning their QR** (VisionKit), or sharing your code by text
- Friend requests with accept, decline, cancel, and remove
- The feed and the "Choose friends" picker only include **your friends**

### Safety & account control
- **Block** anyone from their plan, nudge, friend request, or your friends list. Blocking unfriends you, hides you from each other both ways, and stops new requests. Unblock anytime.
- **Report** a person, plan, or nudge with a reason. Reports go to a private, write-only collection for review.
- **Delete account** (required by the App Store): confirms your password, then removes your profile, plans, friendships, nudges, and blocks before deleting the login.
- All of this is also enforced by **Firestore security rules**, not just the app.

### Who's Down? nudges
Not ready to post to everyone? Privately ping **up to 4 friends** to see if anyone's nearby. They tap **I'm down** or **Not nearby**, you see who's in, and the nudge disappears after **30 minutes**.

### Vibes
Every plan says *how* you want company, not just where you are:
- **Open Door:** drop in anytime
- **Quiet:** sit nearby and bring a laptop, but mostly silent
- **Limited Seats:** "only 2 open seats at my table!" The plan **locks automatically** once it's full, and reopens if someone gives up their seat

Seats are claimed with a **Firestore transaction**, so if two friends tap the last seat at the same moment, only one gets it.

### ✨ AI autofill (on-device)
Type one casual sentence and DropIn fills in the whole plan:

| You type | DropIn fills in |
|---|---|
| *dinner at chipotle, only have room for 2* | Food · Limited Seats (2) · starts now |
| *library grind till 6, quiet pls* | Study · Quiet · lasts until 6:00 |
| *walk in 30 min for an hour* | Walk · starts in 30 min · lasts 1 hour |

- Runs on **Apple Intelligence** with Apple's **Foundation Models** framework: free, works offline, and nothing you type leaves your phone
- Uses **guided generation** (`@Generable`), so the model returns a typed Swift struct with limited choices instead of free text
- A **rule-based parser** double-checks exact times ("till 6") and seat counts ("room for 2"), since small models can be off with clock math
- On iPhones without Apple Intelligence, the same parser fills in the plan on its own, so autofill works everywhere

### Dropping in
- The button matches the vibe: **I'm Coming!**, **I'll Sit Nearby**, or **Grab a Seat** (and **Plan's Full** once it locks). Friends can undo with **Can't Make It** or **Give Up Seat**
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
| **On-device AI** | Foundation Models framework (Apple Intelligence), guided generation with `@Generable` |
| **Security** | Firestore security rules (`firestore.rules`) |
| **Camera** | VisionKit `DataScannerViewController` for QR scanning, Core Image for QR generation |
| **Testing** | Swift Testing (unit tests), GitHub Actions (runs on every push) |
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
│   ├── PlanRules.swift # vibes + who can join (tested)
│   ├── PlanTextParser.swift # rule-based autofill (tested)
│   ├── Friendship.swift # friend requests + friend codes (tested)
│   ├── Nudge.swift # Who's Down? nudges (tested)
│   ├── Safety.swift # blocks + reports (tested)
│   ├── AvatarConfig.swift # every avatar choice + save format
│   └── MockData.swift # sample data for Xcode Previews
├── ViewModels/
│   ├── AuthViewModel.swift # log in, sign up, password reset, session
│   └── HomeViewModel.swift # feed, RSVP transactions, friends, nudges
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
│   ├── Friends/
│   │   ├── FriendsView.swift # your code + QR, requests, friends list
│   │   └── QRScannerView.swift # camera QR scanner
│   ├── Nudges/
│   │   ├── NudgeSheet.swift # send a Who's Down? nudge
│   │   └── NudgeCardView.swift # nudge card in the feed
│   ├── Safety/ReportSheet.swift # report a person, plan, or nudge
│   └── Profile/
│       ├── ProfileView.swift
│       └── DeleteAccountView.swift
├── Services/
│   ├── PlanAssistant.swift # on-device AI autofill
│   ├── FirebaseBootstrap.swift
│   ├── FirestoreService.swift
│   └── NotificationService.swift
├── Theme/
│   ├── Theme.swift # Colors, fonts, spacing, shared styles
│   └── AppBackground.swift
└── Resources/Fonts/
DropInTests/ # Swift Testing unit tests
.github/workflows/tests.yml # runs the tests on every push
firestore.rules # server-side security rules
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
3. Download **`GoogleService-Info.plist`** and put it in the `DropIn/` app folder (next to `Assets.xcassets`). It's in `.gitignore`, so it won't be committed.
4. Under **Authentication → Sign-in method**, turn on **Email/Password**.
5. Under **Firestore Database**, create a database.

### 3. Add the security rules
In the Firebase console, open **Firestore Database → Rules**, paste the contents of [`firestore.rules`](firestore.rules), and tap **Publish**.

### 4. Run
Choose an iPhone simulator and press **⌘R**.

On the login screen, enter a username, email, and password, then tap **Get Started**. If there's no account for that email yet, one is created for you.

**AI autofill** needs a device or simulator with Apple Intelligence turned on (iPhone 15 Pro or newer, or a Mac with Apple silicon running the simulator). Everywhere else, autofill uses the rule-based parser.

## Running Tests

The unit tests cover RSVP rules (seat limits, expired plans, hosts can't join), plan visibility, the autofill parser, avatar saving, friend codes and requests, nudge limits, and blocking. They don't need Firebase.

- **In Xcode:** press **⌘U**
- **From Terminal:**
  ```bash
  xcodebuild test -project DropIn.xcodeproj -scheme DropIn \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:DropInTests CODE_SIGNING_ALLOWED=NO
  ```

GitHub Actions runs the same tests on every push and pull request. See the **Actions** tab.

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

- [ ] Push notifications for new plans, friend requests, and nudges (needs Firebase Cloud Functions + Apple Push Notification service)
- [ ] Server-side plan privacy: query only friends' plans so private plans are never downloaded by others
- [ ] Home screen widgets
- [ ] Haptic feedback on "I'm Coming!"

## Credits

- Fonts: [Raleway](https://fonts.google.com/specimen/Raleway) and [Open Sans](https://fonts.google.com/specimen/Open+Sans), both under the [SIL Open Font License](https://openfontlicense.org/). License files are in `Resources/Fonts`.
- Built with [Firebase](https://firebase.google.com/).
