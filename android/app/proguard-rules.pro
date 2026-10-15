# Flutter ProGuard / R8 rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.**  { *; }

# Cashfree Payment Gateway SDK rules
-keep class com.cashfree.** { *; }
-dontwarn com.cashfree.**

# Firebase & Google Services
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-dontwarn com.google.android.gms.**

# Play Core & Split Compat (suppress unreferenced deferred component warnings)
-dontwarn com.google.android.play.core.**

