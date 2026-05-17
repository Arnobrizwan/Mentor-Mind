// Firestore seed script for MentorMinds.
// Populates /materials and /notifications with realistic demo data so the
// Materials browser, search, and notification bell have content on first run.
//
// Usage:
//   cd tool/seed
//   npm install
//   node seed.js                      # uses service-account.json in this dir
//   node seed.js --project=<id>       # override project (optional)
//
// Authentication options (pick one):
//   A. Service account JSON:
//        Firebase Console → Project Settings → Service Accounts
//        → "Generate new private key" → save as ./service-account.json
//   B. gcloud application-default credentials:
//        gcloud auth application-default login
//
// The script is idempotent — running it twice just overwrites the same docs.

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const args = process.argv.slice(2);
const projectArg = args.find((a) => a.startsWith('--project='));
const projectId = projectArg ? projectArg.split('=')[1] : undefined;

// Prefer service-account.json in this directory; fall back to ADC.
const saPath = path.join(__dirname, 'service-account.json');
if (fs.existsSync(saPath)) {
  const sa = require(saPath);
  admin.initializeApp({
    credential: admin.credential.cert(sa),
    projectId: projectId || sa.project_id,
  });
  console.log(`Authenticated with service account (${sa.project_id}).`);
} else {
  admin.initializeApp({ projectId });
  console.log('Authenticated with application default credentials.');
}

const db = admin.firestore();
const { Timestamp, FieldValue } = admin.firestore;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function daysAgo(n) {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return Timestamp.fromDate(d);
}

function hoursAgo(n) {
  const d = new Date();
  d.setHours(d.getHours() - n);
  return Timestamp.fromDate(d);
}

// ---------------------------------------------------------------------------
// Seed data — materials
// ---------------------------------------------------------------------------

const materials = [
  // Mathematics
  {
    id: 'mat_quadratic_masterclass',
    data: {
      title: 'Quadratic Equations Masterclass',
      subject: 'Mathematics',
      level: 'A Level',
      type: 'pdf',
      fileUrl:
        'https://firebasestorage.googleapis.com/v0/b/mentor-mind-aa765.firebasestorage.app/o/seed%2Fquadratic.pdf?alt=media',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 342,
      createdAt: daysAgo(2),
    },
  },
  {
    id: 'mat_trigonometry_ol',
    data: {
      title: 'Trigonometry Essentials',
      subject: 'Mathematics',
      level: 'O Level',
      type: 'note',
      fileUrl: 'https://example.com/trig-essentials',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 128,
      createdAt: daysAgo(5),
    },
  },
  {
    id: 'mat_calculus_intro',
    data: {
      title: 'Calculus for Beginners',
      subject: 'Mathematics',
      level: 'A Level',
      type: 'video',
      fileUrl: 'https://www.youtube.com/watch?v=WUvTyaaNkzM',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 512,
      createdAt: daysAgo(1),
    },
  },

  // Physics
  {
    id: 'mat_newton_laws',
    data: {
      title: "Newton's Laws — Chapter 3",
      subject: 'Physics',
      level: 'O Level',
      type: 'pdf',
      fileUrl: 'https://example.com/newton-laws.pdf',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 489,
      createdAt: hoursAgo(8),
    },
  },
  {
    id: 'mat_electromagnetism',
    data: {
      title: 'Electromagnetism Explained',
      subject: 'Physics',
      level: 'A Level',
      type: 'video',
      fileUrl: 'https://www.youtube.com/watch?v=wR_ibqi_B5Q',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 276,
      createdAt: daysAgo(3),
    },
  },
  {
    id: 'mat_kinematics_ws',
    data: {
      title: 'Kinematics Practice Worksheet',
      subject: 'Physics',
      level: 'O Level',
      type: 'pdf',
      fileUrl: 'https://example.com/kinematics.pdf',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 98,
      createdAt: daysAgo(7),
    },
  },

  // Chemistry
  {
    id: 'mat_organic_reactions',
    data: {
      title: 'Organic Chemistry Reactions',
      subject: 'Chemistry',
      level: 'A Level',
      type: 'pdf',
      fileUrl: 'https://example.com/organic.pdf',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 203,
      createdAt: daysAgo(4),
    },
  },
  {
    id: 'mat_periodic_table',
    data: {
      title: 'The Periodic Table Deep Dive',
      subject: 'Chemistry',
      level: 'O Level',
      type: 'note',
      fileUrl: 'https://example.com/periodic-table',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 167,
      createdAt: daysAgo(6),
    },
  },
  {
    id: 'mat_stoichiometry',
    data: {
      title: 'Stoichiometry Practice Problems',
      subject: 'Chemistry',
      level: 'A Level',
      type: 'pdf',
      fileUrl: 'https://example.com/stoichiometry.pdf',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 74,
      createdAt: daysAgo(9),
    },
  },

  // Biology
  {
    id: 'mat_cell_division',
    data: {
      title: 'Cell Division Explained',
      subject: 'Biology',
      level: 'O Level',
      type: 'video',
      fileUrl: 'https://www.youtube.com/watch?v=HJyq1bvVY4A',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 412,
      createdAt: hoursAgo(20),
    },
  },
  {
    id: 'mat_physiology_overview',
    data: {
      title: 'Human Physiology Overview',
      subject: 'Biology',
      level: 'A Level',
      type: 'note',
      fileUrl: 'https://example.com/physiology',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 156,
      createdAt: daysAgo(8),
    },
  },

  // English
  {
    id: 'mat_essay_structure',
    data: {
      title: 'Essay Writing Structure',
      subject: 'English',
      level: 'O Level',
      type: 'note',
      fileUrl: 'https://example.com/essay-structure',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 231,
      createdAt: daysAgo(3),
    },
  },
  {
    id: 'mat_literary_devices',
    data: {
      title: 'Literary Devices Guide',
      subject: 'English',
      level: 'A Level',
      type: 'pdf',
      fileUrl: 'https://example.com/literary-devices.pdf',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 189,
      createdAt: daysAgo(11),
    },
  },

  // ICT
  {
    id: 'mat_python_intro',
    data: {
      title: 'Introduction to Python',
      subject: 'ICT',
      level: 'A Level',
      type: 'video',
      fileUrl: 'https://www.youtube.com/watch?v=rfscVS0vtbw',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 618,
      createdAt: hoursAgo(14),
    },
  },

  // Accounting
  {
    id: 'mat_double_entry',
    data: {
      title: 'Double-Entry Bookkeeping Basics',
      subject: 'Accounting',
      level: 'O Level',
      type: 'note',
      fileUrl: 'https://example.com/double-entry',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 62,
      createdAt: daysAgo(12),
    },
  },
];

// ---------------------------------------------------------------------------
// Seed data — notifications
// ---------------------------------------------------------------------------

const notifications = [
  {
    id: 'notif_welcome',
    data: {
      title: 'Welcome to MentorMinds! 🎉',
      body: "Ask MentorBot anything about your O/A Level subjects — we're here 24/7.",
      recipientRole: 'all',
      read: false,
      deeplink: '/tutor',
      createdAt: hoursAgo(2),
      timestamp: hoursAgo(2),
      type: 'announcement',
    },
  },
  {
    id: 'notif_new_physics',
    data: {
      title: 'New Physics materials added 📚',
      body: "Newton's Laws and Electromagnetism just dropped.",
      recipientRole: 'student',
      read: false,
      deeplink: '/materials',
      createdAt: hoursAgo(6),
      timestamp: hoursAgo(6),
      type: 'new_material',
    },
  },
  {
    id: 'notif_streak_reminder',
    data: {
      title: 'Keep your streak alive 🔥',
      body: 'You studied yesterday — swing by for today too!',
      recipientRole: 'student',
      read: false,
      deeplink: '/dashboard',
      createdAt: hoursAgo(12),
      timestamp: hoursAgo(12),
      type: 'reminder',
    },
  },
  {
    id: 'notif_premium_teaser',
    data: {
      title: 'Premium launching soon ⭐',
      body: 'Unlimited AI tutoring, diagram uploads, and full chat history — coming this month.',
      recipientRole: 'all',
      read: false,
      deeplink: null,
      createdAt: daysAgo(2),
      timestamp: daysAgo(2),
      type: 'announcement',
    },
  },
  {
    id: 'notif_teacher_approvals',
    data: {
      title: 'Teacher approvals pending',
      body: 'Review and approve 2 pending teacher accounts.',
      recipientRole: 'admin',
      read: false,
      deeplink: '/admin',
      createdAt: hoursAgo(5),
      timestamp: hoursAgo(5),
      type: 'reminder',
    },
  },
];

// ---------------------------------------------------------------------------
// Seed data — test accounts (Firebase Auth + /users + /rewards)
// ---------------------------------------------------------------------------

const testUsers = [
  {
    email: 'student@mentorminds.test',
    password: 'Student1!',
    profile: {
      name: 'Sana Student',
      role: 'student',
      subscriptionType: 'free',
      subjects: ['Mathematics', 'Physics', 'Chemistry'],
      level: 'O Level',
      isApproved: true,
      badges: ['first_login'],
      points: 12,
    },
  },
  {
    email: 'premium@mentorminds.test',
    password: 'Premium1!',
    profile: {
      name: 'Parvez Premium',
      role: 'student',
      subscriptionType: 'premium',
      subjects: ['Mathematics', 'Physics', 'Biology', 'English'],
      level: 'A Level',
      isApproved: true,
      badges: ['first_login', 'streak_3'],
      points: 140,
    },
  },
  {
    email: 'teacher@mentorminds.test',
    password: 'Teacher1!',
    profile: {
      name: 'Tania Teacher',
      role: 'teacher',
      subscriptionType: 'free',
      subjects: ['Chemistry', 'Biology'],
      level: 'A Level',
      isApproved: true,
      badges: [],
      points: 0,
    },
  },
  {
    email: 'admin@mentorminds.test',
    password: 'Admin1!',
    profile: {
      name: 'Arif Admin',
      role: 'admin',
      subscriptionType: 'premium',
      subjects: [],
      level: '',
      isApproved: true,
      badges: ['first_login'],
      points: 0,
    },
  },
];

async function seedUser(u) {
  let uid;
  try {
    const existing = await admin.auth().getUserByEmail(u.email);
    uid = existing.uid;
    await admin.auth().updateUser(uid, {
      password: u.password,
      displayName: u.profile.name,
      emailVerified: true,
    });
    console.log(`  ✓ ${u.email.padEnd(30)} — updated (${u.profile.role})`);
  } catch (err) {
    if (err.code !== 'auth/user-not-found') throw err;
    const created = await admin.auth().createUser({
      email: u.email,
      password: u.password,
      displayName: u.profile.name,
      emailVerified: true,
    });
    uid = created.uid;
    console.log(`  ✓ ${u.email.padEnd(30)} — created (${u.profile.role})`);
  }

  await db.collection('users').doc(uid).set({
    uid,
    email: u.email,
    name: u.profile.name,
    displayName: u.profile.name,
    role: u.profile.role,
    subscriptionType: u.profile.subscriptionType,
    subjects: u.profile.subjects,
    level: u.profile.level,
    isApproved: u.profile.isApproved,
    badges: u.profile.badges,
    points: u.profile.points,
    emailVerified: true,
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await db.collection('rewards').doc(uid).set({
    userId: uid,
    points: u.profile.points,
    badges: u.profile.badges,
    history: [],
  }, { merge: true });
}

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

async function run() {
  console.log(`\nSeeding ${testUsers.length} test accounts...`);
  for (const u of testUsers) {
    await seedUser(u);
  }

  console.log(`\nSeeding ${materials.length} materials...`);
  for (const m of materials) {
    await db.collection('materials').doc(m.id).set({
      ...m.data,
      // `createdAt` already set above; also stamp `uploadedAt` for compatibility
      // with any legacy fields the client may read.
      uploadedAt: m.data.createdAt,
    });
    console.log(`  ✓ ${m.id.padEnd(32)} — ${m.data.title}`);
  }

  console.log(`\nSeeding ${notifications.length} notifications...`);
  for (const n of notifications) {
    await db.collection('notifications').doc(n.id).set(n.data);
    console.log(`  ✓ ${n.id.padEnd(32)} — ${n.data.title}`);
  }

  console.log('\n✅ Seed complete.');
  console.log(
    '   Re-run this script any time to refresh timestamps / tweak copy.',
  );
}

run().catch((err) => {
  console.error('\n❌ Seed failed:', err);
  process.exit(1);
});
