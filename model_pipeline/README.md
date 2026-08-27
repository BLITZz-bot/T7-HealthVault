# Model Pipeline — PhysioNet 2019 Sepsis Model

## What this does

Trains a sepsis risk prediction model using real PhysioNet 2019 ICU data,
exports it to ONNX, and copies it to Flutter for on-device inference.

## Prerequisites

Python 3.10+ with pip. All packages install automatically.

```powershell
pip install scikit-learn numpy pandas requests onnx skl2onnx onnxruntime tqdm
```

## Step 1 — Smoke Test (2 minutes)

Always run this first. Downloads 10 sample files and validates the full pipeline:

```powershell
python model_pipeline/smoke_test.py
```

Expected output: `SMOKE TEST PASSED`

## Step 2 — Full Training (~2-4 hours)

```powershell
python model_pipeline/train_and_export.py
```

This will:
1. Download all 40,336 patient .psv files from PhysioNet (free, CC BY 4.0)
2. Extract vitals-only features: HR, SBP, DBP, MAP, Temp, SpO2, RR, Age
3. Train a HistGradientBoosting classifier (handles missing values natively)
4. Cross-validate (5-fold AUC-ROC expected: ~0.72-0.78 for vitals-only)
5. Export to `model_pipeline/trained/sepsis_model.onnx`
6. Validate ONNX output matches sklearn output
7. Copy to `flutter_app/assets/models/sepsis_model.onnx`

## Output

| File | Location |
|------|----------|
| `sepsis_model.onnx` | `flutter_app/assets/models/` |
| `sepsis_model_metadata.json` | `flutter_app/assets/models/` |

## Download size

- training_setA: ~20,000 patients (~400 MB)
- training_setB: ~20,336 patients (~400 MB)
- Total: ~800 MB disk space during download, kept for reuse

## Rerunning

The script is idempotent — already-downloaded files are skipped automatically.
If you interrupt and restart, it resumes from where it left off.

## What the model predicts

Input (per-patient aggregated vitals):
- HR (Heart Rate) — mean, min, max, std, trend
- SBP/DBP/MAP (Blood Pressure)
- Temp (Temperature)
- O2Sat (SpO2)
- Resp (Respiratory Rate)
- Age

Output:
- Sepsis risk probability: 0.0 (no risk) → 1.0 (high risk)
- Threshold: < 0.30 Low Risk | 0.30-0.60 Moderate | > 0.60 High Risk

## License

Data: PhysioNet/Computing in Cardiology Challenge 2019 (CC BY 4.0)
Citation: Reyna et al., Critical Care Medicine, 2020.
https://physionet.org/content/challenge-2019/1.0.0/
