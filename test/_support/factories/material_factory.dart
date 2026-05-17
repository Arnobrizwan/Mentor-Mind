import 'package:flutter/material.dart' hide MaterialType;
import 'package:mentor_minds/data/models/learning_material.dart';
import 'package:mentor_minds/data/models/material_item.dart';

// ---------------------------------------------------------------------------
// material_factory.dart — Test data builders for MaterialItem and LearningMaterial.
// MaterialItem is the lightweight dashboard projection; LearningMaterial is the
// full materials-browse projection. Both target the same /materials collection.
// ---------------------------------------------------------------------------

MaterialItem buildMaterialItem({
  String id = 'mat-1',
  String title = 'Test Material',
  String level = 'O Level',
  String subject = 'Mathematics',
  // Brand palette gradient (kPrimary → kAccent) as default.
  List<Color> gradient = const [Color(0xFF1A3C8F), Color(0xFF00C9A7)],
}) {
  return MaterialItem(
    id: id,
    title: title,
    level: level,
    subject: subject,
    gradient: gradient,
  );
}

LearningMaterial buildLearningMaterial({
  String materialId = 'lmat-1',
  String title = 'Test Learning Material',
  String subject = 'Mathematics',
  String level = 'O Level',
  String fileUrl = 'https://example.com/test.pdf',
  MaterialType type = MaterialType.pdf,
  String? thumbnailUrl,
  String? uploadedBy,
  int views = 0,
  DateTime? createdAt,
}) {
  return LearningMaterial(
    materialId: materialId,
    title: title,
    subject: subject,
    level: level,
    fileUrl: fileUrl,
    type: type,
    thumbnailUrl: thumbnailUrl,
    uploadedBy: uploadedBy,
    views: views,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}
