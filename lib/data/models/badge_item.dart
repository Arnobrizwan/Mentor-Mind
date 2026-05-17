import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// BadgeItem — display model for dashboard badge chips.
// Computed in DashboardViewModel._mapBadge; not decoded directly from Firestore.
// ---------------------------------------------------------------------------

class BadgeItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  const BadgeItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}
