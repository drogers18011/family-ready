import 'dart:math' as math;
import 'dart:ui' as ui show PointMode;

import 'package:material_ui/material_ui.dart';

/// Static cloth-like texture behind the page, never over its controls.
/// Place around the viewport, outside its scrolling content.
class FieldBackdrop extends StatelessWidget {
  const FieldBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _FieldBackdropPainter(
                    base: theme.scaffoldBackgroundColor,
                    ink: theme.colorScheme.onSurface,
                    light: theme.brightness == Brightness.light,
                  ),
                  isComplex: true,
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// A matte equipment panel. Its grain and hardware stay behind the content;
/// its measured height follows the child, including enlarged text.
class FieldPanel extends StatelessWidget {
  const FieldPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
    this.prominent = false,
    this.accent,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final bool prominent;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      width: double.infinity,
      margin: margin,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _FieldPanelPainter(
                      base: prominent
                          ? colors.surfaceContainerHigh
                          : colors.surfaceContainerLow,
                      edge: colors.outline,
                      ink: colors.onSurface,
                      accent: accent ?? colors.primary,
                      prominent: prominent,
                      light: theme.brightness == Brightness.light,
                    ),
                    isComplex: true,
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class FieldSectionHeading extends StatelessWidget {
  const FieldSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Semantics(
          header: true,
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.headlineLarge,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 14),
        ExcludeSemantics(
          child: Row(
            children: [
              Container(width: 42, height: 3, color: colors.primary),
              Expanded(
                child: Container(height: 1, color: colors.outlineVariant),
              ),
              const SizedBox(width: 5),
              Container(width: 6, height: 3, color: colors.outline),
            ],
          ),
        ),
      ],
    );
  }
}

Path _chamferedPath(Rect bounds, double corner) {
  final cut = math.min(corner, math.min(bounds.width, bounds.height) / 4);
  return Path()
    ..moveTo(bounds.left + cut, bounds.top)
    ..lineTo(bounds.right - cut, bounds.top)
    ..lineTo(bounds.right, bounds.top + cut)
    ..lineTo(bounds.right, bounds.bottom - cut)
    ..lineTo(bounds.right - cut, bounds.bottom)
    ..lineTo(bounds.left + cut, bounds.bottom)
    ..lineTo(bounds.left, bounds.bottom - cut)
    ..lineTo(bounds.left, bounds.top + cut)
    ..close();
}

class _FieldBackdropPainter extends CustomPainter {
  const _FieldBackdropPainter({
    required this.base,
    required this.ink,
    required this.light,
  });

  final Color base;
  final Color ink;
  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    // Two batched paths form the ripstop weave. Spacing expands on very large
    // surfaces, keeping each direction below 181 lines even on a big monitor.
    final spacing = math.max(12.0, math.max(size.width, size.height) / 180);
    final weave = Path();
    final seam = Path();
    for (double x = 0; x < size.width; x += spacing) {
      weave.moveTo(x, 0);
      weave.lineTo(x, size.height);
    }
    for (double y = 0; y < size.height; y += spacing) {
      weave.moveTo(0, y);
      weave.lineTo(size.width, y);
    }
    for (double x = spacing * 3; x < size.width; x += spacing * 6) {
      seam.moveTo(x, 0);
      seam.lineTo(x, size.height);
    }
    for (double y = spacing * 3; y < size.height; y += spacing * 6) {
      seam.moveTo(0, y);
      seam.lineTo(size.width, y);
    }
    canvas.drawPath(
      weave,
      Paint()
        ..color = ink.withValues(alpha: light ? 0.045 : 0.025)
        ..strokeWidth = 0.6
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      seam,
      Paint()
        ..color = ink.withValues(alpha: light ? 0.055 : 0.035)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
    final grain = <Offset>[];
    for (var i = 0; i < 720; i++) {
      grain.add(
        Offset(
          ((i * 73 + 19) % 997) / 997 * size.width,
          ((i * 191 + 31) % 991) / 991 * size.height,
        ),
      );
    }
    canvas.drawPoints(
      ui.PointMode.points,
      grain,
      Paint()
        ..color = ink.withValues(alpha: light ? 0.10 : 0.07)
        ..strokeWidth = 0.7,
    );
  }

  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_FieldBackdropPainter oldDelegate) =>
      base != oldDelegate.base ||
      ink != oldDelegate.ink ||
      light != oldDelegate.light;
}

class _FieldPanelPainter extends CustomPainter {
  const _FieldPanelPainter({
    required this.base,
    required this.edge,
    required this.ink,
    required this.accent,
    required this.prominent,
    required this.light,
  });

  final Color base;
  final Color edge;
  final Color ink;
  final Color accent;
  final bool prominent;
  final bool light;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 24 || size.height < 24) return;
    final bounds = (Offset.zero & size).deflate(0.75);
    final corner = prominent ? 14.0 : 10.0;
    final shape = _chamferedPath(bounds, corner);
    canvas.drawPath(shape, Paint()..color = base);
    canvas.save();
    canvas.clipPath(shape);

    // A fixed, small grain field; no bitmap, timer, animation, or noise seed.
    final grain = <Offset>[];
    for (var i = 0; i < 160; i++) {
      grain.add(
        Offset(
          ((i * 79 + 7) % 383) / 383 * size.width,
          ((i * 137 + 23) % 379) / 379 * size.height,
        ),
      );
    }
    canvas.drawPoints(
      ui.PointMode.points,
      grain,
      Paint()
        ..color = ink.withValues(alpha: light ? 0.045 : 0.035)
        ..strokeWidth = 0.7,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 1, size.width, 3),
      Paint()..color = Colors.white.withValues(alpha: light ? 0.55 : 0.07),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - 4, size.width, 4),
      Paint()..color = Colors.black.withValues(alpha: light ? 0.10 : 0.32),
    );
    canvas.restore();
    canvas.drawPath(
      shape,
      Paint()
        ..color = edge.withValues(alpha: prominent ? 0.95 : 0.72)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      _chamferedPath(bounds.deflate(3), math.max(4.0, corner - 3)),
      Paint()
        ..color = ink.withValues(alpha: light ? 0.07 : 0.06)
        ..strokeWidth = 0.7
        ..style = PaintingStyle.stroke,
    );

    // Edge brackets and small recessed fasteners sit inside the 16+ px content
    // inset. They are decoration only and never imply a status or affordance.
    final brackets = Path()
      ..moveTo(1, 29)
      ..lineTo(1, corner + 1)
      ..lineTo(corner + 1, 1)
      ..lineTo(29, 1)
      ..moveTo(size.width - 29, size.height - 1)
      ..lineTo(size.width - corner - 1, size.height - 1)
      ..lineTo(size.width - 1, size.height - corner - 1)
      ..lineTo(size.width - 1, size.height - 29);
    canvas.drawPath(
      brackets,
      Paint()
        ..color = accent.withValues(alpha: prominent ? 0.90 : 0.44)
        ..strokeWidth = prominent ? 2.2 : 1.4
        ..style = PaintingStyle.stroke,
    );
    for (final point in [
      const Offset(10, 10),
      Offset(size.width - 10, 10),
      Offset(10, size.height - 10),
      Offset(size.width - 10, size.height - 10),
    ]) {
      canvas.drawCircle(
        point,
        2.4,
        Paint()..color = edge.withValues(alpha: 0.40),
      );
      canvas.drawLine(
        point.translate(-1.2, 0),
        point.translate(1.2, 0),
        Paint()
          ..color = base
          ..strokeWidth = 0.9,
      );
    }
  }

  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_FieldPanelPainter oldDelegate) =>
      base != oldDelegate.base ||
      edge != oldDelegate.edge ||
      ink != oldDelegate.ink ||
      accent != oldDelegate.accent ||
      prominent != oldDelegate.prominent ||
      light != oldDelegate.light;
}
