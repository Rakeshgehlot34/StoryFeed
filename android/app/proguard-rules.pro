# ==============================================================================
# ProGuard / R8 Rules for ShortsSplitter
# ==============================================================================

# Flutter Engine & Framework
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ShortsSplitter Application Classes & Services
-keep class com.shortssplitter.shorts_splitter.** { *; }
-keep class androidx.documentfile.provider.** { *; }

# Suppress missing Play Store core / deferred component warnings
-dontwarn com.google.android.play.core.**

# FFmpegKit JNI & Native Bridge preservation
-keep class com.arthenica.ffmpegkit.** { *; }
-keep interface com.arthenica.ffmpegkit.** { *; }
-keepclassmembers class com.arthenica.ffmpegkit.** {
    native <methods>;
    *;
}
-dontwarn com.arthenica.ffmpegkit.**

# Keep all native JNI method bindings
-keepclasseswithmembernames class * {
    native <methods>;
}

# Video Player Plugin
-keep class io.flutter.plugins.videoplayer.** { *; }

# FilePicker & Media Store SAF
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Shared Preferences & Serialization
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    !private <fields>;
    !private <methods>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep Attributes & Annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes SourceFile,LineNumberTable
