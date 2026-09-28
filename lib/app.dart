import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'features/auth/login_screen.dart';
import 'core/state/grading_provider.dart';

class PalmApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  final GradingProvider gradingProvider;

  const PalmApp({
    super.key,
    required this.cameras,
    required this.gradingProvider,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<GradingProvider>.value(
      value: gradingProvider,
      child: MaterialApp(
        title: 'Palm Grader AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: LoginScreen(cameras: cameras),
      ),
    );
  }
}
