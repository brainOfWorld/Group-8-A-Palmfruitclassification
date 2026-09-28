# Palm Fruit Grader

An on-device artificial intelligence application for real-time classification and grading of oil palm fruits. Built with Flutter, the app runs exclusively on mobile hardware — no cloud inference required — making it fast, private, and usable in remote plantation settings with poor connectivity.

The application fuses two neural network models in an ensemble pipeline to deliver accurate grades (Ripe, Unripe, Overripe, Damaged), filtering out non-fruit captures and rejecting low-confidence frames.

---

## Table of Contents

- [Features](#features)
- [Models & Inference Pipeline](#models--inference-pipeline)
- [Screens & Workflows](#screens--workflows)
- [Grading Metrics](#grading-metrics)
- [Technology Stack](#technology-stack)
- [Getting Started](#getting-started)
- [Project Structure](#project-structure)
- [Model Assets](#model-assets)
- [Performance Optimizations](#performance-optimizations)
- [Limitations](#limitations)
- [License](#license)

---

## Features

| Feature | Description |
|---|---|
| **Live Scanner** | Real-time back-camera capture with laser-guide overlay, tap-to-focus, and flash control |
| **Ensemble Classification** | Fuses a 4-class ONNX backbone with a 6-class TFLite model for maximum accuracy |
| **Non-Fruit Rejection** | TFLite's trained `Negative` / `Empty` classes block non-fruit frames from being graded |
| **Field Map Batch** | Upload multiple gallery images and classify them in a batch with bounded concurrency |
| **Grading Metrics** | Computes derived indicators — color profile, texture density, and estimated oil content |
| **Reports & Analytics** | Aggregate statistics, grade distribution charts, oil content trends, and source breakdown |
| **Local Persistence** | Every grade is stored on-device with Hive; no accounts or cloud storage required |
| **Secure Access** | Optional biometric (fingerprint) authentication via local_auth |
| **Export Ready** | Report generation and CSV export for downstream record-keeping |

---

## Models & Inference Pipeline

The classifier uses an **ensemble of two models** running concurrently on the device:

### 1. TFLite Model — `palm_model_v3.tflite`
- 6 output classes: `Damaged`, `Empty`, `Negative`, `Overripe`, `Ripe`, `Unripe`
- Provides the trained rejection signal (`Negative` / `Empty`) that prevents empty captures and non-fruit frames from being graded
- Input layout: `[1, 224, 224, 3]` RGB, `0–1` normalized (NHWC)

### 2. ONNX Backbone — `palm_fruit_backbone.onnx`
- 4 output classes: `Damaged`, `Overripe`, `Ripe`, `Unripe`
- The primary driver of the final grade
- Input layout: `[1, 3, 224, 224]` RGB, ImageNet-normalized (NCHW)

### Ensemble Scoring
1. A single image decode/resize pass produces both tensor layouts.
2. Both engines infer concurrently (`ONNX` logits + `TFLite` scores).
3. TFLite raw outputs are softmaxed when logits are detected.
4. Negative/Empty dominance or high entropy/low gap triggers **rejection** → `"Not a Palm Fruit"`.
5. Fruit-class probabilities are blended **0.75 / 0.25** (ONNX-dominant) and renormalized.
6. Blended confidence below **0.45** returns `"Low Confidence — Reposition Camera"`.

> **Engine fallback:** If either engine fails to initialize or run, the app gracefully falls back to the remaining engine and logs the event in debug output.

---

## Screens & Workflows

### Scanner (Live)
- Opens the back camera with an animated laser-guide overlay.
- **Tap Capture** → still image is decoded once, classified through the ensemble, and the grade is shown instantly.
- Grade card displays class, confidence, color profile, texture density, and estimated oil content.
- **Log Grade** persists the record locally.

### Field Map (Batch / Drone)
- Pick multiple images from the gallery.
- Images are downscaled to **1280px** at pick time to keep decode fast.
- Batch runs with a bounded **4-worker concurrency pool** via isolates.
- Each valid image produces a graded record tagged with a shared batch session ID.

### Dashboard
- Summary of scans, grade distribution, and quick access to analytics.

### History
- Full list of recorded grades with detail view.

### Inference Center
- Filterable grid of records by source (`Drone` / `Live`).
- Aggregate statistics: total scans, average confidence, ripe/unripe/damaged distribution.
- **Analytical Report** page with:
  - Grade distribution pie chart
  - Color profile / texture density grouped bars
  - Oil content bar chart
  - Confidence-over-time trend line
  - Source breakdown and recommendation card

### Settings
- App preferences and authentication management.

---

## Grading Metrics

Per grade, three derived metrics are produced from the model's confidence and class:

| Metric | Range | Meaning |
|---|---|---|
| Color Profile | 0–100 % | Reflects expected skin color for the class |
| Texture Density | 0–100 % | Reflects surface texture consistency for the class |
| Est. Oil Content | 0–5 | Estimated oil yield indicator for the class |

---

## Technology Stack

- **Flutter** (Dart) — cross-platform UI
- **flutter_onnxruntime** — ONNX Runtime sessions (multi-threaded)
- **tflite_flutter** — TensorFlow Lite interpreter
- **camera** + **image_picker** — capture and gallery
- **image** — decode, resize, pixel access
- **provider** — state management
- **hive / hive_flutter** — local persistence
- **path_provider** — file system access
- **geolocator** — location services
- **local_auth** — biometric authentication
- **fl_chart** — analytical charts
- **csv** — export utilities
- **intl** — formatting

---

## Getting Started

### Prerequisites
- Flutter SDK (3.x, Dart 3.x)
- Android Studio / Android SDK (min SDK 24, target SDK 36) or Xcode for iOS

### Run
```bash
# Clone the repository
git clone https://github.com/brainOfWorld/Group-8-A-Palmfruitclassification.git
cd fruitclassification

# Fetch dependencies
flutter pub get

# Run on a connected device
flutter run
```

### Build APK
```bash
flutter build apk --debug     # debug build
flutter build apk --release   # release build
```

---

## Project Structure

```
fruitclassification/
├── assets/                        # Models and labels
│   ├── palm_fruit_backbone.onnx   # 4-class ONNX backbone
│   ├── palm_model_v3.tflite       # 6-class TFLite model
│   └── labels.txt                 # Class label order
├── lib/
│   ├── main.dart                  # App entry point
│   ├── app.dart                   # Root widget / routing
│   ├── core/
│   │   ├── models/                # GradingRecord data model
│   │   ├── state/                 # GradingProvider (Hive-backed)
│   │   └── theme/                 # Colors and theming
│   └── features/
│       ├── auth/                  # Login, signup, biometric
│       ├── classifier/            # Scanner UI + classifier engine
│       ├── field_map/             # Batch gallery processing
│       ├── history/               # Record history
│       ├── home/                  # Dashboard
│       ├── reports/               # Inference center + analytical report
│       └── settings/              # Settings screen
├── android/ ios/ linux/ macos/
└── windows/ web/                  # Platform scaffolding
```

### Key File: `lib/features/classifier/classifier_logic.dart`
The engine layer. Encapsulates model loading, preprocessing, concurrent inference, ensemble fusion, confidence gating, and graceful fallback between the ONNX and TFLite engines.

---

## Model Assets

| Asset | Size | Classes | Role |
|---|---|---|---|
| `palm_fruit_backbone.onnx` | ~17 MB | 4 | Grade backbone (primary) |
| `palm_model_v3.tflite` | ~2.7 MB | 6 | Rejection signal + secondary vote |
| `labels.txt` | 44 B | — | Label ordering reference |

Models are cached into the app's documents directory on first launch and verified against the bundled asset by size before each load.

---

## Performance Optimizations

- **Single decode pass** — both tensor layouts are produced from one decode/resize, avoiding duplicated work per frame.
- **Concurrent inference** — ONNX and TFLite run in parallel via `Future.wait`.
- **Multi-threaded runtimes** — 4 intra-op threads configured on both ONNX sessions and TFLite interpreters.
- **Isolate offload** — preprocessing runs inside an isolate to keep the UI thread responsive.
- **Bounded batch concurrency** — field-map batches run through a fixed 4-worker pool instead of unbounded `Future.wait`.
- **Pick-time downscaling** — gallery images are resized to 1280px by the picker before classification.

---

## Limitations

- The ensemble weights and rejection thresholds are tuned for palm-fruit captures; capturing non-fruit scenes may produce `"Not a Palm Fruit"` or `"Low Confidence"` results by design.
- ONNX class ordering is assumed from PyTorch's alphabetical export convention and verified empirically on-device via debug logs.
- First model load copies ~20 MB of assets to device storage and may take a few seconds.

---

## License

This project is the work of **Group 8 — Palm Fruit Classification**. All rights reserved.