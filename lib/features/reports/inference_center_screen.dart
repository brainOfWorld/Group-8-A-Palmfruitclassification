import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/models/grading_record.dart';
import '../../core/state/grading_provider.dart';
import '../settings/settings_screen.dart';
import '../classifier/classifier_screen.dart';
import '../home/home_screen.dart';
import '../field_map/field_map_screen.dart';

// ═════════════════════════════════════════════
// Main screen
// ═════════════════════════════════════════════

class InferenceCenterScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const InferenceCenterScreen({super.key, required this.cameras});

  @override
  State<InferenceCenterScreen> createState() => _InferenceCenterScreenState();
}

class _InferenceCenterScreenState extends State<InferenceCenterScreen> {
  String _activeFilter = "ALL";

  List<GradingRecord> _filtered(List<GradingRecord> all) {
    if (_activeFilter == "ALL") return all;
    final source = _activeFilter == "DRONE" ? ScanSource.drone : ScanSource.live;
    return all.where((e) => e.source == source).toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<GradingProvider>().records;
    final filtered = _filtered(all);
    final droneCount = all.where((e) => e.source == ScanSource.drone).length;
    final liveCount = all.where((e) => e.source == ScanSource.live).length;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildHeader(),
                    _buildFilterTabs(),
                    _buildSummaryLabel(all.length, droneCount, liveCount),
                    _buildImageGrid(filtered),
                    _buildAggregateStats(all),
                  ],
                ),
              ),
            ),
            _buildReportButton(all),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ───

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      color: AppColors.scaffoldBg,
      child: const Column(
        children: [
          Text(
            "INFERENCE CENTER",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2),
          Text(
            "(Source: Drone & Live)",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  // ─── FILTER TOGGLES ───

  Widget _buildFilterTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.containerBg,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: ["ALL", "DRONE", "LIVE"].map((tab) {
            final active = _activeFilter == tab;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _activeFilter = tab),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? AppColors.harvestGold.withValues(alpha: 0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: active
                        ? Border.all(color: AppColors.harvestGold, width: 1)
                        : null,
                  ),
                  child: Text(
                    "[$tab]",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: active ? AppColors.harvestGold : const Color(0xFF757575),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryLabel(int total, int drone, int live) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        "Collection: $total Scans ($drone Drone, $live Live)",
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Color(0xFF757575),
        ),
      ),
    );
  }

  // ─── IMAGE GRID ───

  Widget _buildImageGrid(List<GradingRecord> items) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Center(
          child: Text(
            "No scans yet — capture a fruit or pick from gallery",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 13,
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) => _buildGridItem(items[i]),
      ),
    );
  }

  Widget _buildGridItem(GradingRecord entry) {
    final cat = entry.gradeResult.split(" ").first;
    final Color baseColor;
    final String dotLabel;
    if (cat == "Ripe") {
      baseColor = AppColors.activeGreen;
      dotLabel = "RIPE";
    } else if (cat == "Unripe") {
      baseColor = AppColors.harvestGold;
      dotLabel = "UNRIPE";
    } else if (cat == "Overripe") {
      baseColor = AppColors.neonOrange;
      dotLabel = "OVERRIPE";
    } else if (cat == "Damaged") {
      baseColor = Colors.redAccent;
      dotLabel = "DAMAGED";
    } else {
      baseColor = const Color(0xFF757575);
      dotLabel = entry.gradeResult.length > 8
          ? "${entry.gradeResult.substring(0, 8)}…"
          : entry.gradeResult;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (entry.imagePath.isNotEmpty)
            Image.file(
              File(entry.imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildPlaceholderIcon(baseColor),
            )
          else
            _buildPlaceholderIcon(baseColor),
          // Overlay HUD: status dot
          Positioned(
            left: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: baseColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    dotLabel,
                    style: TextStyle(
                      fontSize: 6,
                      fontWeight: FontWeight.w700,
                      color: baseColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Overlay HUD: index
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "#${entry.id.substring(0, 4)}",
                style: const TextStyle(
                  fontSize: 5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFBDBDBD),
                ),
              ),
            ),
          ),
          // Bottom timestamp
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Text(
                "${entry.timestamp.hour.toString().padLeft(2, '0')}:${entry.timestamp.minute.toString().padLeft(2, '0')}",
                style: const TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFBDBDBD),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderIcon(Color color) {
    return Center(
      child: Icon(
        Icons.agriculture_rounded,
        color: color.withValues(alpha: 0.25),
        size: 28,
      ),
    );
  }

  // ─── AGGREGATE STATS ───

  Widget _buildAggregateStats(List<GradingRecord> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    final total = items.length;
    final avgConf =
        items.fold<double>(0, (s, e) => s + e.confidenceScore) / total;
    final ripe = items.where((e) => e.gradeResult.startsWith("Ripe")).length;
    final unripe = items.where((e) => e.gradeResult.startsWith("Unripe")).length;
    final damaged =
        items.where((e) => e.gradeResult.startsWith("Damaged")).length;
    final avgColor = items.fold<double>(
            0, (s, e) => s + (e.metrics['colorProfile'] ?? 0)) /
        total;
    final avgTexture = items.fold<double>(
            0, (s, e) => s + (e.metrics['textureDensity'] ?? 0)) /
        total;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "COLLECTION DATA SUMMARY (AGGREGATE STATS)",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 18),
          _statRow("Total Scans", "$total"),
          _statRow("Average Confidence",
              "${(avgConf * 100).toStringAsFixed(0)}%"),
          _statRow("Ripe Distribution",
              "${(ripe / total * 100).toStringAsFixed(0)}%"),
          _statRow("Unripe Distribution",
              "${(unripe / total * 100).toStringAsFixed(0)}%"),
          _statRow("Damaged Distribution",
              "${(damaged / total * 100).toStringAsFixed(0)}%"),
          _statRow("Average Texture Density",
              "${avgTexture.toStringAsFixed(0)}%"),
          _statRow("Average Color Profile",
              "${avgColor.toStringAsFixed(0)}%"),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFFBDBDBD),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.harvestGold,
            ),
          ),
        ],
      ),
    );
  }

  // ─── REPORT BUTTON ───

  Widget _buildReportButton(List<GradingRecord> all) {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AnalyticalReportPage(records: all),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.neonOrange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          child: const Text(
            "GENERATE ANALYTICAL REPORT",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  // ─── BOTTOM NAV ───

  Widget _buildBottomNav() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.qr_code_scanner, "SCANNER", false,
              ClassifierScreen(cameras: widget.cameras)),
          _navItem(Icons.dashboard_customize_outlined, "DASHBOARD", false,
              HomeScreen(cameras: widget.cameras)),
          _navItem(Icons.map_outlined, "FIELD MAP", false,
              FieldMapScreen(cameras: widget.cameras)),
          _navItem(Icons.settings_outlined, "SETTINGS", false,
              SettingsScreen(cameras: widget.cameras)),
          _navItem(Icons.analytics_outlined, "INFERENCE", true, null),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool active, Widget? screen) {
    final color = active ? AppColors.neonOrange : const Color(0xFF757575);
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
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════
// Analytical Report Page (fl_chart)
// ═════════════════════════════════════════════

class _GradeStats {
  final String label;
  final int count;
  final double avgConfidence;
  final double avgColorProfile;
  final double avgTextureDensity;
  final double avgOilContent;
  final Color color;

  const _GradeStats({
    required this.label,
    required this.count,
    required this.avgConfidence,
    required this.avgColorProfile,
    required this.avgTextureDensity,
    required this.avgOilContent,
    required this.color,
  });
}

class AnalyticalReportPage extends StatelessWidget {
  final List<GradingRecord> records;
  const AnalyticalReportPage({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    final total = records.length;
    if (total == 0) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBg,
        appBar: _buildAppBar(context),
        body: const Center(child: Text("No data to report",
            style: TextStyle(color: Color(0xFF757575)))),
      );
    }

    final grades = _computeGradeStats(records);
    final avgConf = records.fold<double>(0, (s, e) => s + e.confidenceScore) / total;
    final liveCount = records.where((e) => e.source == ScanSource.live).length;
    final droneCount = records.where((e) => e.source == ScanSource.drone).length;
    final recommendation = _recommendation(grades, total);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: _buildAppBar(context),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryHeader(total, avgConf, liveCount, droneCount),
            const SizedBox(height: 20),
            _buildRecommendationCard(recommendation),
            const SizedBox(height: 24),
            _buildSectionTitle("GRADE DISTRIBUTION"),
            const SizedBox(height: 12),
            _buildGradePieChart(grades, total),
            const SizedBox(height: 24),
            _buildSectionTitle("METRICS BY GRADE"),
            const SizedBox(height: 4),
            const Text("Color Profile & Texture Density",
                style: TextStyle(fontSize: 10, color: Color(0xFF757575))),
            const SizedBox(height: 12),
            _buildGroupedMetricsChart(grades),
            const SizedBox(height: 24),
            _buildSectionTitle("OIL CONTENT BY GRADE"),
            const SizedBox(height: 12),
            _buildOilContentChart(grades),
            const SizedBox(height: 24),
            _buildSectionTitle("SOURCE BREAKDOWN"),
            const SizedBox(height: 12),
            _buildSourceChart(liveCount, droneCount, total),
            const SizedBox(height: 24),
            _buildSectionTitle("GRADE BREAKDOWN"),
            const SizedBox(height: 12),
            _buildGradeTable(grades, total),
            const SizedBox(height: 24),
            if (records.length >= 2) ...[
              _buildSectionTitle("CONFIDENCE OVER TIME"),
              const SizedBox(height: 12),
              _buildConfidenceLineChart(),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext ctx) {
    return AppBar(
      backgroundColor: AppColors.containerBg,
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(ctx),
      ),
      title: const Text(
        "ANALYTICAL REPORT",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  // ─── DATA COMPUTATION ───

  List<_GradeStats> _computeGradeStats(List<GradingRecord> items) {
    final groups = <String, List<GradingRecord>>{};
    for (final r in items) {
      final key = r.gradeResult.split(" ").first;
      groups.putIfAbsent(key, () => []).add(r);
    }

    final colorMap = <String, Color>{
      'Ripe': AppColors.activeGreen,
      'Unripe': AppColors.harvestGold,
      'Overripe': AppColors.neonOrange,
      'Damaged': Colors.redAccent,
      'Empty': const Color(0xFF757575),
    };

    final result = <_GradeStats>[];
    for (final entry in groups.entries) {
      final list = entry.value;
      final n = list.length;
      result.add(_GradeStats(
        label: entry.key,
        count: n,
        avgConfidence: list.fold<double>(0, (s, e) => s + e.confidenceScore) / n,
        avgColorProfile:
            list.fold<double>(0, (s, e) => s + (e.metrics['colorProfile'] ?? 0)) / n,
        avgTextureDensity:
            list.fold<double>(0, (s, e) => s + (e.metrics['textureDensity'] ?? 0)) / n,
        avgOilContent:
            list.fold<double>(0, (s, e) => s + (e.metrics['oilContent'] ?? 0)) / n,
        color: colorMap[entry.key] ?? Colors.grey,
      ));
    }

    // Sort: Ripe first, then by count descending
    const order = ['Ripe', 'Unripe', 'Overripe', 'Damaged', 'Empty'];
    result.sort((a, b) {
      final ai = order.indexOf(a.label);
      final bi = order.indexOf(b.label);
      if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
      if (ai >= 0) return -1;
      if (bi >= 0) return 1;
      return b.count.compareTo(a.count);
    });
    return result;
  }

  String _recommendation(List<_GradeStats> grades, int total) {
    final ripePct = _gradePct(grades, 'Ripe', total);
    final unripePct = _gradePct(grades, 'Unripe', total);
    final damagedPct = _gradePct(grades, 'Damaged', total);

    if (ripePct >= 70) {
      return "Batch is predominantly ripe. Ready for processing or harvest.";
    } else if (ripePct >= 50) {
      return "Moderate ripe proportion. Monitor remaining stock for optimal timing.";
    } else if (unripePct > 40) {
      return "High unripe content. Allow more ripening time before processing.";
    } else if (damagedPct > 30) {
      return "Elevated damage rate. Inspect handling and storage conditions.";
    } else if (damagedPct > 15) {
      return "Some damage detected. Consider quality control review.";
    }
    return "Mixed maturity. Sort before processing for best output.";
  }

  double _gradePct(List<_GradeStats> grades, String label, int total) {
    final g = grades.where((e) => e.label == label);
    return g.isEmpty ? 0 : (g.first.count / total) * 100;
  }

  // ─── SUMMARY HEADER ───

  Widget _buildSummaryHeader(int total, double avgConf, int live, int drone) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _summaryTile("TOTAL SCANS", "$total", Icons.fact_check_outlined),
              _summaryTile("AVG CONFIDENCE",
                  "${(avgConf * 100).toStringAsFixed(0)}%", Icons.trending_up),
              _summaryTile("LIVE : DRONE", "$live : $drone", Icons.sensors),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.neonOrange, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.harvestGold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: Color(0xFF757575),
          ),
        ),
      ],
    );
  }

  // ─── RECOMMENDATION CARD ───

  Widget _buildRecommendationCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.harvestGold.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline,
              color: AppColors.harvestGold, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE0E0E0),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── SECTION TITLE ───

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }

  // ─── PIE CHART ───

  Widget _buildGradePieChart(List<_GradeStats> grades, int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: grades.map((g) {
                    return PieChartSectionData(
                      value: g.count.toDouble(),
                      color: g.color,
                      title: "${(g.count / total * 100).toStringAsFixed(0)}%",
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                      radius: 45,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: grades.map((g) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: BoxDecoration(
                        color: g.color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${g.label} (${g.count})",
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFBDBDBD),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─── GROUPED METRICS CHART (Color Profile + Texture Density) ───

  Widget _buildGroupedMetricsChart(List<_GradeStats> grades) {
    final maxVal = 100.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal,
            barGroups: List.generate(grades.length, (i) {
              final g = grades[i];
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: g.avgColorProfile,
                    color: AppColors.neonOrange,
                    width: 8,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                  BarChartRodData(
                    toY: g.avgTextureDensity,
                    color: AppColors.harvestGold,
                    width: 8,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
                barsSpace: 3,
              );
            }),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= grades.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        grades[i].label.length > 6
                            ? grades[i].label.substring(0, 6)
                            : grades[i].label,
                        style: const TextStyle(fontSize: 8, color: Color(0xFF757575)),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 25,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      "${value.toInt()}%",
                      style: const TextStyle(fontSize: 8, color: Color(0xFF757575)),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (value) => FlLine(
                color: const Color(0xFF2A2A2A),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  // ─── OIL CONTENT CHART ───

  Widget _buildOilContentChart(List<_GradeStats> grades) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: 5.5,
            barGroups: List.generate(grades.length, (i) {
              final g = grades[i];
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: g.avgOilContent,
                    color: g.color,
                    width: 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ],
              );
            }),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= grades.length) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        grades[i].label.length > 6
                            ? grades[i].label.substring(0, 6)
                            : grades[i].label,
                        style: const TextStyle(fontSize: 8, color: Color(0xFF757575)),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 8, color: Color(0xFF757575)),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) => FlLine(
                color: const Color(0xFF2A2A2A),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
          ),
        ),
      ),
    );
  }

  // ─── SOURCE BREAKDOWN ───

  Widget _buildSourceChart(int live, int drone, int total) {
    final livePct = total > 0 ? (live / total * 100) : 0.0;
    final dronePct = total > 0 ? (drone / total * 100) : 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _sourceBar("LIVE", live, livePct, AppColors.neonOrange),
              const SizedBox(width: 16),
              _sourceBar("DRONE", drone, dronePct, Colors.blueAccent),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              width: double.infinity,
              child: Row(
                children: [
                  Flexible(
                    flex: live,
                    child: Container(color: AppColors.neonOrange)),
                  if (drone > 0)
                    Flexible(
                      flex: drone,
                      child: Container(color: Colors.blueAccent)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sourceBar(String label, int count, double pct, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            "$count",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "${pct.toStringAsFixed(0)}%",
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF757575),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ─── GRADE TABLE ───

  Widget _buildGradeTable(List<_GradeStats> grades, int total) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Table header
          Row(
            children: [
              _cell("Grade", true, true),
              _cell("Count", true, false),
              _cell("%", true, false),
              _cell("Confidence", true, false),
              _cell("Oil /5", true, false),
            ],
          ),
          const Divider(color: Color(0xFF2A2A2A), height: 1),
          ...grades.map((g) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                _cell(g.label, false, true),
                _cell("${g.count}", false, false),
                _cell("${(g.count / total * 100).toStringAsFixed(0)}%", false, false),
                _cell("${(g.avgConfidence * 100).toStringAsFixed(0)}%", false, false),
                _cell(g.avgOilContent.toStringAsFixed(1), false, false),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _cell(String text, bool isHeader, bool isFirst) {
    return Expanded(
      flex: isFirst ? 3 : 2,
      child: Text(
        text,
        style: TextStyle(
          fontSize: isHeader ? 9 : 11,
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w600,
          color: isHeader
              ? const Color(0xFF757575)
              : isFirst
                  ? AppColors.harvestGold
                  : const Color(0xFFBDBDBD),
        ),
      ),
    );
  }

  // ─── CONFIDENCE LINE CHART ───

  Widget _buildConfidenceLineChart() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 25,
              getDrawingHorizontalLine: (value) => FlLine(
                color: const Color(0xFF2A2A2A),
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (records.length / 4).ceilToDouble().clamp(1, double.infinity),
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= records.length) return const SizedBox.shrink();
                    final r = records[i];
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        "${r.timestamp.month}/${r.timestamp.day}\n${r.timestamp.hour.toString().padLeft(2, '0')}:${r.timestamp.minute.toString().padLeft(2, '0')}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 6,
                          color: Color(0xFF757575),
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: 25,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      "${value.toInt()}%",
                      style: const TextStyle(
                        fontSize: 8,
                        color: Color(0xFF757575),
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(records.length, (i) {
                  return FlSpot(i.toDouble(), records[i].confidenceScore * 100);
                }),
                isCurved: true,
                color: AppColors.harvestGold,
                barWidth: 2,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 2,
                      color: AppColors.harvestGold,
                      strokeWidth: 0,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.harvestGold.withValues(alpha: 0.12),
                ),
              ),
            ],
            minY: 0,
            maxY: 100,
          ),
        ),
      ),
    );
  }
}
