# TanDanGenie ProGuard Rules
# Prevents code obfuscation issues in release builds

# ================================
# Flutter Core
# ================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ================================
# Google Generative AI (Gemini)
# ================================
# Keep all Gemini API classes to prevent JSON deserialization issues
-keep class com.google.ai.client.generativeai.** { *; }
-keep class com.google.generativeai.** { *; }
-keep interface com.google.ai.client.generativeai.** { *; }

# Keep Google API client classes
-keep class com.google.api.** { *; }
-dontwarn com.google.api.**

# ================================
# Kotlin Serialization
# ================================
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt

-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}

-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Keep Kotlin metadata
-keepattributes RuntimeVisibleAnnotations,AnnotationDefault

# ================================
# JSON / Gson
# ================================
# Keep fields annotated with @SerializedName
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep generic signature of JSON classes
-keepattributes Signature

# Keep JSON fields from being removed or renamed
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ================================
# OkHttp3 / Retrofit (for HTTP requests)
# ================================
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**

# Keep OkHttp platform implementations
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ================================
# Google Auth / BigQuery
# ================================
-keep class com.google.auth.** { *; }
-keep class com.google.cloud.** { *; }
-dontwarn com.google.auth.**
-dontwarn com.google.cloud.**

# ================================
# SQLite / Database
# ================================
-keep class * extends android.database.sqlite.SQLiteOpenHelper { *; }
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# ================================
# Image Processing
# ================================
# Keep camera and image picker classes
-keep class androidx.camera.** { *; }
-dontwarn androidx.camera.**

# ================================
# General Android
# ================================
# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom view constructors
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ================================
# Debugging (optional - remove in production)
# ================================
# Uncomment to see what's being removed
# -verbose
# -printusage usage.txt
# -printseeds seeds.txt

# Uncomment to preserve line numbers for debugging
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
