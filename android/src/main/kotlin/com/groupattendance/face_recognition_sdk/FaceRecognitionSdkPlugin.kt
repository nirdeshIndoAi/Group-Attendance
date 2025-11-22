package com.groupattendance.face_recognition_sdk

import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.groupattendance.face_recognition_native.FaceRecognitionNative
import kotlin.concurrent.thread

class FaceRecognitionSdkPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var nativeCore: FaceRecognitionNative

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        try {
            nativeCore = FaceRecognitionNative.getInstance()
        } catch (e: Exception) {
            throw RuntimeException("Failed to initialize FaceRecognitionNative: ${e.message}", e)
        }
        nativeCore.setContext(binding.applicationContext)
        val initResult = nativeCore.initialize()
        if (initResult != 0) {
            return
        }
        channel = MethodChannel(binding.binaryMessenger, "face_recognition_sdk/native")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "compareTemplates" -> handleCompareTemplates(call, result)
            "validateLicense" -> handleValidateLicense(call, result)
            "verifyIntegrity" -> handleVerifyIntegrity(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleCompareTemplates(call: MethodCall, result: Result) {
        val template1 = call.argument<ByteArray>("template1")
        val template2 = call.argument<ByteArray>("template2")

        if (template1 == null || template2 == null) {
            result.success(
                mapOf(
                    "final" to 0.0,
                    "cosine" to 0.0,
                    "distance" to 0.0,
                    "exactMatch" to 0.0,
                    "correlation" to 0.0
                )
            )
            return
        }

        val comparison = nativeCore.compareTemplates(template1, template2)
        result.success(comparison)
    }

    private fun handleValidateLicense(call: MethodCall, result: Result) {
        val licenseKey = call.argument<String>("licenseKey").orEmpty()
        val appId = call.argument<String>("appId").orEmpty()
        val endpoint = call.argument<String>("endpoint").orEmpty()

        thread {
            val validationResult = nativeCore.validateLicense(licenseKey, appId, endpoint)
            handler.post {
                result.success(validationResult == 0)
            }
        }
    }

    private fun handleVerifyIntegrity(call: MethodCall, result: Result) {
        val challenge = call.argument<String>("challenge").orEmpty()
        val signature = nativeCore.verifyIntegrity(challenge)
        result.success(signature)
    }
}

