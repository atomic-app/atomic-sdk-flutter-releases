package io.atomic.atomic_sdk_flutter

import androidx.annotation.NonNull
import com.atomic.actioncards.sdk.events.AACEventPayload
import io.atomic.atomic_sdk_flutter.utils.asListOfType
import io.atomic.atomic_sdk_flutter.utils.asStringMap
import io.atomic.atomic_sdk_flutter.utils.asStringMapOfType
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Flutter plugin for Atomic SDK on Android
 * AACFlutterPlugin is the entry point between Flutter and Android by using a
 * Flutter Method Channel.
 **/
class AACFlutterPlugin : FlutterPlugin, MethodCallHandler {

  private val aacFlutterSDK = AACFlutterSDK()
  private lateinit var channel: MethodChannel
  private val flutterLogger = AACFlutterLogger()

  override fun onAttachedToEngine(@NonNull binding: FlutterPluginBinding) {
    channel = MethodChannel(binding.binaryMessenger, SESSION_CHANNEL)
    channel.setMethodCallHandler(this)

    aacFlutterSDK.initSDK(binding.applicationContext)

    val singleCardViewFactory = AACFlutterSingleCardViewFactory(binding.binaryMessenger)
    binding
      .platformViewRegistry
      .registerViewFactory("io.atomic.sdk.singleCard", singleCardViewFactory)

    val streamContainerFactory = AACFlutterStreamContainerFactory(binding.binaryMessenger)
    binding
      .platformViewRegistry
      .registerViewFactory("io.atomic.sdk.streamContainer", streamContainerFactory)
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "setApiBaseUrl" -> setApiBaseUrl(call, result)
      "initialise" -> initialise(call, result)
      "setLoggingEnabled" -> setLoggingEnabled(call, result)
      "logout" -> logout(result)
      "registerDeviceForNotifications" -> registerDeviceForNotifications(call, result)
      "registerStreamContainersForNotifications" -> registerStreamContainersForNotifications(
        call,
        result
      )
      "deregisterDeviceForNotifications" -> deregisterDeviceForNotifications(result)
      "notificationFromPushPayload" -> notificationFromPushPayload(call, result)
      "observeCardCount" -> observeCardCount(call, result)
      "stopObservingCardCount" -> stopObservingCardCount(call, result)
      "requestCardCount" -> requestCardCount(call, result)
      "sendEvent" -> sendEvent(call, result)
      "userMetrics" -> userMetrics(call, result)
      "trackPushNotificationReceived" -> trackPushNotificationReceived(call, result)
      else -> result.notImplemented()
    }
  }

  private fun trackPushNotificationReceived(call: MethodCall, result: Result) {
    try {
      val parameters = call.arguments as ArrayList<*>
      val payloadRaw = (parameters[0] as Map<*, *>).asStringMapOfType<String>()
        ?: throw IllegalArgumentException("Notification payload was not in the expected format.")
      val token = parameters[1] as? String
        ?: throw IllegalArgumentException("You must supply a string token when tracking received notification.")
      if (aacFlutterSDK.trackPushNotificationReceived(payloadRaw, token)) {
        result.success(true)
      } else {
        result.error(ERROR_CODE_TRACK_PUSH_NOTIFICATION,
                     "Failed to convert push payload to an Atomic object.",
                     "Failed to track received push notification.")
      }
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(ERROR_CODE_TRACK_PUSH_NOTIFICATION,
                   e.message,
                   "Failed to track received push notification.")
    }
  }

  private fun userMetrics(call: MethodCall, result: Result) {
    try {
      val parameters =
        call.arguments.asListOfType<String>()
          ?: throw IllegalArgumentException("You must supply a stream container ID and authentication token when requesting user metrics.")
      aacFlutterSDK.userMetrics(parameters[0], parameters[1], result)
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(ERROR_CODE_USER_METRICS, e.message, "Failed to request user metrics.")
    }
  }

  private fun sendEvent(call: MethodCall, result: Result) {
    try {
      val parameters = call.arguments as ArrayList<*>
      val payloadRaw = (parameters[0] as Map<*, *>).asStringMap()
        ?: throw IllegalArgumentException("Event payload was not in the expected format.")
      val token = parameters[1] as? String
        ?: throw IllegalArgumentException("You must supply a string token when sending event.")
      val eventName = payloadRaw["name"] as? String
        ?: throw IllegalArgumentException("You must supply an event name when sending event.")
      AACEventPayload(eventName).apply {
        lifecycleId = payloadRaw["lifecycleId"] as? String
        payload.apply {
          payloadRaw["detail"]?.let {
            detail.putAll(
              (it as Map<*, *>).asStringMapOfType()
                ?: throw IllegalArgumentException("You must supply a string dictionary for the event payload.")
            )
          }
          payloadRaw["notificationDetail"]?.let {
            notificationDetail.putAll(
              (it as Map<*, *>).asStringMapOfType()
                ?: throw IllegalArgumentException("You must supply a string dictionary for the notification detail.")
            )
          }
          payloadRaw["metadata"]?.let {
            metadata.putAll(
              (it as Map<*, *>).asStringMapOfType()
                ?: throw IllegalArgumentException("You must supply a string dictionary for the event meta data.")
            )
          }
        }
      }.run {
        aacFlutterSDK.sendEvent(this, token, result)
      }
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(ERROR_CODE_SEND_EVENT, e.message, "Failed to send event.")
    }
  }

  private fun requestCardCount(call: MethodCall, result: Result) {
    try {
      val parameters =
        (call.arguments as ArrayList<*>).asListOfType<String>()
          ?: throw IllegalArgumentException("You must supply a stream container ID and authentication token when requesting card count.")
      aacFlutterSDK.requestCardCountForStreamContainerWithIdentifier(parameters[0], parameters[1], result)
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(
        ERROR_CODE_REQUEST_CARD_COUNT, e.message,
        "Failed to request card count."
      )
    }
  }

  private fun setApiBaseUrl(call: MethodCall, result: Result) {
    try {
      val parameters =
        call.arguments.asListOfType<String>()
          ?: throw IllegalArgumentException("You must supply a valid URL when setting the API base URL.")
      result.success(aacFlutterSDK.setApiBaseUrl(parameters))
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(
        ERROR_CODE_BASE_URL, e.message,
        "Failed to set API base URL. Check the base URL provided matches that specified in the Atomic Workbench."
      )
    }
  }

  private fun initialise(call: MethodCall, result: Result) {
    try {
      val parameters =
        call.arguments.asListOfType<String>()
          ?: throw IllegalArgumentException("You must supply a valid environment ID and API key when initialising the Atomic SDK.")
      result.success(aacFlutterSDK.initialise(parameters))
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(
        ERROR_CODE_INITIALISE, e.message,
        "Failed to initialise SDK with provided environment ID and API key."
      )
    }
  }

  private fun setLoggingEnabled(call: MethodCall, result: Result) {
    try {
      val arguments =
        call.arguments.asListOfType<Boolean>()
          ?: throw IllegalArgumentException("You must provide a boolean value when enabling or disabling logging.")
      result.success(aacFlutterSDK.setLoggingEnabled(arguments))
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(
        ERROR_CODE_LOGGING, e.message,
        "Failed to set logging enabled or disabled on the SDK."
      )
    }
  }

  private fun logout(result: Result) {
    try {
      result.success(aacFlutterSDK.logout())
    } catch (e: java.lang.Exception) {
      flutterLogger.error(e)
      result.error(
        ERROR_CODE_LOGOUT, e.message,
        "Failed to logout."
      )
    }
  }

  private fun registerDeviceForNotifications(call: MethodCall, result: Result) {
    try {
      val parameters =
        call.arguments.asListOfType<String>()
          ?: throw IllegalArgumentException("You must provide an authentication token and device token when registering a device for push notifications.")
      result.success(
        aacFlutterSDK.registerDeviceForNotifications(parameters)
      )
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(
        ERROR_CODE_REGISTER_DEVICE, e.message,
        "Failed to register device for notifications. Ensure you have provided a valid push token."
      )
    }
  }

  private fun registerStreamContainersForNotifications(call: MethodCall, result: Result) {
    try {
      val streamContainers = call.arguments.asListOfType<Any>()
        ?: throw IllegalArgumentException("You must provide an array of stream container IDs and authentication token when registering stream containers for notifications.")
      result.success(aacFlutterSDK.registerStreamContainersForNotifications(streamContainers))
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(
        ERROR_CODE_REGISTER_STREAM, e.message,
        "Failed to register stream container for notifications. Ensure you have provided a valid array of container IDs."
      )
    }
  }

  private fun deregisterDeviceForNotifications(result: Result) {
    try {
      result.success(aacFlutterSDK.deregisterDeviceForNotifications())
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(
        ERROR_CODE_DEREGISTER, e.message,
        "Failed to deregister device for notifications."
      )
    }
  }

  private fun notificationFromPushPayload(call: MethodCall, result: Result) {
    try {
      /// Legal structure of arguments: List<Map<String, String>>
      val payload = ((call.arguments as List<*>)[0] as Map<*, *>).asStringMapOfType<String>()
        ?: throw IllegalArgumentException("You must supply a push notification payload that will parsed to an object.")
      result.success(aacFlutterSDK.notificationFromPushPayload(payload))
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(
        ERROR_CODE_NOTIFICATION_PAYLOAD, e.message,
        "Failed to convert push payload to an Atomic object."
      )
    }
  }

  private fun observeCardCount(call: MethodCall, result: Result) {
    try {
      val arguments = call.arguments as List<*>
      val containerId = arguments[0] as String
      val interval = arguments[1] as Double
      val authToken = arguments[2] as String

      val identifier = aacFlutterSDK.observeCardCount(containerId, interval, authToken
      ) { count, identifier ->
        channel.invokeMethod("cardCountChanged", mapOf("identifier" to identifier, "cardCount" to count))
      }
      result.success(identifier)
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(
        ERROR_CODE_CARD_COUNT, e.message,
        "Failed to observe card count."
      )
    }
  }

  private fun stopObservingCardCount(call: MethodCall, result: Result) {
    try {
      val identifier = (call.arguments as List<*>)[0] as String
      result.success(aacFlutterSDK.stopObservingCardCount(identifier))
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(
        ERROR_CODE_STOP_CARD_COUNT, e.message,
        "Failed to stop observe card count."
      )
    }
  }

  companion object {
    const val SESSION_CHANNEL = "io.atomic.sdk.session"
    const val ERROR_CODE_BASE_URL = "0"
    const val ERROR_CODE_INITIALISE = "1"
    const val ERROR_CODE_LOGGING = "2"
    const val ERROR_CODE_LOGOUT = "3"
    const val ERROR_CODE_REGISTER_DEVICE = "4"
    const val ERROR_CODE_REGISTER_STREAM = "5"
    const val ERROR_CODE_DEREGISTER = "6"
    const val ERROR_CODE_CARD_COUNT = "7"
    const val ERROR_CODE_NOTIFICATION_PAYLOAD = "8"
    const val ERROR_CODE_STOP_CARD_COUNT = "9"
    const val ERROR_CODE_REQUEST_CARD_COUNT = "10"
    const val ERROR_CODE_SEND_EVENT = "11"
    const val ERROR_CODE_USER_METRICS = "12"
    const val ERROR_CODE_TRACK_PUSH_NOTIFICATION = "13"
  }
}
