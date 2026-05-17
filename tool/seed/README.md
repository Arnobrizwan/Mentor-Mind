# MentorMinds Seed Script

Populates your Firestore project with demo `/materials` and `/notifications`
so the Materials browser, search, and notification bell have real content.

## One-time setup

```bash
cd tool/seed
npm install
```

Then authenticate (pick **one**):

### Option A — Service account JSON (recommended)

1. Open **Firebase Console → Project Settings → Service accounts**
2. Click **"Generate new private key"** → download the JSON
3. Save it in this folder as **`service-account.json`** (it's gitignored)

### Option B — gcloud application-default credentials

```bash
gcloud auth application-default login
```

## Run

```bash
node seed.js
# or: npm run seed
```

Override the target project if needed:

```bash
node seed.js --project=mentor-mind-aa765
```

## What gets seeded

- **`/materials`** — 15 items across Math, Physics, Chemistry, Biology, English, ICT, Accounting; mix of PDFs, videos, notes; both O-Level and A-Level; realistic view counts and spread-out `createdAt` timestamps.
- **`/notifications`** — 5 notifications (welcome, new materials, streak reminder, premium teaser, admin pending).

## Re-running

The script is **idempotent** — it `.set()`s docs by fixed ID, so running it
again overwrites the same docs without creating duplicates. Use that to bump
timestamps when you want the "new" sort to look fresh.

## Notes

- `fileUrl` values point to demo URLs (YouTube for videos, `example.com` for PDFs).
  Replace with real Cloud Storage URLs after you upload actual files.
- `thumbnailUrl` is left `null` so the app falls back to its subject-tinted
  gradient placeholder — looks better than a broken image.
- Security rules restrict writes on these collections to admins. The script
  bypasses rules via the Admin SDK service account (that's the whole point).
