import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../core/theme/colors.dart';
import '../settings/settings_screen.dart';
import '../classifier/classifier_screen.dart';
import '../home/home_screen.dart';
import '../field_map/field_map_screen.dart';
import 'history_detail_screen.dart';
import 'history_service.dart';

class HistoryListScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HistoryListScreen({super.key, required this.cameras});

  @override
  State<HistoryListScreen> createState() => _HistoryListScreenState();
}

class _HistoryListScreenState extends State<HistoryListScreen> {
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  void _loadHistory() {
    setState(() => _isLoading = true);
    final history = HistoryService.getHistory();
    setState(() {
      _records = history;
      _isLoading = false;
    });
  }

  Color _resultColor(String result) {
    if (result.contains("Ripe")) return Colors.white;
    if (result.contains("Unripe")) return AppColors.harvestGold;
    if (result.contains("Damaged") || result.contains("Empty")) return Colors.redAccent;
    if (result.contains("Overripe")) return Colors.orange;
    return const Color(0xFF9E9E9E);
  }

  IconData _resultIcon(String result) {
    if (result.contains("Ripe")) return Icons.check_circle_rounded;
    if (result.contains("Unripe")) return Icons.schedule_rounded;
    if (result.contains("Damaged")) return Icons.warning_rounded;
    if (result.contains("Empty")) return Icons.block_rounded;
    if (result.contains("Overripe")) return Icons.timer_rounded;
    return Icons.help_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
          Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(
                      color: AppColors.neonOrange,
                    ))
                  : _records.isEmpty
                      ? _buildEmptyState()
                      : _buildHistoryList(),
          ),
          _buildBottomNav(),
        ],
      ),
    ),
  );
  }

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

  Widget _buildAppBar() {
    return Container(
      color: AppColors.containerBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "INFERENCE LOG",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              if (_records.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 20),
                  onPressed: _loadHistory,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.analytics_outlined,
            size: 64,
            color: AppColors.neonOrange.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            "NO INFERENCE DATA",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Scan results will appear here",
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9E9E9E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _records.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 4),
            child: Text(
              "${_records.length} RECORDS FOUND",
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
                color: Color(0xFF9E9E9E),
              ),
            ),
          );
        }
        final record = _records[index - 1];
        return _buildHistoryItem(record, index - 1);
      },
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> record, int index) {
    final result = record['result'] as String? ?? "Unknown";
    final date = record['date'] as String? ?? "";
    final confidence = (record['confidence'] as double?) ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.containerBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HistoryDetailScreen(record: record),
              ),
            );
          },
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.neonOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _resultIcon(result),
                  color: _resultColor(result),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _resultColor(result),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9E9E9E),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.neonOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${(confidence * 100).toStringAsFixed(0)}%",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neonOrange,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF757575),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
