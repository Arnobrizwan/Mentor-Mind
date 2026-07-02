import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;

import '../../core/theme/app_spacing.dart';

// ---------------------------------------------------------------------------
// MathMarkdownBody — MarkdownBody with LaTeX rendering (flutter_math_fork).
//
// The AI tutor emits mark-scheme answers that mix Markdown with LaTeX:
//   inline  $x^2$  or  \( x^2 \)
//   display $$\frac{a}{b}$$  or  \[ \frac{a}{b} \]
// Unparseable TeX falls back to the raw source text so an odd expression
// never blanks a message.
// ---------------------------------------------------------------------------

class MathMarkdownBody extends StatelessWidget {
  final String data;
  final bool selectable;
  final MarkdownStyleSheet? styleSheet;

  const MathMarkdownBody({
    super.key,
    required this.data,
    this.selectable = false,
    this.styleSheet,
  });

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: data,
      selectable: selectable,
      styleSheet: styleSheet,
      builders: {'math': _MathElementBuilder()},
      // Display syntax is registered first so `$$…$$` wins over `$…$`.
      inlineSyntaxes: [_DisplayMathSyntax(), _InlineMathSyntax()],
    );
  }
}

class _InlineMathSyntax extends md.InlineSyntax {
  _InlineMathSyntax() : super(r'\$([^$\n]+?)\$|\\\((.+?)\\\)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = match[1] ?? match[2] ?? '';
    final element = md.Element.text('math', tex);
    element.attributes['display'] = 'false';
    parser.addNode(element);
    return true;
  }
}

class _DisplayMathSyntax extends md.InlineSyntax {
  _DisplayMathSyntax() : super(r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = (match[1] ?? match[2] ?? '').trim();
    final element = md.Element.text('math', tex);
    element.attributes['display'] = 'true';
    parser.addNode(element);
    return true;
  }
}

class _MathElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final tex = element.textContent;
    final display = element.attributes['display'] == 'true';

    final math = Math.tex(
      tex,
      mathStyle: display ? MathStyle.display : MathStyle.text,
      textStyle: preferredStyle,
      onErrorFallback: (_) => Text(
        display ? '\$\$$tex\$\$' : '\$$tex\$',
        style: preferredStyle,
      ),
    );

    if (!display) return math;

    // Display math gets breathing room and horizontal scroll for wide
    // expressions on narrow phones.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: math,
        ),
      ),
    );
  }
}
