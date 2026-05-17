import 'package:flutter/material.dart';

import 'package:mentor_minds/data/models/learning_material.dart';

// ---------------------------------------------------------------------------
// SessionSearchHit — a search result for a tutoring session. Decoded from
// /sessions; carries the preview text and message count for display.
// ---------------------------------------------------------------------------

class SessionSearchHit {
  final String id;
  final String subject;
  final String preview;
  final int messageCount;
  final DateTime updatedAt;

  const SessionSearchHit({
    required this.id,
    required this.subject,
    required this.preview,
    required this.messageCount,
    required this.updatedAt,
  });

  Color get subjectColor => subjectColorFor(subject);
}
