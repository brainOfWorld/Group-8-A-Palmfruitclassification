import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/colors.dart';
import '../settings/settings_screen.dart';
import 'classifier_logic.dart';
import '../home/home_screen.dart';
import '../field_map/field_map_screen.dart';
import '../reports/inference_center_screen.dart';
import '../../core/models/grading_record.dart';
import '../../core/state/grading_provider.dart';
import 'package:provider/provider.dart';

class ClassifierScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ClassifierScreen({super.key, required this.cameras});

  @override
  State<ClassifierScreen> createState() => _ClassifierScreenState();
}

class _ClassifierScreenState extends State<ClassifierScreen>
    with TickerProviderStateMixin {
  CameraController? _controller;
  late PalmClassifier _classifier;
  late AnimationController _laserAnimCtrl;

  Future<void>? _initFuture;
  bool _isProcessing = false;
  FlashMode _flashMode = FlashMode.off;
  Offset? _focusPoint;

  String _resultLabel = "—";
  bool _hasResult = false;

  double _colorProfile = 0.0;
  double _textureDensity = 0.0;
  double _oilContent = 0.0;

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

  @override
  void initState() {
    super.initState();
    _classifier = PalmClassifier();

    _laserAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    if (widget.cameras.isNotEmpty) {
      CameraDescription? back;
      for (final c in widget.cameras) {
        if (c.lensDirection == CameraLensDirection.back) {
          back = c;
          break;
        }
      }
      _controller = CameraController(
        back ?? widget.cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );
      _initFuture = _controller!.initialize().then((_) {
        if (!mounted) return;
        _controller!.setFlashMode(FlashMode.off);
        _controller!.setFocusMode(FocusMode.auto);
        _controller!.setExposureMode(ExposureMode.auto);
        setState(() {});
      });
    }
  }

  void _onTapToFocus(TapUpDetails details) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final box = context.findRenderObject() as RenderBox;
      final local = box.globalToLocal(details.globalPosition);
      final size = box.size;
      final norm = Offset(local.dx / size.width, local.dy / size.height);
      await _controller!.setFocusPoint(norm);
      await _controller!.setExposurePoint(norm);
      setState(() => _focusPoint = local);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _focusPoint = null);
      });
    } catch (_) {}
  }

  void _toggleFlash() {
    setState(() {
      _flashMode = switch (_flashMode) {
        FlashMode.off => FlashMode.always,
        FlashMode.always => FlashMode.auto,
        FlashMode.auto => FlashMode.torch,
        FlashMode.torch => FlashMode.off,
      };
    });
    _controller?.setFlashMode(_flashMode);
  }

  Future<void> _captureAndClassify() async {
    if (_isProcessing || _controller == null || !_controller!.value.isInitialized) {
      return;
    }
    setState(() {
      _isProcessing = true;
      _hasResult = false;
      _resultLabel = "—";
    });
    try {
      await _initFuture;
      final image = await _controller!.takePicture();
      if (!mounted) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;

      final resultData = await _classifier.classifyBytes(bytes);
      if (!mounted) return;

      final label = resultData['result'] ?? "Unknown";
      final scores = List<double>.from(resultData['rawScores'] ?? []);
      final isValid = resultData['isValid'] == true;

      final className = isValid ? label.split(" ").first : "";
      final baseMetrics = _classMetrics[className] ?? _defaultMetrics;
      final variation = (scores.isNotEmpty ? scores.reduce(math.max) : 0.5);
      final colorP = (baseMetrics['colorProfile']! + (variation - 0.5) * 6)
          .clamp(0.0, 100.0);
      final textureD = (baseMetrics['textureDensity']! + (variation - 0.5) * 8)
          .clamp(0.0, 100.0);
      final oilC =
          (baseMetrics['oilContent']! + (variation - 0.5) * 0.6).clamp(0.0, 5.0);

      setState(() {
        _isProcessing = false;
        _hasResult = true;
        _resultLabel = label;
        _colorProfile = colorP;
        _textureDensity = textureD;
        _oilContent = oilC;
      });

      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final savedPath = '${dir.path}/scan_$stamp.jpg';
      await File(image.path).copy(savedPath);

      final maxScore = scores.isNotEmpty ? scores.reduce(math.max) : 0.5;
      final record = GradingRecord.create(
        imagePath: savedPath,
        source: ScanSource.live,
        gradeResult: label,
        confidenceScore: maxScore,
        metrics: {
          'colorProfile': colorP,
          'textureDensity': textureD,
          'oilContent': oilC,
        },
      );
      if (mounted) {
        context.read<GradingProvider>().addRecord(record);
      }
    } catch (e, stack) {
      debugPrint("Capture error: ${e.runtimeType} ${e.toString()}");
      debugPrint("$stack");
      setState(() {
        _isProcessing = false;
      });
    }
  }



  IconData _flashIcon() => switch (_flashMode) {
    FlashMode.off => Icons.flash_off_rounded,
    FlashMode.always => Icons.flash_on_rounded,
    FlashMode.auto => Icons.flash_auto_rounded,
    FlashMode.torch => Icons.flashlight_on_rounded,
  };

  @override
  void dispose() {
    _laserAnimCtrl.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildStatusBadge(),
            Expanded(child: _buildCameraViewport()),
            _buildProcessingOrCaptureButton(),
            _buildResultsCard(),
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
            "PALMFRUIT GRADER",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.white,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      color: AppColors.containerBg,
      padding: const EdgeInsets.only(bottom: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.activeGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.activeGreen,
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                "ONLY CAPTURE PALM FRUITS",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: AppColors.activeGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraViewport() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "CAMERA SCANNER VIEW",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 320,
            width: double.infinity,
            child: FutureBuilder<void>(
              future: _initFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    _controller != null) {
                  return GestureDetector(
                    onTapUp: _onTapToFocus,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.neonOrange,
                          width: 3,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          FittedBox(
                            fit: BoxFit.cover,
                            clipBehavior: Clip.hardEdge,
                            child: SizedBox(
                              width:
                                  _controller!.value.previewSize?.height ?? 640,
                              height:
                                  _controller!.value.previewSize?.width ?? 480,
                              child: CameraPreview(_controller!),
                            ),
                          ),
                          // Laser beam across vertical midpoint
                          AnimatedBuilder(
                            animation: _laserAnimCtrl,
                            builder: (context, _) {
                              final t = _laserAnimCtrl.value;
                              final offset = (t - 0.5) * 40;
                              return Positioned(
                                top: null,
                                bottom: null,
                                left: 0,
                                right: 0,
                                height: 3,
                                child: Transform.translate(
                                  offset: Offset(0, offset),
                                  child: Center(
                                    child: Container(
                                      height: 3,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: AppColors.neonOrange,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.neonOrange
                                                .withValues(alpha: 0.6),
                                            blurRadius: 14,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          // Focus point indicator
                          if (_focusPoint != null)
                            Positioned(
                              left: _focusPoint!.dx - 24,
                              top: _focusPoint!.dy - 24,
                              child: IgnorePointer(
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.neonOrange,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          // Flash toggle (bottom-right)
                          Positioned(
                            right: 12,
                            bottom: 12,
                            child: GestureDetector(
                              onTap: _toggleFlash,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  _flashIcon(),
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: AppColors.containerBg,
                    ),
                    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
                          Icon(Icons.error_outline,
                              size: 36, color: Colors.redAccent),
                          SizedBox(height: 8),
                          Text("Camera Error",
                              style: TextStyle(color: Colors.white54)),
                        ],
                      ),
                    ),
                  );
                }
                return Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: AppColors.containerBg,
                  ),
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessingOrCaptureButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: GestureDetector(
        onTap: _isProcessing ? null : _captureAndClassify,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.neonOrange,
            borderRadius: BorderRadius.circular(23),
          ),
          child: Center(
            child: _isProcessing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.harvestGold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "ANALYZING...",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    "CAPTURE & CLASSIFY",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: const BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "CURRENT GRADE:",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _hasResult ? _resultLabel : "—",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _hasResult
                  ? AppColors.harvestGold
                  : Colors.white38,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildMetric("COLOR PROFILE", "${_colorProfile.toStringAsFixed(0)}%"),
              _buildMetric(
                  "TEXTURE DENSITY", "${_textureDensity.toStringAsFixed(0)}%"),
              _buildMetric(
                  "EST. OIL CONTENT", "${_oilContent.toStringAsFixed(1)}/5"),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [AppColors.neonOrange, AppColors.neonOrange],
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _hasResult
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Grade logged")),
                          );
                        }
                      : null,
                  child: Center(
                    child: Text(
                      "LOG GRADE",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: _hasResult ? Colors.black : Colors.white38,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
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
          _navItem(Icons.qr_code_scanner, "SCANNER", true, null),
          _navItem(Icons.dashboard_customize_outlined, "DASHBOARD", false,
              HomeScreen(cameras: widget.cameras)),
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
