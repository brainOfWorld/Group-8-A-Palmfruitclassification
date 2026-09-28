import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../classifier/result_chart.dart';

class HistoryDetailScreen extends StatelessWidget {
  final Map<String, dynamic> record;

  const HistoryDetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final result = record['result'] as String? ?? "Unknown";
    final date = record['date'] as String? ?? "";
    final confidence = (record['confidence'] as double?) ?? 0.0;
    final rawScores = List<double>.from(record['rawScores'] as List? ?? []);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.containerBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "SCAN DETAILS",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultHeader(result, confidence),
            const SizedBox(height: 24),
            _buildInfoCard(date, result),
            const SizedBox(height: 24),
            if (rawScores.isNotEmpty) _buildChartSection(rawScores),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHeader(String result, double confidence) {
    Color resultColor;
    IconData resultIcon;
    String quality;

    if (result.contains("Ripe")) {
      resultColor = AppColors.activeGreen;
      resultIcon = Icons.check_circle_rounded;
      quality = "OPTIMAL QUALITY";
    } else if (result.contains("Unripe")) {
      resultColor = AppColors.harvestGold;
      resultIcon = Icons.schedule_rounded;
      quality = "NEEDS MORE TIME";
    } else if (result.contains("Damaged")) {
      resultColor = Colors.redAccent;
      resultIcon = Icons.warning_rounded;
      quality = "DAMAGED DETECTED";
    } else if (result.contains("Empty")) {
      resultColor = Colors.redAccent;
      resultIcon = Icons.block_rounded;
      quality = "NO FRUIT";
    } else if (result.contains("Overripe")) {
      resultColor = Colors.deepOrange;
      resultIcon = Icons.timer_rounded;
      quality = "PAST OPTIMAL";
    } else {
      resultColor = const Color(0xFF9E9E9E);
      resultIcon = Icons.help_outline_rounded;
      quality = "UNCERTAIN";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(resultIcon, size: 36, color: resultColor),
          ),
          const SizedBox(height: 16),
          Text(
            result,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: resultColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              quality,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: resultColor,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.neonOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "${(confidence * 100).toStringAsFixed(0)}% CONFIDENCE",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: AppColors.neonOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String date, String result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "SCAN INFORMATION",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 16),
          _infoRow(Icons.calendar_today_rounded, "DATE & TIME", date),
          const SizedBox(height: 12),
          _infoRow(Icons.eco_rounded, "CATEGORY",
              result.split(" ").first.toUpperCase()),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.neonOrange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.neonOrange),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: Color(0xFF9E9E9E),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChartSection(List<double> rawScores) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.containerBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart_rounded,
                      size: 16, color: Color(0xFF9E9E9E)),
                  SizedBox(width: 8),
                  Text(
                    "BAR CHART",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ResultChart(rawScores: rawScores),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.containerBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.pie_chart_rounded,
                      size: 16, color: Color(0xFF9E9E9E)),
                  SizedBox(width: 8),
                  Text(
                    "PIE CHART",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ResultChart(rawScores: rawScores, isPieChart: true),
            ],
          ),
        ),
      ],
    );
  }
}
