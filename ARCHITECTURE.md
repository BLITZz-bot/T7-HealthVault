# T7 HealthVault — System Architecture & Engineering Specification

## 1. Executive Summary

**T7 HealthVault** is an enterprise-grade, offline-first clinical Electronic Health Record (EHR) and Decision Support System engineered specifically for **Accredited Social Health Activists (ASHA)**, Community Health Officers (CHOs), and Primary Health Centres (PHCs) across India.

The platform provides:
* **100% Offline Clinical Intelligence**: Real-time triage, maternal health monitoring, sepsis risk scoring, and longitudinal physiological delta tracking.
* **On-Device Generative AI (LLM)**: Quantized on-device GGUF neural weights (`Qwen2.5-1.5B-Instruct-Q4_K_M`) capable of zero-latency, open-ended clinical reasoning in low-connectivity rural environments.
* **Pan-India Multilingual Support**: Dynamic bi-directional clinical explanations across **all 22 Scheduled Indian Languages + English**.
* **Zero-Leakage Privacy**: ABHA-compliant patient record architecture where all patient health data is processed and stored locally on the device.

---

## 2. System Architecture & Component Topology

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           PRESENTATION LAYER                            │
│  ┌───────────────────────┐  ┌───────────────────────┐  ┌─────────────┐  │
│  │   ASHA Home Screen    │  │ Member Detail Screen  │  │  AI Chat    │  │
│  │ (Demographics/Search) │  │  (EHR & Vital Trends) │  │   Modal     │  │
│  └───────────┬───────────┘  └───────────┬───────────┘  └──────┬──────┘  │
└──────────────┼──────────────────────────┼─────────────────────┼─────────┘
               │                          │                     │
┌──────────────▼──────────────────────────▼─────────────────────▼─────────┐
│                         DOMAIN & LOGIC SERVICES                         │
│  ┌─────────────────────────┐  ┌──────────────────────────────────────┐  │
│  │   LanguageService       │  │       OnDeviceLLMService             │  │
│  │ • 22 Indian Languages   │  │ • HTTP Range Resumable Downloader    │  │
│  │ • Clinical Dictionaries │  │ • GGUF Neural Model Runtime          │  │
│  └─────────────────────────┘  └──────────────────────────────────────┘  │
│  ┌─────────────────────────┐  ┌──────────────────────────────────────┐  │
│  │ NEWS2 & Delta Engine    │  │     Sepsis Inference Service         │  │
│  │ • Vital score triage    │  │ • Deterioration Risk % Prediction    │  │
│  │ • Historical trajectory │  │ • Clinical Red Flag Alerting         │  │
│  └─────────────────────────┘  └──────────────────────────────────────┘  │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────────────┐
│                      DATA PERSISTENCE LAYER (LOCAL)                     │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                    LocalDBService (SQLite)                        │  │
│  │ • `families` table (Head of household, Ward, Village relation)    │  │
│  │ • `members` table (Demographics, ABHA ID, Pregnancy, Chronic)     │  │
│  │ • `vitals` table (BP, HR, SpO2, Temp, Glucose, RR, NEWS2)         │  │
│  │ • `jurisdictions` table (National > State > District > PHC tree)  │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Directory & Folder Structure

```
flutter_app/
├── lib/
│   ├── core/                        # Application Core
│   │   ├── constants/               # System thresholds, URLs, storage keys
│   │   │   └── app_constants.dart
│   │   └── theme/                   # Material 3 Design System
│   │       └── app_theme.dart
│   │
│   ├── models/                      # Strongly-Typed Domain Entities
│   │   ├── clinical_models.dart     # NEWS2ScoreResult, SepsisRiskResult, VitalRecordModel
│   │   ├── family_model.dart        # FamilyModel & metadata
│   │   ├── member_model.dart        # MemberModel demographic & clinical entity
│   │   ├── jurisdiction_model.dart  # Master Administrative Hierarchy
│   │   └── models.dart              # Barrel export
│   │
│   ├── services/                    # Business Logic & Infrastructure Services
│   │   ├── local_db_service.dart    # SQLite persistence & migrations
│   │   ├── on_device_llm_service.dart# Resumable GGUF downloader & reasoning engine
│   │   ├── language_service.dart    # 22 Scheduled Indian Languages + English
│   │   ├── news2_delta_service.dart # Longitudinal physiological delta calculator
│   │   ├── sepsis_inference_service.dart # Sepsis risk & deterioration ML engine
│   │   └── app_update_service.dart  # In-app update & integrity verification
│   │
│   ├── widgets/                     # Reusable UI Component Library
│   │   ├── language_switcher_widget.dart
│   │   ├── qwen_ai_chat_modal.dart  # Universal T7 Clinical AI Chatbot
│   │   └── searchable_dropdown.dart # Filterable jurisdiction & selection dropdown
│   │
│   ├── screens/                     # Feature Screens
│   │   ├── login_screen.dart        # Role-based authentication
│   │   ├── language_setup_screen.dart # First-run regional language onboarding
│   │   ├── asha_home_screen.dart    # Field dashboard & active AI banner
│   │   ├── family_detail_screen.dart# Household registry
│   │   ├── member_detail_screen.dart# Clinical charts, NEWS2 & vital recorder
│   │   ├── admin_dashboard.dart     # Administrative analytics
│   │   ├── admin_settings_screen.dart
│   │   └── master_jurisdiction_editor_screen.dart # Administrative hierarchy editor
│   │
│   └── main.dart                    # Application bootstrap & dependency initialization
```

---

## 4. On-Device LLM & Multilingual Inference Pipeline

### 4.1 Resumable HTTP Chunk Downloader
The GGUF model weights (~1.04 GB) are downloaded via an enterprise-grade streaming engine:
* **HTTP Range Requests**: Implements `Range: bytes=<existing_bytes>-` to allow pausing and resuming at exact byte boundaries.
* **Redirect Preservation**: Handles HTTP 301/302/307 CDN redirects while forwarding the Range header to the final storage node.
* **Crash-Resilience**: Incomplete downloads persist in a `.tmp` file. If the app is closed or killed, next startup automatically detects existing progress and enables immediate one-tap resuming.
* **Storage Reclaim**: Complete deletion of local GGUF weights and partial temp files at any time via the UI.

### 4.2 Dual-Layer AI Architecture
```
User Query / Patient Vitals
          │
          ▼
┌────────────────────────────────────────────────────────┐
│  Layer 1: On-Device Generative Engine                  │
│  • Qwen2.5-1.5B quantized GGUF weights                │
│  • Open-ended contextual natural language synthesis   │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│  Layer 2: Clinical Safety & Protocol Guardrails        │
│  • National Health Mission (NHM) / WHO Guidelines      │
│  • Standard Emergency Antipyretic & ORS Dosages        │
│  • 108 Emergency Ambulance Red-Flag Detection          │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
4-Part Actionable Clinical Consultation (Translated to Active Language)
```

---

## 5. Clinical Decision Support Specifications

### 5.1 NEWS2 Scoring Engine
Implements the National Early Warning Score 2 (NEWS2) standard across 6 physiological parameters:
1. **Respiration Rate**: Normal (12–20 bpm), Alert (< 8 or > 25 bpm).
2. **Oxygen Saturations (SpO2)**: Normal (≥ 96%), Moderate (94–95%), Critical (≤ 91%).
3. **Systolic Blood Pressure**: Normal (111–219 mmHg), Critical (≤ 90 mmHg).
4. **Pulse / Heart Rate**: Normal (51–90 bpm), Critical (< 40 or > 130 bpm).
5. **Temperature**: Normal (36.1–38.0°C / 96.9–100.4°F), High (≥ 39.1°C / 102.4°F).
6. **Blood Glucose & Consciousness**: Rapid hypoglycemia alerts (< 70 mg/dL).

### 5.2 Longitudinal Delta Tracking
Calculates vital changes between consecutive visits:
$$\Delta \text{Parameter} = \text{Current Value} - \text{Previous Value}$$
Highlights acute trends (e.g., sudden BP drop + heart rate spike indicative of impending septic shock).

---

## 6. Security, Compliance & Privacy

* **Zero Telemetry Leakage**: No patient names, ABHA numbers, or vital readings are transmitted to external servers.
* **100% On-Device Processing**: Sepsis ML inference, NEWS2 calculations, and LLM generative advice execute locally on mobile CPU/GPU.
* **ACID SQLite Transactions**: Database writes use parameter binding and transaction envelopes to prevent database corruption during sudden battery exhaustion.
