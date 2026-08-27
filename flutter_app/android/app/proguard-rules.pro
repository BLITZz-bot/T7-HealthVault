# ==============================================================================
# T7 HealthVault - ProGuard / R8 Obfuscation & Security Rules
# Copyright (c) 2026 M M Bharath / T7 HealthVault. All Rights Reserved.
# ==============================================================================

# Flutter Core Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep native methods and JNI bindings for ONNX Runtime / TFLite / LLM GGUF
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep serializable classes and reflection-based plugins
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Suppress warnings from third-party libraries if needed
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
