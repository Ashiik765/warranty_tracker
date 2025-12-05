# ======================================
# SMART WARRANTY TRACKER – PROGUARD RULES (FINAL WORKING VERSION)
# ======================================

#########################################
# Flutter & Dart
#########################################
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keepattributes *Annotation*

#########################################
# Firebase (ALL modules)
#########################################
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Firestore POJOs
-keepclassmembers class * {
  @com.google.firebase.firestore.PropertyName <fields>;
}

#########################################
# Google ML Kit – OCR / Text Recognition
#########################################
# ML Kit Vision
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# ML Kit Common + Vision Text internal dependencies
-keep class com.google.android.gms.internal.mlkit_vision_common.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_text_common.** { *; }
-dontwarn com.google.android.gms.internal.mlkit_vision_common.**
-dontwarn com.google.android.gms.internal.mlkit_vision_text_common.**

# ODML (VERY IMPORTANT!)
-keep class com.google.android.odml.** { *; }
-dontwarn com.google.android.odml.**

#########################################
# Google Play Services (required by ML Kit)
#########################################
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

#########################################
# AndroidX & Multidex
#########################################
-keep class androidx.multidex.** { *; }
-dontwarn androidx.multidex.**

#########################################
# ======================================
#  FIX FOR R8 MISSING PLAY CORE CLASSES
#  (This is the reason your build failed)
# ======================================

# Google Play Core (SplitCompat & SplitInstall)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Play Core Tasks
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.tasks.**

# Play Core SplitInstall
-keep class com.google.android.play.core.splitinstall.** { *; }
-dontwarn com.google.android.play.core.splitinstall.**

# Play Core SplitCompat
-keep class com.google.android.play.core.splitcompat.** { *; }
-dontwarn com.google.android.play.core.splitcompat.**

#########################################
# Extra safety (prevents R8 from stripping Flutter code)
#########################################
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.** { *; }

