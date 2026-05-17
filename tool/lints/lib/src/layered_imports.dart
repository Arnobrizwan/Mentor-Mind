import 'package:analyzer/error/error.dart' show ErrorSeverity;
import 'package:analyzer/error/listener.dart';
import 'package:custom_lint_builder/custom_lint_builder.dart';

// Bans:
//   1. Firebase SDK imports inside lib/presentation/**
//   2. lib/data/** importing from lib/presentation/**
// Exempts lib/core/** and lib/application/**.
class LayeredImportsRule extends DartLintRule {
  const LayeredImportsRule() : super(code: _code);

  static const _code = LintCode(
    name: 'layered_imports',
    problemMessage:
        'Layered architecture violation: presentation must not import Firebase SDKs, and data must not import presentation.',
    correctionMessage:
        'Move the data access into a repository under lib/data/, or call through an application/viewmodel.',
    errorSeverity: ErrorSeverity.ERROR,
  );

  static const _bannedFirebasePrefixes = <String>[
    'package:cloud_firestore',
    'package:firebase_auth',
    'package:firebase_storage',
    'package:firebase_messaging',
  ];

  static const _bannedDataToPresentationPrefix =
      'package:mentor_minds/presentation/';

  @override
  void run(
    CustomLintResolver resolver,
    ErrorReporter reporter,
    CustomLintContext context,
  ) {
    final path = resolver.source.uri.path;
    final isPresentation = path.contains('/lib/presentation/');
    final isData = path.contains('/lib/data/');

    if (!isPresentation && !isData) return;

    context.registry.addImportDirective((node) {
      final uri = node.uri.stringValue;
      if (uri == null) return;

      if (isPresentation) {
        for (final prefix in _bannedFirebasePrefixes) {
          if (uri.startsWith(prefix)) {
            reporter.atNode(node, _code);
            return;
          }
        }
      }

      if (isData && uri.startsWith(_bannedDataToPresentationPrefix)) {
        reporter.atNode(node, _code);
      }
    });
  }
}
