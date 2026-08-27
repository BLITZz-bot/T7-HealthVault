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

# Suppress warnings from optional Flutter Play Core deferred components
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Keep ONNX Runtime & Native Bindings
-keep class ai.onnxruntime.** { *; }
-dontwarn ai.onnxruntime.**

# Keep SQLite & Database
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**

# Suppress warnings from third-party libraries if needed
-dontwarn javax.annotation.**
-dontwarn org.checkerframework.**
-dontwarn sun.misc.**
