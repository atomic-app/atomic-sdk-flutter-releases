import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'atomic_stream_container.dart';

/**
    Represents a push notification successfully parsed by the Atomic SDK.
 */
class AACPushNotification {
  final String containerId;
  final String cardInstanceId;
  final Map detail;

  AACPushNotification(this.containerId, this.cardInstanceId, this.detail);

  AACPushNotification.fromJson(Map json)
      : containerId = json["containerId"],
        cardInstanceId = json["cardInstanceId"],
        detail = json["detail"];
}

/**
    Static methods used to initialise and configure global SDK properties.
 */
class AACSession {
  static MethodChannel _sessionChannel = MethodChannel('io.atomic.sdk.session')
    ..setMethodCallHandler((call) {
      switch (call.method) {
        case 'cardCountChanged':
          String identifier = call.arguments['identifier'];

          if (identifier != null &&
              _cardCountObservers.containsKey(identifier)) {
            _cardCountObservers[identifier](call.arguments['cardCount']);
          }

          break;
      }

      return null;
    });
  static Map _cardCountObservers = Map<String, Function>();

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
    array.
 
    Push notifications will not be delivered to a user unless they have registered for push notifications first. 
    However, the registration of device token and registration of stream container IDs can occur in either order.
   */
  static Future<void> registerStreamContainersForNotifications(
      List<String> containerIds, AACSessionDelegate sessionDelegate) async {
    String authToken = await sessionDelegate.authToken();
    await _sessionChannel.invokeMethod(
        'registerStreamContainersForNotifications', [containerIds, authToken]);
  }

  /**
    Asks the SDK to register the given device token against the currently logged in user. The logged in user
    is specified by the authentication token provided by the session delegate.
   */
  static Future<void> registerDeviceForNotifications(
      String pushToken, AACSessionDelegate sessionDelegate) async {
    String authToken = await sessionDelegate.authToken();
    await _sessionChannel
        .invokeMethod('registerDeviceForNotifications', [pushToken, authToken]);
  }

  /**
    Asks the SDK to deregister the current device for Atomic push notifications, within the current app.
   */
  static Future<bool> deregisterDeviceForNotifications() async {
    try {
      await _sessionChannel
          .invokeMethod('deregisterDeviceForNotifications', []);
    } catch (e) {
      return false;
    }

    return true;
  }

  /**
    Determines whether the given push notification payload is for a push notification sent by the Atomic Platform.
 
    If the push payload is for an Atomic push notification, this method returns an instance of `AACPushNotification` populated with
    details of the notification. Otherwise, it returns null.
   */
  static Future<AACPushNotification> notificationFromPushPayload(
      Map payload) async {
    try {
      Map result = await _sessionChannel
          .invokeMethod('notificationFromPushPayload', [payload]);

      if (result != null) {
        return AACPushNotification.fromJson(result);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /**
    Asks the SDK to observe the card count for the given stream container, calling the `callback` every time
    the count changes.
   */
  static Future<String> observeCardCount(
      String containerId,
      double pollingInterval,
      AACSessionDelegate sessionDelegate,
      Function(int cardCount) callback) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return "";
    }

    String authToken = await sessionDelegate.authToken();
    String observerToken = await _sessionChannel.invokeMethod(
        'observeCardCount', [containerId, pollingInterval, authToken]);
    _cardCountObservers[observerToken] = callback;
    return observerToken;
  }

  /**
    Asks the SDK to stop observing card count for the given token, which was returned from a call to
    `observeCardCount`. If the token does not correspond to an existing card count observer, this method does nothing.
   */
  static Future<void> stopObservingCardCount(String observerToken) async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return;
    }

    await _sessionChannel
        .invokeMethod('stopObservingCardCount', [observerToken]);
    _cardCountObservers.remove(observerToken);
  }
}
