import 'package:flutter/material.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';

const kSubjectColors = <String, Color>{
  'Mathematics': Color(0xFF3B82F6),
  'Physics': Color(0xFF8B5CF6),
  'Chemistry': Color(0xFF22C55E),
  'Biology': Color(0xFF14B8A6),
  'English': Color(0xFFEC4899),
  'ICT': Color(0xFF06B6D4),
  'Accounting': Color(0xFFF59E0B),
  'Economics': Color(0xFFEF4444),
  'History': Color(0xFFA855F7),
  'Geography': Color(0xFF10B981),
  'General': AppColors.kPrimary,
};

Color colorForSubject(String name) =>
    kSubjectColors[name] ?? AppColors.kPrimary;
