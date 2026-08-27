/// Application-wide constants & clinical configuration
class AppConstants {
  // App Identity
  static const String appName = 'T7 HealthVault';
  static const String appVersion = '1.2.0';
  static const String buildNumber = '12';

  // AI & LLM Engine
  static const String llmModelFileName = 'qwen2.5-1.5b-instruct-q4_k_m.gguf';
  static const String llmModelDownloadUrl =
      'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf';
  static const int llmEstimatedSizeBytes = 1117320736; // ~1.04 GB

  // Database
  static const String dbName = 'asha_records.db';
  static const int dbVersion = 3;

  // Clinical Thresholds (NEWS2 & Sepsis)
  static const int news2LowRiskMax = 4;
  static const int news2MediumRiskMax = 6;
  static const int news2HighRiskMin = 7;

  // Storage Keys
  static const String keyAppLanguage = 'selected_language';
  static const String keyAdminToken = 'admin_jwt_token';
  static const String keyLastSyncTimestamp = 'last_sync_time';
}
