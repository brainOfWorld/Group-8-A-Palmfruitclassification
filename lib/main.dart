import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'app.dart';
import 'features/classifier/classifier_logic.dart';
import 'core/state/grading_provider.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  GradingProvider gradingProvider;

  try {
    await Hive.initFlutter();
    await Hive.openBox("userBox");
    gradingProvider = GradingProvider();
    await gradingProvider.init();
  } catch (e) {
    debugPrint("Hive init failed: $e");
    gradingProvider = GradingProvider();
  }

  try {
    final classifier = PalmClassifier();
    await classifier.initModel();
    _cameras = await availableCameras();
  } catch (e) {
    debugPrint("Hardware init failed: $e");
    _cameras = [];
  }

  runApp(PalmApp(cameras: _cameras, gradingProvider: gradingProvider));
}
