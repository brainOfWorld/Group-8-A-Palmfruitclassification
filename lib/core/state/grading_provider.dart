import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/grading_record.dart';

class GradingProvider extends ChangeNotifier {
  static const String _boxName = 'gradingRecords';

  List<GradingRecord> _records = [];
  List<GradingRecord> get records => List.unmodifiable(_records);

  Future<void> init() async {
    await Hive.openBox(_boxName);
    _loadFromCache();
  }

  void _loadFromCache() {
    final box = Hive.box(_boxName);
    final raw = box.get('records', defaultValue: <dynamic>[]) as List<dynamic>;
    _records = raw
        .map((e) => GradingRecord.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    notifyListeners();
  }

  Future<void> addRecord(GradingRecord record) async {
    _records.insert(0, record);
    notifyListeners();
    _persist();
  }

  Future<void> _persist() async {
    try {
      final box = Hive.box(_boxName);
      await box.put('records', _records.map((r) => r.toMap()).toList());
    } catch (_) {}
  }
}
