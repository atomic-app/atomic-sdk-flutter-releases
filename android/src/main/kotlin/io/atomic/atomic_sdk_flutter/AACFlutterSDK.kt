package io.atomic.atomic_sdk_flutter

import android.content.Context
import com.atomic.actioncards.sdk.AACSDK
import com.atomic.actioncards.sdk.AACSessionDelegate
import com.atomic.actioncards.sdk.events.AACEventPayload
import com.atomic.actioncards.sdk.events.AACProcessedEvent
import io.atomic.atomic_sdk_flutter.utils.asListOfType
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.*

private var flutterLogger: AACFlutterLogger = AACFlutterLogger()

/**
 * Manages Android AACSDK
 */
class AACFlutterSDK {

  private var observeCardCount = mutableMapOf<String, Boolean>()
  private var cardCountInstanceCount = 0

  private fun createSessionDelegate(token: String) = object : AACSessionDelegate() {
    override fun getToken(completionHandler: (String?, Exception?) -> Unit) {
      // Retrieve the user's JWT, then call the completion handler
      completionHandler(token, null)
    }
  }

  /**
   * Initialises the components of the Atomic SDK. This method must be called before
   * using any other methods.
   */
  fun initSDK(context: Context) {
    AACSDK.init(context)
  }

  fun trackPushNotificationReceived(data: Map<String, String>, token: String): Boolean {
    return AACSDK.notificationFromPushPayload(data, createSessionDelegate(token)) != null
  }

  fun userMetrics(streamContainerId: String, token: String, result: Result) {
    AACSDK.userMetrics(createSessionDelegate(token)) { userMetrics ->
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

  fun sendEvent(eventPayload: AACEventPayload, token: String, result: Result) {
    AACSDK.sendEvent(eventPayload, createSessionDelegate(token), object : AACSDK.SendEventListener {
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
    token: String,
    result: Result
  ) {
    AACSDK.getCardCountForStreamContainer(
      streamContainerId,
      createSessionDelegate(token)
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

  fun registerDeviceForNotifications(arguments: ArrayList<String>): Boolean {
    AACSDK.registerDeviceForNotifications(arguments[0], createSessionDelegate(arguments[1]))
    return true
  }

  fun registerStreamContainersForNotifications(arguments: ArrayList<Any>): Boolean {
    try {
      val containerIds = arguments[0].asListOfType<String>()
      val authToken = arguments[1] as? String

      if (containerIds == null || authToken == null) {
        return false
      }

      AACSDK.registerStreamContainersForNotifications(
        containerIds,
        createSessionDelegate(authToken)
      )
      return true
    } catch (e: Exception) {
      flutterLogger.error(e)
    }

    return false
  }

  fun deregisterDeviceForNotifications(): Boolean {
    AACSDK.deregisterDeviceForNotifications()
    return true
  }

  fun notificationFromPushPayload(payload: Map<String, String>): Map<String, Any>? {
    try {
      AACSDK.notificationFromPushPayload(payload, null)?.let {
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

  fun setLoggingEnabled(arguments: ArrayList<Boolean>): Boolean {
    try {
      AACSDK.setLoggingEnabled(arguments[0])
      AACFlutterLogger.enabled = arguments[0]
    } catch (e: Exception) {
      flutterLogger.error(e)
    }
    return true
  }

  fun logout(): Boolean {
    AACSDK.logout(object : AACSDK.LogoutCompleteListener {
      override fun onComplete() {}
    })
    return true
  }

  fun observeCardCount(
    containerId: String,
    interval: Double,
    token: String,
    onCount: ((Int, String) -> Unit)
  ): String {
    val identifier = getNextIdentifier()
    observeCardCount[identifier] = true
    val i = if (interval < 1000) {
      1000L
    } else {
      interval.toLong()
    }
    val delegate = createSessionDelegate(token)
    CoroutineScope(Dispatchers.Main + NonCancellable).launch {
      while (observeCardCount[identifier] == true) {
        val count = AACSDK.getCardCountForStreamContainer(containerId, delegate)
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
