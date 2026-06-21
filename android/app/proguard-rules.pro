# ML Kit text recognition pulls in optional language recognizers
# (Chinese / Devanagari / Japanese / Korean) that we don't bundle — the app
# only uses the default Latin recognizer. R8 otherwise fails the release
# build on the missing classes. Silence those and keep the ML Kit/GMS API.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
