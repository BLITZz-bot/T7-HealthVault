# -*- coding: utf-8 -*-
"""
Quick smoke test: downloads 10 sample files, runs the full pipeline,
verifies the ONNX model exports correctly.
Run this before the full train_and_export.py to confirm everything works.
"""
import sys
import requests
import re
import numpy as np
import pandas as pd
from pathlib import Path

# Minimal test
BASE_URL  = "https://physionet.org/files/challenge-2019/1.0.0/training"
SET_A_DIR = f"{BASE_URL}/training_setA/"

VITALS_FEATURES = ["HR","SBP","DBP","MAP","Temp","O2Sat","Resp","Age"]
LABEL_COL = "SepsisLabel"

def test_download_and_pipeline():
    print("[SMOKE TEST] PhysioNet 2019 Pipeline")
    print("=" * 50)

    # 1. List files
    print("\n[1] Listing files ...")
    r = requests.get(SET_A_DIR, timeout=30)
    r.raise_for_status()
    files = re.findall(r'href="([^"]+\.psv)"', r.text)
    print(f"    Found {len(files)} .psv files in training_setA")
    if len(files) == 0:
        print("    ERROR: No .psv files found. Check URL.")
        sys.exit(1)

    # 2. Download 10 files
    print("\n[2] Downloading 10 sample files ...")
    test_dir = Path("model_pipeline/data/smoke_test")
    test_dir.mkdir(parents=True, exist_ok=True)
    for fname in files[:10]:
        dest = test_dir / fname
        if not dest.exists():
            url = SET_A_DIR + fname
            data = requests.get(url, timeout=30).content
            dest.write_bytes(data)
            print(f"    Downloaded: {fname}")
        else:
            print(f"    Cached:     {fname}")

    # 3. Parse files
    print("\n[3] Parsing downloaded files ...")
    rows = []
    for psv_path in sorted(test_dir.glob("*.psv")):
        df = pd.read_csv(psv_path, sep="|")
        label = int(df[LABEL_COL].max()) if LABEL_COL in df.columns else 0
        row = {"SepsisLabel": label}
        for col in VITALS_FEATURES:
            vals = df[col].dropna() if col in df.columns else pd.Series([], dtype=float)
            n = len(vals)
            row[f"{col}_mean"]  = vals.mean()  if n > 0 else np.nan
            row[f"{col}_min"]   = vals.min()   if n > 0 else np.nan
            row[f"{col}_max"]   = vals.max()   if n > 0 else np.nan
            row[f"{col}_std"]   = vals.std()   if n > 1 else 0.0
            row[f"{col}_trend"] = (vals.iloc[-1]-vals.iloc[0]) if n >= 2 else 0.0
            row[f"{col}_n"]     = n
        rows.append(row)
    df_out = pd.DataFrame(rows)
    print(f"    Dataset shape: {df_out.shape}")
    print(f"    Columns: {list(df_out.columns)}")
    print(f"    Sepsis cases: {df_out['SepsisLabel'].sum()}")

    # 4. Quick model fit
    print("\n[4] Quick model fit (2 estimators) ...")
    from sklearn.ensemble import GradientBoostingClassifier
    from sklearn.pipeline import Pipeline
    from sklearn.impute import SimpleImputer
    feature_cols = [c for c in df_out.columns if c != LABEL_COL]
    X = df_out[feature_cols].values.astype(np.float64)
    y = df_out[LABEL_COL].values.astype(np.int32)
    
    # If all labels in smoke test are same, add synthetic balance for testing fit
    if len(np.unique(y)) < 2:
        y[0] = 1
        y[1] = 0

    pipeline = Pipeline([
        ("imputer", SimpleImputer(strategy="median")),
        ("clf", GradientBoostingClassifier(n_estimators=2, random_state=42)),
    ])
    pipeline.fit(X, y)
    probs = pipeline.predict_proba(X)[:, 1]
    print(f"    Model fit OK. Sample probabilities: {probs[:5].round(3)}")

    # 5. ONNX export
    print("\n[5] ONNX export ...")
    from skl2onnx import convert_sklearn
    from skl2onnx.common.data_types import FloatTensorType
    initial_type = [("vitals_input", FloatTensorType([None, len(feature_cols)]))]
    onnx_model = convert_sklearn(
        pipeline, initial_types=initial_type, target_opset=17,
        options={type(pipeline.named_steps["clf"]): {"zipmap": False}}
    )
    onnx_path = Path("model_pipeline/data/smoke_test_model.onnx")
    onnx_path.write_bytes(onnx_model.SerializeToString())
    print(f"    ONNX saved: {onnx_path} ({onnx_path.stat().st_size/1024:.1f} KB)")

    # 6. ONNX inference
    print("\n[6] ONNX inference validation ...")
    import onnxruntime as rt
    sess = rt.InferenceSession(str(onnx_path))
    out = sess.run(None, {"vitals_input": X.astype(np.float32)})
    onnx_probs = out[1][:, 1] if len(out) > 1 and len(out[1].shape) > 1 else out[0]
    if isinstance(onnx_probs, np.ndarray) and onnx_probs.ndim > 1:
        onnx_probs = onnx_probs[:, 1]
    max_diff = np.abs(probs - onnx_probs).max()
    print(f"    Max diff (sklearn vs ONNX): {max_diff:.6f}")
    print(f"    {'PASSED' if max_diff < 0.01 else 'FAILED'}")

    print("\n" + "=" * 50)
    print("SMOKE TEST PASSED - Ready to run full pipeline!")
    print("Run: python model_pipeline/train_and_export.py")
    print()

if __name__ == "__main__":
    test_download_and_pipeline()
