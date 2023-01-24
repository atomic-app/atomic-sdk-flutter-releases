import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'atomic_card_event.dart';
import 'atomic_card_runtime_variable.dart';

/**
 * Supported options for card voting.
 */
enum AACVotingOption { none, useful, notUseful, both }

extension VotingOptionSerialised on AACVotingOption {
  String get stringValue {
    switch (this) {
      case AACVotingOption.none:
        return 'none';
      case AACVotingOption.useful:
        return 'useful';
      case AACVotingOption.notUseful:
        return 'notUseful';
      case AACVotingOption.both:
        return 'both';
      default:
        return 'none';
    }
  }
}

/**
 * Supported flags for interface style.
 */
enum AACInterfaceStyle { automatic, light, dark }

extension InterfaceStyleSerialised on AACInterfaceStyle {
  String get stringValue {
    switch (this) {
      case AACInterfaceStyle.automatic:
        return "automatic";
      case AACInterfaceStyle.dark:
        return "dark";
      case AACInterfaceStyle.light:
        return "light";
      default:
        return "automatic";
    }
  }
}

enum AACCustomString {
  /**
      The title to display at the top of the card list.
      Defaults to `Cards`.
   */
  cardListTitle,
  /**
      The title to display for the card snooze functionality.
      Defaults to `Remind me`.
   */
  cardSnoozeTitle,
  /**
      The message displayed over the card list, when the user has never received a card before.
      Defaults to `Cards will appear here when there’s something to action.`.
   */
  awaitingFirstCard,
  /**
      The message displayed when the user has received at least one card before, and there are no cards to show.
      Defaults to `All caught up`.
   */
  allCardsCompleted,
  /**
      The title to display for the action a user taps when they flag a card as useful.
      Defaults to `This is useful`.
   */
  votingUseful,
  /**
      The title to display for the action a user taps when they flag a card as not useful.
      Defaults to `This isn't useful`.
   */
  votingNotUseful,
  /**
      The title to display at the top of the screen allowing a user to provide feedback on why
      they didn't find a card useful.
      Defaults to `Send feedback`.
   */
  votingFeedbackTitle,
  /**
      Message to display below the last card in the card list, if there is at least 1 card present.
      Has no effect in single card view, or if `cardListFooterMessageEnabled` is set to `false`.
      Defaults to an empty string.
   */
  cardListFooterMessage,
  /**
      Message to display on the first load screen and card list when there is no internet connection.
      Defaults to `No internet connection`.
   */
  noInternetConnectionMessage,
  /**
      Message to display on the first load screen and card list when data fails to load.
      Defaults to `Couldn't load data`.
   */
  dataLoadFailedMessage,
  /**
      The title for the button on the first load screen and card list, allowing the user to retry the request.
      Defaults to `Try again`.
   */
  tryAgainTitle
}

extension CustomStringSerialised on AACCustomString {
  String get stringValue {
    switch (this) {
      case AACCustomString.cardListTitle:
        return "cardListTitle";
      case AACCustomString.cardSnoozeTitle:
        return "cardSnoozeTitle";
      case AACCustomString.awaitingFirstCard:
        return "awaitingFirstCard";
      case AACCustomString.allCardsCompleted:
        return "allCardsCompleted";
      case AACCustomString.votingUseful:
        return "votingUseful";
      case AACCustomString.votingNotUseful:
        return "votingNotUseful";
      case AACCustomString.votingFeedbackTitle:
        return "votingFeedbackTitle";
      case AACCustomString.cardListFooterMessage:
        return "cardListFooterMessage";
      case AACCustomString.noInternetConnectionMessage:
        return "noInternetConnectionMessage";
      case AACCustomString.dataLoadFailedMessage:
        return "dataLoadFailedMessage";
      case AACCustomString.tryAgainTitle:
        return "tryAgainTitle";
      default:
        throw Exception('Unsupported custom string.');
    }
  }
}

enum AACPresentationStyle {
  /**
      The stream container should not display a button in its top left.
      It is your responsibility to ensure that the stream container is presented
      in a way that allows the user to navigate away from it.
   */
  withoutButton,
  /**
      The stream container should display an action (overflow) button in its
      top left. When tapped, you will be notified via the action delegate, at which
      point you can perform your own custom action.
   */
  withActionButton,
  /**
      The stream container is being presented with a Close button in its top left.
   */
  withContextualButton
}

extension PresentationStyleSerialised on AACPresentationStyle {
  String get stringValue {
    switch (this) {
      case AACPresentationStyle.withActionButton:
        return "withActionButton";
      case AACPresentationStyle.withContextualButton:
        return "withContextualButton";
      case AACPresentationStyle.withoutButton:
        return "withoutButton";
      default:
        return "withoutButton";
    }
  }
}

/**
 * Bitmask of user interface elements that should be enabled in the stream container.
 * The default value enables toast messages and the card list header.
 */
class AACUIElement {
  final int index;

  const AACUIElement(this.index);

  /**
   * Value indicating that none of the listed UI elements should be shown.
   */
  static const AACUIElement none = const AACUIElement(0);

  /**
   * Value indicating that toast messages should shown over the card list.   *
   */
  static const AACUIElement cardListToast = const AACUIElement(1 << 0);

  /**
   * Value indicating that the footer message should be shown beneath the last card in the list.   *
   */
  static const AACUIElement cardListFooterMessage = const AACUIElement(1 << 1);

  /**
   * Value indicating that the header should be shown at the top of the card list.   *
   */
  static const AACUIElement cardListHeader = const AACUIElement(1 << 2);

  /**
   * Value indicating that toast messages and the card list header should be shown.   *
   */
  static final AACUIElement defaultValue = AACUIElement.cardListHeader | AACUIElement.cardListToast;

  operator |(AACUIElement other) => AACUIElement(other.index | this.index);

  operator &(AACUIElement other) => AACUIElement(other.index & this.index);

  operator ~() => AACUIElement(~this.index);

  bool contains(AACUIElement other) => (this & other).index == other.index;

  List<String> get toJson {
    List<String> values = [];
    if (this.contains(cardListToast)) {
      values.add('cardListToast');
    }
    if (this.contains(cardListFooterMessage)) {
      values.add('cardListFooterMessage');
    }
    if (this.contains(cardListHeader)) {
      values.add('cardListHeader');
    }
    return values;
  }
}

/**
    Represents features that can be turned on or off in the Atomic SDK.
 */
class AACFeatureFlags {
  /**
      Whether the `runtime-vars-updated` analytics event, which includes resolved values of each
      runtime variable, should be sent when runtime variables are resolved. Defaults to `false`.

      When setting this flag to `true`, ensure that the resolved values of your runtime variables
      do not include any sensitive information that should not appear in analytics.
   */
  bool runtimeVariableAnalytics = false;
}

/**
 * Configuration object that allows integrators to tailor the stream container.
 */
class AACStreamContainerConfiguration {
  int pollingInterval = 15;
  AACVotingOption votingOption = AACVotingOption.none;
  AACStreamContainerLaunchColors launchColors = AACStreamContainerLaunchColors();
  AACInterfaceStyle interfaceStyle = AACInterfaceStyle.automatic;
  Map<AACCustomString, String> customStrings = {};
  AACPresentationStyle presentationStyle = AACPresentationStyle.withoutButton;
  AACUIElement enabledUiElements = AACUIElement.defaultValue;
  int runtimeVariableResolutionTimeout = 5;
  AACFeatureFlags features = AACFeatureFlags();

  Map<String, dynamic> toJson() {
    var jsonValue = {
      'pollingInterval': pollingInterval,
      'cardVotingOptions': votingOption.stringValue,
      'launchColors': launchColors,
      'interfaceStyle': interfaceStyle.stringValue,
      'presentationStyle': presentationStyle.stringValue,
      'enabledUiElements': enabledUiElements.toJson,
      'runtimeVariableResolutionTimeout': runtimeVariableResolutionTimeout,
      'runtimeVariableAnalytics': features.runtimeVariableAnalytics
    };
    if (customStrings.isNotEmpty) {
      jsonValue['customStrings'] = customStrings.map((key, value) => MapEntry(key.stringValue, value));
    }
    return jsonValue;
  }

  /**
      Assigns the given value to the custom string defined by the given key.
      `value` must be non-empty.
   */
  void setValueForCustomString(AACCustomString key, String value) {
    if (value.isEmpty) {
      // Don't allow empty strings.
      return;
    }
    customStrings[key] = value;
  }
}

/**
 * Specialised configuration object for use with a single card view.
 */
class AACSingleCardConfiguration extends AACStreamContainerConfiguration {
  /**
   * Whether the single card view should automatically display the next card in the list, if there is one,
   * once the current card is actioned.
   * Defaults to [false].
   */
  bool automaticallyLoadNextCard = false;

  @override
  Map<String, dynamic> toJson() {
    var jsonValue = super.toJson();
    jsonValue["automaticallyLoadNextCard"] = automaticallyLoadNextCard;
    return jsonValue;
  }
}

/**
 * Object that stores customisable colours for first time launch, before a
 * theme has been loaded.
 */
class AACStreamContainerLaunchColors {
  Color background = Color.fromRGBO(255, 255, 255, 1);
  Color loadingIndicator = Color.fromRGBO(0, 0, 0, 1);
  Color button = Color.fromRGBO(0, 0, 0, 1);
  Color text = Color.fromRGBO(0, 0, 0, 0.5);
  Color statusBarBackground = Color.fromRGBO(0, 0, 0, 1);

  Map<String, dynamic> toJson() {
    return {
      'background': background.value,
      'loadingIndicator': loadingIndicator.value,
      'button': button.value,
      'text': text.value,
      "statusBarBackground": statusBarBackground.value
    };
  }
}

/**
 * Extend this class to provide a session delegate that supplies authentication tokens
 * when requested by the SDK.
 * The method [authToken] must be implemented, and is used to supply an authentication token to the SDK.
 * If you do not supply a valid authentication token, API requests within the SDK will fail.
 */
abstract class AACSessionDelegate {
  /**
   * Called when the SDK has requested an authentication token.
   */
  Future<String> authToken ();
}

/**
 * Implements logic to resolve runtime variables on cards, when requested by the SDK.
 *
 */
abstract class AACRuntimeVariableDelegate {
  /**
      Delegate method that can be implemented when one or more cards include runtime variables.
      If the card includes runtime variables to be resolved, the SDK will call this method to ask that you resolve them.
      If this method is not implemented, or you do not resolve a given variable, the default values for that variable
      will be used (as defined in the Atomic Workbench).

      Variables are resolved on each card by calling `resolveRuntimeVariableWithName:value:`.

      - [cardInstances] An array of cards containing runtime variables that need to be resolved.
   */
  Future<List<AACCardInstance>?> requestRuntimeVariables(List<AACCardInstance> cardInstances) async {
    return null;
  }
}

/**
    Represents a custom action triggered by a link button or submit button on a card.
 */
class AACCardCustomAction {
  /**
      The instance ID of the card where the action was triggered.
   */
  final String cardInstanceId;

  /**
      The ID of the stream container that the card is contained within.
   */
  final String containerId;
  /**
      A custom action payload that is associated with the link/submit button.
      Inspect the data in this payload to determine which action to take.
   */
  final Map<String, dynamic> actionPayload;

  const AACCardCustomAction({required this.cardInstanceId, required this.containerId, required this.actionPayload});
}

/**
 * Represents an instance of a filter that can be applied to a list of cards.
 */
class AACCardFilter {
  /// The instance ID of the card to show.
  String _cardInstanceId;

  AACCardFilter.byCardInstanceId(String cardInstanceId): _cardInstanceId = cardInstanceId;

  Map<String, String> get toJson => {"byCardInstanceId": _cardInstanceId};
}

/**
 * Extend this class to provide a delegate that responds to the event of tapping the
 * action button.
 */
abstract class AACStreamContainerActionDelegate {
  /**
   * The user tapped on the button in the top left of the stream container.
   *
   * This method is only called when the `presentationStyle` of the stream container is set
      to [AACPresentationStyle.withActionButton].
   */
  void didTapActionButton() {}

  /**
   * The user tapped on a link button, which is configured with a custom [action] in the Atomic Workbench.
   *
   * The [action] object provided here includes a payload - a set of key-value pairs assigned in the Workbench to this link button.
   * Use the information in this object to determine which action to take in your app.
   */
  void didTapLinkButton(AACCardCustomAction action) {}

  /**
   *  The user submitted a card from a submit button that is configured with a custom [action] in the Atomic Workbench.
   *  The [action] object provided here includes a payload - a set of key-value pairs assigned in the Workbench to this submit button.
   *  Use the information in this object to determine which action to take in your app after the card has been submitted.
   */
  void didTapSubmitButton(AACCardCustomAction action) {}
}

/**
 * Creates an Atomic stream container, rendering a list of cards.
 * You must supply a `containerId` and `configuration` object.
 */
class AACStreamContainer extends StatefulWidget {
  final String containerId;
  final AACStreamContainerConfiguration configuration;
  final AACRuntimeVariableDelegate? runtimeVariableDelegate;
  final AACStreamContainerActionDelegate? actionDelegate;
  final AACCardEventDelegate? eventDelegate;
  final Function(AACStreamContainerState containerState)? onViewLoaded;

  AACStreamContainer(
      {Key? key,
      required this.containerId,
      required this.configuration,
      this.runtimeVariableDelegate,
      this.actionDelegate,
      this.eventDelegate,
      this.onViewLoaded})
      : super(key: key);

  @override
  AACStreamContainerState createState() => AACStreamContainerState();
}

class AACStreamContainerState extends State<AACStreamContainer> {
  late MethodChannel _channel;

  @override
  Widget build(BuildContext context) {
    final String viewType = 'io.atomic.sdk.streamContainer';
    final Map<String, dynamic> creationParams = <String, dynamic>{"containerId": widget.containerId, "configuration": widget.configuration};

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return PlatformViewLink(
          viewType: viewType,
          surfaceFactory: (BuildContext context, PlatformViewController controller) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController,
              gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            );
          },
          onCreatePlatformView: (PlatformViewCreationParams params) {
            return PlatformViewsService.initSurfaceAndroidView(
              id: params.id,
              viewType: viewType,
              layoutDirection: TextDirection.ltr,
              creationParams: creationParams,
              creationParamsCodec: JSONMessageCodec(),
            )
              ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
              ..addOnPlatformViewCreatedListener(_createMethodChannel)
              ..create();
          },
        );
      case TargetPlatform.iOS:
        return UiKitView(
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: creationParams,
            gestureRecognizers: Set()..add(Factory<PanGestureRecognizer>(() => PanGestureRecognizer())),
            onPlatformViewCreated: (int viewId) => _createMethodChannel(viewId),
            creationParamsCodec: const JSONMessageCodec());
      default:
        throw UnsupportedError('The Atomic SDK Flutter wrapper supports iOS and Android only.');
    }
  }

  void _createMethodChannel(int viewId) {
    _channel = MethodChannel('io.atomic.sdk.streamContainer/' + viewId.toString());
    _channel.setMethodCallHandler(handleMethodCall);
  }

  void refresh() {
    _channel.invokeMethod("refresh");
  }

  void applyFilter(AACCardFilter filter) {
    /// Arguments explanation: argument is passed as an array to align with other channel methods.
    /// The first argument is an [AACCardFilter] object, future arguments can be added in line with it
    _channel.invokeMethod("applyFilter", [filter.toJson]);
  }

  void updateVariables() {
    _channel.invokeMethod("updateVariables");
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'viewLoaded':
        /// Indicate that the native container has been completely loaded
        widget.onViewLoaded?.call(this);
        break;
      case 'didTapActionButton':
        widget.actionDelegate?.didTapActionButton();
        break;
      case 'didTapLinkButton':
        if (widget.actionDelegate != null) {
          final action = AACCardCustomAction(
              cardInstanceId: call.arguments["cardInstanceId"],
              containerId: call.arguments["containerId"],
              actionPayload: Map<String, dynamic>.from(call.arguments["actionPayload"]));
          widget.actionDelegate!.didTapLinkButton(action);
        }
        break;
      case 'didTapSubmitButton':
        if (widget.actionDelegate != null) {
          final action = AACCardCustomAction(
              cardInstanceId: call.arguments["cardInstanceId"],
              containerId: call.arguments["containerId"],
              actionPayload: Map<String, dynamic>.from(call.arguments["actionPayload"]));
          widget.actionDelegate!.didTapSubmitButton(action);
        }
        break;
      case 'requestRuntimeVariables':
        List<AACCardInstance> cards = [];
        List<dynamic> cardsToResolveRaw = call.arguments['cardsToResolve'];
        for (var cardJson in cardsToResolveRaw) {
          AACCardInstance card = AACCardInstance.fromJson(cardJson);
          cards.add(card);
        }
        List<AACCardInstance>? results = await widget.runtimeVariableDelegate?.requestRuntimeVariables(cards);
        if (results != null) {
          return results.map((e) => e.toJson()).toList();
        } else {
          return cards.map((e) => e.toJson()).toList();
        }
      case 'didTriggerCardEvent':
        if (widget.eventDelegate != null) {
          AACCardEvent event = AACCardEvent.fromJson(call.arguments['cardEvent']);
          widget.eventDelegate!.didTriggerCardEvent(event);
        }
        break;
    }
  }
}
