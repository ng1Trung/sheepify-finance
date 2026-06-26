# Ignore missing non-Latin text recognizer dependencies in google_mlkit_text_recognition
-dontwarn com.google.mlkit.vision.text.**

# Keep Flutter wrapper & plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Google ML Kit
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Keep Speech to Text
-keep class com.speech.speech_to_text.** { *; }

# Keep Flutter Local Notifications
-keep class com.dexterous.** { *; }

# Keep GSON (required by flutter_local_notifications)
-keepattributes Signature
-keepattributes *Annotation*
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keep class com.google.gson.** { *; }

# Ignore missing Play Core classes (deferred components)
-dontwarn com.google.android.play.core.**
