# Sortyd Android ProGuard / R8 Rules

# ── Kotlin ──
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# ── Kotlinx Serialization ──
# Required: without this, @Serializable classes are mangled in release and JSON parsing breaks.
-keepattributes RuntimeVisibleAnnotations,AnnotationDefault
-keep @kotlinx.serialization.Serializable class * { *; }
-keepclassmembers class * {
    @kotlinx.serialization.SerialName <fields>;
}
-keep class kotlinx.serialization.** { *; }
-keepclassmembers class kotlinx.serialization.json.** { *; }

# ── Room ──
-keepclassmembers class * {
    @androidx.room.* <methods>;
}
-keep class * extends androidx.room.RoomDatabase { *; }
-keep @androidx.room.Entity class * { *; }
-keep @androidx.room.Dao interface * { *; }

# ── DataStore ──
-keep class androidx.datastore.** { *; }

# ── Health Connect ──
-keep class androidx.health.connect.** { *; }

# ── Glance Widgets ──
-keep class androidx.glance.** { *; }
-keep class com.sortyd.app.widget.** { *; }

# ── App model classes (serialized to/from JSON and Room) ──
-keep class com.sortyd.app.data.model.** { *; }

# ── WorkManager ──
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-keepclassmembers class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}

# ── Coroutines ──
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}
