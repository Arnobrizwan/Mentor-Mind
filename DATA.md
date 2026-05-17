# MentorMinds — Seed Data Reference

This is the demo content populated by `tool/seed/seed.js` into Firebase project `mentor-mind-aa765`. Re-run the script any time to refresh.

---

## 🔑 Test Accounts

Email **verified** on all accounts so verification screens are skipped. Passwords meet the 8+ / uppercase / digit policy.

| Role | Email | Password | Subscription | Level | Notes |
|---|---|---|---|---|---|
| Student (free) | `student@mentorminds.test` | `Student1!` | free | O Level | Subjects: Math, Physics, Chemistry · 12 pts · 1 badge · **10/day chat limit** |
| Student (premium) | `premium@mentorminds.test` | `Premium1!` | **premium** | A Level | Subjects: Math, Physics, Biology, English · 140 pts · 2 badges · unlimited chat |
| Teacher (approved) | `teacher@mentorminds.test` | `Teacher1!` | free | A Level | Subjects: Chemistry, Biology · `isApproved: true` |
| Admin | `admin@mentorminds.test` | `Admin1!` | premium | — | Full admin; can write materials/notifications via security rules |

Re-running `node seed.js` preserves existing UIDs and just updates password + profile fields. The `/users/{uid}` + `/rewards/{uid}` documents are merged so existing user-generated data (sessions, usage history) is left alone.

---

## 📚 Seeded Materials (15)

Collection: **`/materials`** — all public-readable, admin-writable.

Each doc has `fileUrl`, `thumbnailUrl: null` (app falls back to subject gradient), `uploadedBy: 'seed_admin'`, plus realistic `createdAt` (2 hours → 12 days ago) and `views` counts.

### Mathematics (3)

| ID | Title | Level | Type | Views |
|---|---|---|---|---|
| `mat_quadratic_masterclass` | Quadratic Equations Masterclass | A Level | PDF | 342 |
| `mat_trigonometry_ol` | Trigonometry Essentials | O Level | Note | 128 |
| `mat_calculus_intro` | Calculus for Beginners | A Level | Video | 512 |

### Physics (3)

| ID | Title | Level | Type | Views |
|---|---|---|---|---|
| `mat_newton_laws` | Newton's Laws — Chapter 3 | O Level | PDF | 489 |
| `mat_electromagnetism` | Electromagnetism Explained | A Level | Video | 276 |
| `mat_kinematics_ws` | Kinematics Practice Worksheet | O Level | PDF | 98 |

### Chemistry (3)

| ID | Title | Level | Type | Views |
|---|---|---|---|---|
| `mat_organic_reactions` | Organic Chemistry Reactions | A Level | PDF | 203 |
| `mat_periodic_table` | The Periodic Table Deep Dive | O Level | Note | 167 |
| `mat_stoichiometry` | Stoichiometry Practice Problems | A Level | PDF | 74 |

### Biology (2)

| ID | Title | Level | Type | Views |
|---|---|---|---|---|
| `mat_cell_division` | Cell Division Explained | O Level | Video | 412 |
| `mat_physiology_overview` | Human Physiology Overview | A Level | Note | 156 |

### English (2)

| ID | Title | Level | Type | Views |
|---|---|---|---|---|
| `mat_essay_structure` | Essay Writing Structure | O Level | Note | 231 |
| `mat_literary_devices` | Literary Devices Guide | A Level | PDF | 189 |

### ICT (1)

| ID | Title | Level | Type | Views |
|---|---|---|---|---|
| `mat_python_intro` | Introduction to Python | A Level | Video | 618 |

### Accounting (1)

| ID | Title | Level | Type | Views |
|---|---|---|---|---|
| `mat_double_entry` | Double-Entry Bookkeeping Basics | O Level | Note | 62 |

> Video `fileUrl`s point to real YouTube pages. PDF `fileUrl`s are `example.com` placeholders — replace with Cloud Storage URLs once you upload real files.

---

## 🔔 Seeded Notifications (5)

Collection: **`/notifications`** — signed-in readable, admin-writable.

| ID | Title | Recipient | Read | Deeplink |
|---|---|---|---|---|
| `notif_welcome` | Welcome to MentorMinds! 🎉 | `all` | false | `/tutor` |
| `notif_new_physics` | New Physics materials added 📚 | `student` | false | `/materials` |
| `notif_streak_reminder` | Keep your streak alive 🔥 | `student` | false | `/dashboard` |
| `notif_premium_teaser` | Premium launching soon ⭐ | `all` | false | `null` |
| `notif_teacher_approvals` | Teacher approvals pending | `admin` | false | `/admin` |

### Expected bell badge counts

- **`student@mentorminds.test`** → **3** (welcome + new-physics + streak — all + student)
- **`premium@mentorminds.test`** → **3** (same as above; premium is just a flag, role is still `student`)
- **`teacher@mentorminds.test`** → **2** (welcome + premium-teaser — only the `all` ones)
- **`admin@mentorminds.test`** → **3** (welcome + premium-teaser + teacher-approvals)

Marking a notification `read: true` in Firestore drops the count in real time.

---

## 🧪 Quick test scenarios

1. **Sign in as `student@mentorminds.test` / `Student1!`**
   - Dashboard shows 3 unread, streak `0 🔥` (first login), 12 pts in the gold chip
   - Quick-actions work: Ask AI → Materials → Rewards
   - Daily Challenge shows countdown to midnight
   - Subject rings render for Math / Physics / Chemistry
   - Materials carousel: 4 most recent items
   - Bottom nav: tap Materials → 15-item grid appears

2. **Sign in as `premium@mentorminds.test` / `Premium1!`**
   - Tutor chat has no daily message limit (140 pts to start)
   - Image attach button opens the picker
   - Search → Sessions tab unlocked (requires having chat sessions to return hits)

3. **Sign in as `teacher@mentorminds.test` / `Teacher1!`**
   - Same student-like UI for now (teacher dashboard is still a placeholder)
   - Can write to `/materials` once the teacher upload UI lands (already allowed by rules because `isApproved: true`)

4. **Sign in as `admin@mentorminds.test` / `Admin1!`**
   - Should see the `notif_teacher_approvals` notification
   - Can write any collection per `firestore.rules`

---

## 🔄 Re-seeding

```bash
cd tool/seed
node seed.js
```

The script is idempotent:
- Auth users: looked up by email, password + profile updated
- Materials / notifications: `.set()` by fixed doc ID — overwrites, no duplicates
- User-generated docs (`/sessions/{id}`, `/users/{uid}/usage/{date}`): untouched

If you ever want a clean slate, delete the test users from Auth console + delete the collections, then re-run.
