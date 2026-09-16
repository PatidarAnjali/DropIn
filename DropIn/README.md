# DropIn — Milestone 1 Starter

This is a working SwiftUI starter for the **Local Prototyping** milestone from your MVP doc:
static/mock data, no Firebase yet, but the real screens (Login, Live Feed, Broadcast sheet)
laid out and colored to match your mockup.

## What's inside
```
DropIn/
├── App/DropInApp.swift          # Entry point, switches Login <-> Home
├── Models/                      # Status, User, MockData
├── ViewModels/                  # AuthViewModel, HomeViewModel (local-only for now)
├── Views/Auth/LoginView.swift
├── Views/Home/HomeFeedView.swift + StatusRowView.swift
├── Views/Component/CreateStatusSheet.swift
├── Theme/Theme.swift            # Your exact palette + font hooks
└── Assets/                      # Your two logo PNGs
```

## 1. Add these files to Xcode
Once you've created your Xcode project (see the chat for the step-by-step),
drag the `App`, `Models`, `ViewModels`, `Views`, and `Theme` folders into the
Xcode project navigator. In the dialog that appears, make sure **"Copy items
if needed"** is checked and your app target is checked.

## 2. Add the logo to Assets.xcassets
1. In Xcode, open `Assets.xcassets`.
2. Right-click → **New Image Set**, name it exactly `Logo`.
3. Drag `Assets/Logo-Transparent.png` into the "1x" (or "Universal") slot.
   That's the version the code references — it's already wired up in
   `LoginView` and `HomeFeedView` via `Image("Logo")`.
4. Optionally add a second image set named `Logo-OnCream` using
   `Logo-OnBackground.png` if you want the solid-background version somewhere
   (e.g. an app icon draft).

## 3. Add your custom fonts (Cerebri + Raleway)
Custom fonts have to be physically embedded — Xcode can't "link" to a font
you have installed on your Mac.
1. Get the `.ttf`/`.otf` files (Raleway is free on Google Fonts; Cerebri Sans
   is a commercial font — make sure you have a license that allows app
   embedding).
2. Drag the font files into your Xcode project (Copy items if needed, target
   membership checked).
3. In your target's **Info** tab, add a key **"Fonts provided by
   application"** (`UIAppFonts`) as an array, and list each font filename,
   e.g. `Raleway-Regular.ttf`.
4. To find the exact PostScript name Swift needs (it's often not the
   filename), run this once in a SwiftUI `.onAppear`:
   ```swift
   for family in UIFont.familyNames {
       for name in UIFont.fontNames(forFamilyName: family) {
           print(name)
       }
   }
   ```
5. Update the font names in `Theme/Theme.swift` (`DropInFont.heading` /
   `.body`) to match exactly what printed.

Until you do this, the app runs fine — SwiftUI just quietly falls back to
the system font, so nothing breaks.

## 4. Run it
Select an iPhone simulator (top toolbar) and press **Cmd+R**. You should land
on the Login screen; typing anything in both fields and tapping "Get
Started" takes you to the Live Feed with the three mock statuses, and the
`+` button opens the Broadcast sheet.

## Next milestones (from your doc)
- **Milestone 2**: swap the `AuthViewModel` TODOs for real Firebase Auth calls.
- **Milestone 3**: replace `HomeViewModel.loadMockStatuses()` with a Firestore
  snapshot listener — the views don't need to change.
- **Milestone 4**: add the expiry query filter + haptics on "I'm Coming".

Come back to the chat any time you want help with the next milestone —
happy to build that out the same way.

 
