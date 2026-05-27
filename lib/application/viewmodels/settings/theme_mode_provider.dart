import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// User-facing theme mode override.
//
// MaterialApp.router reads from this provider for `themeMode`. The user can
// pick:
//   • system → follow iOS Display & Brightness (the default)
//   • light  → force the light palette
//   • dark   → force the dark palette
//
// Persisted to SharedPreferences under key `theme_mode` so the choice
// survives app restarts. Until the load completes the provider serves
// ThemeMode.system, which is also the safe fallback.
// ---------------------------------------------------------------------------

const _kPrefsKey = 'theme_mode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw == null) return;
      state = switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // SharedPreferences can fail on first launch / cold simulator runs.
      // Falling through means we keep the constructor default (system),
      // which is what the user expects anyway.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, _encode(mode));
    } catch (_) {
      // Non-fatal — the in-memory state still flips immediately.
    }
  }

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);

/// Convenience helper: human-readable label for the current mode.
String themeModeLabel(ThemeMode mode) => switch (mode) {
      ThemeMode.system => 'Follows system',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
