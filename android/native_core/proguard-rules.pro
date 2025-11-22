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

-keep class com.groupattendance.face_recognition_native.FaceRecognitionNative {
    *;
}
-keep class com.groupattendance.face_recognition_native.FaceRecognitionNative$Companion {
    *;
}
-keepnames class com.groupattendance.face_recognition_native.FaceRecognitionNative
-keepnames class com.groupattendance.face_recognition_native.FaceRecognitionNative$Companion
-keepclassmembers class com.groupattendance.face_recognition_native.FaceRecognitionNative {
    public static <methods>;
}
-keepclassmembers class com.groupattendance.face_recognition_native.FaceRecognitionNative$Companion {
    *;
}

-dontwarn java.lang.invoke.StringConcatFactory
-keep class java.lang.invoke.StringConcatFactory { *; }
-keepclassmembers class * {
    @java.lang.invoke.MethodHandle *;
}

-dontwarn kotlin.**
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn org.jetbrains.kotlin.**

-keepclasseswithmembers class * {
    @kotlin.jvm.JvmStatic <methods>;
}

