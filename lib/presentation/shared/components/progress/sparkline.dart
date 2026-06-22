import 'package:flutter/material.dart';

class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.data,
    this.strokeWidth = 2.0,
    this.color,
    this.height = 40,
    this.semanticLabel,
  });

  final List<double> data;
  final double strokeWidth;
  final Color? color;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    return Semantics(
      label: semanticLabel ?? 'Sparkline chart',
      child: SizedBox(
        height: height,
        child: CustomPaint(
          size: Size(double.infinity, height),
          painter: _SparklinePainter(
            data: data,
            strokeWidth: strokeWidth,
            color: effectiveColor,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.data,
    required this.strokeWidth,
    required this.color,
  });

  final List<double> data;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withAlpha(25), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final minY = data.reduce((a, b) => a < b ? a : b);
    final maxY = data.reduce((a, b) => a > b ? a : b);
    final range = maxY - minY;

    if (range == 0) return;

    final stepX = size.width / (data.length - 1);

    final path = Path();
    final fillPath = Path();

    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - minY) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo((data.length - 1) * stepX, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.data.length != data.length ||
      oldDelegate.data != data ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
