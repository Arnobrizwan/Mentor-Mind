import 'package:flutter/material.dart' hide MaterialType;

import 'package:mentor_minds/data/models/learning_material.dart';

// ---------------------------------------------------------------------------
// MaterialSearchHit — a search result for a material. Constructed from a
// LearningMaterial via fromLearningMaterial; carries only display fields.
// ---------------------------------------------------------------------------

class MaterialSearchHit {
  final String id;
  final String title;
  final String subject;
  final String level;
  final MaterialType type;
  final DateTime createdAt;

  const MaterialSearchHit({
    required this.id,
    required this.title,
    required this.subject,
    required this.level,
    required this.type,
    required this.createdAt,
  });

  factory MaterialSearchHit.fromLearningMaterial(LearningMaterial m) {
    return MaterialSearchHit(
      id: m.materialId,
      title: m.title,
      subject: m.subject,
      level: m.level,
      type: m.type,
      createdAt: m.createdAt,
    );
  }

  Color get subjectColor => subjectColorFor(subject);
}
