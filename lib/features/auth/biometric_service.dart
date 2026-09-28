import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Checks whether biometric hardware is available and enrolled.
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on MissingPluginException {
      // Plugin not registered — requires hot restart, not hot reload
      return false;
    } catch (e) {
      debugPrint("Biometric availability check failed: $e");
      return false;
    }
  }

  /// Prompts the user to authenticate with their fingerprint/biometric.
  /// Returns `true` if authentication succeeded.
  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on MissingPluginException {
      return false;
    } catch (e) {
      debugPrint("Biometric auth failed: $e");
      return false;
    }
  }
}
