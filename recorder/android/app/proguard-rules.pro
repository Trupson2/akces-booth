# ─────────────────────────────────────────────────────────────
# Akces Booth Recorder - ProGuard / R8 rules
# ─────────────────────────────────────────────────────────────
# Problem: libdartjni.so FindClassUnchecked crash przy starcie release buildu.
# Powod: R8 usuwa klasy Java ktorych natywne pluginy (ffmpeg_kit, camera, BLE)
# uzywaja przez JNI reflection.
# ─────────────────────────────────────────────────────────────

# --- Flutter core ---
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.embedding.** { *; }

# --- ffmpeg_kit_flutter_new / ffmpeg-kit ---
# Biblioteka uzywa JNI callbacks do raportowania progressu.
-keep class com.arthenica.ffmpegkit.** { *; }
-keep class com.arthenica.smartexception.** { *; }
-dontwarn com.arthenica.**

# --- camera (CameraX backend) ---
-keep class androidx.camera.** { *; }
-keep class io.flutter.plugins.camera.** { *; }
-dontwarn androidx.camera.**

# --- flutter_blue_plus ---
-keep class com.lib.flutter_blue_plus.** { *; }
-keep class com.boskokg.flutter_blue_plus.** { *; }

# --- permission_handler ---
-keep class com.baseflow.permissionhandler.** { *; }

# --- web_socket_channel / okhttp / dio HTTP ---
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# --- google_fonts ---
-keep class com.google.fonts.** { *; }

# --- Kotlin coroutines + serialization reflection ---
-keepclassmembers class kotlinx.coroutines.** { volatile <fields>; }
-dontwarn kotlinx.**

# --- Zachowaj wszystkie public konstruktory klas wolanych przez JNI ---
# (FindClass wymaga default ctor zeby instantiate)
-keepclassmembers class * {
    public <init>(...);
}

# --- Zachowaj native methods ---
-keepclasseswithmembernames class * {
    native <methods>;
}

# --- Zachowaj enum values()/valueOf() (Dart JNI czasem je uzywa) ---
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# --- Serializable support (gdyby ktos uzywal) ---
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}
