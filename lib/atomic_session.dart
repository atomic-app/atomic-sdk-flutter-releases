import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'atomic_embedded_font.dart';
import 'atomic_event_payload.dart';
import 'atomic_stream_container.dart';
import 'atomic_literals.dart';

/**
 * Returns card-related metrics for the current user.
 */
class AACUserMetrics {
  /**
   * The total number of cards available.
   */
  final int totalCards;

  /**
   * The total number of cards unseen for the user.
   */
  final int unseenCards;

  AACUserMetrics.fromJson(dynamic json)
      : totalCards = json['totalCards'],
        unseenCards = json['unseenCards'];
}

/**
 * Represents a push notification successfully parsed by the Atomic SDK.
 */
class AACPushNotification {
  final String containerId;
  final String cardInstanceId;
  final Map<String, dynamic> detail;

  AACPushNotification.fromJson(dynamic json)
      : containerId = json["containerId"],
        cardInstanceId = json["cardInstanceId"],
        detail = json["detail"];
}

/**
 * Supported network protocol types in the SDK.
 */
enum AACApiProtocol {
  /// Represents the WebSockets protocol
  webSockets("webSockets"),
  /// Represents the HTTP protocol
  http("http");
  final String stringValue;
  const AACApiProtocol(this.stringValue);
}

/**
 * Static methods used to initialise and configure global SDK properties.
 */
class AACSession {
  static MethodChannel _sessionChannel = MethodChannel('io.atomic.sdk.session')
    ..setMethodCallHandler((call) async {
      switch (call.method) {
        case 'cardCountChanged':
          String? identifier = call.arguments['identifier'];
          if (identifier == null) {
            throw PlatformException(code: "Method ${call.method} does not contain an `identifier` argument");
          }
          _cardCountObservers[identifier]?.call(call.arguments['cardCount']);
          break;
        case 'authTokenRequested':
          String? identifier = call.arguments['identifier'];
          String noDelegateError =
              'An authentication token was requested by the Atomic SDK but no session delegate has been configured. Ensure you have called `AACSession.setSessionDelegate`, providing a delegate that extends AACSessionDelegate and resolves to a JWT.';
          if (identifier == null) {
            throw PlatformException(code: "Method ${call.method} does not contain an `identifier` argument");
          }
          if (_sessionDelegate == null) {
            throw PlatformException(code: noDelegateError);
          }
          try {
            final token = await _sessionDelegate?.authToken();
            if (token != null) {
              _sessionChannel.invokeMethod('onAuthTokenReceived', [token, identifier]);
            } else {
              throw PlatformException(code: "Failed to get authentication token. Null token returned.");
            }
          } catch (error) {
            throw PlatformException(code: "Failed to get authentication token. $error");
          }
          break;
        default:
          throw MissingPluginException("No handler for method ${call.method}");
      }
    });
  static Map<String, Function> _cardCountObservers = Map<String, Function>();
  static AACSessionDelegate? _sessionDelegate;

  static void _reportError({required Object exception, required String context}) {
    FlutterError.reportError(FlutterErrorDetails(
      exception: exception,
      library: aac_framework_name,
      context: ErrorSummary(context),
    ));
  }

  /**
   * Sets the time interval used to determine whether Atomic SDK should retry to fetch a token from the session delegate.
   * The SDK won't fetch the JWT in a frequency higher than `1/[retryInterval]`. The interval must not be smaller than zero.
   * If this method is not called, the default retry interval is 0 seconds, which means the SDK will retry immediately
   * after failing to get a valid token.
   */
  static Future<void> setTokenRetryInterval(double retryInterval) async {
    await _sessionChannel.invokeMethod('setSessionDelegateRetryInterval', [retryInterval]);
  }

  /**
   * Sets the time interval used to determine whether the authentication token has expired. If the interval between the
   * current time and the token's `exp` field is smaller than [expiryInterval], the token is considered to be expired.
   * The interval must not be smaller than zero.
   * If this method is not called, the default expiry interval is 60 seconds.
   */
  static Future<void> setTokenExpiryInterval(double expiryInterval) async {
    await _sessionChannel.invokeMethod('setSessionDelegateExpiryInterval', [expiryInterval]);
  }

  /**
   * Configures the Atomic SDK to use the provided base URL when making API requests.
   * The base URL can be found in the Atomic Workbench.
   */
  static Future<void> setApiBaseUrl(String url) async {
    await _sessionChannel.invokeMethod('setApiBaseUrl', [url]);
  }

  /**
   * Set up a [sessionDelegate] used by the SDK to acquire an authentication token.
   * The token is requested once by the SDK, and provided that the token is valid and contains a user ID, the
   * token is retained in memory by the SDK until it is due to expire - at which point, a new token is requested.
   */

  static Future<void> setSessionDelegate(AACSessionDelegate sessionDelegate) async {
    _sessionDelegate = sessionDelegate;
  }

  /**
   * Initialises the Atomic SDK with the provided environment ID and API key.
   * You must call this before attempting to use any Atomic SDK functionality.
   */
  static Future<void> initialise(String environmentId, String apiKey) async {
    await _sessionChannel.invokeMethod('initialise', [environmentId, apiKey]);
  }

  /**
   * Sets the debug logging level within the SDK. This can be useful in debug
   * builds when integrating the SDK. Defaults to `0`, which means no logs. Setting this takes immediate effect.
   * - [level] The logging message level that controls the details of logging information.
   * Must be one of the following values: 0, 1, 2, 3.
   */
  static Future<void> enableDebugMode(int level) async {
    await _sessionChannel.invokeMethod('enableDebugMode', [level]);
  }

  /**
   * Purges all cached card data stored by the SDK. Call this method when a user logs out of your app
   * or the active user changes.
   * If the registration does not succeed, this method has no effect and throws out an error.
   */
  static Future<void> logout() async {
    try {
      await _sessionChannel.invokeMethod('logout', []);
    } catch (exception) {
      _reportError(exception: exception, context: aac_error_logout_context);
      rethrow;
    }
  }

  /**
   * Sets up the network protocol used by the SDK to acquire cards. Calling it takes immediate effect.
   */
  static Future<void> setApiProtocol(AACApiProtocol protocol) async {
    await _sessionChannel.invokeMethod('setApiProtocol', [protocol.stringValue]);
  }

  /**
   * Asks the SDK to register the currently logged in user for push notifications on the stream container IDs in the provided
   * array with notifications enabled or disabled.
   * Push notifications will not be delivered to a user unless they have registered for push notifications first.
   * However, the registration of device token and registration of stream container IDs can occur in either order.
   *
   * If the registration does not success, this method has no effect and throws out an error.
   *
   * The [notificationsEnabled] parameter is optional and will set the user's preference in the Atomic Platform to true or false accordingly.
   */
  static Future<void> registerStreamContainersForNotifications(List<String> containerIds,
      [bool? notificationsEnabled]) async {
    try {
      if (notificationsEnabled == null) {
        await _sessionChannel.invokeMethod('registerStreamContainersForNotifications', [containerIds]);
      } else {
        await _sessionChannel
            .invokeMethod('registerStreamContainersForNotificationsEnabled', [containerIds, notificationsEnabled]);
      }
    } catch (exception) {
      _reportError(exception: exception, context: aac_error_register_stream_container_push_notifications_context);
      rethrow;
    }
  }

  /**
   * Asks the SDK to register the given device token against the currently logged in user identified by the authentication token returned by the
   * session delegate that is registered when initiating the SDK.
   * If the registration does not succeed, this method has no effect and throws out an error.
   */
  static Future<void> registerDeviceForNotifications(String pushToken) async {
    try {
      await _sessionChannel.invokeMethod('registerDeviceForNotifications', [pushToken]);
    } catch (exception) {
      _reportError(exception: exception, context: aac_error_register_device_push_notifications_context);
      rethrow;
    }
  }

  /**
   * Asks the SDK to deregister the current device for Atomic push notifications, within the current app.
   * If the deregistration fails, it throws out an error.
   */
  static Future<void> deregisterDeviceForNotifications() async {
    try {
      await _sessionChannel.invokeMethod('deregisterDeviceForNotifications', []);
    } catch (exception) {
      _reportError(exception: exception, context: aac_error_deregister_device_push_notifications_context);
      rethrow;
    }
  }

  /**
   * Determines whether the given push notification payload is for a push notification sent by the Atomic Platform.
   * If the push payload is for an Atomic push notification, this method returns an instance of [AACPushNotification] populated with
   * details of the notification. Otherwise, it returns null.
   */
  static Future<AACPushNotification?> notificationFromPushPayload(Map<String, dynamic> payload) async {
    final result =
        await _sessionChannel.invokeMethod('notificationFromPushPayload', [payload]) as Map<String, dynamic>?;
    if (result != null) {
      return AACPushNotification.fromJson(result);
    } else {
      return null;
    }
  }

  /**
   * Asks the SDK to observe the card count for the given stream container on the frequency of the [pollingInterval], calling the [callback] every time
   * the count changes.
   * The [pollingInterval] must be at least 1 second, otherwise it defaults to 1 second.
   * The SDK returns an [observerToken] to distinguish card count observers.
   * This method does nothing on the Android platform.
   */
  static Future<String> observeCardCount(
      String containerId, double pollingInterval, Function(int cardCount) callback) async {
    String observerToken = await _sessionChannel.invokeMethod('observeCardCount', [containerId, pollingInterval]);
    _cardCountObservers[observerToken] = callback;
    return observerToken;
  }

  /**
   * Asks the SDK to stop observing card count for the given token, which was returned from a call to
   * [observeCardCount]. If the token does not correspond to an existing card count observer, this method does nothing.
   */
  static Future<void> stopObservingCardCount(String observerToken) async {
    await _sessionChannel.invokeMethod('stopObservingCardCount', [observerToken]);
    _cardCountObservers.remove(observerToken);
  }

  /**
   * Tracks that a push notification, with the given payload, was received by this device.
   *
   * If the payload does not represent an Atomic push notification, this method has no effect and throws out an error.
   * This method dispatches an analytics event back to Atomic to indicate that the user's device received the notification.
   * It is the responsibility of the integrator to ensure that this method is called at the correct location to ensure accurate tracking.
   */
  static Future<void> trackPushNotificationReceived(Map<String, dynamic> payload) async {
    await _sessionChannel.invokeMethod('trackPushNotificationReceived', [payload]);
  }

  /**
   * Triggers an event on the Atomic Platform, exclusively for the user identified by by the authentication token returned by the
   * session delegate that is registered when initiating the SDK.
   *
   * Events must opt-in to be triggered from the SDK. To opt-in, turn on the 'Enable client trigger' option in the Atomic Workbench
   * for the event.
   *
   * - [payload] represents the event payload used to trigger the event.
   *
   * If the request succeeds, details of the processed event are provided with an [AACEventResponse] object, otherwise an error is thrown out.
   */
  @Deprecated('The feature `send event` is deprecated and no longer used by Atomic Workbench.')
  static Future<AACEventResponse> sendEvent(AACEventPayload payload) async {
    var result = await _sessionChannel.invokeMethod('sendEvent', [payload.toJson()]);
    return AACEventResponse.fromJson(result);
  }

  /**
   * Asks the SDK to return the number of cards for the given stream container.
   *
   * - [streamContainerId] represents the stream container ID to retrieve the card count for.
   *
   * The function throws if the card count is not available for this stream container (the user may not have access or the internet connection
   * may be unavailable).
   */
  static Future<int> requestCardCount(String containerId) async {
    return await _sessionChannel.invokeMethod('requestCardCount', [containerId]);
  }

  /**
   * Retrieves user metrics for the user identified by by the authentication token returned by the
   * session delegate that is registered when initiating the SDK.
   * User metrics provide a count of the total number of cards visible to a user,as well as the total number not yet seen by the user.
   *
   * Pass a [streamContainerId] to get user metrics for a specific stream container, or an empty string
   * to retrieve metrics across all containers.
   *
   * Use the returned [AACUserMetrics] object to obtain these values.
   */

  static Future<AACUserMetrics> userMetrics(String streamContainerId) async {
    var result = await _sessionChannel.invokeMethod('userMetrics', [streamContainerId]);
    return AACUserMetrics.fromJson(result);
  }

  /**
   * Registers the specified local fonts with the SDK. The fonts are defined in the theme created in the Atomic Workbench
   * and integrated locally with the app. Pass an empty [fontList] to clear the embedded fonts being used.
   */
  static Future<void> registerEmbeddedFonts(List<AACEmbeddedFont> fontList) async {
    List<Map<String, dynamic>> fontListJson = [];
    for (AACEmbeddedFont font in fontList) {
      fontListJson.add(font.toJson());
    }
    await _sessionChannel.invokeMethod('registerEmbeddedFonts', [fontListJson]);
  }
}
