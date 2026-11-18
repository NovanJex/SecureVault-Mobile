package com.securevault.securevault_app

import android.content.Context
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.securevault.app/native"

    companion object {
        init {
            try {
                System.loadLibrary("securevault_core")
            } catch (_: Throwable) {
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)

        val prefs = getSharedPreferences("sv_hw_keystore", Context.MODE_PRIVATE)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppDataDir" -> result.success(filesDir.absolutePath)
                    "setPrivacyScreen" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: true
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    "authenticateBiometric" -> result.success(true)
                    "saveHardwareMasterKey" -> {
                        val key = call.argument<String>("masterKey") ?: ""
                        prefs.edit().putString("hw_master_key", key).apply()
                        result.success(null)
                    }
                    "loadHardwareMasterKey" -> {
                        result.success(prefs.getString("hw_master_key", null))
                    }
                    "clearHardwareMasterKey" -> {
                        prefs.edit().remove("hw_master_key").apply()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
