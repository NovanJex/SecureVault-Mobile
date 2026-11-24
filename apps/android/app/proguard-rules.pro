# Keep Rust JNI native bridge methods
-keep class app.suoxia.vault.bridge.RustCore {
    native <methods>;
}
-keepclassmembers class app.suoxia.vault.bridge.RustCore {
    native <methods>;
}
