-optimizationpasses 5
-allowaccessmodification
-repackageclasses ''
-allowaccessmodification

-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-verbose

-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*

-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses
-keepattributes EnclosingMethod

-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugin.platform.** { *; }
-dontwarn io.flutter.embedding.**
-dontwarn io.flutter.plugin.**
-dontwarn io.flutter.plugins.**

-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

-keepclassmembers class * extends io.flutter.plugin.common.PluginRegistry {
    public <methods>;
}

-keepclassmembers class * extends io.flutter.plugin.platform.PlatformView {
    public <methods>;
}

-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

