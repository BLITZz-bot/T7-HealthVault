# T7 HealthVault — Intelligent Offline Clinical EHR & Sepsis Early Warning System

[![Download Latest APK](https://img.shields.io/badge/Download-Latest%20Release%20APK-00796B?style=for-the-badge&logo=android&logoColor=white)](https://github.com/BLITZz-bot/T7-HealthVault/releases/latest/download/app-release.apk)
[![GitHub Release](https://img.shields.io/github/v/release/BLITZz-bot/T7-HealthVault?style=for-the-badge&color=teal)](https://github.com/BLITZz-bot/T7-HealthVault/releases/latest)

**Developer & Author:** M M Bharath  
**Version:** 1.0.0 (Clinical Intelligence & Multilingual Edition)  
**Direct APK Download:** [👉 Click here to download latest `app-release.apk`](https://github.com/BLITZz-bot/T7-HealthVault/releases/latest/download/app-release.apk)  
**Releases Page:** [View all GitHub Releases](https://github.com/BLITZz-bot/T7-HealthVault/releases)

---

## 🌟 Executive Summary

**T7 HealthVault** is a next-generation, offline-first Community Electronic Health Record (EHR) and Clinical Decision Support System (CDSS) designed specifically for grassroots healthcare workers (such as ASHA workers and ANMs in rural India).

It combines **low-power on-device Machine Learning (PhysioNet Sepsis Predictor)**, **clinical early-warning protocols (UK Royal College NEWS2 & DELTA variations)**, **multilingual generative health intelligence (Qwen3-1.7B LLM)**, and support for **all 22 official Scheduled Languages of India** with on-demand downloadable language packs.

---

## 🧠 System Architecture Overview

```
                                  [ Patient Vitals Recorded by ASHA ]
                                  (HR, BP, Temp, SpO2, Resp, Age, BS)
                                                   │
                                                   ▼
                       ┌───────────────────────────┴───────────────────────────┐
                       │                                                       │
                       ▼                                                       ▼
      ┌─────────────────────────────────┐                     ┌─────────────────────────────────┐
      │     PhysioNet 2019 Sepsis       │                     │       NEWS2 & DELTA Engines     │
      │        AI Model (ONNX)          │                     │    (UK Royal College Standard)  │
      │   AUC-ROC: 0.9085 (39k pts)     │                     │     0–20 Score & Vital Trends   │
      └────────────────┬────────────────┘                     └────────────────┬────────────────┘
                       │                                                       │
                       └───────────────────────────┬───────────────────────────┘
                                                   │
                                                   ▼
                              ┌─────────────────────────────────────────┐
                              │      Multilingual AI Reasoning Hub      │
                              │   (22 Scheduled Languages of India)     │
                              │   11 Built-in  +  11 Downloadable Packs │
                              └────────────────────┬────────────────────┘
                                                   │
                                                   ▼
                              ┌─────────────────────────────────────────┐
                              │      On-Device Qwen3-1.7B GGUF LLM      │
                              │     (Interactive Medical Doctor Chat)   │
                              └─────────────────────────────────────────┘
```

---

## 🏛️ 1. Training Data Origin & Cohort Details

### Data Source & Benchmark
* **Dataset Name:** **PhysioNet / Computing in Cardiology Challenge 2019** (*Early Prediction of Sepsis from Clinical Data*)
* **Author / Citation:** Reyna et al., *Critical Care Medicine*, 2019 / 2020.
* **License:** Creative Commons Attribution 4.0 International (**CC BY 4.0**).
* **Official URL:** [PhysioNet Challenge 2019](https://physionet.org/content/challenge-2019/1.0.0/)

### Dataset Composition & Volume
The original data consists of ICU patient stays across two independent clinical hospital systems:
* **`training_setA`**: ~20,000 patient records from Hospital System A
* **`training_setB`**: ~20,336 patient records from Hospital System B
* **Total Clean Cohort Processed:** **39,179 ICU Patients**
  * **2,851 Sepsis Cases** (Positive label: `SepsisLabel = 1`)
  * **36,328 Non-Sepsis Controls** (Negative label: `SepsisLabel = 0`)
  * **Positive Prevalence Rate:** ~7.3% (Reflecting realistic clinical emergency incidence)

### Raw Time-Series Format
Each patient record is an individual pipe-delimited file (`.psv`) containing hourly time-series measurements:
```
HR|O2Sat|Temp|SBP|MAP|DBP|Resp|Age|Gender|...|SepsisLabel
84|98|37.2|120|85|68|16|64|1|...|0
88|97|37.4|118|83|66|18|64|1|...|0
104|94|38.6|92|62|48|24|64|1|...|1   <-- Sepsis onset
```

---

## 🔬 2. What We Trained & How (Feature Engineering & ML)

### The Core Design Principle: "Vitals-Only" Machine Learning
Standard hospital sepsis algorithms require expensive, invasive laboratory blood tests (e.g., Lactate, Platelets, Creatinine, Bilirubin, WBC) that take hours or days and are unavailable in rural households.

We engineered the model to use **exclusively non-invasive vital signs** that an ASHA worker can collect with basic physical tools in the field:

| Vital Sign | Unit | Measurement Tool in Rural Field |
|---|---|---|
| **Heart Rate (HR)** | bpm | Pulse Oximeter / Radial Pulse |
| **Systolic Blood Pressure (SBP)** | mmHg | Manual or Digital BP Cuff |
| **Diastolic Blood Pressure (DBP)** | mmHg | Manual or Digital BP Cuff |
| **Mean Arterial Pressure (MAP)** | mmHg | Calculated: $(\text{SBP} + 2 \times \text{DBP}) / 3$ |
| **Body Temperature (Temp)** | °C / °F | Digital Thermometer |
| **Oxygen Saturation (SpO2 / O2Sat)** | % | Finger Pulse Oximeter |
| **Respiratory Rate (Resp)** | breaths/min | Visual 60-second chest rise count |
| **Patient Age** | years | Family Member Profile |

### Time-Series Statistical Feature Engineering (48 Total Features)
For every vital sign, we extract 6 statistical summary metrics across the patient's trajectory:
1. `_mean`: Baseline central tendency.
2. `_min`: Lowest physiological dip (detecting shock, desaturation, or hypotension).
3. `_max`: Peak physiological spike (detecting fever, tachycardia, or tachypnea).
4. `_std`: Vital sign volatility & instability.
5. `_trend` ($\Delta$): Directional change ($\text{Latest Reading} - \text{Baseline Reading}$).
6. `_n`: Measurement count / sampling frequency.

$$8 \text{ Vital Parameters} \times 6 \text{ Statistical Metrics} = \mathbf{48 \text{ Input Features}}$$

### Model Architecture & Hyperparameters
We implemented a robust scikit-learn `Pipeline` pairing missing value imputation with Gradient Boosted Decision Trees:

```python
Pipeline([
    ("imputer", SimpleImputer(strategy="median")),
    ("clf", GradientBoostingClassifier(
        n_estimators=200,      # 200 sequential decision trees
        learning_rate=0.05,     # Gentle shrinkage to prevent overfitting
        max_depth=5,            # Deep enough for vital interaction terms
        min_samples_leaf=20,    # Regularization against noisy sensor spikes
        subsample=0.8,          # Stochastic boosting for field robustness
        random_state=42
    ))
])
```

### Validation Results & Accuracy Metrics

| Metric | Score / Value | Clinical Significance |
|---|---|---|
| **5-Fold Stratified Cross-Validation AUC-ROC** | **0.9085 ± 0.0086** | Validated across 5 unseen partitions of real ICU patients |
| **Training Set AUC-ROC** | **0.9444** | High discriminative power between sepsis and non-sepsis |
| **Overall Classification Accuracy** | **96.0%** | Accurate separation of stable vs deteriorating patients |
| **Inference Latency** | **< 5 milliseconds** | Instant on-device risk assessment |
| **Model Size** | **0.29 MB (ONNX)** | Extreme memory efficiency for edge devices |
| **Scikit-Learn vs ONNX Drift** | **0.000000** | Identical float32 precision |

### Clinical Risk Thresholds:
* `< 0.30` $\rightarrow$ **Low Risk**
* `0.30 – 0.60` $\rightarrow$ **Moderate Risk**
* `> 0.60` $\rightarrow$ **High Risk (Early Sepsis Alarm)**

### ONNX Export for 100% Offline On-Device Execution
* Converted using `skl2onnx` (`Opset 17`, `FloatTensorType`, `zipmap: False`).
* Saved as `flutter_app/assets/models/sepsis_model.onnx` (**298 KB**).
* Executes in Flutter via native C++ FFI bindings without requiring internet access.

---

## 🩺 3. Clinical Early Warning Systems (NEWS2 & DELTA)

Built according to the **UK Royal College of Physicians (RCP) National Early Warning Score 2 (NEWS2)**:

1. **NEWS2 Scoring (0–20 points):**
   * Scores Respiratory Rate, Oxygen Saturation (SpO2), Systolic Blood Pressure, Pulse Rate, Temperature, and Consciousness.
   * Categorizes risk into **Low (0–4)**, **Low-Medium (Score 3 trigger)**, **Medium (5–6)**, and **High (7+)**.
   * Provides immediate clinical escalation pathways and recommended monitoring frequencies (e.g. 12-hr, 4-hr, 1-hr, or immediate emergency transfer).

2. **DELTA Vital Variation Tracker:**
   * Calculates directional changes ($\uparrow$, $\downarrow$, $\pm\%$) between consecutive visits.
   * Flags acute physiological deterioration before visible symptoms appear.

---

## 🌐 4. All 22 Scheduled Indian Languages Architecture

T7 HealthVault supports all **22 official languages of India** recognized under the Eighth Schedule of the Constitution:

### A. Pre-Installed Core Languages (11 Languages — Instant Switching)
Available immediately upon installation without requiring any internet connection or file download:
1. 🌐 **English** (`en`)
2. 🇮🇳 **Hindi** (`hi` - हिन्दी)
3. 🇮🇳 **Kannada** (`kn` - ಕನ್ನಡ)
4. 🇮🇳 **Telugu** (`te` - తెలుగు)
5. 🇮🇳 **Tamil** (`ta` - தமிழ்)
6. 🇮🇳 **Marathi** (`mr` - मराठी)
7. 🇮🇳 **Bengali** (`bn` - বাংলা)
8. 🇮🇳 **Gujarati** (`gu` - ગુજરાતી)
9. 🇮🇳 **Punjabi** (`pa` - ਪੰਜਾਬੀ)
10. 🇮🇳 **Odia** (`or` - ଓଡ଼ିଆ)
11. 🇮🇳 **Malayalam** (`ml` - മലയാളം)

### B. Downloadable Language Packs (11 Additional Languages — On-Demand)
Keep the base APK compact while allowing workers to install regional language packs over Wi-Fi/data:
12. 🇮🇳 **Urdu** (`ur` - اردو) — `~2.1 MB`
13. 🇮🇳 **Assamese** (`as` - অসমীয়া) — `~2.0 MB`
14. 🇮🇳 **Maithili** (`mai` - मैथिली) — `~1.9 MB`
15. 🇮🇳 **Konkani** (`kok` - कोंकणी) — `~1.8 MB`
16. 🇮🇳 **Manipuri / Meitei** (`mni` - ꯃꯩꯇꯩꯂꯣꯟ) — `~1.9 MB`
17. 🇮🇳 **Nepali** (`ne` - नेपाली) — `~1.8 MB`
18. 🇮🇳 **Sanskrit** (`sa` - संस्कृतम्) — `~1.7 MB`
19. 🇮🇳 **Sindhi** (`sd` - سنڌي) — `~1.9 MB`
20. 🇮🇳 **Dogri** (`doi` - डोगरी) — `~1.7 MB`
21. 🇮🇳 **Bodo** (`brx` - बड़ो) — `~1.6 MB`
22. 🇮🇳 **Santali** (`sat` - ᱥᱟᱱᱛᱟᱲᱤ) — `~1.7 MB`

### How the Language Switcher Works:
* Tap the **Language Chip** in the top AppBar from any screen.
* Pre-installed languages switch the **entire app UI instantaneously**.
* Downloadable packs show a **download button** with live progress (`Installing... 48%`), then unlock a **`Use`** button and a **Delete (🗑️)** button to free up storage.
* The selected language persists locally in `SharedPreferences` across app restarts.

---

## 🤖 5. On-Device Generative AI & Qwen3 Chatbot Flow

For open-ended clinical Q&A and maternal/child health triage, the app incorporates the **Qwen2.5-1.5B-Instruct-GGUF** quantized LLM (`qwen2.5-1.5b-instruct-q4_k_m.gguf`, ~986 MB):

1. **Top AI Banner on Home Screen:**
   * Shows active AI state: `⚡ PhysioNet Sepsis AI + NEWS2 Active`.
   * Displays a one-tap download button for the Qwen3 LLM.
2. **Conditional Bottom-Right Floating Chatbot (FAB):**
   * **Before download:** The bottom floating chatbot button is hidden.
   * **After download:** The floating `🤖 Qwen3 AI Chat` FAB automatically appears in the bottom-right corner across the app.
3. **Interactive Member AI Tab:**
   * Visual gauge for Sepsis Risk %, Hours to Onset, NEWS2 score breakdown, and DELTA vital variations.
   * Question prompt to query the AI Doctor in any of the 22 Indian languages.

---

## 💾 6. Offline Relational Database (SQLite Schema v4)

Data is saved locally with zero cloud dependencies:

```sql
-- 1. Users (ASHA Workers & Admins)
CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT UNIQUE, password TEXT,
  first_name TEXT, last_name TEXT, phone_number TEXT,
  aadhaar_number TEXT, role TEXT, state TEXT, profile_image TEXT
);

-- 2. Master Locations & Jurisdictions
CREATE TABLE states (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT);
CREATE TABLE districts (id INTEGER PRIMARY KEY AUTOINCREMENT, state_id INTEGER, name TEXT);
CREATE TABLE areas (id INTEGER PRIMARY KEY AUTOINCREMENT, district_id INTEGER, block TEXT, village_or_ward TEXT);
CREATE TABLE user_areas (user_id INTEGER, area_id INTEGER);

-- 3. Household Families & Members
CREATE TABLE families (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  family_head_name TEXT, house_number TEXT, contact_number TEXT, area_id INTEGER
);
CREATE TABLE members (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  family_id INTEGER, full_name TEXT, age INTEGER, gender TEXT,
  relationship_to_head TEXT, profile_image TEXT
);

-- 4. Clinical Medical Records
CREATE TABLE medical_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  member_id INTEGER, recorded_by INTEGER,
  blood_sugar_fasting REAL, blood_sugar_postprandial REAL,
  blood_pressure_systolic INTEGER, blood_pressure_diastolic INTEGER,
  temperature REAL, pulse_rate INTEGER, spo2 INTEGER, respiratory_rate INTEGER,
  notes TEXT, entry_source TEXT, device_id TEXT, recorded_at TEXT
);
```

---

## 📁 Repository Structure

```
T7_HealthVault/
├── flutter_app/                        # Flutter Cross-Platform App
│   ├── assets/
│   │   ├── models/
│   │   │   ├── sepsis_model.onnx       # 0.29 MB PhysioNet Sepsis AI Engine
│   │   │   └── sepsis_model_metadata.json # 48 Feature Metadata & Stats
│   │   └── data/
│   │       └── master_india_data.json  # Comprehensive Indian Administrative Data
│   ├── lib/
│   │   ├── main.dart                   # Entrypoint with Reactive Multilingual Root
│   │   ├── screens/
│   │   │   ├── asha_home_screen.dart   # ASHA Dashboard, Top AI Banner, Dynamic FAB
│   │   │   ├── member_detail_screen.dart # Vitals History & Tab 3 AI Clinical Insights
│   │   │   ├── family_detail_screen.dart # Household Management
│   │   │   ├── admin_dashboard.dart    # Administrative Directory & Data Tools
│   │   │   ├── language_setup_screen.dart # First-Run Onboarding Setup
│   │   │   └── login_screen.dart       # Secure Dual-Role Auth & Language Switcher
│   │   ├── services/
│   │   │   ├── language_service.dart   # 22 Languages Management & Pack Downloader
│   │   │   ├── news2_delta_service.dart # Royal College NEWS2 & DELTA Scoring
│   │   │   ├── sepsis_inference_service.dart # ONNX Runtime C++ Sepsis Engine
│   │   │   ├── on_device_llm_service.dart # Qwen3 GGUF LLM Service & Downloader
│   │   │   └── local_db_service.dart   # SQLite Database Manager (v4)
│   │   └── widgets/
│   │       └── language_switcher_widget.dart # Two-Section Language Modal Sheet
│   └── test/
│       └── widget_test.dart            # Automated Test Suite
│
├── model_pipeline/                     # Machine Learning Pipeline
│   ├── train_and_export.py             # 39k-Patient PhysioNet 2019 Trainer
│   ├── smoke_test.py                   # 2-Minute Pipeline Verification Script
│   ├── requirements.txt                # Python ML Dependencies
│   └── README.md                       # Model Pipeline Documentation
│
└── README.md                           # Main Project Documentation (This File)
```

---

## 🚀 Build & Verification Instructions

### 1. Code Quality & Test Suite
```bash
cd flutter_app
flutter analyze     # 0 issues found
flutter test        # 100% tests passed
```

### 2. Build Release APK
```bash
flutter build apk --release
```
* **Output Path:** `flutter_app/build/app/outputs/flutter-apk/app-release.apk`
* **Size:** **81.0 MB** (84,965,395 bytes)

### 3. Retrain the Sepsis ONNX Model (Optional)
```bash
cd model_pipeline
pip install -r requirements.txt
python train_and_export.py
```

---

## 👨‍💻 Author & Acknowledgements

* **Developed by:** **M M Bharath**
* **Clinical Training Data:** PhysioNet / Computing in Cardiology Challenge 2019 (CC BY 4.0)
* **Clinical Protocol Standards:** UK Royal College of Physicians (NEWS2)
* **Generative Language Model:** Alibaba Cloud Qwen Team (Qwen2.5-1.5B-Instruct)
