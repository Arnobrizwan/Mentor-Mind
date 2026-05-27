import 'package:flutter/material.dart';

import 'package:mentor_minds/core/constants/app_colors.dart';

// ---------------------------------------------------------------------------
// MentorMindsLogo — the canonical brand mark (Option B).
//
// A bold "M" monogram whose right leg dissolves into a teal chat bubble
// containing three gold typing dots — a direct reference to MentorBot.
// Implemented as a CustomPainter so it scales crisply at any size without
// adding flutter_svg as a dependency, and so the colors swap between
// light/dark backgrounds with one parameter.
//
// Source-of-truth geometry mirrors assets/images/logo.svg (200×200 viewBox).
// ---------------------------------------------------------------------------

enum MentorMindsLogoMode {
  /// Indigo M for light backgrounds (login, profile, etc.).
  onLight,

  /// White M for dark/indigo backgrounds (splash, gradient hero).
  onDark,
}

class MentorMindsLogo extends StatelessWidget {
  const MentorMindsLogo({
    super.key,
    this.size = 64,
    this.mode = MentorMindsLogoMode.onLight,
  });

  final double size;
  final MentorMindsLogoMode mode;

  @override
  Widget build(BuildContext context) {
    final isLight = mode == MentorMindsLogoMode.onLight;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MentorMindsMarkPainter(
          mColor: isLight ? AppColors.kPrimary : Colors.white,
          bubbleColor: AppColors.kAccent,
          dotColor: AppColors.kGold,
        ),
      ),
    );
  }
}

class _MentorMindsMarkPainter extends CustomPainter {
  const _MentorMindsMarkPainter({
    required this.mColor,
    required this.bubbleColor,
    required this.dotColor,
  });

  final Color mColor;
  final Color bubbleColor;
  final Color dotColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Normalize from the 200×200 design viewport so all coordinates
    // below are exactly the SVG source values.
    final sx = size.width / 200;
    final sy = size.height / 200;
    double x(double v) => v * sx;
    double y(double v) => v * sy;

    // M strokes — right leg ends short (y=130) so the chat bubble can
    // take over visually at the lower right.
    final mPaint = Paint()
      ..color = mColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = x(18)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final mPath = Path()
      ..moveTo(x(30), y(165))
      ..lineTo(x(30), y(45))
      ..lineTo(x(100), y(115))
      ..lineTo(x(170), y(45))
      ..lineTo(x(170), y(130));
    canvas.drawPath(mPath, mPaint);

    // Chat bubble body — rounded rectangle at the lower right.
    final bubblePaint = Paint()..color = bubbleColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x(135), y(125), x(55), y(50)),
        Radius.circular(x(14)),
      ),
      bubblePaint,
    );

    // Chat bubble tail — small triangle pointing down-right.
    final tailPath = Path()
      ..moveTo(x(165), y(175))
      ..lineTo(x(160), y(192))
      ..lineTo(x(150), y(178))
      ..close();
    canvas.drawPath(tailPath, bubblePaint);

    // Three typing-indicator dots in gold, centered in the bubble.
    final dotPaint = Paint()..color = dotColor;
    canvas.drawCircle(Offset(x(148), y(150)), x(3.5), dotPaint);
    canvas.drawCircle(Offset(x(162), y(150)), x(3.5), dotPaint);
    canvas.drawCircle(Offset(x(176), y(150)), x(3.5), dotPaint);
  }

  @override
  bool shouldRepaint(_MentorMindsMarkPainter old) =>
      mColor != old.mColor ||
      bubbleColor != old.bubbleColor ||
      dotColor != old.dotColor;
}
