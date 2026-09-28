import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

class HistoryService {
  static const String _boxName = "scanHistory";

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  // CALL THIS after your AI finishes a scan
  static Future<void> saveScan({
    required String result,
    required double confidence,
    required List<double> rawScores,
    String? imagePath,
  }) async {
    var box = Hive.box(_boxName);

    final newRecord = {
      'date': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
      'result': result,
      'confidence': confidence,
      'rawScores': rawScores,
      'imagePath': imagePath,
    };

    // Get current list, add new record at the start, and save
    List<dynamic> history = box.get('records', defaultValue: []);
    history.insert(0, newRecord); // Newest first
    await box.put('records', history);
  }

  static List<Map<String, dynamic>> getHistory() {
    var box = Hive.box(_boxName);
    List<dynamic> raw = box.get('records', defaultValue: []);
    return raw.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}