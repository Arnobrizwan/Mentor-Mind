import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// AppColors — palette anchors.
// The k-prefixed light tokens are the historical brand constants used in
// 400+ call sites. The Dark.* group adds dark-mode variants for the
// redesign. New code should prefer `Theme.of(context).extension<BrandColors>()`
// over the raw constants so brightness switching works automatically.
// ---------------------------------------------------------------------------

abstract final class AppColors {
  // -- Light (brand canonical) -----------------------------------------------
  static const Color kPrimary    = Color(0xFF1A3C8F);
  static const Color kAccent     = Color(0xFF00C9A7);
  static const Color kGold       = Color(0xFFF5A623);
  static const Color kBackground = Color(0xFFF4F6FB);
  static const Color kSurface    = Color(0xFFFFFFFF);
  static const Color kTextDark   = Color(0xFF1C1F2E);
  static const Color kTextMuted  = Color(0xFF6B7280);
  static const Color kError      = Color(0xFFEF4444);

  static const Color kSplashTop    = Color(0xFF1A3C8F);
  static const Color kSplashBottom = Color(0xFF0D2660);

  // -- Light surface accents -------------------------------------------------
  static const Color kBorder       = Color(0xFFE5E7EB);
  static const Color kSurfaceAlt   = Color(0xFFF9FAFC);

  // -- Dark variants (redesign) ----------------------------------------------
  // Approach: shift indigo brighter (more visible on dark), keep accent/gold
  // identical (they pop in both modes), and use a near-black canvas.
  static const Color kDarkPrimary    = Color(0xFF5A82E0);
  static const Color kDarkAccent     = Color(0xFF26D9B9);
  static const Color kDarkGold       = Color(0xFFFFB94A);
  static const Color kDarkBackground = Color(0xFF0F1117);
  static const Color kDarkSurface    = Color(0xFF1A1D26);
  static const Color kDarkSurfaceAlt = Color(0xFF222633);
  static const Color kDarkBorder     = Color(0xFF2D3142);
  static const Color kDarkTextDark   = Color(0xFFF1F2F6);
  static const Color kDarkTextMuted  = Color(0xFF9CA3AF);
  static const Color kDarkError      = Color(0xFFFF6B6B);
}
