# kotlinx.serialization (supabase-kt models)
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.**
-keepclassmembers class kotlinx.serialization.json.** { *** Companion; }
-keep,includedescriptorclasses class az.devet.app.**$$serializer { *; }
-keepclassmembers class az.devet.app.** { *** Companion; }
-keepclasseswithmembers class az.devet.app.** { kotlinx.serialization.KSerializer serializer(...); }

# Ktor / OkHttp
-dontwarn org.slf4j.**
-dontwarn okhttp3.internal.platform.**
