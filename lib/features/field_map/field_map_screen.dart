import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../../core/theme/colors.dart';
import '../../core/models/grading_record.dart';
import '../../core/state/grading_provider.dart';
import '../settings/settings_screen.dart';
import '../classifier/classifier_screen.dart';
import '../classifier/classifier_logic.dart';
import '../home/home_screen.dart';
import '../reports/inference_center_screen.dart';

enum _FieldMapMode { idle, selected, processing }

class FieldMapScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const FieldMapScreen({super.key, required this.cameras});

  @override
  State<FieldMapScreen> createState() => _FieldMapScreenState();
}

class _FieldMapScreenState extends State<FieldMapScreen> {
  final PalmClassifier _classifier = PalmClassifier();
  final ImagePicker _picker = ImagePicker();

  _FieldMapMode _mode = _FieldMapMode.idle;
  List<File> _selectedImages = [];
  int _processedCount = 0;
  int _totalCount = 0;
  String? _batchResult;

  static const _classMetrics = <String, Map<String, double>>{
    'Ripe': {'colorProfile': 96, 'textureDensity': 89, 'oilContent': 4.2},
    'Overripe': {'colorProfile': 82, 'textureDensity': 52, 'oilContent': 4.7},
    'Unripe': {'colorProfile': 58, 'textureDensity': 74, 'oilContent': 1.5},
    'Damaged': {'colorProfile': 28, 'textureDensity': 32, 'oilContent': 0.7},
    'Empty': {'colorProfile': 8, 'textureDensity': 18, 'oilContent': 0.0},
  };
  static const _defaultMetrics = <String, double>{
    'colorProfile': 50, 'textureDensity': 50, 'oilContent': 2.5,
  };

  static String _generateBatchId() {
    final r = math.Random.secure();
    final bytes = List<int>.generate(8, (_) => r.nextInt(256));
    return 'batch_${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  Future<void> _pickBatchFromGallery() async {
    final xFiles = await _picker.pickMultiImage(
      imageQuality: 90,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (xFiles.isEmpty) return;
    setState(() {
      _selectedImages = xFiles.map((x) => File(x.path)).toList();
      _mode = _FieldMapMode.selected;
      _processedCount = 0;
      _batchResult = null;
    });
  }

  void _removeImage(int index) {
    if (_mode != _FieldMapMode.selected) return;
    setState(() {
      _selectedImages.removeAt(index);
      if (_selectedImages.isEmpty) _mode = _FieldMapMode.idle;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedImages = [];
      _mode = _FieldMapMode.idle;
      _batchResult = null;
    });
  }

  Future<void> _processBatch() async {
    if (_selectedImages.isEmpty) return;
    final batchId = _generateBatchId();
    setState(() {
      _mode = _FieldMapMode.processing;
      _totalCount = _selectedImages.length;
      _processedCount = 0;
    });

    const workers = 4;
    final queue = List<File>.from(_selectedImages);
    final running = <_BatchTask>[];
    var i = 0;
    while (i < queue.length || running.isNotEmpty) {
      while (running.length < workers && i < queue.length) {
        final file = queue[i++];
        running.add(_BatchTask(_classifyAndPublish(file, batchId)));
      }
      await Future.any(running.map((t) => t.future));
      running.removeWhere((t) => t.done);
    }

    if (!mounted) return;
    setState(() {
      _batchResult = "Batch complete — $_totalCount images processed";
    });
  }

  Future<void> _classifyAndPublish(File file, String batchSessionId) async {
    try {
      final resultData = await _classifier.classify(file.path);
      if (!mounted) return;

      final bool isValid = resultData['isValid'] == true;
      final label = resultData['result'] ?? "Unknown";
      final scores = List<double>.from(resultData['rawScores'] ?? []);

      if (!isValid) {
        if (mounted) {
          setState(() => _processedCount++);
        }
        return;
      }

      final className = label.split(" ").first;
      final baseMetrics = _classMetrics[className] ?? _defaultMetrics;
      final variation = (scores.isNotEmpty ? scores.reduce((a, b) => a > b ? a : b) : 0.5);
      final colorP = (baseMetrics['colorProfile']! + (variation - 0.5) * 6)
          .clamp(0.0, 100.0);
      final textureD = (baseMetrics['textureDensity']! + (variation - 0.5) * 8)
          .clamp(0.0, 100.0);
      final oilC =
          (baseMetrics['oilContent']! + (variation - 0.5) * 0.6).clamp(0.0, 5.0);

      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final savedPath = '${dir.path}/drone_${stamp}_$_processedCount.jpg';
      await file.copy(savedPath);

      final record = GradingRecord.create(
        imagePath: savedPath,
        source: ScanSource.drone,
        gradeResult: label,
        confidenceScore: scores.isNotEmpty ? scores.reduce((a, b) => a > b ? a : b) : 0,
        metrics: {
          'colorProfile': colorP,
          'textureDensity': textureD,
          'oilContent': oilC,
        },
        batchSessionId: batchSessionId,
      );
      if (mounted) {
        context.read<GradingProvider>().addRecord(record);
        setState(() => _processedCount++);
      }
    } catch (e, stack) {
      debugPrint("Batch classify error: $e\n$stack");
      if (mounted) {
        setState(() => _processedCount++);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(child: _buildBody()),
            _buildBottomNav(),
          ],
        ),
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
            "DRONE GALLERY",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.activeGreen,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                "BATCH MODE",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AppColors.activeGreen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return switch (_mode) {
      _FieldMapMode.idle => _buildIdle(),
      _FieldMapMode.selected => _buildSelectionGrid(),
      _FieldMapMode.processing => _buildProcessing(),
    };
  }

  // ── IDLE STATE ──

  Widget _buildIdle() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight_rounded, size: 64, color: AppColors.neonOrange),
            const SizedBox(height: 16),
            const Text(
              "BATCH GALLERY UPLOAD",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Select multiple images from your gallery\nto run batch drone-based analysis",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.5),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _pickBatchFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text(
                  "SELECT BATCH FROM GALLERY",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                    color: Colors.black,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neonOrange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SELECTION GRID WITH NUMBERED BADGES ──

  Widget _buildSelectionGrid() {
    final count = _selectedImages.length;
    return Column(
      children: [
        if (_batchResult != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.activeGreen.withValues(alpha: 0.12),
            child: Text(
              _batchResult!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.activeGreen,
              ),
            ),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: count,
              itemBuilder: (context, i) => _buildSelectionCell(i),
            ),
          ),
        ),
        // Bottom action bar
        Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _clearSelection,
                  child: const Text(
                    "CLEAR ALL",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF757575),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _processBatch,
                    icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                    label: Text(
                      "PROCESS BATCH ($count)",
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Colors.black,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.harvestGold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionCell(int index) {
    final orderNum = index + 1;
    return GestureDetector(
      onTap: () => _removeImage(index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _selectedImages[index],
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                decoration: BoxDecoration(
                  color: AppColors.containerBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.broken_image_outlined,
                    color: Color(0xFF555555)),
              ),
            ),
          ),
          // Remove overlay on tap
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.neonOrange, width: 2),
            ),
          ),
          // Numbered badge - top right
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.neonOrange,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  "$orderNum",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
          // Tap-to-remove hint
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                "TAP TO\nREMOVE",
                style: TextStyle(
                  fontSize: 6,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFBDBDBD),
                  height: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PROCESSING OVERLAY ──

  Widget _buildProcessing() {
    final progress = _totalCount > 0 ? _processedCount / _totalCount : 0.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 4,
                color: AppColors.neonOrange,
                backgroundColor: AppColors.containerBg,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "BATCH PROCESSING",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "$_processedCount of $_totalCount images analyzed",
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Results appear in real-time on\nDashboard & Inference Center",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.harvestGold.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
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
          _navItem(Icons.map_outlined, "FIELD MAP", true, null),
          _navItem(Icons.settings_outlined, "SETTINGS", false,
              SettingsScreen(cameras: widget.cameras)),
          _navItem(Icons.analytics_outlined, "INFERENCE", false,
              InferenceCenterScreen(cameras: widget.cameras)),
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

/// Wraps a batch classification future so completion can be checked for
/// bounded-concurrency scheduling.
class _BatchTask {
  final Future<void> future;
  bool done = false;
  _BatchTask(Future<void> f)
      : future = f.whenComplete(() {}) {
    future.whenComplete(() => done = true);
  }
}
