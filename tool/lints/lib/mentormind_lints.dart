import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/layered_imports.dart';

PluginBase createPlugin() => _MentorMindLints();

class _MentorMindLints extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) =>
      [const LayeredImportsRule()];
}
