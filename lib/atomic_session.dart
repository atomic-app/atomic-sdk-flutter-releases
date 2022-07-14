import 'package:flutter/services.dart';
import 'atomic_stream_container.dart';
import 'atomic_event_payload.dart';
import 'atomic_embedded_font.dart';

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
    Represents a push notification successfully parsed by the Atomic SDK.
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
    Static methods used to initialise and configure global SDK properties.
 */
class AACSession {
  static MethodChannel _sessionChannel = MethodChannel('io.atomic.sdk.session')
    ..setMethodCallHandler((call) async {
      switch (call.method) {
        case 'cardCountChanged':
          String? identifier = call.arguments['identifier'];
          if(identifier == null) throw PlatformException(code: "Method ${call.method} does not contain an `identifier` argument");
          _cardCountObservers[identifier]?.call(call.arguments['cardCount']);
          break;
        default:
          throw MissingPluginException("No handler for method ${call.method}");
      }
    });
  static Map<String, Function> _cardCountObservers = Map<String, Function>();

  /**
      Configures the Atomic SDK to use the provided base URL when making API requests.
      The base URL can be found in the Atomic Workbench.
   */
  static Future<void> setApiBaseUrl(String url) async {
    await _sessionChannel.invokeMethod('setApiBaseUrl', [url]);
  }

  /**
      Initialises the Atomic SDK with the provided environment ID and API key.
      You must call this before attempting to use any Atomic SDK functionality.
   */
  static Future<void> initialise(String environmentId, String apiKey) async {
    await _sessionChannel.invokeMethod('initialise', [environmentId, apiKey]);
  }

  /**
      Sets whether debug logging should be enabled within the SDK. This can be useful in debug
      builds when integrating the SDK. Defaults to `false`. Turning this on or off takes immediate effect.
   */
  static Future<void> setLoggingEnabled(bool enabled) async {
    await _sessionChannel.invokeMethod('setLoggingEnabled', [enabled]);
  }

  /**
      Purges all cached card data stored by the SDK. Call this method when a user logs out of your app
      or the active user changes.
   */
  static Future<void> logout() async {
    await _sessionChannel.invokeMethod('logout', []);
  }

  /**
      Asks the SDK to register the currently logged in user for push notifications on the stream container IDs in the provided
      array with notifications enabled or disabled.

      Push notifications will not be delivered to a user unless they have registered for push notifications first.
      However, the registration of device token and registration of stream container IDs can occur in either order.

      If the registration does not success, this method has no effect and throws out an error.

      The [notificationsEnabled] parameter is optional and will set the user's preference in the Atomic Platform to true or false accordingly.
   */
  static Future<void> registerStreamContainersForNotifications(List<String> containerIds, AACSessionDelegate sessionDelegate,
      [bool? notificationsEnabled]) async {
    String authToken = await sessionDelegate.authToken();
    if (notificationsEnabled == null) {
      await _sessionChannel.invokeMethod('registerStreamContainersForNotifications', [containerIds, authToken]);
    } else {
      await _sessionChannel.invokeMethod('registerStreamContainersForNotificationsEnabled', [containerIds, authToken, notificationsEnabled]);
    }
  }

  /**
      Asks the SDK to register the given device token against the currently logged in user. The logged in user
      is specified by the authentication token provided by the session delegate.
      If the registration does not success, this method has no effect and throws out an error.
   */
  static Future<void> registerDeviceForNotifications(String pushToken, AACSessionDelegate sessionDelegate) async {
    String authToken = await sessionDelegate.authToken();
    await _sessionChannel.invokeMethod('registerDeviceForNotifications', [pushToken, authToken]);
  }

  /**
      Asks the SDK to deregister the current device for Atomic push notifications, within the current app. If the deregistration fails, it
      throws an error.
   */
  static Future<void> deregisterDeviceForNotifications() async {
    await _sessionChannel.invokeMethod('deregisterDeviceForNotifications', []);
  }

  /**
      Determines whether the given push notification payload is for a push notification sent by the Atomic Platform.

      If the push payload is for an Atomic push notification, this method returns an instance of [AACPushNotification] populated with
      details of the notification. Otherwise, it returns null.
   */
  static Future<AACPushNotification?> notificationFromPushPayload(Map<String, dynamic> payload) async {
    final result = await _sessionChannel.invokeMethod('notificationFromPushPayload', [payload]) as Map<String, dynamic>?;
    if (result != null) {
      return AACPushNotification.fromJson(result);
    } else {
      return null;
    }
  }

  /**
      Asks the SDK to observe the card count for the given stream container on the frequency of the [pollingInterval], calling the [callback] every time
      the count changes.

      The [pollingInterval] must be at least 1 second, otherwise it defaults to 1 second.

      The SDK returns an [observerToken] to distinguish card count observers.

      This method does nothing on the Android platform.
   */
  static Future<String> observeCardCount(
      String containerId, double pollingInterval, AACSessionDelegate sessionDelegate, Function(int cardCount) callback) async {
    String authToken = await sessionDelegate.authToken();
    String observerToken = await _sessionChannel.invokeMethod('observeCardCount', [containerId, pollingInterval, authToken]);
    _cardCountObservers[observerToken] = callback;
    return observerToken;
  }

  /**
      Asks the SDK to stop observing card count for the given token, which was returned from a call to
      [observeCardCount]. If the token does not correspond to an existing card count observer, this method does nothing.
   */
  static Future<void> stopObservingCardCount(String observerToken) async {
    await _sessionChannel.invokeMethod('stopObservingCardCount', [observerToken]);
    _cardCountObservers.remove(observerToken);
  }

  /**
   *  Tracks that a push notification, with the given payload, was received by this device.
   *
   *  If the payload does not represent an Atomic push notification, this method has no effect and throws out an error.
   *  This method dispatches an analytics event back to Atomic to indicate that the user's device received the notification.
   *  It is the responsibility of the integrator to ensure that this method is called at the correct location to ensure accurate tracking.
   */
  static Future<void> trackPushNotificationReceived(Map<String, dynamic> payload, AACSessionDelegate sessionDelegate) async {
    String authToken = await sessionDelegate.authToken();
    await _sessionChannel.invokeMethod('trackPushNotificationReceived', [payload, authToken]);
  }

  /**
   * Triggers an event on the Atomic Platform, exclusively for the user identified by the authentication token provided by the
   * session delegate.
   *
   * Events must opt-in to be triggered from the SDK. To opt-in, turn on the 'Enable client trigger' option in the Atomic Workbench
   * for the event.
   *
   * - [payload] represents the event payload used to trigger the event.
   * - [sessionDelegate] represents a session delegate that identifies the user to trigger the event for.
   *
   * If the request succeeds, details of the processed event are provided with an [AACEventResponse] object, otherwise an error is thrown out.
   */
  static Future<AACEventResponse> sendEvent(AACEventPayload payload, AACSessionDelegate sessionDelegate) async {
    String authToken = await sessionDelegate.authToken();
    var result = await _sessionChannel.invokeMethod('sendEvent', [payload.toJson(), authToken]);
    return AACEventResponse.fromJson(result);
  }

  /**
   * Asks the SDK to return the number of cards for the given stream container.
   *
   * - [streamContainerId] represents the stream container ID to retrieve the card count for.
   * - [sessionDelegate] represents a delegate that supplies a user authentication token when requested by the SDK.
   *
   * The function throws if the card count is not available for this stream container (the user may not have access or the internet connection
   * may be unavailable).
   */
  static Future<int> requestCardCount(String containerId, AACSessionDelegate sessionDelegate) async {
    String authToken = await sessionDelegate.authToken();
    return await _sessionChannel.invokeMethod('requestCardCount', [containerId, authToken]);
  }

  /**
   * Retrieves user metrics for the user identified by the authentication token returned by the
   * [sessionDelegate]. User metrics provide a count of the total number of cards visible to a user,
   * as well as the total number not yet seen by the user.
   *
   * Pass a [streamContainerId] to get user metrics for a specific stream container, or an empty string
   * to retrieve metrics across all containers.
   *
   * Use the returned [AACUserMetrics] object to obtain these values.
   */
  static Future<AACUserMetrics> userMetrics(String streamContainerId, AACSessionDelegate sessionDelegate) async {
    String authToken = await sessionDelegate.authToken();
    var result = await _sessionChannel.invokeMethod('userMetrics', [streamContainerId, authToken]);
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
