# Minimum Viable Product (MVP) Specification & Architecture
## Project Name: DropIn (Casual Micro-Plans for Friends)

---

## 1. Executive Summary
**DropIn** is a lightweight, iOS-exclusive mobile application designed to solve the problem of staying connected with busy friends. Instead of relying on formal, high-friction event planning, DropIn allows users to broadcast low-pressure, spontaneous micro-plans (e.g., "Grabbing coffee," "Studying at the library") that they are already doing. Friends can see these active broadcasts in real time and easily "drop in" if they are free, eliminating scheduling overhead and social rejection anxiety.

---

## 2. Scope of the MVP
The core philosophy of the MVP is **simplicity and low friction**. The initial release will focus entirely on a single, trusted friend circle rather than public discovery or complex algorithmic feeds.

### In-Scope Features
* **User Authentication:** Simple signup/login using Email/Password via Firebase.
* **The "Live Feed":** A single, real-time scrollable view showing active statuses posted by friends.
* **One-Tap Status Broadcast:** A creation screen allowing users to type a status, pick an icon/category, and set an expiration window (e.g., 1 hour, 3 hours).
* **"I'm Coming" (DropIn) Interaction:** A simple tap mechanism for friends to notify the host that they are on their way.
* **Automatic Expiration:** Statuses vanish automatically after their expiration time passes to keep the feed fresh and relevant.

### Out-of-Scope (Future Phases)
* Home screen interactive widgets (`WidgetKit`).
* Push notifications for new broadcasts.
* Complex map integrations and live location tracking (`CoreLocation`).
* Multiple distinct friend circles or group management.

---

## 3. Technology Stack
* **Language:** Swift 5.10+
* **UI Framework:** SwiftUI
* **Concurrency:** Swift Async/Await (`async/await`)
* **Local Data & State:** `@State`, `@StateObject`, `@Published`
* **Backend & Real-time Database:** Firebase Firestore (for live status synchronization) and Firebase Auth.
* **Minimum iOS Target:** iOS 17.0+ (to leverage modern SwiftUI APIs and SwiftData if needed later).

---

## 4. Architecture & Design Patterns
The application follows the **MVVM (Model-View-ViewModel)** structural pattern, which is standard and highly performant for SwiftUI applications.

```
┌─────────────────────────────────────────────────────────┐
│                          VIEW                           │
│  (SwiftUI: HomeFeedView, CreateStatusView, LoginView)   │
└────────────────────────────┬────────────────────────────┘
                             │ Observes & Triggers Actions
                             ▼
┌─────────────────────────────────────────────────────────┐
│                        VIEWMODEL                        │
│         (Swift/Combine: HomeViewModel, AuthViewModel)  │
└────────────────────────────┬────────────────────────────┘
                             │ Fetches & Mutates
                             ▼
┌─────────────────────────────────────────────────────────┐
│                          MODEL                          │
│               (Swift Structs: User, Status)             │
└─────────────────────────────────────────────────────────┘
```

### Directory Structure
```text
DropIn/
├── App/
│   └── DropInApp.swift              # App Entry Point & Firebase Setup
├── Models/
│   ├── User.swift                    # User Profile Data Structure
│   └── Status.swift                  # Micro-Plan Status Structure
├── ViewModels/
│   ├── AuthViewModel.swift           # Handles Login, Registration, Session State
│   └── HomeViewModel.swift           # Handles Fetching, Posting, and Expiring Statuses
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift           # Login UI
│   │   └── RegisterView.swift        # Registration UI
│   ├── Home/
│   │   ├── HomeFeedView.swift        # Main Dashboard / Live Feed
│   │   └── StatusRowView.swift       # Reusable Individual Status Card Component
│   └── Component/
│       └── CreateStatusSheet.swift   # Sheet to Broadcast a New Plan
└── Services/
    └── FirebaseManager.swift         # Firestore Data Pipeline & Auth Wrappers
```

---

## 5. Data Models (Swift Representation)

```swift
import Foundation
import FirebaseFirestore

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    let name: String
    let email: String
    let avatarUrl: String?
}

struct Status: Codable, Identifiable {
    @DocumentID var id: String?
    let userId: String
    let username: String
    let activityText: String
    let categoryIcon: String // E.g., "coffee", "book", "figure.walk"
    let createdAt: Date
    let expiresAt: Date
    var attendees: [String] // Array of userIds who tapped "I'm Coming"
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
}
```

---

## 6. Implementation & Learning Plan (Milestones)

### Milestone 1: Local Prototyping (No Backend)
* **Goal:** Understand SwiftUI Layouts and Local State.
* **Tasks:**
  * Build `HomeFeedView` using static mock data arrays.
  * Implement the `CreateStatusSheet` modal overlay using `.sheet()`.
  * Use `@State` and `@Binding` to pass information from the sheet back to the list layout locally.

### Milestone 2: Cloud Infrastructure & Authentication
* **Goal:** Connect your app to the outside world.
* **Tasks:**
  * Create a free-tier Firebase project.
  * Integrate the Firebase iOS SDK using Swift Package Manager (SPM).
  * Build simple login and signup screens that switch views conditionally based on the active user session.

### Milestone 3: Real-Time Syncing (The "Magic" Phase)
* **Goal:** Master asynchronous data flows and reactive pipelines.
* **Tasks:**
  * Implement a Firestore snapshot listener in `HomeViewModel` to fetch live data streams.
  * Wire up the "Create" button to push real-time document models into Firestore.
  * Test updating a status on an iOS simulator and watching it instantly update on a physical iPhone screen.

### Milestone 4: Polishing & Edge Cases
* **Goal:** Deliver a smooth UX.
* **Tasks:**
  * Add automatic query filters to Firestore so statuses where `expiresAt < CurrentTime` are excluded.
  * Implement haptic feedback (`UIImpactFeedbackGenerator`) when tapping the "I'm Coming" button to make the action feel tactile and satisfying.
