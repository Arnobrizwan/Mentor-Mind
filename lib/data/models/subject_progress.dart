import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// SubjectProgress — per-subject progress bar data for the dashboard screen.
// Computed from DashboardUser.subjects; not stored in Firestore directly.
// ---------------------------------------------------------------------------

class SubjectProgress {
  final String name;
  final double progress; // 0..1
  final Color color;
  const SubjectProgress({
    required this.name,
    required this.progress,
    required this.color,
  });
}
