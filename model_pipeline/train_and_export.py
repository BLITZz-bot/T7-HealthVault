# -*- coding: utf-8 -*-
"""
Hospital-Grade Clinical AI Model Training Pipeline
PhysioNet 2019 Computing in Cardiology Challenge + Clinical Emergency Indices

This script:
  1. Extracts multi-horizon sliding windows (1-visit spot checks, 3-6 visit trajectories, and 12-24h windows)
  2. Computes 62 clinical features (Vitals + Dynamics + Shock Index + qSOFA + Glucose + Pulse Pressure)
  3. Trains a tuned, class-balanced Gradient Boosted Decision Tree ensemble
  4. Exports to ONNX format (opset 17) for 100% on-device offline inference
  5. Synchronizes model & metadata to flutter_app/assets/models/
"""

import os
import sys
import time
import json
import shutil
import numpy as np
import pandas as pd
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm

from sklearn.ensemble import GradientBoostingClassifier
from sklearn.pipeline import Pipeline
from sklearn.impute import SimpleImputer
from sklearn.model_selection import StratifiedKFold, cross_val_score
from sklearn.metrics import roc_auc_score, average_precision_score, classification_report, confusion_matrix, brier_score_loss
from sklearn.utils.class_weight import compute_sample_weight
from skl2onnx import convert_sklearn
from skl2onnx.common.data_types import FloatTensorType
import onnxruntime as rt

# Paths
SCRIPT_DIR = Path(__file__).parent
ROOT_DIR = SCRIPT_DIR.parent
DATA_DIR = SCRIPT_DIR / "data"
MODEL_DIR = SCRIPT_DIR / "trained"
FLUTTER_ASSETS = ROOT_DIR / "flutter_app" / "assets" / "models"
DATASET_CACHE = DATA_DIR / "hospital_dataset_cache.parquet"

DATA_DIR.mkdir(parents=True, exist_ok=True)
MODEL_DIR.mkdir(parents=True, exist_ok=True)
FLUTTER_ASSETS.mkdir(parents=True, exist_ok=True)

# 9 Clinical Vital Channels (matched with ASHA field entry)
VITALS_CHANNELS = [
    "HR",       # Heart rate / Pulse rate (bpm)
    "SBP",      # Systolic BP (mmHg)
    "DBP",      # Diastolic BP (mmHg)
    "MAP",      # Mean Arterial Pressure (mmHg)
    "Temp",     # Body Temperature (°C)
    "O2Sat",    # Oxygen Saturation SpO2 (%)
    "Resp",     # Respiratory Rate (breaths/min)
    "Glucose",  # Blood Sugar (mg/dL)
    "Age",      # Patient Age (years)
]

# Statistics per vital (6 stats per channel -> 9 x 6 = 54 features)
STAT_NAMES = ["latest", "mean", "min", "max", "std", "trend"]

# 8 Clinical Emergency Indices
CLINICAL_INDICES = [
    "Shock_Index",            # HR / SBP (Normal: 0.5-0.7, Shock: > 0.9)
    "Modified_Shock_Index",   # HR / MAP (Normal: 0.7-1.3, Shock: > 1.3)
    "Pulse_Pressure",         # SBP - DBP (Narrow < 30 mmHg indicates shock)
    "qSOFA_Score",            # (Resp >= 22) + (SBP <= 100)
    "Temp_Deviation",         # |Temp - 37.0°C| (Severity of fever/hypothermia)
    "Hypoglycemia_Flag",      # Glucose < 70 mg/dL
    "Hyperglycemia_Flag",     # Glucose > 200 mg/dL
    "Hypoxemia_Flag",         # SpO2 < 92%
]

def build_feature_names():
    features = []
    for vital in VITALS_CHANNELS:
        for stat in STAT_NAMES:
            features.append(f"{vital}_{stat}")
    features.extend(CLINICAL_INDICES)
    return features

FEATURE_NAMES = build_feature_names()
LABEL_COL = "SepsisLabel"

def extract_features_from_window(df_window: pd.DataFrame, patient_age: float):
    """
    Computes the 62 clinical features from a window of vital observations.
    Works for 1 single spot-check (n=1) up to long histories (n=50).
    """
    row = {}
    
    # 1. Extract 9 vital series
    for col in VITALS_CHANNELS:
        if col == "Age":
            vals = pd.Series([patient_age] * len(df_window), dtype=float)
        elif col in df_window.columns:
            vals = df_window[col].dropna()
        else:
            vals = pd.Series([], dtype=float)
            
        n = len(vals)
        if n == 0:
            row[f"{col}_latest"] = np.nan
            row[f"{col}_mean"]   = np.nan
            row[f"{col}_min"]    = np.nan
            row[f"{col}_max"]    = np.nan
            row[f"{col}_std"]    = 0.0
            row[f"{col}_trend"]  = 0.0
        elif n == 1:
            v = float(vals.iloc[0])
            row[f"{col}_latest"] = v
            row[f"{col}_mean"]   = v
            row[f"{col}_min"]    = v
            row[f"{col}_max"]    = v
            row[f"{col}_std"]    = 0.0
            row[f"{col}_trend"]  = 0.0
        else:
            row[f"{col}_latest"] = float(vals.iloc[-1])
            row[f"{col}_mean"]   = float(vals.mean())
            row[f"{col}_min"]    = float(vals.min())
            row[f"{col}_max"]    = float(vals.max())
            row[f"{col}_std"]    = float(vals.std()) if n > 1 else 0.0
            row[f"{col}_trend"]  = float(vals.iloc[-1] - vals.iloc[0])

    # 2. Extract Clinical Emergency Indices from latest available vitals
    latest_hr  = row.get("HR_latest", np.nan)
    latest_sbp = row.get("SBP_latest", np.nan)
    latest_dbp = row.get("DBP_latest", np.nan)
    latest_map = row.get("MAP_latest", np.nan)
    latest_temp = row.get("Temp_latest", np.nan)
    latest_resp = row.get("Resp_latest", np.nan)
    latest_spo2 = row.get("O2Sat_latest", np.nan)
    latest_gluc = row.get("Glucose_latest", np.nan)

    # If DBP or MAP missing, derive if possible
    if np.isnan(latest_dbp) and not np.isnan(latest_sbp):
        latest_dbp = latest_sbp * 0.65
        row["DBP_latest"] = latest_dbp
    if np.isnan(latest_map) and not np.isnan(latest_sbp) and not np.isnan(latest_dbp):
        latest_map = latest_dbp + (latest_sbp - latest_dbp) / 3.0
        row["MAP_latest"] = latest_map

    # Shock Index = HR / SBP
    if not np.isnan(latest_hr) and not np.isnan(latest_sbp) and latest_sbp > 30:
        row["Shock_Index"] = float(latest_hr / latest_sbp)
    else:
        row["Shock_Index"] = np.nan

    # Modified Shock Index = HR / MAP
    if not np.isnan(latest_hr) and not np.isnan(latest_map) and latest_map > 20:
        row["Modified_Shock_Index"] = float(latest_hr / latest_map)
    else:
        row["Modified_Shock_Index"] = np.nan

    # Pulse Pressure = SBP - DBP
    if not np.isnan(latest_sbp) and not np.isnan(latest_dbp):
        row["Pulse_Pressure"] = float(latest_sbp - latest_dbp)
    else:
        row["Pulse_Pressure"] = np.nan

    # qSOFA Score = (Resp >= 22) + (SBP <= 100)
    qsofa = 0.0
    if not np.isnan(latest_resp) and latest_resp >= 22.0:
        qsofa += 1.0
    if not np.isnan(latest_sbp) and latest_sbp <= 100.0:
        qsofa += 1.0
    row["qSOFA_Score"] = qsofa

    # Temp Deviation from normal 37.0°C
    if not np.isnan(latest_temp):
        row["Temp_Deviation"] = float(abs(latest_temp - 37.0))
    else:
        row["Temp_Deviation"] = np.nan

    # Hypoglycemia Flag (< 70 mg/dL)
    if not np.isnan(latest_gluc):
        row["Hypoglycemia_Flag"] = 1.0 if latest_gluc < 70.0 else 0.0
        row["Hyperglycemia_Flag"] = 1.0 if latest_gluc > 200.0 else 0.0
    else:
        row["Hypoglycemia_Flag"] = 0.0
        row["Hyperglycemia_Flag"] = 0.0

    # Hypoxemia Flag (SpO2 < 92%)
    if not np.isnan(latest_spo2):
        row["Hypoxemia_Flag"] = 1.0 if latest_spo2 < 92.0 else 0.0
    else:
        row["Hypoxemia_Flag"] = 0.0

    return row

def parse_patient_file_multi_window(psv_path: Path):
    try:
        df = pd.read_csv(psv_path, sep="|")
        if df.empty or LABEL_COL not in df.columns:
            return []
        
        patient_age = float(df["Age"].dropna().iloc[0]) if "Age" in df.columns and len(df["Age"].dropna()) > 0 else 55.0
        total_rows = len(df)
        samples = []

        sepsis_indices = df.index[df[LABEL_COL] == 1].tolist()
        has_sepsis = len(sepsis_indices) > 0
        first_sepsis_idx = sepsis_indices[0] if has_sepsis else -1

        # 1. Spot check
        window_1 = df.iloc[:max(1, min(2, total_rows))]
        target_1 = 1 if has_sepsis and first_sepsis_idx < 6 else 0
        feat_1 = extract_features_from_window(window_1, patient_age)
        feat_1[LABEL_COL] = target_1
        samples.append(feat_1)

        # 2. Multi-hour trajectory
        if total_rows >= 4:
            end_idx = min(6, total_rows)
            window_2 = df.iloc[:end_idx]
            target_2 = 1 if has_sepsis and first_sepsis_idx < (end_idx + 6) else 0
            feat_2 = extract_features_from_window(window_2, patient_age)
            feat_2[LABEL_COL] = target_2
            samples.append(feat_2)

        # 3. Crash / Sepsis onset window
        if has_sepsis and first_sepsis_idx >= 3:
            start_s = max(0, first_sepsis_idx - 6)
            window_s = df.iloc[start_s:first_sepsis_idx + 1]
            feat_s = extract_features_from_window(window_s, patient_age)
            feat_s[LABEL_COL] = 1
            samples.append(feat_s)

        # 4. Long stable stay
        if not has_sepsis and total_rows >= 16:
            start_m = total_rows // 2
            window_m = df.iloc[start_m:start_m + 12]
            feat_m = extract_features_from_window(window_m, patient_age)
            feat_m[LABEL_COL] = 0
            samples.append(feat_m)

        return samples
    except Exception:
        return []

def load_or_build_dataset(data_folders: list[Path]):
    if DATASET_CACHE.exists():
        print(f"\n[1/5] Loading cached dataset from {DATASET_CACHE}...")
        try:
            df = pd.read_parquet(DATASET_CACHE)
            print(f"  [OK] Loaded {len(df):,} samples ({df[LABEL_COL].sum():,} danger cases)")
            return df
        except Exception:
            pass

    all_psv = []
    for folder in data_folders:
        all_psv.extend(sorted(folder.rglob("*.psv")))

    print(f"\n[1/5] Extracting multi-horizon clinical windows from {len(all_psv):,} patient files...")
    all_rows = []
    with ThreadPoolExecutor(max_workers=32) as pool:
        for res_list in tqdm(pool.map(parse_patient_file_multi_window, all_psv), total=len(all_psv), unit="patient"):
            if res_list:
                all_rows.extend(res_list)

    df_out = pd.DataFrame(all_rows)
    try:
        df_out.to_parquet(DATASET_CACHE, index=False)
        print(f"  [OK] Saved dataset cache: {DATASET_CACHE}")
    except Exception:
        pass
    print(f"  [OK] Dataset ready: {len(df_out):,} training samples, {df_out[LABEL_COL].sum():,} danger cases")
    return df_out

def train_hospital_grade_model(df: pd.DataFrame):
    feature_cols = [c for c in FEATURE_NAMES if c in df.columns]
    X = df[feature_cols].values.astype(np.float64)
    y = df[LABEL_COL].values.astype(np.int32)

    # Calculate balanced sample weights (giving adequate sensitivity to danger cases)
    # Balanced weighting scales positive cases to balance class prevalence
    weights = compute_sample_weight("balanced", y)

    print(f"\n[2/5] Training Class-Balanced Hospital-Grade Classifier ({len(feature_cols)} features)...")
    print(f"  Samples: {len(y):,} | Danger cases: {y.sum():,} | Stable cases: {(y == 0).sum():,}")

    imputer = SimpleImputer(strategy="median")
    X_imputed = imputer.fit_transform(X)

    clf = GradientBoostingClassifier(
        n_estimators=300,
        learning_rate=0.04,
        max_depth=5,
        min_samples_leaf=20,
        subsample=0.8,
        random_state=42,
    )

    clf.fit(X_imputed, y, sample_weight=weights)

    pipeline = Pipeline([
        ("imputer", imputer),
        ("clf", clf),
    ])

    y_prob = pipeline.predict_proba(X)[:, 1]
    train_auc = roc_auc_score(y, y_prob)
    train_pr = average_precision_score(y, y_prob)
    print(f"  Training ROC-AUC: {train_auc:.4f} | PR-AUC: {train_pr:.4f}")

    return pipeline, feature_cols

def export_onnx_model(pipeline, feature_cols: list, output_path: Path):
    print(f"\n[3/5] Exporting ONNX model to {output_path}...")
    initial_type = [("vitals_input", FloatTensorType([None, len(feature_cols)]))]
    
    onnx_model = convert_sklearn(
        pipeline,
        initial_types=initial_type,
        target_opset=17,
        options={type(pipeline.named_steps["clf"]): {"zipmap": False}},
    )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_bytes(onnx_model.SerializeToString())
    size_kb = output_path.stat().st_size / 1024
    print(f"  [OK] Saved ONNX Model: {output_path} ({size_kb:.1f} KB)")
    return output_path

def validate_onnx_parity(pipeline, onnx_path: Path, X_sample: np.ndarray):
    print("\n[4/5] Validating ONNX Runtime Parity...")
    sess = rt.InferenceSession(str(onnx_path))
    input_name = sess.get_inputs()[0].name

    X_test = X_sample[:200].astype(np.float32)
    sk_probs = pipeline.predict_proba(X_test)[:, 1]
    onnx_out = sess.run(None, {input_name: X_test})
    onnx_probs = onnx_out[1][:, 1]

    max_diff = np.abs(sk_probs - onnx_probs).max()
    print(f"  Max probability difference (sklearn vs ONNX): {max_diff:.8f}")
    assert max_diff < 1e-3, f"Parity mismatch! Diff={max_diff}"
    print("  [OK] ONNX Validation PASSED.")

def save_and_deploy_metadata(feature_cols: list, output_dirs: list[Path]):
    meta = {
        "model_version": "2.0.0-hospital-grade",
        "trained_on": "PhysioNet/CinC Challenge 2019 (CC BY 4.0) + Sliding Window Trajectories + Emergency Indices",
        "algorithm": "GradientBoostedTrees_Ensemble_300_Balanced",
        "n_features": len(feature_cols),
        "features": feature_cols,
        "vitals_channels": VITALS_CHANNELS,
        "clinical_indices": CLINICAL_INDICES,
        "label": "sepsis_and_clinical_deterioration_probability",
        "thresholds": {
            "normal":   "< 0.25  -> Normal / Low Risk (Routine community health monitoring)",
            "abnormal": "0.25 - 0.55 -> Abnormal / Moderate Risk (Physiological variation, monitor closely)",
            "danger":   "> 0.55  -> Critical Danger (Immediate Referral to Primary Health Centre)"
        },
        "disclaimer": (
            "Hospital-grade clinical decision support model trained on PhysioNet ICU vital dynamics "
            "and clinical emergency shock indices. Designed for decision support; healthcare professional "
            "judgment is always primary."
        )
    }

    for d in output_dirs:
        d.mkdir(parents=True, exist_ok=True)
        out_file = d / "sepsis_model_metadata.json"
        with open(out_file, "w") as f:
            json.dump(meta, f, indent=2)
        print(f"  [OK] Metadata deployed: {out_file}")

def main():
    start = time.time()
    print("=" * 65)
    print("  T7 HealthVault — Hospital-Grade Clinical AI Model Pipeline")
    print("=" * 65)

    data_folders = [
        DATA_DIR / "training_setA",
        DATA_DIR / "training_setB",
    ]

    df = load_or_build_dataset(data_folders)

    # Train model
    pipeline, feature_cols = train_hospital_grade_model(df)

    # Export ONNX
    onnx_file = MODEL_DIR / "sepsis_model.onnx"
    export_onnx_model(pipeline, feature_cols, onnx_file)

    # Validate ONNX
    X_val = df[feature_cols].values
    validate_onnx_parity(pipeline, onnx_file, X_val)

    # Deploy to Flutter assets
    print("\n[5/5] Deploying Model & Metadata to Flutter Assets...")
    flutter_onnx = FLUTTER_ASSETS / "sepsis_model.onnx"
    shutil.copy2(onnx_file, flutter_onnx)
    print(f"  [OK] Copied model to Flutter: {flutter_onnx}")

    save_and_deploy_metadata(feature_cols, [MODEL_DIR, FLUTTER_ASSETS])

    elapsed = time.time() - start
    print("\n" + "=" * 65)
    print(f"  [OK] SUCCESS! Training and Deployment finished in {elapsed/60:.1f} minutes.")
    print("=" * 65)

if __name__ == "__main__":
    main()
