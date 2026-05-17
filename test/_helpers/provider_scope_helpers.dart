import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// provider_scope_helpers.dart — Shared test helpers for wiring ProviderScope
// overrides in widget tests and unit tests.
//
// pumpWithProviders — wraps a widget in ProviderScope + optional MaterialApp
// and calls pumpWidget + pumpAndSettle. Use for widget tests.
//
// makeContainer — creates a ProviderContainer with overrides and registers
// disposal as a tearDown. Use for pure logic tests that don't need a widget
// tree (Anchor 3 style — ProviderContainer.read the viewmodel notifier).
// ---------------------------------------------------------------------------

/// Pumps [child] inside a [ProviderScope] with [overrides] applied.
/// Wraps in [MaterialApp] when [wrapInMaterialApp] is true (default).
/// Calls [tester.pumpAndSettle] after pumping — skip for screens that have
/// perpetual animations (shimmer, timers) — call [tester.pump()] directly
/// in those cases instead of this helper.
Future<void> pumpWithProviders(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const [],
  bool wrapInMaterialApp = true,
}) async {
  final widget =
      wrapInMaterialApp ? MaterialApp(home: child) : child;
  await tester.pumpWidget(
    ProviderScope(overrides: overrides, child: widget),
  );
  await tester.pumpAndSettle();
}

/// Creates a [ProviderContainer] with [overrides] and registers
/// [container.dispose] as a tearDown so tests cannot leak providers.
ProviderContainer makeContainer({List<Override> overrides = const []}) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}
