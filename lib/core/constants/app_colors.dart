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
  // Thesis "MentorMinds" green palette (sampled from the reference design):
  //   header/banner green  #71AFA8   button/action green  #66A39B
  //   deep green           #3E7D74   accent orange        #D98D50
  // Primary is the interactive green (buttons, focus borders, primary text);
  // the header banners read a touch lighter but share the same hue family.
  static const Color kPrimary    = Color(0xFF66A39B);
  static const Color kAccent     = Color(0xFF4E8F86);
  static const Color kGold       = Color(0xFFD98D50);
  static const Color kBackground = Color(0xFFF4F6F7);
  static const Color kSurface    = Color(0xFFFFFFFF);
  static const Color kTextDark   = Color(0xFF1C2A28);
  static const Color kTextMuted  = Color(0xFF6B7A78);
  static const Color kError      = Color(0xFFEF4444);

  static const Color kSplashTop    = Color(0xFF71AFA8);
  static const Color kSplashBottom = Color(0xFF3E7D74);

  // -- Light surface accents -------------------------------------------------
  static const Color kBorder       = Color(0xFFE3E9E8);
  static const Color kSurfaceAlt   = Color(0xFFF6F9F8);

  // -- Dark variants (redesign) ----------------------------------------------
  // Approach: shift the sage green brighter (more visible on dark), lift the
  // orange accent, and use a near-black canvas.
  static const Color kDarkPrimary    = Color(0xFF7FC0B7);
  static const Color kDarkAccent     = Color(0xFF62A89E);
  static const Color kDarkGold       = Color(0xFFE8A66A);
  static const Color kDarkBackground = Color(0xFF0F1513);
  static const Color kDarkSurface    = Color(0xFF18211F);
  static const Color kDarkSurfaceAlt = Color(0xFF212C29);
  static const Color kDarkBorder     = Color(0xFF2C3936);
  static const Color kDarkTextDark   = Color(0xFFF1F4F3);
  static const Color kDarkTextMuted  = Color(0xFF9CADAA);
  static const Color kDarkError      = Color(0xFFFF6B6B);
}
