package io.atomic.atomic_sdk_flutter

import androidx.annotation.NonNull
import com.atomic.actioncards.sdk.AACSDK
import com.atomic.actioncards.sdk.AACSessionDelegate
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** Flutter plugin for Atomic SDK on Android */
class AACFlutterPlugin : FlutterPlugin, MethodCallHandler {

  private lateinit var channel: MethodChannel
  private var flutterLogger: AACFlutterLogger = AACFlutterLogger()

  override fun onAttachedToEngine(
      @NonNull binding: FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, SESSION_CHANNEL)
    channel.setMethodCallHandler(this)

    val streamContainerFactory = AACFlutterStreamContainerFactory(binding.binaryMessenger)

    binding
        .platformViewRegistry
        .registerViewFactory("io.atomic.sdk.streamContainer", streamContainerFactory)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "setApiBaseUrl" -> result.success(setApiBaseUrl(call))
      "initialise" -> initialise(call, result)
      "setLoggingEnabled" -> result.success(setLoggingEnabled(call))
      "logout" -> result.success(logout())
      "registerDeviceForNotifications" -> result.success(registerDeviceForNotifications(call))
      "registerStreamContainersForNotifications" -> result.success(
          registerStreamContainersForNotifications(call))
      "deregisterDeviceForNotifications" -> result.success(deregisterDeviceForNotifications())
      "notificationFromPushPayload" -> result.success(notificationFromPushPayload(call))
      "observeCardCount" -> result.success("10") // TODO: Implement
      "stopObservingCardCount" -> result.success(true) // TODO: Implement
      else -> result.notImplemented()
    }
  }

  private fun logout(): Boolean {
    AACSDK.logout(object : AACSDK.LogoutCompleteListener {
      override fun onComplete() {}
    })
    return true
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  companion object {
    const val SESSION_CHANNEL = "io.atomic.sdk.session"
  }

  private fun setLoggingEnabled(call: MethodCall): Boolean {
    try {
      var arguments = call.arguments as ArrayList<Boolean>
      AACSDK.setLoggingEnabled(arguments[0])
      AACFlutterLogger.enabled = arguments[0]
    } catch (e: Exception) {
      flutterLogger.error(e)
    }
    return true
  }

  private fun setApiBaseUrl(call: MethodCall): Boolean {
    try {
      var arguments = call.arguments as ArrayList<String>
      AACSDK.setApiHost(arguments[0])
      return true
    } catch (e: Exception) {
      flutterLogger.error(e)
    }
    return false
  }

  private fun initialise(call: MethodCall, result: Result) {
    try {
      var arguments = call.arguments as ArrayList<String>
      var environmentId = arguments[0]
      var apiKey = arguments[1]

      AACSDK.setEnvironmentId(environmentId)
      AACSDK.setApiKey(apiKey)

      result.success(true)
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error("AACSDK.initialise",
          "Failed to initialise SDK with provided environment ID and API key.", null)
    }
  }

  private fun registerDeviceForNotifications(call: MethodCall): Boolean {
    try {
      var arguments = call.arguments as ArrayList<String>
      val pushToken = arguments[0]
      val authToken = arguments[1]

      AACSDK.registerDeviceForNotifications(
          pushToken,
          object : AACSessionDelegate() {
            override fun getToken(completionHandler: (String?, Exception?) -> Unit) {
              completionHandler(authToken, null)
            }
          }
      )

      return true
    } catch (e: Exception) {
      flutterLogger.error(e)
    }

    return false
  }

  private fun registerStreamContainersForNotifications(call: MethodCall): Boolean {
    try {
      var arguments = call.arguments as ArrayList<Any>
      val containerIds = arguments[0] as? ArrayList<String>
      val authToken = arguments[1] as? String

      if (containerIds == null || authToken == null) {
        return false
      }

      AACSDK.registerStreamContainersForNotifications(containerIds, object : AACSessionDelegate() {
        override fun getToken(completionHandler: (String?, Exception?) -> Unit) {
          completionHandler(authToken, null)
        }
      })
      return true
    } catch (e: Exception) {
      flutterLogger.error(e)
    }

    return false
  }

  private fun deregisterDeviceForNotifications(): Boolean {
    AACSDK.deregisterDeviceForNotifications()
    return true
  }

  private fun notificationFromPushPayload(call: MethodCall): Map<String, Any>? {
    try {
      var arguments = call.arguments as ArrayList<Any>
      val payload = arguments[0] as? Map<String, String> ?: return null

      AACSDK.notificationFromPushPayload(payload)?.let {
        return mapOf(
            "containerId" to it.streamContainerId,
            "cardInstanceId" to it.cardInstanceId,
            "detail" to it.details
        )
      }
    } catch (e: Exception) {
      flutterLogger.error(e)
    }

    return null
  }
}
