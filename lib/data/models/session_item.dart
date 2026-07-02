import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// SessionItem — a single recent tutoring session, decoded from /sessions.
// Used on the dashboard and in search results.
// ---------------------------------------------------------------------------

class SessionItem {
  final String id;
  final String subject;
  final Color subjectColor;
  final String question;
  final DateTime timestamp;
  const SessionItem({
    required this.id,
    required this.subject,
    required this.subjectColor,
    required this.question,
    required this.timestamp,
  });

  factory SessionItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final subject = (data['subject'] as String?) ?? 'General';
    final question = (data['lastQuestion'] as String?) ??
        (data['title'] as String?) ??
        'Recent question';
    final ts = (data['updatedAt'] as Timestamp?)?.toDate() ??
        (data['createdAt'] as Timestamp?)?.toDate() ??
        DateTime.now();
    return SessionItem(
      id: doc.id,
      subject: subject,
      subjectColor: _colorForSubject(subject),
      question: question,
      timestamp: ts,
    );
  }
}

// ---------------------------------------------------------------------------
// Subject → brand color mapping (shared helper used by SessionItem.fromDoc)
// ---------------------------------------------------------------------------

const _subjectColors = <String, Color>{
  'Mathematics': Color(0xFF3B82F6),
  'Physics':     Color(0xFF8B5CF6),
  'Chemistry':   Color(0xFF22C55E),
  'Biology':     Color(0xFF14B8A6),
  'English':     Color(0xFFEC4899),
  'ICT':         Color(0xFF06B6D4),
  'Accounting':  Color(0xFFF59E0B),
  'Economics':   Color(0xFFEF4444),
  'History':     Color(0xFFA855F7),
  'Geography':   Color(0xFF10B981),
};

Color _colorForSubject(String s) =>
    _subjectColors[s] ?? const Color(0xFF66A39B); // AppColors.kPrimary
