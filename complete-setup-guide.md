# Complete Setup Guide — VS Code + PostgreSQL + Django + Flutter

This is the full path from a clean Windows machine to a running Django backend
(connected to PostgreSQL) and a Flutter app talking to it. Follow the steps in order.

---

## PART 1 — Install the Core Tools

### 1.1 Install VS Code
1. Go to https://code.visualstudio.com/
2. Download the Windows installer, run it
3. During install, check these boxes (they're usually pre-checked):
   - "Add to PATH"
   - "Add 'Open with Code' action to Windows Explorer context menu"

### 1.2 Install Python
1. Go to https://www.python.org/downloads/ → download latest **Python 3.12.x**
2. Run installer → **check "Add python.exe to PATH"** at the bottom of the first screen (easy to miss, very important)
3. Click "Install Now"
4. Verify — open PowerShell and run:
   ```powershell
   python --version
   ```
   Should print something like `Python 3.12.x`

### 1.3 Install PostgreSQL
1. Go to https://www.postgresql.org/download/windows/ → use the EDB installer
2. Run installer, keep default install path
3. When it asks for a password for the `postgres` superuser — **set one and remember it** (you'll use it everywhere below, e.g. `bharatha01`)
4. Keep default port `5432`
5. When Stack Builder launches at the end → **click Cancel** (you don't need any add-ons)
6. Note the version number you installed (e.g. 17 or 18) — you'll need this for the file path later

### 1.4 Install Git
1. Go to https://git-scm.com/download/win → run installer with all defaults
2. Verify:
   ```powershell
   git --version
   ```

### 1.5 Install Flutter SDK
1. Go to https://docs.flutter.dev/get-started/install/windows
2. Download the Flutter SDK zip
3. Extract it to a path with **no spaces**, e.g. `C:\src\flutter`
4. Add `C:\src\flutter\bin` to your Windows PATH:
   - Search "Environment Variables" in Windows search → Edit the system environment variables → Environment Variables → under "User variables", select `Path` → Edit → New → paste `C:\src\flutter\bin`
5. Verify (open a **new** PowerShell window):
   ```powershell
   flutter --version
   ```
6. Run:
   ```powershell
   flutter doctor
   ```
   Fix whatever it flags (usually Android Studio / Android SDK / license acceptance — see 1.6)

### 1.6 Install Android Studio (for Android SDK + emulator, not for coding)
1. Download from https://developer.android.com/studio
2. Install, open it once, let it install the Android SDK (default settings are fine)
3. In PowerShell:
   ```powershell
   flutter doctor --android-licenses
   ```
   Accept all licenses (type `y` repeatedly)
4. Re-run `flutter doctor` — should now show mostly green checkmarks

---

## PART 2 — Set Up VS Code Extensions

Open VS Code → click the Extensions icon (left sidebar, or `Ctrl+Shift+X`) → install:

| Extension | Publisher | Purpose |
|---|---|---|
| Flutter | Dart Code | Flutter dev, hot reload, debugging (auto-installs Dart extension) |
| Python | Microsoft | Python/Django support |
| Pylance | Microsoft | Better autocomplete (usually auto-installed with Python) |
| Docker | Microsoft | Manage containers if you use them later |
| SQLTools | Matheus Teixeira | Query Postgres from inside VS Code |
| SQLTools PostgreSQL Driver | Matheus Teixeira | Driver for the above |
| GitLens | GitKraken | Git history/blame inline |
| Thunder Client | Ranga Vadhineni | Test API endpoints without leaving VS Code |
| Error Lens | Alexander | Shows errors inline instead of only in Problems tab |

---

## PART 3 — Create Your Project Folder Structure

Open PowerShell:
```powershell
mkdir "D:\Projects\T7_HealthVault"
cd "D:\Projects\T7_HealthVault"
mkdir backend_django
mkdir flutter_app
code .
```
`code .` opens the whole folder in VS Code. This is your project root going forward.

---

## PART 4 — Create the Database & User (correct, safe way)

Open a terminal **inside VS Code** (`` Ctrl+` ``, or Terminal → New Terminal). Make sure it's PowerShell.

First, find your actual PostgreSQL install folder (version might be 17 or 18):
```powershell
dir "C:\Program Files\PostgreSQL"
```
Use whatever version number shows up in the commands below — replace `18` if yours is different.

```powershell
# 1. Create the database
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d postgres -c "CREATE DATABASE asha_health_db;"

# 2. Create the app's database user (NOT superuser)
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d postgres -c "CREATE USER asha_admin WITH PASSWORD 'admin';"

# 3. Give this user full control of ONLY this one database
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE asha_health_db TO asha_admin;"
& "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d postgres -c "ALTER DATABASE asha_health_db OWNER TO asha_admin;"
```
You'll be prompted for the `postgres` password each time — enter what you set during install.

> Why not `SUPERUSER` on `asha_admin`? Because that would give your app's DB user control over the entire Postgres server, not just its own database. Scoping it to one database is safer and is what you'd want in production anyway.

---

## PART 5 — Initialize the Django Project

Inside your VS Code terminal:
```powershell
# 1. Move into the backend folder
cd "D:\Projects\T7_HealthVault\backend_django"

# 2. Create a Python virtual environment
python -m venv venv

# 3. Activate it
.\venv\Scripts\Activate.ps1
```
If you get a "running scripts is disabled" error, run this once (as your normal user, not admin):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
Then retry activating. Your terminal prompt should now show `(venv)` at the start.

```powershell
# 4. Install required packages
pip install django psycopg2-binary djangorestframework django-cors-headers djangorestframework-simplejwt python-decouple

# 5. Start the Django project (the trailing dot matters — keeps manage.py at this folder level)
django-admin startproject asha_backend .

# 6. Create your app
python manage.py startapp health_api
```

At this point, in VS Code's Explorer sidebar, open the `backend_django` folder — you should see `manage.py`, `asha_backend/`, and `health_api/`.

---

## PART 6 — Store Secrets Safely (do this before settings.py)

Create a file named `.env` inside `backend_django/` (same level as `manage.py`):
```
DB_NAME=asha_health_db
DB_USER=asha_admin
DB_PASSWORD=bharatha01
DB_HOST=localhost
DB_PORT=5432
```

Create a `.gitignore` file in the same folder so this never gets committed to Git:
```
venv/
.env
__pycache__/
*.pyc
db.sqlite3
```

---

## PART 7 — Configure `asha_backend/settings.py`

Open `backend_django/asha_backend/settings.py` in VS Code.

**A. Add near the top:**
```python
from decouple import config
```

**B. In `INSTALLED_APPS`, add:**
```python
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    'rest_framework',
    'corsheaders',
    'health_api',
]
```

**C. Add corsheaders middleware** (near the top of `MIDDLEWARE`, before `CommonMiddleware`):
```python
MIDDLEWARE = [
    'corsheaders.middleware.CorsMiddleware',
    'django.middleware.security.SecurityMiddleware',
    # ...keep the rest as-is
]
```

**D. Replace the `DATABASES` block:**
```python
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': config('DB_NAME'),
        'USER': config('DB_USER'),
        'PASSWORD': config('DB_PASSWORD'),
        'HOST': config('DB_HOST'),
        'PORT': config('DB_PORT'),
    }
}
```

**E. Add at the very bottom of the file:**
```python
AUTH_USER_MODEL = 'health_api.User'

CORS_ALLOW_ALL_ORIGINS = True  # fine for local dev; restrict this in production
```

---

## PART 8 — Write the Models (`health_api/models.py`)

Delete everything in `backend_django/health_api/models.py` and paste:

```python
from django.db import models
from django.contrib.auth.models import AbstractUser
import uuid

class User(AbstractUser):
    ROLE_CHOICES = (
        ('admin', 'Admin'),
        ('asha', 'ASHA Worker'),
    )
    role = models.CharField(max_length=10, choices=ROLE_CHOICES, default='asha')
    phone_number = models.CharField(max_length=15, blank=True, null=True)

    def __str__(self):
        return f"{self.username} ({self.get_role_display()})"


class Area(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    state = models.CharField(max_length=100)
    district = models.CharField(max_length=100)
    block = models.CharField(max_length=100)
    village_or_ward = models.CharField(max_length=100)
    assigned_asha = models.ForeignKey(
        User, on_delete=models.SET_NULL, null=True, blank=True,
        related_name='assigned_areas'
    )

    def __str__(self):
        return f"{self.village_or_ward} ({self.district}, {self.state})"


class Family(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    area = models.ForeignKey(Area, on_delete=models.CASCADE, related_name='families')
    family_head_name = models.CharField(max_length=200)
    house_number = models.CharField(max_length=50)
    contact_number = models.CharField(max_length=15, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False)

    def __str__(self):
        return f"Family of {self.family_head_name} - House {self.house_number}"


class Member(models.Model):
    GENDER_CHOICES = (
        ('male', 'Male'),
        ('female', 'Female'),
        ('other', 'Other'),
    )
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    family = models.ForeignKey(Family, on_delete=models.CASCADE, related_name='members')
    full_name = models.CharField(max_length=200)
    age = models.IntegerField()
    gender = models.CharField(max_length=10, choices=GENDER_CHOICES)
    relationship_to_head = models.CharField(max_length=100)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False)

    def __str__(self):
        return self.full_name


class MedicalRecord(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    member = models.ForeignKey(Member, on_delete=models.CASCADE, related_name='medical_records')
    blood_sugar_fasting = models.FloatField(null=True, blank=True, help_text="mg/dL")
    blood_sugar_postprandial = models.FloatField(null=True, blank=True, help_text="mg/dL")
    blood_pressure_systolic = models.IntegerField(null=True, blank=True)
    blood_pressure_diastolic = models.IntegerField(null=True, blank=True)
    temperature = models.FloatField(null=True, blank=True, help_text="Fahrenheit")
    pulse_rate = models.IntegerField(null=True, blank=True)
    notes = models.TextField(blank=True, null=True)
    recorded_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='recorded_visits')
    recorded_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False)

    def __str__(self):
        return f"Health Record for {self.member.full_name} on {self.recorded_at.strftime('%Y-%m-%d')}"
```

---

## PART 9 — Register Models in the Admin Panel

Open `backend_django/health_api/admin.py`, replace contents with:

```python
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User, Area, Family, Member, MedicalRecord

class CustomUserAdmin(UserAdmin):
    model = User
    list_display = ['username', 'email', 'role', 'is_staff']
    fieldsets = UserAdmin.fieldsets + (
        (None, {'fields': ('role', 'phone_number')}),
    )
    add_fieldsets = UserAdmin.add_fieldsets + (
        (None, {'fields': ('role', 'phone_number')}),
    )

admin.site.register(User, CustomUserAdmin)
admin.site.register(Area)
admin.site.register(Family)
admin.site.register(Member)
admin.site.register(MedicalRecord)
```

---

## PART 10 — Create Tables and Superuser

Back in the VS Code terminal (make sure `(venv)` is still showing — if not, re-activate it):

```powershell
python manage.py makemigrations health_api
python manage.py migrate
python manage.py createsuperuser
```
It'll ask for username, email, password — pick something you'll remember, this is your admin login.

---

## PART 11 — Run and Test

```powershell
python manage.py runserver
```
Open a browser → go to:
```
http://127.0.0.1:8000/admin/
```
Log in with the superuser credentials from Part 10. You should see the Django admin dashboard with Users, Areas, Families, Members, and Medical Records — all editable.

Leave this terminal running. Open a **second** VS Code terminal (`+` icon in the terminal panel) for any future commands, so the server keeps running.

---

## PART 12 — Set Up the Flutter App (parallel track)

```powershell
cd "D:\Projects\T7_HealthVault\flutter_app"
flutter create .
```
Open the folder in VS Code (`File → Open Folder` → select `flutter_app`, or add it to the same workspace as your backend — see below).

Test it runs:
```powershell
flutter run
```
(Needs an emulator running or a device connected — Android Studio's Device Manager can launch one.)

---

## PART 13 — Combine Into One VS Code Workspace

In VS Code:
1. `File → Add Folder to Workspace` → add `backend_django`
2. `File → Add Folder to Workspace` → add `flutter_app`
3. `File → Save Workspace As...` → save as `T7_HealthVault.code-workspace` in your project root

From now on, open the project by double-clicking that `.code-workspace` file — both folders show up in one sidebar, each with the correct language server active.

---

## Quick Reference — Commands You'll Reuse

```powershell
# Activate Django venv (run this every time you open a new terminal for backend work)
cd "D:\Projects\T7_HealthVault\backend_django"
.\venv\Scripts\Activate.ps1

# Run Django server
python manage.py runserver

# After changing models.py
python manage.py makemigrations health_api
python manage.py migrate

# Run Flutter app
cd "D:\Projects\T7_HealthVault\flutter_app"
flutter run
```

---

## Next Steps (once this is running)
1. Build DRF serializers + viewsets in `health_api` to expose REST API endpoints
2. Add JWT auth endpoints using `djangorestframework-simplejwt`
3. Connect Flutter app to the API using `dio`
4. Add Isar for local offline storage in Flutter
5. Build the outbox/sync pattern

Reply **"server is running, what next?"** once Part 11 works, and we'll move to building the API endpoints.
