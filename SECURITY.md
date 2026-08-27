# 🛡️ Security Policy — T7 HealthVault

T7 HealthVault is an offline-first Clinical Decision Support System (CDSS) and Electronic Health Record (EHR) platform. Because this software handles sensitive patient and clinical data, security, confidentiality, and data integrity are our highest priorities.

---

## 📦 Supported Versions

Only the latest production releases receive active security updates and patches:

| Version | Supported          | Status |
| ------- | ------------------ | ------ |
| 1.0.x   | :white_check_mark: | Active (Current Production Release) |
| < 1.0   | :x:                | Deprecated / Unsupported |

---

## 🔒 Security & Privacy Architecture

T7 HealthVault employs an enterprise-grade security posture:

1. **100% Offline-First (Zero Cloud Leakage)**:
   * Patient records, vital histories, and AI inferences are executed **strictly on-device**.
   * No protected health information (PHI) is ever transmitted to external cloud servers or unverified third-party endpoints.

2. **Encrypted Local Storage**:
   * All clinical tables, family demographics, and jurisdiction datasets are stored in encrypted local SQLite databases.

3. **Code Obfuscation & Binary Hardening**:
   * Production Android APKs are compiled with R8 code obfuscation, dead-code stripping, and isolated symbol maps to prevent decompilation and reverse-engineering of clinical IP.

4. **On-Device Machine Learning Safety**:
   * PhysioNet Sepsis ONNX models and GGUF neural weights run locally in an isolated sandbox with zero network telemetry.

---

## 🚨 Reporting a Vulnerability

We take all security and privacy reports seriously. If you discover a vulnerability, security flaw, or clinical calculation anomaly, please follow our responsible disclosure protocol:

### How to Report:
* **Email**: Please send a detailed security report to **`bharatha9483@gmail.com`**.
* **Subject Line**: `[SECURITY] T7 HealthVault Vulnerability Report`
* **Do NOT create public GitHub issues** for zero-day vulnerabilities or security exploits.

### What to Include:
1. Description of the vulnerability and its potential impact.
2. Step-by-step instructions or Proof of Concept (PoC) to reproduce the issue.
3. Affected device OS version and T7 HealthVault app build number.

### Our Response SLA:
* **Acknowledgment**: Within **24 to 48 hours**.
* **Assessment & Triage**: Within **3 business days**.
* **Remediation & Patch**: A security patch will be built, tested, and published to GitHub Releases as a high-priority hotfix.

---

## ⚖️ Intellectual Property & Compliance

T7 HealthVault is proprietary software. Reverse-engineering, unauthorized copying, or extracting machine learning models from compiled binaries is strictly prohibited under the [LICENSE](LICENSE).
