# ProGuard rules for OkHttp 4.x
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Rules for OkHttp's internal usage of reflection
-dontwarn javax.annotation.**
-dontwarn okio.**

# Rules to keep important classes used by OkHttp
-keepattributes Signature
-keepattributes *Annotation*

# Prevent R8 from removing method references used by OkHttp
-keep class okhttp3.internal.** { *; }