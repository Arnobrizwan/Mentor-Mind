import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mentor_minds/core/constants/app_text_styles.dart';
import 'package:mentor_minds/core/theme/app_spacing.dart';
import 'package:mentor_minds/core/theme/brand_colors.dart';

// ---------------------------------------------------------------------------
// LegalScreen — shared scaffold for Help & FAQ, Privacy Policy, and Terms.
//
// Content is bundled with the app (no network round-trip) so these screens
// always work offline and on first launch. If we ever want admin-editable
// copy, we can switch the body to read from /config/legal_* — interface stays
// the same.
//
// Markdown is rendered with flutter_markdown (already in pubspec). External
// links inside the body are launched via url_launcher.
// ---------------------------------------------------------------------------

enum LegalDoc { helpFaq, privacy, terms }

extension LegalDocX on LegalDoc {
  String get title => switch (this) {
        LegalDoc.helpFaq => 'Help & FAQ',
        LegalDoc.privacy => 'Privacy Policy',
        LegalDoc.terms => 'Terms of Service',
      };

  String get body => switch (this) {
        LegalDoc.helpFaq => _helpFaqBody,
        LegalDoc.privacy => _privacyBody,
        LegalDoc.terms => _termsBody,
      };
}

class LegalScreen extends StatelessWidget {
  final LegalDoc doc;
  const LegalScreen({super.key, required this.doc});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Scaffold(
      backgroundColor: brand.background,
      appBar: AppBar(
        backgroundColor: brand.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: brand.textDark),
          onPressed: () =>
              context.canPop() ? context.pop() : Navigator.of(context).pop(),
        ),
        title: Text(
          doc.title,
          style: AppTextStyles.headingMedium.copyWith(color: brand.primary),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl,
        ),
        child: Markdown(
          data: doc.body,
          padding: EdgeInsets.zero,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            h1: AppTextStyles.headingLarge.copyWith(color: brand.textDark),
            h2: AppTextStyles.headingMedium.copyWith(color: brand.textDark),
            h3: AppTextStyles.headingSmall.copyWith(color: brand.textDark),
            p: AppTextStyles.bodyMedium
                .copyWith(color: brand.textDark, height: 1.55),
            listBullet: AppTextStyles.bodyMedium
                .copyWith(color: brand.textDark, height: 1.55),
            strong: AppTextStyles.bodyMedium.copyWith(
              color: brand.textDark,
              fontWeight: FontWeight.w700,
            ),
            blockSpacing: AppSpacing.sm + 4,
            a: TextStyle(
              color: brand.primary,
              decoration: TextDecoration.underline,
            ),
          ),
          onTapLink: (_, href, __) async {
            if (href == null || href.isEmpty) return;
            final uri = Uri.tryParse(href);
            if (uri == null) return;
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bundled content. Plain-text Markdown — keep terms factual; this is a study
// app for minors so guardian-readability matters.
// ---------------------------------------------------------------------------

const _helpFaqBody = '''
# Hi! 👋

This screen answers the most common questions. If you can't find what you need, tap the support email at the bottom.

## Getting started

**How do I start a tutor chat?**
Tap **AI Tutor** in the bottom navigation bar (or **Ask AI** on the dashboard). Pick your subject + level, type a question, and MentorBot will reply with a step-by-step answer aligned to Cambridge / Edexcel syllabi.

**Why do I get a "daily limit reached" message?**
Free accounts can send up to 30 messages per day to MentorBot. The counter resets at midnight in your time zone. Premium accounts have unlimited messages.

**What does Premium include?**
- Unlimited AI Tutor messages
- Diagram / image analysis (snap a textbook page, ask a question)
- Search across all your past chat sessions
- No daily-limit interruptions

## Subjects + materials

**Can I add or remove subjects?**
Yes. Tap **Profile → Edit profile → Subjects** to update your list. Your dashboard rings and tutor suggestions update immediately.

**Where do study materials come from?**
Teachers and admins publish materials. You'll see new uploads on the dashboard and in the Library tab, filtered to your subjects + level.

## Rewards

**How do I earn points?**
- Daily login: +5 pts
- Each tutor session you finish: +10 pts
- Daily challenge attempts: +15 pts
- Subject-mastery milestones unlock badges automatically

**Why isn't my streak counting?**
Streaks need an active day — at least one tutor message or daily challenge attempt. Missing one day breaks the streak (you get a 1-day grace period).

## Account

**How do I delete my account?**
Profile → Account → **Delete account**. This is permanent and removes all your sessions, points, and badges.

**I'm a teacher — why can't I publish materials yet?**
Teacher accounts require admin approval. You'll see a gold banner on your dashboard while it's pending. Once approved, the Upload + Announcement buttons unlock.

## Still stuck?

Email us at **support@mentorminds.app**. Include your role (student / teacher), the device you're using, and what you tried. We respond within one school day.
''';

const _privacyBody = '''
# Privacy Policy

_Last updated: May 2026_

MentorMinds is built for O-Level and A-Level students in Bangladesh. We take the privacy of minors seriously and collect only what we need to run the app.

## What we collect

- **Account info**: name, email, role (student / teacher / admin), level, subjects.
- **Study activity**: questions you ask MentorBot, chat session metadata, daily challenge attempts, materials you open. Used to improve responses and run your dashboard.
- **Device info**: device model + OS version (for crash reports), push-notification token (so we can deliver alerts you opted into).

We do **not** collect: location, contacts, photos library (we only read photos you explicitly attach to a chat), microphone, or biometric data.

## How we use it

- To answer your questions through the AI tutor (your messages are sent to Groq, our LLM provider, with no personally identifying tags).
- To show your dashboard, streak, points, and badges.
- To send you push notifications you opted into.
- For aggregate, de-identified analytics — how many students used the tutor today, which subjects are popular — never tied to your name.

## How we store it

- Hosted on **Google Firebase** (Firestore + Cloud Storage) inside Google Cloud's `asia-south1` region.
- Encrypted at rest and in transit.
- Access controlled by Firestore security rules — students see only their own data; teachers see only their own uploads; admins have audit-logged access.

## What we share

We **do not** sell your data. We share data only with:

- **Groq** — to process your tutor questions. They process; they do not retain or train on your messages on the free tier we use.
- **Google Firebase** — our hosting + analytics provider.
- **Stripe** — only if you start a Premium subscription. Stripe handles payment data; we never see your card number.

## Your rights

You can:

- View your data: Profile → Edit profile.
- Edit your data: same screen.
- Delete your data: Profile → Account → Delete account. This is permanent and irreversible.
- Export your data: email **support@mentorminds.app** and we'll send a JSON archive within 30 days.

## For parents / guardians

If your child uses MentorMinds and you'd like a copy of their data or want it deleted, email **support@mentorminds.app** with proof of guardianship.

## Contact

Privacy questions go to **privacy@mentorminds.app**. Other questions: **support@mentorminds.app**.
''';

const _termsBody = '''
# Terms of Service

_Last updated: May 2026_

By using MentorMinds you agree to these terms. They're short — please read them.

## 1. Eligibility

MentorMinds is intended for students aged 13+ preparing for O-Level / A-Level exams (Cambridge CAIE and Edexcel boards). Younger users need guardian consent.

## 2. Your account

- One person, one account. Don't share your password.
- Tell us at **support@mentorminds.app** if you think someone else has accessed your account.
- Teacher accounts require admin approval before you can publish materials or send announcements.

## 3. Acceptable use

You may use MentorMinds to:

- Ask MentorBot subject questions
- Read study materials
- Track your own progress

You may **not**:

- Use MentorBot to cheat on a graded assessment (it's a learning tool, not an exam tool).
- Upload copyrighted material you don't own as a teacher.
- Spam announcements, harass other users, or post sexual / hateful / illegal content.
- Attempt to reverse-engineer the app or probe our infrastructure for vulnerabilities (responsible-disclosure: **security@mentorminds.app**).

We may suspend or delete accounts that break these rules.

## 4. Subscriptions

Premium subscriptions renew monthly through Stripe Checkout. You can cancel anytime in Profile → Manage Subscription; cancellations take effect at the end of the billing period. No refunds for unused time except where legally required.

## 5. AI-generated content

MentorBot answers are produced by an AI model (Llama 3.3 70B via Groq). They aim for accuracy but can be wrong. **Always verify against your textbook or teacher before exam day.** We're not liable for grade outcomes that depend solely on AI output.

## 6. Intellectual property

- Materials you upload remain yours.
- The app itself, brand, mascot, and codebase are owned by MentorMinds.
- By uploading, you grant us a license to display your material to students in your subjects.

## 7. Termination

You can delete your account anytime (Profile → Account → Delete account). We may terminate accounts that violate these terms. Termination removes your data per our Privacy Policy.

## 8. Changes

We may update these terms. Material changes will trigger an in-app notice. Continued use after that constitutes acceptance.

## 9. Contact

Questions: **support@mentorminds.app**.
''';
