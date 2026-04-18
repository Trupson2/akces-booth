# ─────────────────────────────────────────────────────────────
# Akces Booth Station - ProGuard / R8 rules
# ─────────────────────────────────────────────────────────────
# Defense-in-depth: minify i tak wylaczony (isMinifyEnabled = false),
# ale jakby ktos w przyszlosci wlaczyl - te reguly zapobiegna JNI crashom
# w flutter_blue_plus, camera, video_player i shelf HTTP serverze.
# ─────────────────────────────────────────────────────────────

-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

-keep class com.lib.flutter_blue_plus.** { *; }
-keep class com.boskokg.flutter_blue_plus.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }

-keep class com.google.fonts.** { *; }

-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

-keepclasseswithmembernames class * {
    native <methods>;
}

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
