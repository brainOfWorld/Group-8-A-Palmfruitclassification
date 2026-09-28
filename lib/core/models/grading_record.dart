import 'dart:convert';
import 'dart:math';

enum ScanSource { live, drone }

class GradingRecord {
  final String id;
  final String imagePath;
  final ScanSource source;
  final DateTime timestamp;
  final String gradeResult;
  final double confidenceScore;
  final Map<String, double> metrics;
  final String? batchSessionId;

  const GradingRecord({
    required this.id,
    required this.imagePath,
    required this.source,
    required this.timestamp,
    required this.gradeResult,
    required this.confidenceScore,
    required this.metrics,
    this.batchSessionId,
  });

  static String _generateId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  factory GradingRecord.create({
    required String imagePath,
    required ScanSource source,
    required String gradeResult,
    required double confidenceScore,
    required Map<String, double> metrics,
    String? batchSessionId,
  }) {
    return GradingRecord(
      id: _generateId(),
      imagePath: imagePath,
      source: source,
      timestamp: DateTime.now(),
      gradeResult: gradeResult,
      confidenceScore: confidenceScore,
      metrics: metrics,
      batchSessionId: batchSessionId,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'imagePath': imagePath,
        'source': source.name,
        'timestamp': timestamp.toIso8601String(),
        'gradeResult': gradeResult,
        'confidenceScore': confidenceScore,
        'metrics': metrics,
        'batchSessionId': batchSessionId,
      };

  factory GradingRecord.fromMap(Map<String, dynamic> map) {
    return GradingRecord(
      id: map['id'] as String,
      imagePath: map['imagePath'] as String? ?? '',
      source: ScanSource.values.firstWhere(
        (e) => e.name == map['source'],
        orElse: () => ScanSource.live,
      ),
      timestamp: DateTime.parse(map['timestamp'] as String),
      gradeResult: map['gradeResult'] as String,
      confidenceScore: (map['confidenceScore'] as num).toDouble(),
      metrics: Map<String, double>.from(
        (map['metrics'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as num).toDouble()),
            ) ??
            {},
      ),
      batchSessionId: map['batchSessionId'] as String?,
    );
  }
}
