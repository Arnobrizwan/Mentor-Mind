# MentorMinds: Step-by-Step Product Demo Guide

Welcome to the MentorMinds Product Demo Guide. This document provides a complete, step-by-step walkthrough to demonstrate the core value, user experience, and architecture of the MentorMinds mobile application and its serverless backend.

MentorMinds is a feature-hardened study platform tailored specifically for O-Level and A-Level students in Bangladesh preparing for Cambridge (CAIE) and Edexcel exams.

---

## 🎬 Recorded Showcase Video

A ~2.5-minute end-to-end walkthrough recorded on an Android emulator against the Firebase Local Emulator Suite (sign-in → dashboard → live MentorBot answer → materials → rewards → profile):

- ▶️ **Video:** [`docs/showcase/MentorMinds_Showcase.mp4`](docs/showcase/MentorMinds_Showcase.mp4)
- 📊 **Slide deck (video embedded + link):** [`docs/showcase/MentorMinds_Showcase.pptx`](docs/showcase/MentorMinds_Showcase.pptx)

Regenerate it any time with the `integration_test/showcase_test.dart` tour (see the README).

---

## Demo Prerequisites & Setup

Before starting the demo, ensure the local development environment is configured:

1. **Start the Firebase Emulators:**
   Ensure you are running the Firestore, Auth, Functions, and Storage emulators:
   ```bash
   firebase emulators:start
   ```
2. **Launch the Flutter Client:**
   Launch the app on an iOS Simulator targeting the local emulator:
   ```bash
   flutter run --dart-define=USE_EMULATOR=true
   ```
3. **Database Seeding (Optional):**
   Seed study materials, notifications, and mock users to showcase a populated environment:
   ```bash
   npm run seed --prefix tool/seed
   ```

---

## Test Accounts (4 Roles)

All four are seeded by `tool/seed/seed.js` with `emailVerified: true` and `isApproved: true`, so login is instant — no email confirmation flow blocks them.

| Role | Email | Password | Profile | Demo it to show… |
|---|---|---|---|---|
| **Student (Free)** | `student@mentorminds.test` | `Student1!` | Sana Student · O-Level · Math/Physics/Chem · 12 pts · `first_login` badge · Q-counts: **Math 38**, **Physics 22**, **Chemistry 14** · 6 recent sessions | Daily-quota gating · upgrade card · free-tier tutor flow · subject rings (38% / 22% / 14%) |
| **Student (Premium)** | `premium@mentorminds.test` | `Premium1!` | Parvez Premium · A-Level · Math/Physics/Bio/English · 140 pts · `first_login` + `streak_3` badges · Q-counts: **Math 72**, **Physics 55**, **Biology 40**, **English 28** · 4 recent sessions | No-quota tutor · image upload (vision) · upgrade card replaced by "premium active" |
| **Teacher** | `teacher@mentorminds.test` | `Teacher1!` | Tania Teacher · A-Level · Chem/Bio | Teacher-dashboard routing post-login (admin-redirect logic) |
| **Admin** | `admin@mentorminds.test` | `Admin1!` | Arif Admin · `subscriptionType: premium` · `first_login` badge | Admin panel · broadcast notifications · Toggle Premium · content upload |

> ⚠️ Passwords are committed in `tool/seed/seed.js` — **dev only**. Re-running the seed script idempotently resets these back to the defaults above.

---

## Seed Data Inventory

After running `npm run seed --prefix tool/seed`, the following ships into Firestore:

### 1. `/config/*` — Admin-Editable Runtime Config (5 docs)

| Doc | Drives |
|---|---|
| `gamification` | Badges (7 total), points-to-badge milestones (7 tiers), streak grace days |
| `curriculum` | 10 subjects (Math, Physics, Chem, Bio, English, ICT, Accounting, Economics, History, Geography), 2 levels (O / A Level) |
| `quotas` | Daily message limits per tier (Free 30, Premium unlimited) |
| `subscription` | Monthly price (৳299), feature list, CTA copy — drives the Profile upgrade card |
| `support` | Help-email target, Privacy/Terms URLs, App Store / Play Store IDs |

**Demo move:** edit any of these in the Firebase Console mid-demo; the running client picks up the change in <1 s (Firestore stream). No release required.

### 2. `/users` and `/rewards` — 4 Seeded Accounts

See the **Test Accounts** table above. Each user also gets a `/rewards/{uid}` doc with their starting points + badge ledger.

### 3. `/materials` — 28 Study Materials Across All 10 Subjects

| Subject | Count | Sample titles |
|---|---|---|
| Mathematics | 3 | *Quadratic Equations Masterclass*, *Trigonometry Essentials*, *Calculus for Beginners* |
| Physics | 3 | *Newton's Laws — Chapter 3*, *Electromagnetism Explained*, *Kinematics Practice Worksheet* |
| Chemistry | 3 | *Organic Chemistry Reactions*, *The Periodic Table Deep Dive*, *Stoichiometry Practice Problems* |
| Biology | 3 | *Cell Division Explained*, *Human Physiology Overview*, *Photosynthesis Step-by-Step* |
| English | 3 | *Essay Writing Structure*, *Literary Devices Guide*, *Unseen Passage Strategy (PEEL)* |
| ICT | 2 | *Introduction to Python*, *Databases & SQL Crash Course* |
| Accounting | 2 | *Double-Entry Bookkeeping Basics*, *Trial Balance Worked Examples* |
| Economics | 3 | *Supply and Demand Diagrams*, *Price Elasticity Explained*, *Market Failure Case Studies* |
| History | 3 | *Partition of 1947 — Key Causes*, *Bangladesh Liberation War 1971*, *The Cold War: A-Level Overview* |
| Geography | 3 | *Plate Tectonics and Earthquakes*, *Population Geography — Bangladesh*, *Climate Change Case Study* |

Each material has: `title`, `subject`, `level` (O / A / Both), `type` (PDF / video / worksheet / notes), `gradient` (decorative pair of brand colors), `views: 0` counter, `createdAt`/`uploadedAt` timestamps.

### 4. `/notifications` — 9 In-App Notifications

| Title | Targets | Demo angle |
|---|---|---|
| *Welcome to MentorMinds! 🎉* | all roles | Onboarding handoff |
| *New Physics materials added 📚* | role_student | Topic-targeted FCM |
| *Keep your streak alive 🔥* | role_student | Habit nudge |
| *Premium launching soon ⭐* | free tier | Upsell |
| *Teacher approvals pending* | role_admin | Admin-only routing |
| *Today's challenge is live ⚡* | role_student | Daily challenge tie-in |
| *New badge: First Step 🌱* | role_student | Gamification celebration |
| *Geography drops just landed 🌍* | role_student | Curriculum coverage |
| *Weekly recap: +145 points* | role_student | Engagement pulse |

### 5. `/sessions` — 10 Pre-Seeded Tutor Sessions

For demo realism — the dashboard's "Recent Sessions" and Search's "Sessions" tab aren't empty on first login.

**Student (6 sessions, spanning the last 3 days):**
- Math: "Walk me through solving x² − 5x + 6 = 0" (2h ago)
- Math: "How do I differentiate sin(x²)?" (6h ago)
- Physics: "Explain Newton's second law with an example" (22h ago)
- Chemistry: "Balance H₂ + O₂ → H₂O and explain why" (30h ago)
- Physics: "Speed vs velocity — what's the difference?" (50h ago)
- Math: "Practice problem on the quadratic formula" (3d ago)

**Premium (4 sessions):**
- Biology: "Explain photosynthesis step by step" (1h ago)
- Math: "Integration by parts — when do I use it?" (8h ago)
- Physics: "Derive the kinematic equations" (26h ago)
- English: "How do I structure a persuasive essay?" (48h ago)

### 6. `/config/gamification` Badge Catalog — 7 Badges

| ID | Emoji | Name | Unlock |
|---|---|---|---|
| `first_step` | 🌱 | First Step | Complete 1 session |
| `curious_learner` | 💬 | Curious Learner | Ask 50 questions across any subject |
| `dedicated_learner` | 📚 | Dedicated Learner | Complete 5 sessions |
| `week_warrior` | 🏆 | Week Warrior | 7-day study streak |
| `month_master` | 🗓️ | Month Master | 30-day study streak |
| `diagram_detective` | 🔍 | Diagram Detective | Upload 10 diagrams (Premium) |
| `subject_expert` | 🎯 | Subject Expert | Ask 100 questions in one subject |

---

## Demo Flow by Role (Suggested Order)

For a 10-minute live demo, run accounts in this sequence:

1. **`student@`** (3 min) — onboarding → dashboard hero → AI Tutor sends "Walk me through solving x² − 5x + 6 = 0" → response in <5 s with Cambridge syllabus citation → rate-limit warning appears at message ~25/30.
2. **`premium@`** (3 min) — dashboard shows higher progress + 4 sessions → AI Tutor with image attach (Biology diagram) → no quota warning → premium-active card on Profile.
3. **`teacher@`** (1 min) — login routes to teacher dashboard (placeholder) → demonstrate role-based redirect.
4. **`admin@`** (3 min) — admin panel → live DAU/revenue charts → Toggle Premium on a student → send a broadcast notification → confirm push delivered to a student session.

---

## Step 1: The First Launch (Onboarding & Authentication)
**Objective:** Show the sleek, brand-aligned onboarding flow that caches user preferences and secures access.

1. **Splash Screen:**
   - Launch the app. Point out the brand-accurate gradient (Primary Indigo `#1A3C8F` to Teal Mint `#00C9A7`) and the lettermark entrance animation.
2. **3-Page Onboarding (Screen 02):**
   - **Page 1 (Welcome):** Show the custom robot mascot (onboarding hero) and note the `Semantics` label for screen readers.
   - **Page 2 (Level Selection):** Select either **O-Level** or **A-Level**.
   - **Page 3 (Subject Selection):** Pick subjects (e.g., Mathematics, Physics, Chemistry). Highlight how these selections are cached locally in `SharedPreferences`.
3. **Registration (Screen 04):**
   - Tap **Get Started** to open the Sign-up screen.
   - Enter mock details. Notice the dynamic password strength indicators and the **Terms of Service** gate.
   - Select a role: **Student** (default).
4. **Email Verification:**
   - Register the account. Point out the informational banner on the Dashboard.
   - Note that trying to open the Tutor Chat or submit a question blocks the user with a verification overlay—ensuring clean database writes.

---

## Step 2: The Student Hub (Dashboard Overview)
**Objective:** Show the high-level home base that coordinates daily tasks, streaks, and navigation.

1. **SliverAppBar Greeting:**
   - Observe the personalized header showing the student's name, current streak count, and points.
2. **Daily Challenge Card:**
   - Point out the **Daily Challenge** card. This card is populated by a daily Cloud Scheduler job.
   - Tap **Attempt Now**. Note how it deep-links directly into the Tutor screen, pre-filling the day's curriculum question.
3. **Subject Progress Rings:**
   - View the circular progress widgets showing syllabus completion percentages based on completed study materials.
4. **Recent Sessions & New Materials:**
   - Scroll through the horizontal carousels showing recently accessed tutor sessions and newly published study handouts.

---

## Step 3: Interactive Learning (AI Tutor "MentorBot")
**Objective:** Demonstrate the core product value—a fast, context-aware, syllabus-aligned AI tutor.

1. **Subject Context Switching:**
   - Open the Tutor tab. Pick a subject (e.g., **Chemistry**) and a level from the dropdown.
   - Observe the suggestion chips changing dynamically based on the active subject (e.g., moles, organic mechanisms).
2. **Sending a Text Prompt (Playbook Calibration):**
   - Type a syllabus question: *"How do I balance the combustion of propane?"*
   - Observe the **typing indicator** while the Groq-backed Cloud Function executes.
   - Point out the response features:
     - Clear subject playbooks applied (e.g., Chemistry includes balanced equations with state symbols: `(s)`, `(l)`, `(g)`, `(aq)`).
     - Markdown formatting with bold concepts, code fences, and step-by-step structured layout.
     - Syllabus citation at the bottom (e.g., *"Cambridge IGCSE Chemistry 0620 / Topic 4"*).
3. **Idempotency & Cost Gating:**
   - Double-click the Send button or simulate a network disconnect.
   - Explain that because the client generates a unique `clientRequestId`, the server deduplicates the request: the model is only billed once, and points are only awarded once.
4. **Rate Limit Warning & Premium Block:**
   - Highlight the daily message counter (30 text messages/day for Free Tier).
   - Once the count exceeds 30, try sending another message. The **Premium Upgrade Modal** will slide in, blocking further queries until the user upgrades.

---

## Step 4: Independent Study (Materials & Search)
**Objective:** Show how students find specific topics and read through past curriculum notes.

1. **Materials Browser (Screen 07):**
   - Navigate to the **Library** tab.
   - Use the top filters (Subject, Level, Document Type) to narrow down items.
   - Note the **shimmer loading skeleton** before items populate.
   - Tap on a study card to open the detail sheet, incrementing the material's view count in Firestore.
2. **Cross-Content Search (Screen 08):**
   - Tap the **Search** icon.
   - Type a keyword like *"Differentiation"*.
   - Point out the tabbed results:
     - **All:** Combined results.
     - **Materials:** Syllabus handouts and notes.
     - **Sessions:** Matches from your past chat histories with MentorBot.
   - Observe that the **Sessions** tab is locked behind a premium indicator, promoting upgrades.

---

## Step 5: Gamification & Rewards
**Objective:** Show the server-authoritative gamification engine designed to build daily study habits.

1. **Earning Points:**
   - Complete a daily challenge or finish a chat session.
   - Observe the **confetti animation** and the `BadgeCelebrationOverlay` popping up.
2. **Rewards Ledger (Screen 10):**
   - Go to the **Rewards** tab.
   - Highlight the **Badges** section showing unlocked badges (e.g., *"First-of-Day", "7-Day Streak"*).
   - Switch to the **History** tab. This shows a detailed, paginated ledger from `/rewards/{uid}/ledger`.
   - Explain the **Security Invariant:** Clients cannot directly write points. The ledger is written exclusively by firestore background triggers (`onSessionMessageWrite`), making points tamper-proof.

---

## Step 6: Upgrades & Account Management (Profile)
**Objective:** Show the student profile, native integrations, and the subscription upgrade path.

1. **Subscription Card:**
   - Go to the **Profile** tab. Point out the dynamic pricing and feature list loaded from Firestore Remote Config.
   - Tap **Upgrade Now**.
   - Note that Stripe Checkout opens in an **external Safari browser** (rather than an in-app webview) to comply with App Store Guideline 3.1.1.
2. **Settings & Support List:**
   - Select **Language**. Note it shows the active locale (e.g., `English · US` or `বাংলা · BD`).
   - Tap **Help & FAQ**. Show how it launches the native mail client with pre-filled support addresses and subjects.
   - Tap **Rate the App**. Show how it targets the platform store native deep link (`itms-apps://` or `market://`).

---

## Step 7: The Control Center (Admin Panel)
**Objective:** Show how teachers and platform managers oversee users, upload curriculum, and broadcast announcements.

1. **Accessing the Panel (Screen 12):**
   - Log in with a user whose custom claims include `{ role: 'admin' }`.
   - Navigate to `/admin`. Explain that non-admin accounts attempting to open this route are auto-redirected back to `/dashboard` with a security toast.
2. **Dashboard & Analytics Tab:**
   - Review live metric cards: Daily Active Users (DAU), active subscriptions, and support requests.
   - Review charts (`fl_chart`) showing monthly revenue and popular study subjects.
3. **Users Management:**
   - Scroll through the paginated list of users.
   - Tap the settings menu on a user to manually **Toggle Premium** (updating their custom auth claims instantly) or change roles.
4. **Content Upload Form:**
   - Fill out the form to upload a new O-Level Physics PDF.
   - Select the target group (`role_student`). Uploading pushes the document to Firebase Storage, registers it in Firestore, and triggers a FCM notification to subscribed devices.
5. **Broadcast Notifications:**
   - Compose a platform-wide alert and select the target audience (e.g., *All students*).
   - Send the broadcast. Note how it instantly delivers the push notification using Firebase Cloud Messaging.
