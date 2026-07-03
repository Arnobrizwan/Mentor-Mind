# MentorMinds

AI-powered tutoring app for **O/A Level students in Bangladesh** (Cambridge / CAIE & Edexcel). Built with **Flutter + Firebase**, featuring **MentorBot** — a curriculum-aligned AI tutor — plus streaks, points, badges, a leaderboard, and a materials library.

## 🎬 Showcase Video

Walkthroughs recorded live on an Android emulator (running against the Firebase Local Emulator Suite):

- ▶️ **Roles video (~3 min):** [`docs/showcase/MentorMinds_Roles.mp4`](docs/showcase/MentorMinds_Roles.mp4) — **Student**, **Premium Student**, and **Teacher** roles, each with a title card.
- ▶️ **Student deep-dive (~2.5 min):** [`docs/showcase/MentorMinds_Showcase.mp4`](docs/showcase/MentorMinds_Showcase.mp4)
- 📊 **Slide deck (video embedded + link):** [`docs/showcase/MentorMinds_Showcase.pptx`](docs/showcase/MentorMinds_Showcase.pptx)

**Student tour:** sign-in → dashboard (streak, points, subject progress, daily challenge) → **MentorBot** answering an exam question with a fully worked, syllabus-cited solution → materials library → rewards (badges + leaderboard) → profile.

**Teacher tour:** teacher dashboard (approval status, subject materials, uploads) → library → inbox → profile.

**Premium tour:** the premium account (A-Level, "Premium Member — all features unlocked") dashboard → AI tutor → rewards → profile.

> Each role runs via `--dart-define=ROLE=<student|premium|teacher|admin>` against the seeded accounts. The **admin** console is load-heavy on a small emulator — `admin_viewmodel` now loads its tabs lazily (it used to eagerly fetch the users list + 14-day analytics on mount, which ANR'd/crashed the app); it still needs a real device or a 4 GB+ emulator with error dialogs suppressed (`adb shell settings put global hide_error_dialogs 1`) for the tab data to populate reliably.

> The video is committed to the repo, so the links above resolve directly on GitHub and in local clones.

## Stack

- **Frontend:** Flutter 3.41 / Dart, Riverpod (`hooks_riverpod`), Material 3, `go_router`
- **Backend:** Firebase — Auth, Firestore, Storage, Cloud Functions (TypeScript)
- **AI Tutor:** `mentorBotChat` Cloud Function (region `asia-south1`); Gemini in production, an env-selectable canned/fake client for offline demos
- **Platforms:** iOS (v1.0) + Android

## Run locally (against the Firebase Emulator Suite)

```bash
# 1. Start the emulators (Auth 9099, Firestore 8080, Storage 9199, Functions 5001)
firebase emulators:start --only auth,firestore,functions,storage --project mentor-mind-aa765

# 2. Seed test data (test accounts, materials, rewards, notifications)
cd tool/seed && npm run seed:emulator && cd ../..

# 3. Run the app pointed at the emulators
#    Android emulator reaches the host via 10.0.2.2 automatically (handled in main.dart).
flutter run --dart-define=USE_EMULATOR=true --dart-define=GEMINI_API_KEY=<your-key> -d <device>
```

Seeded student login: `student@mentorminds.test` / `Student1!`

### Offline AI demo (no API key)

Set `TUTOR_AI_CLIENT_MODE=fake` in `functions/.env` and MentorBot returns polished, exam-style canned answers through the real callable — used to record the showcase above.

### Re-record the showcase tour

```bash
adb shell screenrecord --time-limit 179 /sdcard/demo.mp4 &   # start recording
flutter test integration_test/showcase_test.dart \
  --dart-define=USE_EMULATOR=true --dart-define=GEMINI_API_KEY=demo -d <device>
```

See [`DEMO_GUIDE.md`](DEMO_GUIDE.md) for a full walkthrough and [`BACKEND_SETUP.md`](BACKEND_SETUP.md) for backend configuration.
