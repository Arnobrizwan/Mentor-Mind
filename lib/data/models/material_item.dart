import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// MaterialItem — lightweight dashboard projection of /materials.
// Contains only display fields (id, title, level, subject, gradient).
// Full browse projection: LearningMaterial (lib/data/models/learning_material.dart)
// ---------------------------------------------------------------------------

class MaterialItem {
  final String id;
  final String title;
  final String level;
  final String subject;
  final List<Color> gradient;
  const MaterialItem({
    required this.id,
    required this.title,
    required this.level,
    required this.subject,
    required this.gradient,
  });

  factory MaterialItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final subject = (data['subject'] as String?) ?? 'General';
    return MaterialItem(
      id: doc.id,
      title: (data['title'] as String?) ?? 'Untitled',
      level: (data['level'] as String?) ?? '',
      subject: subject,
      gradient: _gradientForSubject(subject),
    );
  }
}

// ---------------------------------------------------------------------------
// Subject → brand color mapping (shared helper used by MaterialItem.fromDoc)
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

// Pastel gradient: shifts the subject's saturated hue toward a light wash
// (top-left) and a softer mid-tone (bottom-right). White text still passes
// AA contrast against the bottom stop on every subject in the catalog.
List<Color> _gradientForSubject(String s) {
  final base = _colorForSubject(s);
  final hsl = HSLColor.fromColor(base);
  final lighter = hsl
      .withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0))
      .withSaturation((hsl.saturation * 0.85).clamp(0.0, 1.0))
      .toColor();
  final mid = hsl
      .withLightness((hsl.lightness + 0.06).clamp(0.0, 1.0))
      .toColor();
  return [lighter, mid];
}
