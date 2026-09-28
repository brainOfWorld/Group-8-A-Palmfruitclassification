import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';

class ResultChart extends StatelessWidget {
  final List<double> rawScores;
  final bool isPieChart;
  final List<String> labels = const ['Damaged', 'Empty', 'Negative', 'Overripe', 'Ripe', 'Unripe'];

  const ResultChart({
    super.key,
    required this.rawScores,
    this.isPieChart = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Confidence Breakdown",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Icon(
                isPieChart ? Icons.pie_chart_rounded : Icons.bar_chart_rounded,
                size: 18,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 24),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: isPieChart ? _buildPieView() : _buildBarView(),
          ),
        ],
      ),
    );
  }

  Widget _buildBarView() {
    return Row(
      key: const ValueKey('barView'),
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(labels.length, (index) {
        return _buildBar(
          labels[index],
          rawScores.length > index ? rawScores[index] : 0.0,
        );
      }),
    );
  }

  Widget _buildBar(String label, double score) {
    final Color barColor = _getColorForLabel(label);
    return Column(
      children: [
        Text(
          "${(score * 100).toStringAsFixed(0)}%",
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: barColor),
        ),
        const SizedBox(height: 6),
        Container(
          width: 28,
          height: 120 * score.clamp(0.08, 1.0),
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            boxShadow: [
              BoxShadow(
                color: barColor.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Transform.rotate(
          angle: -0.4,
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildPieView() {
    int topIndex = 0;
    double maxScore = 0;
    for (int i = 0; i < rawScores.length; i++) {
      if (rawScores[i] > maxScore) {
        maxScore = rawScores[i];
        topIndex = i;
      }
    }

    return Center(
      key: const ValueKey('pieView'),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: 180,
            width: 180,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: maxScore),
              duration: const Duration(seconds: 1),
              builder: (context, value, child) {
                return CustomPaint(
                  painter: PiePainter(
                    score: value,
                    color: _getColorForLabel(labels[topIndex]),
                  ),
                );
              },
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${(maxScore * 100).toStringAsFixed(0)}%",
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              ),
              Text(
                labels[topIndex].toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getColorForLabel(labels[topIndex]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getColorForLabel(String label) {
    switch (label) {
      case 'Ripe': return AppColors.primary;
      case 'Unripe': return Colors.orange;
      case 'Negative': return Colors.blueGrey;
      case 'Empty':
      case 'Damaged': return Colors.red;
      case 'Overripe': return Colors.amber;
      default: return Colors.blue;
    }
  }
}

class PiePainter extends CustomPainter {
  final double score;
  final Color color;

  PiePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = 22.0;

    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - (strokeWidth / 2), bgPaint);

    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2)),
      -math.pi / 2,
      2 * math.pi * score,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(PiePainter oldDelegate) =>
      oldDelegate.score != score || oldDelegate.color != color;
}
