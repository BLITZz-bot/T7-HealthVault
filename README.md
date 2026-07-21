# T7 HealthVault

**Developer / Credit:** M M Bharath

---

## Tech Stack & Libraries Used

### Frontend & Core
* **Framework:** Flutter (Dart SDK ^3.12.2)
* **UI Design System:** Material Design 3 (Custom Healthcare Teal Theme)

### Database & Storage
* **Local Relational Database:** `sqflite` (Mobile) & `sqflite_common_ffi` (Desktop: Windows, Linux, macOS)
* **Path Management:** `path` & `path_provider`

### Data Visualization & Utilities
* **Charts & Analytics:** `fl_chart` (Vitals and health trend plotting)
* **Date & Number Formatting:** `intl`
* **File Operations:** `file_picker` (JSON database backup & restore)
* **Networking:** `http`

### Backend Stack Architecture
* **Backend Framework:** Python 3.12, Django, Django REST Framework
* **Database Engine:** PostgreSQL
* **Authentication:** SimpleJWT (JSON Web Tokens), Django Auth
* **Configuration:** `python-decouple`, `django-cors-headers`

---

## Features & Functional Modules

* **Dual Role Portal**
  * **Admin Dashboard:** Manage ASHA workers, assign villages/blocks/districts, view systemic health metrics, export/import JSON database backups.
  * **ASHA Worker Portal:** Register families, manage member profiles, record clinical vital signs.
* **Health Metrics Logging**
  * Fasting & Postprandial Blood Sugar (mg/dL)
  * Systolic & Diastolic Blood Pressure (mmHg)
  * Body Temperature (°F) & Pulse Rate (bpm)
* **Data Visualization**
  * Dynamic line charts and trend tracking for patient vital histories.
* **Offline-First Storage**
  * Local SQLite storage with auto-seeded demo dataset and desktop/mobile FFI compatibility.

---

## Getting Started

### Prerequisites
* Flutter SDK (3.12+ recommended)
* Dart SDK

### Installation & Run Steps

1. Clone the repository:
   ```bash
   git clone https://github.com/BLITZz-bot/T7-HealthVault.git
   cd T7-HealthVault/flutter_app
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   flutter run
   ```

---

## Author

Developed by **M M Bharath**.
