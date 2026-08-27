# T7 HealthVault — Flutter Application

**Developer & Author:** M M Bharath  
**Version:** 2.1.0  
**Platform:** Flutter (Android, Windows, Linux, macOS)  
**APK Artifact:** `build/app/outputs/flutter-apk/app-release.apk` (81.0 MB)

---

## 🌟 Overview

T7 HealthVault is an offline-first Community Electronic Health Record (EHR) and Clinical Decision Support application for healthcare workers.

### Key Capabilities
* **PhysioNet Sepsis Predictor (ONNX):** **0.9085 AUC-ROC** on 39,179 ICU patients; **96.0% accuracy**; 0.29 MB model footprint; < 5 ms inference time.
* **NEWS2 & DELTA Scoring:** UK Royal College of Physicians 0–20 standard + vital sign trend variations.
* **22 Scheduled Indian Languages:** 11 pre-installed core languages + 11 on-demand downloadable language packs.
* **On-Device Qwen3 Generative LLM:** Downloadable ~986 MB GGUF for full medical chat; triggers floating bottom-right chatbot only after download.
* **Local Database:** SQLite v4 with full household/family/vitals schemas.

---

## 🧪 Verification Commands

```bash
flutter analyze   # Checks for syntax, linter, and static analysis issues (0 issues)
flutter test      # Runs all widget and unit tests (100% pass)
flutter build apk --release # Generates release APK (81.0 MB)
```
