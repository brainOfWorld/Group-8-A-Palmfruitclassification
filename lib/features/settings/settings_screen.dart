import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/colors.dart';
import '../auth/login_screen.dart';
import '../home/home_screen.dart';

class SettingsScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const SettingsScreen({super.key, required this.cameras});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // -- Controllers --
  late TextEditingController _apiEndpointCtrl;
  late TextEditingController _manualPriceCtrl;

  // -- State --
  String _cameraResolution = 'High';
  bool _forceFlash = false;
  double _frameThrottling = 300;
  bool _offlineInference = true;
  double _confidenceThreshold = 0.8;
  bool _syncEnabled = true;
  String _apiEndpoint = 'https://api.rcees-mill-sync.local/v1/sort';
  String _currentCurrency = 'GH¢';
  bool _autoPriceSync = true;
  String _manualPriceOverride = '';
  int _cachedRecords = 14;
  bool _isCheckingUpdate = false;
  bool _isSyncing = false;

  // -- SharedPreferences keys --
  static const _kCameraResolution = 'camera_resolution';
  static const _kForceFlash = 'force_flash';
  static const _kFrameThrottling = 'frame_throttling';
  static const _kOfflineInference = 'offline_inference';
  static const _kConfidenceThreshold = 'confidence_threshold';
  static const _kSyncEnabled = 'sync_enabled';
  static const _kApiEndpoint = 'api_endpoint';
  static const _kCurrency = 'currency';
  static const _kAutoPriceSync = 'auto_price_sync';
  static const _kManualPrice = 'manual_price';

  @override
  void initState() {
    super.initState();
    _apiEndpointCtrl = TextEditingController(text: _apiEndpoint);
    _manualPriceCtrl = TextEditingController(text: _manualPriceOverride);
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _cameraResolution = prefs.getString(_kCameraResolution) ?? 'High';
      _forceFlash = prefs.getBool(_kForceFlash) ?? false;
      _frameThrottling = prefs.getDouble(_kFrameThrottling) ?? 300;
      _offlineInference = prefs.getBool(_kOfflineInference) ?? true;
      _confidenceThreshold = prefs.getDouble(_kConfidenceThreshold) ?? 0.8;
      _syncEnabled = prefs.getBool(_kSyncEnabled) ?? true;
      _apiEndpoint = prefs.getString(_kApiEndpoint) ?? _apiEndpoint;
      _currentCurrency = prefs.getString(_kCurrency) ?? 'GH¢';
      _autoPriceSync = prefs.getBool(_kAutoPriceSync) ?? true;
      _manualPriceOverride = prefs.getString(_kManualPrice) ?? '';
      _apiEndpointCtrl.text = _apiEndpoint;
      _manualPriceCtrl.text = _manualPriceOverride;
    });
  }

  Future<void> _save(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    switch (value.runtimeType) {
      case const (String):
        await prefs.setString(key, value as String);
      case const (bool):
        await prefs.setBool(key, value as bool);
      case const (double):
        await prefs.setDouble(key, value as double);
      case const (int):
        await prefs.setInt(key, value as int);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _apiEndpointCtrl.dispose();
    _manualPriceCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────── BUILD ───────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.containerBg,
          leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HomeScreen(cameras: widget.cameras),
              ),
            );
          },
        ),
        title: const Text(
          "SETTINGS",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _buildHardwareCard(),
          const SizedBox(height: 14),
          _buildInferenceCard(),
          const SizedBox(height: 14),
          _buildSyncCard(),
          const SizedBox(height: 14),
          _buildFinanceCard(),
          const SizedBox(height: 14),
          _buildDiagnosticsCard(),
          const SizedBox(height: 24),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  // ─────────────── MODULE A: HARDWARE & CAMERA ───────────────

  Widget _buildHardwareCard() {
    return _card(
      "HARDWARE & CAMERA CONFIGURATION",
      children: [
        _dropdownTile(
          label: "Camera Resolution Preset",
          value: _cameraResolution,
          items: const ["Low", "Medium", "High", "Ultra/Max"],
          onChanged: (v) {
            _cameraResolution = v;
            _save(_kCameraResolution, v);
          },
        ),
        _divider(),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text("Force Device Flashlight/Torch",
              style: _itemTitleStyle),
          subtitle: const Text(
            "Forces flash ON during image capture to stabilize lighting",
            style: _subtitleStyle,
          ),
          value: _forceFlash,
          activeTrackColor: AppColors.neonOrange,
          activeThumbColor: Colors.white,
          onChanged: (v) {
            _forceFlash = v;
            _save(_kForceFlash, v);
          },
        ),
        _divider(),
        _sliderTile(
          label: "Frame Ingestion Throttling",
          subtitle: "Adjusts model frame evaluation speed to manage device CPU cycles and prevent overheating.",
          value: _frameThrottling,
          min: 100,
          max: 500,
          divisions: 8,
          displayValue: "${_frameThrottling.toInt()}ms",
          onChanged: (v) {
            _frameThrottling = v;
            _save(_kFrameThrottling, v);
          },
        ),
      ],
    );
  }

  // ─────────────── MODULE B: AI MODEL & INFERENCE ───────────────

  Widget _buildInferenceCard() {
    return _card(
      "AI MODEL & INFERENCE ENGINE",
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text("On-Device Offline Inference",
              style: _itemTitleStyle),
          subtitle: const Text(
            "Uses local TFLite weights for offline farm operations",
            style: _subtitleStyle,
          ),
          value: _offlineInference,
          activeTrackColor: AppColors.neonOrange,
          activeThumbColor: Colors.white,
          onChanged: (v) {
            _offlineInference = v;
            _save(_kOfflineInference, v);
          },
        ),
        _divider(),
        _sliderTile(
          label: "Confidence Acceptance Threshold",
          subtitle: "Minimum prediction assurance before logging a grade",
          value: _confidenceThreshold * 100,
          min: 50,
          max: 100,
          divisions: 10,
          displayValue: "${_confidenceThreshold.toStringAsFixed(0)}%",
          onChanged: (v) {
            _confidenceThreshold = v / 100;
            _save(_kConfidenceThreshold, _confidenceThreshold);
          },
        ),
        _divider(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text("Update Classification Weights",
              style: _itemTitleStyle),
          subtitle: const Text("v1.4 (0526-HE)", style: _subtitleStyle),
          trailing: _isCheckingUpdate
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.harvestGold,
                  ),
                )
              : TextButton(
                  onPressed: () async {
                    setState(() => _isCheckingUpdate = true);
                    await Future.delayed(const Duration(seconds: 2));
                    setState(() => _isCheckingUpdate = false);
                  },
                  child: const Text(
                    "CHECK FOR UPDATE",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.harvestGold,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ─────────────── MODULE C: INDUSTRIAL SYNC ───────────────

  Widget _buildSyncCard() {
    return _card(
      "INDUSTRIAL ENTERPRISE SYNC",
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text("RCEES Processing Hub Sync",
              style: _itemTitleStyle),
          subtitle: const Text(
            "Active pipeline link to regional research infrastructure",
            style: _subtitleStyle,
          ),
          value: _syncEnabled,
          activeTrackColor: AppColors.activeGreen,
          activeThumbColor: Colors.white,
          onChanged: (v) {
            _syncEnabled = v;
            _save(_kSyncEnabled, v);
          },
        ),
        _divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Mill Automation API Endpoint",
                  style: _itemTitleStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _apiEndpointCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "https://api.rcees-mill-sync.local/v1/sort",
                  hintStyle: const TextStyle(color: Color(0xFF555555)),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.3),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF333333)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.neonOrange),
                  ),
                ),
                onChanged: (v) {
                  _apiEndpoint = v;
                  _save(_kApiEndpoint, v);
                },
              ),
            ],
          ),
        ),
        _divider(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text("API Connectivity Status",
              style: _itemTitleStyle),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (_syncEnabled ? AppColors.activeGreen : const Color(0xFF555555))
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _syncEnabled ? "Connected (200 OK)" : "Offline / Desynced",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _syncEnabled ? AppColors.activeGreen : const Color(0xFF757575),
              ),
            ),
          ),
        ),
        _divider(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text("Local Cached Records",
              style: _itemTitleStyle),
          subtitle: Text(
            "$_cachedRecords Un-synchronized local logs found.",
            style: _subtitleStyle,
          ),
          trailing: _isSyncing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.neonOrange,
                  ),
                )
              : SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: () async {
                      setState(() => _isSyncing = true);
                      await Future.delayed(const Duration(seconds: 2));
                      setState(() {
                        _isSyncing = false;
                        _cachedRecords = 0;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.neonOrange,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text(
                      "SYNC CACHE NOW",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ─────────────── MODULE D: FINANCIAL ───────────────

  Widget _buildFinanceCard() {
    final manualEnabled = !_autoPriceSync;
    return _card(
      "FINANCIAL & REGIONAL PARAMETERS",
      children: [
        _dropdownTile(
          label: "Active Currency Unit",
          value: _currentCurrency,
          items: const ["GH¢", r"$"],
          onChanged: (v) {
            _currentCurrency = v;
            _save(_kCurrency, v);
          },
        ),
        _divider(),
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          title: const Text("Automated Live Market Price Sync",
              style: _itemTitleStyle),
          subtitle: const Text(
            "Pull market pricing indices from central agricultural API",
            style: _subtitleStyle,
          ),
          value: _autoPriceSync,
          activeTrackColor: AppColors.neonOrange,
          activeThumbColor: Colors.white,
          onChanged: (v) {
            _autoPriceSync = v;
            _save(_kAutoPriceSync, v);
          },
        ),
        _divider(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Manual Price Override (per Metric Ton)",
                  style: _itemTitleStyle),
              const SizedBox(height: 8),
              TextField(
                controller: _manualPriceCtrl,
                enabled: manualEnabled,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  color: manualEnabled ? Colors.white : const Color(0xFF555555),
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: "e.g. 4500.00",
                  hintStyle: const TextStyle(color: Color(0xFF555555)),
                  prefixText: "$_currentCurrency ",
                  prefixStyle: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.3),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF333333)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: AppColors.neonOrange),
                  ),
                ),
                onChanged: (v) {
                  _manualPriceOverride = v;
                  _save(_kManualPrice, v);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────── MODULE E: USER & DIAGNOSTICS ───────────────

  Widget _buildDiagnosticsCard() {
    return _card(
      "USER DIAGNOSTICS & ACCOUNT",
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.neonOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_circle_rounded,
                color: AppColors.neonOrange, size: 28),
          ),
          title: const Text("Grading Officer / Field Agent",
              style: _itemTitleStyle),
          subtitle: const Text("RCEES Research Group",
              style: _subtitleStyle),
        ),
        _divider(),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.neonOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: AppColors.neonOrange, size: 28),
          ),
          title: const Text("App Version", style: _itemTitleStyle),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.activeGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              "1.0.0 (Stable Build)",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.activeGreen,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => LoginScreen(cameras: widget.cameras),
            ),
            (route) => false,
          );
        },
        icon: const Icon(Icons.logout_rounded, color: Color(0xFFE53935)),
        label: const Text(
          "LOG OUT FIELD PROFILE",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: Color(0xFFE53935),
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFE53935)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // ─────────────── SHARED BUILDERS ───────────────

  Widget _card(String header, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.containerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              header,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Color(0xFF9E9E9E),
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }

  Widget _dropdownTile({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: const Text("Camera Resolution Preset",
          style: _itemTitleStyle),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            dropdownColor: const Color(0xFF1A1A1A),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            icon: const Icon(Icons.expand_more_rounded,
                color: AppColors.neonOrange, size: 20),
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
      ),
    );
  }

  Widget _sliderTile({
    required String label,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label, style: _itemTitleStyle),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.neonOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  displayValue,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neonOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: _subtitleStyle),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.neonOrange,
              inactiveTrackColor: AppColors.neonOrange.withValues(alpha: 0.15),
              thumbColor: Colors.white,
              overlayColor: AppColors.neonOrange.withValues(alpha: 0.12),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  static const _itemTitleStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const _subtitleStyle = TextStyle(
    fontSize: 12,
    color: Color(0xFF9E9E9E),
  );
}
