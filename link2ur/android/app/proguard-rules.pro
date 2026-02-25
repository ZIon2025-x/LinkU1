# ==================== Flutter ====================
# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ==================== Firebase ====================
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ==================== Google Maps ====================
-keep class com.google.android.gms.maps.** { *; }
-keep class com.google.android.gms.location.** { *; }
-dontwarn com.google.android.gms.**

# ==================== Google Play Services ====================
-keep class com.google.android.gms.common.** { *; }

# ==================== Stripe ====================
-keep class com.stripe.android.** { *; }
-dontwarn com.stripe.android.**

# ==================== WeChat (fluwx) ====================
-keep class com.tencent.mm.opensdk.** { *; }
-keep class com.tencent.wxop.** { *; }
-keep class com.tencent.mm.sdk.** { *; }
-dontwarn com.tencent.**

# ==================== QQ / Tencent ====================
-keep class com.tencent.connect.** { *; }
-keep class com.tencent.tauth.** { *; }

# ==================== AndroidX / Jetpack ====================
-keep class androidx.** { *; }
-dontwarn androidx.**

# ==================== Keep native methods ====================
-keepclasseswithmembernames class * {
    native <methods>;
}

# ==================== Keep Parcelable ====================
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# ==================== Keep Serializable ====================
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ==================== Keep enums ====================
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ==================== Keep R class ====================
-keepclassmembers class **.R$* {
    public static <fields>;
}

# ==================== Suppress warnings ====================
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**

# ==================== Flutter deferred components (optional path) ====================
# App 未使用 deferred components；R8 在扫描 Flutter embedding 可选代码路径时会要求这些旧 Play Core task 类
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task
