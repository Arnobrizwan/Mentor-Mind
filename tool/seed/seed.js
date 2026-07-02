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

// Emulator mode: when FIRESTORE_EMULATOR_HOST is set the Admin SDK talks to
// the local emulator and needs no credentials at all. Also point Auth at its
// emulator if the caller didn't already.
const emulatorMode = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
if (emulatorMode && !process.env.FIREBASE_AUTH_EMULATOR_HOST) {
  process.env.FIREBASE_AUTH_EMULATOR_HOST = 'localhost:9099';
}

// Prefer service-account.json in this directory; fall back to ADC.
const saPath = path.join(__dirname, 'service-account.json');
if (emulatorMode) {
  admin.initializeApp({ projectId: projectId || 'mentor-mind-aa765' });
  console.log(
    `Emulator mode: Firestore=${process.env.FIRESTORE_EMULATOR_HOST}, ` +
      `Auth=${process.env.FIREBASE_AUTH_EMULATOR_HOST}`,
  );
} else if (fs.existsSync(saPath)) {
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

// Dhaka (UTC+6) date key — mirrors functions/src/lib/quota.ts getDhakaDateKey.
// Usage docs and the daily challenge doc are keyed by this.
function dhakaDateKey(date = new Date()) {
  const dhaka = new Date(date.getTime() + 6 * 60 * 60 * 1000);
  return dhaka.toISOString().slice(0, 10);
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
  {
    id: 'mat_trial_balance',
    data: {
      title: 'Trial Balance Worked Examples',
      subject: 'Accounting',
      level: 'A Level',
      type: 'pdf',
      fileUrl: 'https://example.com/trial-balance.pdf',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 108,
      createdAt: daysAgo(6),
    },
  },

  // Biology (additional)
  {
    id: 'mat_photosynthesis',
    data: {
      title: 'Photosynthesis Step-by-Step',
      subject: 'Biology',
      level: 'O Level',
      type: 'video',
      fileUrl: 'https://www.youtube.com/watch?v=eo5XndJaz-Y',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 287,
      createdAt: daysAgo(4),
    },
  },

  // English (additional)
  {
    id: 'mat_unseen_passage',
    data: {
      title: 'Unseen Passage Strategy (PEEL)',
      subject: 'English',
      level: 'O Level',
      type: 'pdf',
      fileUrl: 'https://example.com/unseen-peel.pdf',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 174,
      createdAt: daysAgo(2),
    },
  },

  // ICT (additional)
  {
    id: 'mat_databases_sql',
    data: {
      title: 'Databases & SQL Crash Course',
      subject: 'ICT',
      level: 'O Level',
      type: 'note',
      fileUrl: 'https://example.com/sql-crash-course',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 235,
      createdAt: daysAgo(10),
    },
  },

  // Economics
  {
    id: 'mat_supply_demand',
    data: {
      title: 'Supply and Demand Diagrams',
      subject: 'Economics',
      level: 'O Level',
      type: 'pdf',
      fileUrl: 'https://example.com/supply-demand.pdf',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 198,
      createdAt: daysAgo(3),
    },
  },
  {
    id: 'mat_elasticity',
    data: {
      title: 'Price Elasticity Explained',
      subject: 'Economics',
      level: 'A Level',
      type: 'video',
      fileUrl: 'https://www.youtube.com/watch?v=HHcblIxiAAk',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 142,
      createdAt: hoursAgo(18),
    },
  },
  {
    id: 'mat_market_failure',
    data: {
      title: 'Market Failure Case Studies',
      subject: 'Economics',
      level: 'A Level',
      type: 'note',
      fileUrl: 'https://example.com/market-failure',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 89,
      createdAt: daysAgo(7),
    },
  },

  // History
  {
    id: 'mat_partition_1947',
    data: {
      title: 'Partition of 1947 — Key Causes',
      subject: 'History',
      level: 'O Level',
      type: 'pdf',
      fileUrl: 'https://example.com/partition-1947.pdf',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 326,
      createdAt: daysAgo(2),
    },
  },
  {
    id: 'mat_liberation_war',
    data: {
      title: 'Bangladesh Liberation War 1971',
      subject: 'History',
      level: 'O Level',
      type: 'video',
      fileUrl: 'https://www.youtube.com/watch?v=ZBjjzJpEM6c',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 521,
      createdAt: hoursAgo(30),
    },
  },
  {
    id: 'mat_cold_war',
    data: {
      title: 'The Cold War: A-Level Overview',
      subject: 'History',
      level: 'A Level',
      type: 'note',
      fileUrl: 'https://example.com/cold-war-overview',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 117,
      createdAt: daysAgo(8),
    },
  },

  // Geography
  {
    id: 'mat_plate_tectonics',
    data: {
      title: 'Plate Tectonics and Earthquakes',
      subject: 'Geography',
      level: 'O Level',
      type: 'video',
      fileUrl: 'https://www.youtube.com/watch?v=RA2-Vc4PMnA',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 264,
      createdAt: daysAgo(5),
    },
  },
  {
    id: 'mat_population_geo',
    data: {
      title: 'Population Geography — Bangladesh',
      subject: 'Geography',
      level: 'O Level',
      type: 'pdf',
      fileUrl: 'https://example.com/population-bd.pdf',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 153,
      createdAt: daysAgo(9),
    },
  },
  {
    id: 'mat_climate_change',
    data: {
      title: 'Climate Change Case Study',
      subject: 'Geography',
      level: 'A Level',
      type: 'note',
      fileUrl: 'https://example.com/climate-case-study',
      thumbnailUrl: null,
      uploadedBy: 'seed_admin',
      views: 99,
      createdAt: daysAgo(13),
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
  {
    id: 'notif_daily_challenge',
    data: {
      title: "Today's challenge is live ⚡",
      body: 'Solve 3 algebra questions and earn 20 bonus points.',
      recipientRole: 'student',
      read: false,
      deeplink: '/dashboard',
      createdAt: hoursAgo(1),
      timestamp: hoursAgo(1),
      type: 'challenge',
    },
  },
  {
    id: 'notif_badge_earned',
    data: {
      title: 'New badge: First Step 🌱',
      body: 'You finished your first tutoring session — keep going!',
      recipientRole: 'student',
      read: true,
      deeplink: '/rewards',
      createdAt: hoursAgo(26),
      timestamp: hoursAgo(26),
      type: 'reward',
    },
  },
  {
    id: 'notif_new_materials_geography',
    data: {
      title: 'Geography drops just landed 🌍',
      body: 'Plate tectonics, climate change, population — all new.',
      recipientRole: 'student',
      read: false,
      deeplink: '/materials',
      createdAt: hoursAgo(10),
      timestamp: hoursAgo(10),
      type: 'new_material',
    },
  },
  {
    id: 'notif_weekly_recap',
    data: {
      title: 'Weekly recap: +145 points',
      body: 'You asked 18 questions and completed 3 sessions this week.',
      recipientRole: 'student',
      read: false,
      deeplink: '/rewards',
      createdAt: daysAgo(1),
      timestamp: daysAgo(1),
      type: 'announcement',
    },
  },
];

// ---------------------------------------------------------------------------
// Seed data — /config/* documents (admin-editable runtime config)
// Mirrors lib/data/models/*_config.dart defaults so a fresh project boots
// with sensible values. Admins edit these docs in Firebase Console; the
// Flutter app picks up changes live via RemoteConfigService.
// ---------------------------------------------------------------------------

const configDocs = {
  gamification: {
    badges: [
      {
        id: 'first_step',
        emoji: '🌱',
        name: 'First Step',
        description: 'Complete your first tutoring session.',
        unlockHint: 'Complete 1 session',
        target: 1,
        progressField: 'sessionsCompleted',
      },
      {
        id: 'curious_learner',
        emoji: '💬',
        name: 'Curious Learner',
        description: 'Ask MentorBot 50 questions across any subject.',
        unlockHint: 'Ask 50 questions',
        target: 50,
        progressField: 'totalQuestions',
      },
      {
        id: 'dedicated_learner',
        emoji: '📚',
        name: 'Dedicated Learner',
        description: 'Complete 5 tutoring sessions.',
        unlockHint: 'Complete 5 sessions',
        target: 5,
        progressField: 'sessionsCompleted',
      },
      {
        id: 'week_warrior',
        emoji: '🏆',
        name: 'Week Warrior',
        description: 'Maintain a 7-day study streak.',
        unlockHint: 'Study 7 days in a row',
        target: 7,
        progressField: 'streakDays',
      },
      {
        id: 'month_master',
        emoji: '🗓️',
        name: 'Month Master',
        description: 'Maintain a 30-day study streak.',
        unlockHint: 'Study 30 days in a row',
        target: 30,
        progressField: 'streakDays',
      },
      {
        id: 'diagram_detective',
        emoji: '🔍',
        name: 'Diagram Detective',
        description: 'Upload 10 diagrams for MentorBot to analyze.',
        unlockHint: 'Upload 10 diagrams',
        target: 10,
        progressField: 'diagramUploads',
      },
      {
        id: 'subject_expert',
        emoji: '🎯',
        name: 'Subject Expert',
        description: 'Ask 100 questions in a single subject.',
        unlockHint: 'Ask 100 questions in one subject',
        target: 100,
        progressField: '_questionsPerSubjectMax',
      },
    ],
    milestones: [
      { points: 50, rewardHint: '🌱 Learner badge' },
      { points: 100, rewardHint: '⭐ Rising Star badge' },
      { points: 200, rewardHint: '📚 Bookworm bonus' },
      { points: 500, rewardHint: '🏆 Week Warrior badge' },
      { points: 1000, rewardHint: '💎 Premium trial day' },
      { points: 2500, rewardHint: '🚀 Booster pack' },
      { points: 5000, rewardHint: '👑 Grandmaster title' },
    ],
    streak: {
      graceDays: 1,
      lookbackDays: 45,
    },
  },
  curriculum: {
    subjects: [
      'Mathematics',
      'Physics',
      'Chemistry',
      'Biology',
      'English',
      'ICT',
      'Accounting',
      'Economics',
      'History',
      'Geography',
    ],
    levels: ['O Level', 'A Level'],
    subjectShortLabels: {
      all: 'All',
      Mathematics: 'Math',
    },
    materialsSubjectAllSentinel: 'all',
    materialsLevelBothSentinel: 'both',
  },
  quotas: {
    // MIRROR: functions/src/lib/rate_limit.ts — server enforcement is
    // independent. Update both when changing limits.
    dailyTextLimit: 30,
    dailyImageLimit: 3,
    warningThreshold: 8,
    timezone: 'Asia/Dhaka',
  },
  subscription: {
    // MIRROR: Stripe price_... in functions/.env (STRIPE_PRICE_MONTHLY). The
    // checkout flow uses the Stripe price ID, NOT this number — keep them
    // aligned or the upgrade CTA will mislead.
    monthlyPriceBdt: 299,
    currencySymbol: '৳',
    headline: 'Upgrade to Premium 🚀',
    features: [
      'Unlimited AI tutoring',
      'Diagram upload & analysis',
      'Full chat history search',
      'Advanced analytics',
    ],
    ctaLabelFormat: 'Upgrade Now',
  },
  support: {
    // Profile → SUPPORT tile destinations. Admin-editable so legal pages and
    // help contact can change without an app release.
    helpEmail: 'support@mentorminds.app',
    helpEmailSubject: 'MentorMinds — Help request',
    privacyPolicyUrl: 'https://mentorminds.app/privacy',
    termsOfServiceUrl: 'https://mentorminds.app/terms',
    playStorePackageName: 'com.mentorminds.mentor_minds',
    // Fill in once the iOS app is approved on the App Store.
    appStoreId: '',
  },
};

// ---------------------------------------------------------------------------
// Seed data — test accounts (Firebase Auth + /users + /rewards)
// ---------------------------------------------------------------------------

// questionsPerSubject drives the progress rings on the dashboard
// ("Your Subjects" section). The badge target for "subject_expert" is 100,
// so a value of 40 reads as ~40% on that subject's ring.
//
// sessions: list of { subject, question, hoursAgo } — seeded into the
// /sessions collection under the user's uid. Drives "Recent Sessions".
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
      // Badge-progress counters (server-maintained in production; seeded so
      // the locked-badge progress bars on the Rewards screen render).
      streakDays: 3,
      sessionsCompleted: 6,
      totalQuestions: 74,
      diagramUploads: 0,
      questionsPerSubject: {
        Mathematics: 38,
        Physics: 22,
        Chemistry: 14,
      },
    },
    sessions: [
      { subject: 'Mathematics', question: 'Walk me through solving x² − 5x + 6 = 0', hoursAgo: 2 },
      { subject: 'Mathematics', question: 'How do I differentiate sin(x²)?',          hoursAgo: 6 },
      { subject: 'Physics',     question: 'Explain Newton\'s second law with an example', hoursAgo: 22 },
      { subject: 'Chemistry',   question: 'Balance H₂ + O₂ → H₂O and explain why',    hoursAgo: 30 },
      { subject: 'Physics',     question: 'Speed vs velocity — what\'s the difference?', hoursAgo: 50 },
      { subject: 'Mathematics', question: 'Practice problem on the quadratic formula',  hoursAgo: 74 },
    ],
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
      streakDays: 9,
      sessionsCompleted: 18,
      totalQuestions: 195,
      diagramUploads: 7,
      questionsPerSubject: {
        Mathematics: 72,
        Physics: 55,
        Biology: 40,
        English: 28,
      },
    },
    sessions: [
      { subject: 'Biology',     question: 'Explain photosynthesis step by step',        hoursAgo: 1 },
      { subject: 'Mathematics', question: 'Integration by parts — when do I use it?',   hoursAgo: 8 },
      { subject: 'Physics',     question: 'Derive the kinematic equations',             hoursAgo: 26 },
      { subject: 'English',     question: 'How do I structure a persuasive essay?',     hoursAgo: 48 },
    ],
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
      questionsPerSubject: {},
    },
    sessions: [],
    // Materials seeded with uploadedBy: <teacherUid> so the teacher dashboard's
    // "My uploads" KPI + "My recent uploads" list show real content for demos.
    // Each gets a deterministic doc id derived from `slug` so re-seeding is
    // idempotent.
    uploads: [
      {
        slug: 'org_chem_naming',
        title: 'Organic Chemistry — IUPAC Naming Guide',
        subject: 'Chemistry',
        level: 'A Level',
        type: 'NOTE',
        daysAgo: 1,
        views: 42,
      },
      {
        slug: 'mole_calc_practice',
        title: 'Mole Calculation Practice Set',
        subject: 'Chemistry',
        level: 'O Level',
        type: 'PDF',
        daysAgo: 3,
        views: 87,
      },
      {
        slug: 'bio_genetics_intro',
        title: 'Genetics — Mendelian Inheritance Intro',
        subject: 'Biology',
        level: 'A Level',
        type: 'NOTE',
        daysAgo: 5,
        views: 31,
      },
      {
        slug: 'bio_resp_diagrams',
        title: 'Cellular Respiration — Annotated Diagrams',
        subject: 'Biology',
        level: 'A Level',
        type: 'PDF',
        daysAgo: 8,
        views: 56,
      },
    ],
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
      questionsPerSubject: {},
    },
    sessions: [],
  },
];

// ---------------------------------------------------------------------------
// Seed data — leaderboard filler students (users + rewards docs only).
// The Rewards screen ranks /users by points; these give the board depth.
// ---------------------------------------------------------------------------

const leaderboardUsers = [
  { id: 'seed_lb_naila',  name: 'Naila Rahman',   points: 480, subjects: ['Mathematics'] },
  { id: 'seed_lb_tanvir', name: 'Tanvir Hasan',   points: 415, subjects: ['Physics'] },
  { id: 'seed_lb_ishita', name: 'Ishita Chowdhury', points: 360, subjects: ['Chemistry'] },
  { id: 'seed_lb_rafi',   name: 'Rafi Karim',     points: 290, subjects: ['Biology'] },
  { id: 'seed_lb_mim',    name: 'Mim Akter',      points: 245, subjects: ['English'] },
  { id: 'seed_lb_sabbir', name: 'Sabbir Ahmed',   points: 180, subjects: ['ICT'] },
  { id: 'seed_lb_priya',  name: 'Priya Das',      points: 120, subjects: ['Economics'] },
  { id: 'seed_lb_arman',  name: 'Arman Hossain',  points: 65,  subjects: ['Geography'] },
];

async function seedLeaderboardUsers() {
  for (const u of leaderboardUsers) {
    await db.collection('users').doc(u.id).set({
      uid: u.id,
      name: u.name,
      displayName: u.name,
      role: 'student',
      subscriptionType: 'free',
      subjects: u.subjects,
      level: 'O Level',
      isApproved: true,
      points: u.points,
      emailVerified: true,
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    await db.collection('rewards').doc(u.id).set({
      userId: u.id,
      points: u.points,
      badges: ['first_login'],
    }, { merge: true });
  }
  return leaderboardUsers.length;
}

// Today's daily challenge — same doc path/shape publishDailyChallenge writes.
async function seedDailyChallenge() {
  const dateKey = dhakaDateKey();
  await db.collection('daily_challenges').doc(dateKey).set({
    dateKey,
    subject: 'Mathematics',
    question: 'Solve for x: 2x² − 5x + 2 = 0. Show your working for full marks.',
    pointsReward: 25,
    publishedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  return dateKey;
}

// Today's usage doc — drives the quota banner and daily-goal UI.
async function seedUsageFor(uid, messageCount, imageCount) {
  const key = dhakaDateKey();
  await db
    .collection('users').doc(uid)
    .collection('usage').doc(key)
    .set({ messageCount, imageCount, burstWindow: [] }, { merge: true });
}

// Realistic Q&A messages under sessions/{id}/messages. Docs carry both
// `content` (client model) and `text` (cloud-function writer) field names.
const seedAnswers = {
  Mathematics:
    '**Step 1 — Factorise.** Find two numbers whose product is (2)(6) = 12 ' +
    'and whose sum is −5... \n\n```\nx² − 5x + 6 = 0\n(x − 2)(x − 3) = 0\n```\n\n' +
    '**Step 2 — Solve.** $x = 2$ or $x = 3$.\n\n**Topic:** Cambridge IGCSE Math 0580 / Topic 2.5.',
  Physics:
    '**Formula first.** $F = ma$ — the resultant force on a body equals mass × acceleration.\n\n' +
    '**Example.** A 2 kg trolley pushed with 6 N: $a = F/m = 6/2 = 3\\ m/s^2$.\n\n' +
    '**Topic:** Cambridge IGCSE Physics 0625 / Topic 1.5 (Dynamics).',
  Chemistry:
    '**Balance it.**\n\n```\n2H₂ + O₂ → 2H₂O\n```\n\nHydrogen and oxygen atoms now match on ' +
    'both sides (4 H, 2 O). State symbols: $2H_2(g) + O_2(g) \\rightarrow 2H_2O(l)$.\n\n' +
    '**Topic:** Cambridge IGCSE Chemistry 0620 / Topic 4.',
  Biology:
    '**Definition.** Photosynthesis converts light energy into chemical energy stored in glucose.\n\n' +
    '**Word equation.**\n```\ncarbon dioxide + water →(light, chlorophyll)→ glucose + oxygen\n```\n\n' +
    '**Topic:** Cambridge IGCSE Biology 0610 / Topic 6 (Plant nutrition).',
  English:
    '**PEEL structure.** Point → Evidence → Explanation → Link. Start with a clear thesis, quote ' +
    'with line references, name the device (metaphor, anaphora), then explain its effect.\n\n' +
    '**Topic:** Cambridge O Level English 1123 / Paper 1.',
};

async function seedMessagesFor(uid, sessions) {
  let count = 0;
  for (let i = 0; i < sessions.length; i++) {
    const s = sessions[i];
    const sessionId = `seed_${uid}_${i}`;
    const askedAt = new Date(Date.now() - s.hoursAgo * 60 * 60 * 1000);
    const answer = seedAnswers[s.subject] || seedAnswers.Mathematics;
    const messagesRef = db
      .collection('sessions').doc(sessionId).collection('messages');
    await messagesRef.doc(`seed_q_${i}`).set({
      role: 'user',
      content: s.question,
      text: s.question,
      createdAt: Timestamp.fromDate(askedAt),
      promptVersion: '3',
    });
    await messagesRef.doc(`seed_a_${i}`).set({
      role: 'assistant',
      content: answer,
      text: answer,
      createdAt: Timestamp.fromDate(new Date(askedAt.getTime() + 8000)),
      promptVersion: '3',
      promptTokens: 220,
      completionTokens: 180,
    });
    count += 2;
  }
  return count;
}

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
    streakDays: u.profile.streakDays || 0,
    sessionsCompleted: u.profile.sessionsCompleted || 0,
    totalQuestions: u.profile.totalQuestions || 0,
    diagramUploads: u.profile.diagramUploads || 0,
    questionsPerSubject: u.profile.questionsPerSubject || {},
    emailVerified: true,
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  await db.collection('rewards').doc(uid).set({
    userId: uid,
    points: u.profile.points,
    badges: u.profile.badges,
    history: [],
  }, { merge: true });

  // Sync the role custom claim. The onUserCreate cloud function defaults
  // every new auth user to { role: 'student', premium: false }, so teachers
  // and admins MUST have their claim explicitly upgraded for the client-side
  // role-aware routing to work without a Firestore fallback fetch.
  const role = u.profile.role;
  const premium = u.profile.subscriptionType === 'premium';
  await admin.auth().setCustomUserClaims(uid, { role, premium });

  return uid;
}

// Seeds /materials documents authored by a single teacher. Idempotent: each
// material uses `mat_seed_<slug>` as its doc id so re-runs update in place.
async function seedUploadsFor(uid, uploads) {
  if (!uploads || uploads.length === 0) return 0;
  const now = Date.now();
  for (const u of uploads) {
    const ts = new Date(now - (u.daysAgo || 0) * 24 * 60 * 60 * 1000);
    const docId = `mat_seed_${u.slug}`;
    await db.collection('materials').doc(docId).set({
      title: u.title,
      subject: u.subject,
      level: u.level,
      type: u.type || 'NOTE',
      fileUrl: '',
      uploadedBy: uid,
      views: u.views ?? 0,
      createdAt: admin.firestore.Timestamp.fromDate(ts),
      uploadedAt: admin.firestore.Timestamp.fromDate(ts),
    });
  }
  return uploads.length;
}

// Seeds /sessions documents for a single user. Idempotent: each session uses
// a deterministic doc id (`seed_<uid>_<index>`) so re-running the script
// updates timestamps in place rather than creating duplicates.
async function seedSessionsFor(uid, sessions) {
  if (!sessions || sessions.length === 0) return 0;
  const now = Date.now();
  for (let i = 0; i < sessions.length; i++) {
    const s = sessions[i];
    const ts = new Date(now - s.hoursAgo * 60 * 60 * 1000);
    const docId = `seed_${uid}_${i}`;
    await db.collection('sessions').doc(docId).set({
      userId: uid,
      subject: s.subject,
      title: s.question,
      lastQuestion: s.question,
      messageCount: 4 + (i % 3),
      createdAt: admin.firestore.Timestamp.fromDate(ts),
      updatedAt: admin.firestore.Timestamp.fromDate(ts),
    });
  }
  return sessions.length;
}

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

async function run() {
  console.log(`\nSeeding /config/* documents...`);
  for (const [docId, data] of Object.entries(configDocs)) {
    await db.collection('config').doc(docId).set(data, { merge: true });
    console.log(`  ✓ config/${docId.padEnd(28)} — seeded`);
  }

  console.log(`\nSeeding ${testUsers.length} test accounts...`);
  let totalSessions = 0;
  let totalUploads = 0;
  for (const u of testUsers) {
    const uid = await seedUser(u);
    const ns = await seedSessionsFor(uid, u.sessions);
    if (ns > 0) {
      console.log(`    └─ ${ns} session${ns === 1 ? '' : 's'} seeded`);
      totalSessions += ns;
      const nm = await seedMessagesFor(uid, u.sessions);
      console.log(`    └─ ${nm} chat messages seeded`);
      // Today's usage → quota banner + daily-goal progress render non-zero.
      await seedUsageFor(uid, u.profile.subscriptionType === 'premium' ? 12 : 7,
        u.profile.subscriptionType === 'premium' ? 2 : 0);
      console.log(`    └─ usage doc for ${dhakaDateKey()} seeded`);
    }
    const nu = await seedUploadsFor(uid, u.uploads);
    if (nu > 0) {
      console.log(`    └─ ${nu} upload${nu === 1 ? '' : 's'} seeded`);
      totalUploads += nu;
    }
  }

  const lb = await seedLeaderboardUsers();
  console.log(`\n  ✓ ${lb} leaderboard filler students seeded`);

  const challengeKey = await seedDailyChallenge();
  console.log(`  ✓ daily challenge for ${challengeKey} seeded`);
  if (totalSessions > 0) {
    console.log(`  ${totalSessions} session document${totalSessions === 1 ? '' : 's'} written under /sessions.`);
  }
  if (totalUploads > 0) {
    console.log(`  ${totalUploads} teacher-authored material${totalUploads === 1 ? '' : 's'} written under /materials.`);
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
