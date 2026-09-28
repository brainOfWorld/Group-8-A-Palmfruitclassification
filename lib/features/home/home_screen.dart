import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/models/grading_record.dart';
import '../../core/state/grading_provider.dart';
import '../settings/settings_screen.dart';
import '../classifier/classifier_screen.dart';
import '../field_map/field_map_screen.dart';
import '../reports/inference_center_screen.dart';

// ────────────────────────────────────────────────
// Custom painters for chart visuals
// ────────────────────────────────────────────────

class _TrendSparkline extends CustomPainter {
  final List<double> data;
  _TrendSparkline(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    const c = AppColors.harvestGold;
    final path = Path();
    final dx = size.width / (data.length - 1);
    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      final y = size.height - (data[i] * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, Paint()
      ..color = c
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);
    canvas.drawPath(path, Paint()
      ..color = c.withValues(alpha: 0.15)
      ..strokeWidth = 6.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_TrendSparkline old) => old.data != data;
}

class _PriceTrendChart extends CustomPainter {
  final List<double> data;
  _PriceTrendChart(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    const c = AppColors.harvestGold;
    final h = size.height;
    final w = size.width;
    const minVal = 55.0;
    const maxVal = 105.0;
    final range = maxVal - minVal;

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF2A2A2A)
      ..strokeWidth = 0.5;
    for (int v = 60; v <= 100; v += 10) {
      final y = h - ((v - minVal) / range) * h;
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Line path
    final path = Path();
    final dx = w / (data.length - 1);
    for (int i = 0; i < data.length; i++) {
      final x = i * dx;
      final y = h - ((data[i] - minVal) / range) * h;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, Paint()
      ..color = c
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);
    canvas.drawPath(path, Paint()
      ..color = c.withValues(alpha: 0.12)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);

    // Filled area
    final fillPath = Path.from(path);
    fillPath.lineTo(w, h);
    fillPath.lineTo(0, h);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [c.withValues(alpha: 0.20), c.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h)));
  }

  @override
  bool shouldRepaint(_PriceTrendChart old) => old.data != data;
}

// ────────────────────────────────────────────────
// Dashboard Screen
// ────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Section C state
  double _confidenceThreshold = 10;
  bool _paramsExpanded = true;
  String _selectedCycle = "Major Cycle (Apr-Oct)";
  String _selectedConfidence = "Medium (70%)";

  @override
  Widget build(BuildContext context) {
    final records = context.watch<GradingProvider>().records;
    final total = records.length;

    // Compute live stats from records
    final ripe = records.where((e) => e.gradeResult.startsWith("Ripe")).length;
    final unripe = records.where((e) => e.gradeResult.startsWith("Unripe")).length;
    final other = total - ripe - unripe;
    final ripePct = total > 0 ? (ripe / total * 100) : 0.0;
    final unripePct = total > 0 ? (unripe / total * 100) : 0.0;
    final otherPct = total > 0 ? (other / total * 100) : 0.0;

    // Sparkline data from actual confidence scores (last 20)
    final trendData = total > 0
        ? records.take(20).map((r) => r.confidenceScore).toList().reversed.toList()
        : [0.5];
    // Price trend data mapped from confidence scores (last 30, scaled to 55-105)
    final priceData = total > 0
        ? records.take(30).map((r) => 55.0 + r.confidenceScore * 50).toList().reversed.toList()
        : [65.0];

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    _buildAppBar(),
                    _buildSeasonOverview(total, ripePct, unripePct, otherPct, trendData),
                    _buildGradingParameters(),
                    _buildRecentScans(),
                    _buildFinancialDashboard(ripe, priceData),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ───── SECTION A: APP BAR ─────

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.activeGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.eco_rounded, color: AppColors.activeGreen, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "PALMFRUIT GRADER",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Colors.white,
              ),
            ),
          ),
          Stack(
            children: [
              const Icon(Icons.notifications, color: Colors.white70, size: 24),
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───── SECTION B: SEASON OVERVIEW ─────

  Widget _buildSeasonOverview(
      int total, double ripePct, double unripePct, double otherPct, List<double> trendData) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Header row
          Row(
            children: [
              const Text(
                "SEASON OVERVIEW",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0xFF9E9E9E),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.activeGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.activeGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "REAL-TIME DATA",
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.activeGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Two-column layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Metrics
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _overviewMetric("TOTAL FRUIT GRADED", "\n$total Bunches",
                        Colors.white, 18),
                    const SizedBox(height: 14),
                    _overviewMetric("HIGH QUALITY (RIPE)",
                        "${ripePct.toStringAsFixed(0)}%",
                        AppColors.harvestGold, 14),
                    const SizedBox(height: 10),
                    _overviewMetric("MED QUALITY (UNRIPE)",
                        "${unripePct.toStringAsFixed(0)}%",
                        const Color(0xFFBDBDBD), 14),
                    const SizedBox(height: 10),
                    _overviewMetric("LOW QUALITY",
                        "${otherPct.toStringAsFixed(0)}%",
                        const Color(0xFF9E9E9E), 14),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Column 2: Sparkline
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "CONFIDENCE TREND",
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: CustomPaint(
                        size: const Size(double.infinity, 100),
                        painter: _TrendSparkline(trendData),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewMetric(
      String label, String value, Color valueColor, double valueSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Color(0xFF9E9E9E),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: valueSize,
            fontWeight: FontWeight.w800,
            color: valueColor,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  // ───── SECTION C: GRADING PARAMETERS ─────

  Widget _buildGradingParameters() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with chevron
          InkWell(
            onTap: () => setState(() => _paramsExpanded = !_paramsExpanded),
            child: Row(
              children: [
                const Text(
                  "GRADING PARAMETERS",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
                const Spacer(),
                Icon(
                  _paramsExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: const Color(0xFF9E9E9E),
                  size: 20,
                ),
              ],
            ),
          ),
          if (_paramsExpanded) ...[
            const SizedBox(height: 20),
            // Slider
            const Text(
              "Adjust Confidence Threshold",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppColors.neonOrange,
                      inactiveTrackColor: AppColors.neonOrange.withValues(alpha: 0.15),
                      thumbColor: Colors.white,
                      overlayColor: AppColors.neonOrange.withValues(alpha: 0.12),
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                    ),
                    child: Slider(
                      value: _confidenceThreshold,
                      min: 0,
                      max: 100,
                      divisions: 20,
                      onChanged: (v) =>
                          setState(() => _confidenceThreshold = v),
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.neonOrange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${_confidenceThreshold.toInt()}%",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.neonOrange,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Dropdown 1
            _dropdownTile("Select Crop Cycles", _selectedCycle,
                ["Major Cycle (Apr-Oct)", "Minor Cycle (Nov-Mar)", "Dry Season"], (v) {
              setState(() => _selectedCycle = v);
            }),
            const SizedBox(height: 12),
            // Dropdown 2
            _dropdownTile("Select Confidence Threshold", _selectedConfidence,
                ["Low (50%)", "Medium (70%)", "High (85%)", "Very High (95%)"],
                (v) {
              setState(() => _selectedConfidence = v);
            }),
          ],
        ],
      ),
    );
  }

  Widget _dropdownTile(
      String label, String value, List<String> items, ValueChanged<String> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
                const SizedBox(height: 2),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF1A1A1A),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70, size: 20),
                    items: items.map((e) {
                      return DropdownMenuItem<String>(
                        value: e,
                        child: Text(e),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) onChanged(v);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───── SECTION D: RECENT SCANS ─────

  Widget _buildRecentScans() {
    final records = context.watch<GradingProvider>().records;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              "RECENT SCANS",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            height: 130,
            child: records.isEmpty
                ? Center(
                    child: Text(
                      "No scans recorded yet",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 13,
                      ),
                    ),
                  )
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(right: 8),
                    itemCount: records.length,
                    itemBuilder: (context, i) => _buildScanCard(records[i]),
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => FieldMapScreen(cameras: widget.cameras)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.harvestGold,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                "VIEW MAP LOGGS",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanCard(GradingRecord record) {
    final thumb = record.imagePath.isNotEmpty
        ? Image.file(
            File(record.imagePath),
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(Icons.agriculture_rounded,
                color: Color(0xFF555555), size: 28),
          )
        : const Icon(Icons.agriculture_rounded,
            color: Color(0xFF555555), size: 28);

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: Center(child: thumb),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.activeGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: AppColors.activeGreen, size: 10),
                      SizedBox(width: 3),
                      Text(
                        "SYNCED",
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w700,
                          color: AppColors.activeGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "${record.timestamp.year}-${record.timestamp.month.toString().padLeft(2, '0')}-${record.timestamp.day.toString().padLeft(2, '0')}",
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF757575),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  record.gradeResult,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.harvestGold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  "Color Profile: ${(record.metrics['colorProfile'] ?? 0).toStringAsFixed(0)}%",
                  style: const TextStyle(fontSize: 9, color: Color(0xFF9E9E9E)),
                ),
                Text(
                  "Texture Density: ${(record.metrics['textureDensity'] ?? 0).toStringAsFixed(0)}%",
                  style: const TextStyle(fontSize: 9, color: Color(0xFF9E9E9E)),
                ),
                Text(
                  "Est. Oil Content: ${(record.metrics['oilContent'] ?? 0).toStringAsFixed(1)}/5",
                  style: const TextStyle(fontSize: 9, color: Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───── SECTION E: FINANCIAL DASHBOARD ─────

  Widget _buildFinancialDashboard(int ripeCount, List<double> priceData) {
    const marketPrice = 65;
    final estValue = ripeCount * marketPrice;
    final valueStr = estValue >= 1000
        ? "GH\u00a2 ${(estValue / 1000).toStringAsFixed(1)}K"
        : "GH\u00a2 $estValue";

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "FINANCIAL DASHBOARD",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 18),
          // Two-column currency display
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "EST. HARVEST VALUE:",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        valueStr,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "LOCAL MARKET",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "GH\u00a2 65 / BUNCH",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$ripeCount ripe bunch${ripeCount == 1 ? '' : 'es'}",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.harvestGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            "CONFIDENCE TREND (LAST 30 SCANS)",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: CustomPaint(
              size: const Size(double.infinity, 140),
              painter: _PriceTrendChart(priceData),
            ),
          ),
        ],
      ),
    );
  }

  // ───── SECTION F: BOTTOM NAV ─────

  Widget _buildBottomNav() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.qr_code_scanner, "SCANNER", false,
              ClassifierScreen(cameras: widget.cameras)),
          _navItem(Icons.dashboard_customize_outlined, "DASHBOARD", true, null),
          _navItem(Icons.map_outlined, "FIELD MAP", false,
              FieldMapScreen(cameras: widget.cameras)),
          _navItem(Icons.settings_outlined, "SETTINGS", false,
              SettingsScreen(cameras: widget.cameras)),
          _navItem(Icons.analytics_outlined, "INFERENCE", false,
              InferenceCenterScreen(cameras: widget.cameras)),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, Widget? screen) {
    final color = active ? AppColors.harvestGold : const Color(0xFF757575);
    return GestureDetector(
      onTap: () {
        if (!active && screen != null) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => screen));
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (active)
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 18,
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.harvestGold,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
        ],
      ),
    );
  }
}
