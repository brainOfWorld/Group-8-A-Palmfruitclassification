import 'package:flutter_test/flutter_test.dart';
import 'package:fruitclassification/app.dart';
import 'package:fruitclassification/core/state/grading_provider.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(PalmApp(
      cameras: [],
      gradingProvider: GradingProvider(),
    ));
    expect(find.byType(PalmApp), findsOneWidget);
  });
}
