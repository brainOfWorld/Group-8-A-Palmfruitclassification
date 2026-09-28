import 'dart:io';
import 'dart:math' as math;
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;

class _PreprocessResult {
  final Float32List onnxInput;
  final Float32List tfliteInput;
  final bool decoded;
  const _PreprocessResult(this.onnxInput, this.tfliteInput, this.decoded);
}

_PreprocessResult _preprocessAll(Uint8List bytes) {
  img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return _PreprocessResult(
        Float32List(3 * 224 * 224), Float32List(224 * 224 * 3), false);
  }
  img.Image rawImg =
      decoded.numChannels == 4 ? decoded.convert(numChannels: 3) : decoded;
  final resized = img.copyResize(
    rawImg,
    width: 224,
    height: 224,
    interpolation: img.Interpolation.linear,
  );
  final onnx = Float32List(3 * 224 * 224);
  final tflite = Float32List(224 * 224 * 3);
  const stride = 224 * 224;
  int pIdx = 0;
  for (var y = 0; y < 224; y++) {
    for (var x = 0; x < 224; x++) {
      final pixel = resized.getPixel(x, y);
      final r = pixel.r.toDouble() / 255.0;
      final g = pixel.g.toDouble() / 255.0;
      final b = pixel.b.toDouble() / 255.0;
      tflite[pIdx++] = r;
      tflite[pIdx++] = g;
      tflite[pIdx++] = b;
      final index = y * 224 + x;
      onnx[index] = (r - 0.485) / 0.229;
      onnx[index + stride] = (g - 0.456) / 0.224;
      onnx[index + 2 * stride] = (b - 0.406) / 0.225;
    }
  }
  return _PreprocessResult(onnx, tflite, true);
}

class PalmClassifier {
  static final PalmClassifier _instance = PalmClassifier._internal();
  factory PalmClassifier() {
    _instance._ensureEngine();
    return _instance;
  }
  PalmClassifier._internal();

  Interpreter? _interpreter;
  OnnxRuntime? _onnxRuntime;
  OrtSession? _onnxSession;
  Future<void>? _initFuture;
  bool _usingOnnx = false;

  final List<String> labels = const [
    'Damaged',
    'Empty',
    'Negative',
    'Overripe',
    'Ripe',
    'Unripe'
  ];

  static const List<String> onnxLabels = [
    'Damaged',
    'Overripe',
    'Ripe',
    'Unripe',
  ];

  bool get isInitialized => _interpreter != null || _onnxSession != null;
  bool get isUsingOnnx => _usingOnnx;

  void _ensureEngine() {
    _initFuture ??= initModel();
  }

  Future<void> initModel() async {
    if (isInitialized) return;
    bool onnxOk = false;
    try {
      onnxOk = await _initOnnx();
    } catch (e) {
      debugPrint("PalmClassifier: ONNX init failed: $e");
    }
    try {
      await _initTflite();
    } catch (e) {
      debugPrint("PalmClassifier: TFLite init failed: $e");
    }
    if (!onnxOk && _interpreter == null) {
      debugPrint("PalmClassifier: Both engines failed");
    }
  }

  Future<bool> _initOnnx() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final modelPath = '${dir.path}/palm_fruit_backbone.onnx';
      final modelFile = File(modelPath);
      final data = await rootBundle.load('assets/palm_fruit_backbone.onnx');

      if (!modelFile.existsSync() ||
          modelFile.lengthSync() != data.lengthInBytes) {
        if (modelFile.existsSync()) {
          await modelFile.delete();
        }
        await modelFile.writeAsBytes(data.buffer.asUint8List());
        debugPrint(
            "PalmClassifier: ONNX model copied (${data.lengthInBytes} bytes)");
      }

      _onnxRuntime = OnnxRuntime();
      _onnxSession = await _onnxRuntime!.createSession(
        modelPath,
        options: OrtSessionOptions(intraOpNumThreads: 4),
      );
      _usingOnnx = true;
      debugPrint("PalmClassifier: ONNX engine ready (4 classes).");
      return true;
    } catch (e) {
      debugPrint("PalmClassifier: ONNX load failed: $e");
      _usingOnnx = false;
      return false;
    }
  }

  Future<void> _initTflite() async {
    final options = InterpreterOptions()..threads = 4;
    if (Platform.isAndroid) options.useNnApiForAndroid = false;
    _interpreter = await Interpreter.fromAsset(
      'assets/palm_model_v3.tflite',
      options: options,
    );
    _interpreter!.allocateTensors();
    debugPrint("PalmClassifier: TFLite engine ready (6 classes).");
  }

  Future<Map<String, dynamic>> classify(String imagePath) async {
    final fileBytes = await File(imagePath).readAsBytes();
    return classifyBytes(fileBytes);
  }

  Future<Map<String, dynamic>> classifyBytes(Uint8List bytes) async {
    await (_initFuture ??= initModel());
    final onnxOk = _usingOnnx && _onnxSession != null;
    final tfliteOk = _interpreter != null;
    debugPrint(
        "PalmClassifier: onnx=$onnxOk tflite=$tfliteOk usingOnnx=$_usingOnnx");
    if (onnxOk && tfliteOk) {
      return _classifyEnsemble(bytes);
    }
    if (onnxOk) {
      return _classifyOnnx(bytes);
    }
    return _classifyTflite(bytes);
  }

  // ───────────────────── ENSEMBLE PATH ─────────────────────

  Future<Map<String, dynamic>> _classifyEnsemble(Uint8List bytes) async {
    try {
      final processed = await Isolate.run(() => _preprocessAll(bytes));
      if (!processed.decoded) {
        return {'result': "Error Decoding", 'rawScores': <double>[]};
      }
      final results = await Future.wait([
        _runOnnx(processed.onnxInput),
        _runTflite(processed.tfliteInput),
      ]);
      final onnxLogits = results[0];
      final tfliteScores = results[1];
      debugPrint("PalmClassifier ensemble: onnx=$onnxLogits tflite=$tfliteScores");
      if (onnxLogits != null && tfliteScores != null) {
        return _computeEnsembleScores(onnxLogits, tfliteScores);
      }
      if (onnxLogits != null) {
        debugPrint("PalmClassifier: TFLite failed, using ONNX only");
        return _computeOnnxScores(onnxLogits);
      }
      if (tfliteScores != null) {
        debugPrint("PalmClassifier: ONNX failed, using TFLite only");
        return _computeTfliteScores(tfliteScores);
      }
      return {'result': "Inference Error", 'rawScores': <double>[]};
    } catch (e, stack) {
      debugPrint("PalmClassifier ensemble error: $e\n$stack");
      return {'result': "Error: $e", 'rawScores': <double>[]};
    }
  }

  Future<List<double>?> _runOnnx(Float32List input) async {
    try {
      final inputTensor =
          await OrtValue.fromList(input, [1, 3, 224, 224]);
      final inputName = _onnxSession!.inputNames.isNotEmpty
          ? _onnxSession!.inputNames.first
          : 'input_tensor';
      final outputs = await _onnxSession!.run({inputName: inputTensor});
      await inputTensor.dispose();
      if (outputs.isEmpty) return null;
      final outTensor = outputs[_onnxSession!.outputNames.first];
      if (outTensor == null) return null;
      final List<dynamic> outList = await outTensor.asFlattenedList();
      await outTensor.dispose();
      final logits =
          List<double>.from(outList.map((e) => (e as num).toDouble()));
      debugPrint("PalmClassifier ONNX raw logits: $logits");
      return logits;
    } catch (e) {
      debugPrint("PalmClassifier ONNX run failed: $e");
      return null;
    }
  }

  Future<List<double>?> _runTflite(Float32List input) async {
    if (_interpreter == null) return null;
    try {
      var output = List<double>.filled(6, 0).reshape([1, 6]);
      _interpreter!.run(input.reshape([1, 224, 224, 3]), output);
      final raw = List<double>.from(output[0]);
      debugPrint("PalmClassifier TFLite raw output: $raw");

      final isProbSpace =
          raw.every((v) => v >= 0) && (raw.reduce((a, b) => a + b) - 1.0).abs() < 0.05;
      if (!isProbSpace) {
        debugPrint("PalmClassifier: TFLite outputs logits, applying softmax");
        return _softmax(raw);
      }
      debugPrint("PalmClassifier: TFLite outputs probabilities (sum=${raw.reduce((a, b) => a + b)})");
      return raw;
    } catch (e) {
      debugPrint("PalmClassifier TFLite run failed: $e");
      return null;
    }
  }

  Map<String, dynamic> _computeEnsembleScores(
      List<double> onnxLogits, List<double> tfliteScores) {
    final onnxProbs = _softmax(onnxLogits);

    debugPrint("PalmClassifier ensemble ONNX probs: $onnxProbs");
    debugPrint("PalmClassifier ensemble TFLite probs: $tfliteScores");

    final negativeIdx = labels.indexOf('Negative');
    final emptyIdx = labels.indexOf('Empty');
    final negativeScore = tfliteScores[negativeIdx];
    final emptyScore = tfliteScores[emptyIdx];
    final tfliteMaxIdx = tfliteScores.indexOf(
        tfliteScores.reduce(math.max));
    final negativeTop = tfliteMaxIdx == negativeIdx;
    final emptyTop = tfliteMaxIdx == emptyIdx;

    final trainedReject = (negativeTop && negativeScore > 0.35) ||
        (emptyTop && emptyScore > 0.50) ||
        (negativeScore + emptyScore) > 0.60;

    final sorted = List<double>.from(onnxProbs)..sort((a, b) => b.compareTo(a));
    final top2gap = sorted[0] - sorted[1];
    double entropy = 0;
    for (final p in onnxProbs) {
      if (p > 0) entropy -= p * math.log(p);
    }
    final normEntropy = entropy / math.log(onnxProbs.length);
    final gateReject = top2gap < 0.12 && normEntropy > 0.75;

    debugPrint(
        "PalmClassifier rejection: neg=$negativeScore empty=$emptyScore "
        "trainedReject=$trainedReject top2gap=$top2gap entropy=$normEntropy gateReject=$gateReject");

    if (trainedReject || gateReject) {
      return {'result': "Not a Palm Fruit", 'rawScores': onnxProbs, 'isValid': false};
    }

    const tfliteToOnnx = [0, 3, 4, 5]; // Damaged, Overripe, Ripe, Unripe
    double fruitSum = 0;
    final tfliteFruit = List<double>.filled(onnxLabels.length, 0);
    for (var i = 0; i < tfliteFruit.length; i++) {
      tfliteFruit[i] = tfliteScores[tfliteToOnnx[i]];
      fruitSum += tfliteFruit[i];
    }
    if (fruitSum > 0) {
      for (var i = 0; i < tfliteFruit.length; i++) {
        tfliteFruit[i] /= fruitSum;
      }
    } else {
      for (var i = 0; i < tfliteFruit.length; i++) {
        tfliteFruit[i] = 1.0 / tfliteFruit.length;
      }
    }

    final blend = List<double>.generate(
        onnxLabels.length, (i) => 0.75 * onnxProbs[i] + 0.25 * tfliteFruit[i]);
    final blendSum = blend.reduce((a, b) => a + b);
    final finalProbs =
        blendSum > 0 ? blend.map((e) => e / blendSum).toList() : onnxProbs;

    debugPrint("PalmClassifier blend: $finalProbs");

    final maxP = finalProbs.reduce(math.max);
    if (maxP < 0.45) {
      debugPrint("PalmClassifier: Low confidence ($maxP < 0.45)");
      return {
        'result': "Low Confidence - Reposition Camera",
        'rawScores': finalProbs,
        'isValid': false,
      };
    }
    final topIdx = finalProbs.indexOf(maxP);
    debugPrint(
        "PalmClassifier FINAL: ${onnxLabels[topIdx]} ${(maxP * 100).toStringAsFixed(1)}%");
    return {
      'result': "${onnxLabels[topIdx]} ${(maxP * 100).toStringAsFixed(1)}%",
      'rawScores': finalProbs,
      'isValid': true,
    };
  }

  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce(math.max);
    final exp = logits.map((l) => math.exp(l - maxLogit)).toList();
    final sum = exp.reduce((a, b) => a + b);
    return exp.map((e) => e / sum).toList();
  }

  // ─────────────────────────── ONNX PATH ───────────────────────────

  Future<Map<String, dynamic>> _classifyOnnx(Uint8List bytes) async {
    try {
      final processed = await Isolate.run(() => _preprocessAll(bytes));
      if (!processed.decoded) {
        return {'result': "Error Decoding", 'rawScores': <double>[]};
      }
      final scores = await _runOnnx(processed.onnxInput);
      if (scores == null) {
        return {'result': "Inference Error", 'rawScores': <double>[]};
      }
      if (scores.length != onnxLabels.length) {
        return {
          'result': "Inference Error: unexpected output size ${scores.length}",
          'rawScores': scores
        };
      }
      return _computeOnnxScores(scores);
    } catch (e, stack) {
      debugPrint("PalmClassifier ONNX classify error: $e\n$stack");
      return {'result': "Error: $e", 'rawScores': <double>[]};
    }
  }

  Map<String, dynamic> _computeOnnxScores(List<double> logits) {
    final probs = _softmax(logits);
    debugPrint("PalmClassifier ONNX probs: $probs");

    final sorted = List<double>.from(probs)..sort((a, b) => b.compareTo(a));
    final top2gap = sorted[0] - sorted[1];

    double entropy = 0;
    for (final p in probs) {
      if (p > 0) entropy -= p * math.log(p);
    }
    final normEntropy = entropy / math.log(onnxLabels.length);

    if (top2gap < 0.12 && normEntropy > 0.75) {
      return {'result': "Not a Palm Fruit", 'rawScores': probs, 'isValid': false};
    }

    final absoluteMax = probs.reduce(math.max);
    final topIdx = probs.indexOf(absoluteMax);
    final topLabel = onnxLabels[topIdx];

    if (absoluteMax < 0.45) {
      return {
        'result': "Low Confidence - Reposition Camera",
        'rawScores': probs,
        'isValid': false,
      };
    }
    return {
      'result': "$topLabel ${(absoluteMax * 100).toStringAsFixed(1)}%",
      'rawScores': probs,
      'isValid': true,
    };
  }

  // ─────────────────────────── TFLITE PATH ───────────────────────────

  Future<Map<String, dynamic>> _classifyTflite(Uint8List bytes) async {
    if (_interpreter == null) {
      return {'result': "Model Not Loaded", 'rawScores': <double>[]};
    }
    try {
      final processed = await Isolate.run(() => _preprocessAll(bytes));
      if (!processed.decoded) {
        return {'result': "Error Decoding", 'rawScores': <double>[]};
      }
      final scores = await _runTflite(processed.tfliteInput);
      if (scores == null) {
        return {'result': "Inference Error", 'rawScores': <double>[]};
      }
      return _computeTfliteScores(scores);
    } catch (e, stack) {
      debugPrint("PalmClassifier TFLite classify error: $e\n$stack");
      return {'result': "Error: $e", 'rawScores': <double>[]};
    }
  }

  Map<String, dynamic> _computeTfliteScores(List<double> scores) {
    debugPrint("PalmClassifier TFLite scores: $scores");

    final sorted = List<double>.from(scores)..sort((a, b) => b.compareTo(a));
    final top2gap = sorted[0] - sorted[1];

    double entropy = 0;
    for (final s in scores) {
      if (s > 0) entropy -= s * math.log(s);
    }
    final normEntropy = entropy / math.log(labels.length);

    if (top2gap < 0.12 && normEntropy > 0.75) {
      return {'result': "Not a Palm Fruit", 'rawScores': scores, 'isValid': false};
    }

    final absoluteMax = scores.reduce(math.max);
    final topIdx = scores.indexOf(absoluteMax);
    final topLabel = labels[topIdx];

    if (topLabel == 'Negative' || topLabel == 'Empty') {
      return {'result': "Not a Palm Fruit", 'rawScores': scores, 'isValid': false};
    }
    if (absoluteMax < 0.45) {
      return {
        'result': "Low Confidence - Reposition Camera",
        'rawScores': scores,
        'isValid': false,
      };
    }
    return {
      'result': "$topLabel ${(absoluteMax * 100).toStringAsFixed(1)}%",
      'rawScores': scores,
      'isValid': true,
    };
  }

  Future<void> dispose() async {
    await _onnxSession?.close();
    _onnxSession = null;
    _onnxRuntime = null;
    _interpreter?.close();
    _interpreter = null;
    _initFuture = null;
  }
}
