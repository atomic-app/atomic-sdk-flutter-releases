package io.atomic.atomic_sdk_flutter

import android.content.Context
import com.atomic.actioncards.sdk.AACSDK
import com.atomic.actioncards.sdk.AACSDKLogoutResult
import com.atomic.actioncards.sdk.events.AACEventPayload
import com.atomic.actioncards.sdk.events.AACProcessedEvent
import com.atomic.actioncards.sdk.notifications.AACSDKRegistrationCallback
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*

private var flutterLogger: AACFlutterLogger = AACFlutterLogger()
/**
 * Manages Android AACSDK
 */
class AACFlutterSDK {

  private var observeCardCount = mutableMapOf<String, Boolean>()
  private var cardCountInstanceCount = 0

  /**
   * Initialises the components of the Atomic SDK. This method must be called before
   * using any other methods.
   */
  fun initSDK(context: Context) {
    AACSDK.init(context)
  }

  fun trackPushNotificationReceived(data: Map<String, String>): Boolean {
    return run {
      AACSDK.notificationFromPushNotificationPayload(data)
    } != null
  }

  fun userMetrics(streamContainerId: String, result: Result) {
    AACSDK.userMetrics() { userMetrics ->
      CoroutineScope(Dispatchers.Main + NonCancellable).launch {
        if (userMetrics != null) {
          with(userMetrics) {
            val totalCardsFinal: Int
            val unseenCardsFinal: Int
            if (streamContainerId.isEmpty()) {
              totalCardsFinal = totalCards
              unseenCardsFinal = unseenCards
            } else {
              totalCardsFinal = totalCardsForStreamContainer(streamContainerId)
              unseenCardsFinal = unseenCardsForStreamContainer(streamContainerId)
            }
            result.success(
              mapOf(
                "totalCards" to totalCardsFinal,
                "unseenCards" to unseenCardsFinal
              )
            )
          }
        } else {
          result.error(
            "User metrics could not be retrieved - the authentication token may be invalid.",
            "Failed to request user metrics.",
            null
          )
        }
      }
    }
  }

  fun sendEvent(eventPayload: AACEventPayload, result: Result) {
    AACSDK.sendEvent(eventPayload, object : AACSDK.SendEventListener {
      override fun onSuccess(batchId: String, processedEvents: Array<AACProcessedEvent>) {
        // Handle success case - the batch ID and processed events are supplied.
        val processedEventsRaw = mutableListOf<Map<String, *>>()
        for (processedEvent in processedEvents) {
          processedEventsRaw.add(
            mapOf(
              "name" to processedEvent.name,
              "lifecycleId" to processedEvent.lifecycleId,
              "version" to processedEvent.version
            )
          )
        }
        CoroutineScope(Dispatchers.Main + NonCancellable).launch {
          result.success(mapOf("batchId" to batchId, "processedEvents" to processedEventsRaw))
        }
      }

      override fun onError(e: Exception) {
        CoroutineScope(Dispatchers.Main + NonCancellable).launch {
          // Handle error case - error details are provided in the exception.
          result.error(
            "Failed to send event. The event name may be invalid or not enabled for client-side triggers in the Atomic Workbench.",
            e.localizedMessage ?: "",
            null
          )
        }
      }
    })
  }

  fun requestCardCountForStreamContainerWithIdentifier(
    streamContainerId: String,
    result: Result
  ) {
    AACSDK.getCardCountForStreamContainer(
      streamContainerId
    ) { cardCount ->
      CoroutineScope(Dispatchers.Main + NonCancellable).launch {
        if (cardCount != null) {
          result.success(cardCount)
        } else {
          result.error(
            "Failed to retrieve card count. The authentication token or stream container ID may be invalid.",
            "The card count is not available for this stream container ($streamContainerId)",
            null
          )
        }
      }
    }
  }

  fun setApiBaseUrl(arguments: ArrayList<String>): Boolean {
    val baseUrl = arguments[0]
    AACSDK.setApiHost(baseUrl)
    return true
  }

  fun initialise(arguments: ArrayList<String>): Boolean {
    val environmentId = arguments[0]
    val apiKey = arguments[1]
    AACSDK.setEnvironmentId(environmentId)
    AACSDK.setApiKey(apiKey)
    return true
  }

  private fun dealRegistrationCallback(errorCode: String, callback: AACSDKRegistrationCallback, result: Result) {
    when(callback) {
      is AACSDKRegistrationCallback.Success -> result.success(true)
      is AACSDKRegistrationCallback.NetworkError ->
        result.error(errorCode, "Failed due to a network error; i.e. the device is offline.", null)
      is AACSDKRegistrationCallback.DataError ->
        result.error(errorCode, "Failed due to a data error or the Atomic Platform being unavailable.", null)
      else -> result.error(errorCode, "Unknown error.", null)
    }
  }

  fun registerDeviceForNotifications(fcmToken: String, result: Result) {
    val errorCode = "Error when registering the device for notifications."
    try {
      AACSDK.registerDeviceForNotifications(fcmToken) {
       dealRegistrationCallback(errorCode, it, result)
      }
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(errorCode, e.message, null)
    }
  }

  fun registerStreamContainersForNotifications(streamContainerIds: ArrayList<String>, result: Result, notificationEnabled: Boolean? = null) {
    val errorCode = "Error when registering stream containers for notifications."
    try {
      if(notificationEnabled != null) {
        AACSDK.registerStreamContainersForNotifications(streamContainerIds, notificationsEnabled = notificationEnabled) {
          dealRegistrationCallback(errorCode, it, result)
        }
      } else {
        AACSDK.registerStreamContainersForNotifications(streamContainerIds) {
          dealRegistrationCallback(errorCode, it, result)
        }
      }
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(errorCode, e.message, null)
    }
  }

  fun deregisterDeviceForNotifications(result: Result) {
    val errorCode = "Error when de-registering the device for notifications."
    try {
      AACSDK.deregisterDeviceForNotifications() {
        dealRegistrationCallback(errorCode, it, result)
      }
    } catch (e: Exception) {
      flutterLogger.error(e)
      result.error(errorCode, e.message, null)
    }
  }

  fun notificationFromPushPayload(payload: Map<String, String>): Map<String, Any>? {
    try {
      AACSDK.notificationFromPushNotificationPayload(payload)?.let {
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

  fun enableDebugMode(arguments: ArrayList<Int>): Boolean {
    try {
      AACSDK.enableDebugMode(arguments[0])
      AACFlutterLogger.enabled = arguments[0] > 0
    } catch (e: Exception) {
      flutterLogger.error(e)
    }
    return true
  }

  fun logout(result: Result) {
    AACSDK.logout {
      when (it) {
        is AACSDKLogoutResult.Success -> result.success(true)
        is AACSDKLogoutResult.NetworkError -> {
          result.error("Error when logging out.", "Analytics events failed to send due to a network error; i.e. the device is offline.", null)
        }
        is AACSDKLogoutResult.DataError -> {
          result.error("Error when logging out.", "Analytics events failed to send due to malformed data or the Atomic Platform being unavailable.", null)
        }
      }
    }
  }

  fun observeCardCount(
    containerId: String,
    interval: Double,
    onCount: ((Int, String) -> Unit)
  ): String {
    val identifier = getNextIdentifier()
    observeCardCount[identifier] = true
    val i = if (interval < 1000) {
      1000L
    } else {
      interval.toLong()
    }

    CoroutineScope(Dispatchers.Main + NonCancellable).launch {
      while (observeCardCount[identifier] == true) {
        val count = AACSDK.getCardCountForStreamContainer(containerId)
        count?.let {
          onCount(it, identifier)
        }
        delay(i)
      }
    }
    return identifier
  }

  private fun getNextIdentifier(): String {
    cardCountInstanceCount += 1
    return "AACFlutterCardCountObserver-${cardCountInstanceCount}"
  }

  fun stopObservingCardCount(identifier: String): Boolean {
    observeCardCount[identifier] = false
    observeCardCount.remove(identifier)
    return true
  }
}
