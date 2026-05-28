import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';

// ---------------------------------------------------------------------------
// MaterialType — discriminator for the three supported material formats.
// Also carries label, emoji, badge color, and CTA text for the UI.
// ---------------------------------------------------------------------------

enum MaterialType { pdf, video, note }

extension MaterialTypeX on MaterialType {
  String get label => switch (this) {
        MaterialType.pdf   => 'PDF',
        MaterialType.video => 'VIDEO',
        MaterialType.note  => 'NOTE',
      };

  String get longLabel => switch (this) {
        MaterialType.pdf   => 'PDF',
        MaterialType.video => 'Video',
        MaterialType.note  => 'Notes',
      };

  String get emoji => switch (this) {
        MaterialType.pdf   => '\u{1F4C4}',
        MaterialType.video => '\u{1F3AC}',
        MaterialType.note  => '\u{1F4DD}',
      };

  Color get badgeColor => switch (this) {
        MaterialType.pdf   => const Color(0xFFEF4444),
        MaterialType.video => const Color(0xFF8B5CF6),
        MaterialType.note  => const Color(0xFFF59E0B),
      };

  String get ctaLabel => switch (this) {
        MaterialType.pdf   => 'Open PDF',
        MaterialType.video => 'Watch Video',
        MaterialType.note  => 'Read Note',
      };

  static MaterialType? parse(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'pdf':
        return MaterialType.pdf;
      case 'video':
        return MaterialType.video;
      case 'note':
      case 'notes':
        return MaterialType.note;
      default:
        return null;
    }
  }
}

// ---------------------------------------------------------------------------
// Subject color mapping (shared by LearningMaterial and MaterialSearchHit)
// ---------------------------------------------------------------------------

const _subjectColors = <String, Color>{
  'Mathematics': Color(0xFF3B82F6),
  'Physics':     Color(0xFF6366F1),
  'Chemistry':   Color(0xFF22C55E),
  'Biology':     Color(0xFF14B8A6),
  'English':     Color(0xFFEC4899),
  'ICT':         Color(0xFF06B6D4),
  'Accounting':  Color(0xFFF59E0B),
  'Economics':   Color(0xFFEF4444),
  'History':     Color(0xFFA855F7),
  'Geography':   Color(0xFF10B981),
};

Color subjectColorFor(String s) =>
    _subjectColors[s] ?? AppColors.kPrimary;

// Subject icon mapping — used on material cards / search rows so each subject
// has a distinct visual identity beyond just colour. Material Icons only (no
// PNG assets to bundle). Fallback is the generic book icon.
const _subjectIcons = <String, IconData>{
  'Mathematics': Icons.functions_rounded,
  'Physics':     Icons.bolt_rounded,
  'Chemistry':   Icons.science_rounded,
  'Biology':     Icons.biotech_rounded,
  'English':     Icons.menu_book_rounded,
  'ICT':         Icons.code_rounded,
  'Accounting':  Icons.calculate_rounded,
  'Economics':   Icons.trending_up_rounded,
  'History':     Icons.history_edu_rounded,
  'Geography':   Icons.public_rounded,
};

IconData subjectIconFor(String s) =>
    _subjectIcons[s] ?? Icons.auto_stories_rounded;

// ---------------------------------------------------------------------------
// LearningMaterial — full materials-browse projection of /materials.
// Contains file URL, type, views, and createdAt for the browse screen.
// Lightweight dashboard projection: MaterialItem (lib/data/models/material_item.dart)
// ---------------------------------------------------------------------------

class LearningMaterial {
  final String materialId;
  final String title;
  final String subject;
  final String level;
  final String fileUrl;
  final MaterialType type;
  final String? thumbnailUrl;
  final String? uploadedBy;
  final int views;
  final DateTime createdAt;

  const LearningMaterial({
    required this.materialId,
    required this.title,
    required this.subject,
    required this.level,
    required this.fileUrl,
    required this.type,
    required this.views,
    required this.createdAt,
    this.thumbnailUrl,
    this.uploadedBy,
  });

  LearningMaterial copyWith({int? views}) {
    return LearningMaterial(
      materialId: materialId,
      title: title,
      subject: subject,
      level: level,
      fileUrl: fileUrl,
      type: type,
      views: views ?? this.views,
      createdAt: createdAt,
      thumbnailUrl: thumbnailUrl,
      uploadedBy: uploadedBy,
    );
  }

  factory LearningMaterial.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return LearningMaterial(
      materialId: doc.id,
      title: ((data['title'] as String?)?.trim().isNotEmpty ?? false)
          ? (data['title'] as String).trim()
          : 'Untitled',
      subject: (data['subject'] as String?) ?? 'General',
      level: (data['level'] as String?) ?? 'O Level',
      fileUrl: (data['fileUrl'] as String?) ??
          (data['url'] as String?) ??
          '',
      type:
          MaterialTypeX.parse(data['type'] as String?) ?? MaterialType.note,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      uploadedBy: data['uploadedBy'] as String?,
      views: (data['views'] as num?)?.toInt() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['uploadedAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }

  // Matches the pastel sweep used by MaterialItem so the browse screen and
  // dashboard carousels render the same softer aesthetic.
  List<Color> get subjectGradient {
    final base = subjectColorFor(subject);
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
}
