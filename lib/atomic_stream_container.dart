import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

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
 * Configuration object that allows integrators to tailor the stream container.
 */
class AACStreamContainerConfiguration {
  int pollingInterval = 15;
  AACVotingOption votingOption = AACVotingOption.none;
  AACStreamContainerLaunchColors launchColors =
      AACStreamContainerLaunchColors();

  Map<String, dynamic> toJson() {
    return {
      'pollingInterval': pollingInterval,
      'cardVotingOptions': votingOption.stringValue,
      'launchColors': launchColors
    };
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

  Map<String, dynamic> toJson() {
    return {
      'background': background.value,
      'loadingIndicator': loadingIndicator.value,
      'button': button.value,
      'text': text.value
    };
  }
}

/**
 * Extend this class to provide a session delegate that supplies authentication tokens
 * when requested by the SDK.
 */
abstract class AACSessionDelegate {
  Future<String> authToken();
}

/**
 * Creates an Atomic stream container, rendering a list of cards.
 * You must supply a `containerId`, `configuration` object and `sessionDelegate`.
 */
class AACStreamContainer extends StatefulWidget {
  final String containerId;
  final AACStreamContainerConfiguration configuration;
  final AACSessionDelegate sessionDelegate;

  AACStreamContainer(
      {Key key,
      @required this.containerId,
      @required this.configuration,
      @required this.sessionDelegate})
      : super(key: key);

  @override
  AACStreamContainerState createState() => AACStreamContainerState();
}

class AACStreamContainerState extends State<AACStreamContainer> {
  MethodChannel _channel;

  @override
  Widget build(BuildContext context) {
    final String viewType = 'io.atomic.sdk.streamContainer';
    final Map<String, dynamic> creationParams = <String, dynamic>{
      "containerId": widget.containerId,
      "configuration": widget.configuration
    };

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return PlatformViewLink(
          viewType: viewType,
          surfaceFactory:
              (BuildContext context, PlatformViewController controller) {
            return AndroidViewSurface(
              controller: controller,
              gestureRecognizers: const <
                  Factory<OneSequenceGestureRecognizer>>{},
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
            onPlatformViewCreated: (int viewId) {
              _createMethodChannel(viewId);
            },
            creationParamsCodec: const JSONMessageCodec());
      default:
        throw UnsupportedError(
            'The Atomic SDK Flutter wrapper supports iOS and Android only.');
    }
  }

  void _createMethodChannel(int viewId) {
    _channel = MethodChannel(
                  'io.atomic.sdk.streamContainer/' + viewId.toString());
    _channel.setMethodCallHandler(handleMethodCall);
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'requestAuthenticationToken':
        String token = await widget.sessionDelegate.authToken();
        return token;
    }
  }
}

/**
 * Creates an Atomic single card view, rendering the most recent card in the container.
 * You must supply a `containerId`, `configuration` object and `sessionDelegate`.
 */
class AACSingleCardView extends StatefulWidget {
  final String containerId;
  final AACStreamContainerConfiguration configuration;
  final AACSessionDelegate sessionDelegate;
  final Function(double width, double height) onSizeChanged;

  AACSingleCardView(
      {Key key,
      @required this.containerId,
      @required this.configuration,
      @required this.sessionDelegate,
      this.onSizeChanged})
      : super(key: key);

  @override
  AACSingleCardViewState createState() => AACSingleCardViewState();
}

class AACSingleCardViewState extends State<AACSingleCardView> {
  MethodChannel _channel;
  double singleCardHeight = 0;

  AACSingleCardViewState() {
    if(defaultTargetPlatform == TargetPlatform.iOS) {
      // Single card view on iOS requires a non-zero height to render correctly.
      singleCardHeight = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String viewType = 'io.atomic.sdk.singleCard';
    final Map<String, dynamic> creationParams = <String, dynamic>{
      "containerId": widget.containerId,
      "configuration": widget.configuration
    };

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return Column(children: []);
      case TargetPlatform.iOS:
        return SizedBox(
            width: double.infinity,
            height: singleCardHeight,
            child: UiKitView(
                viewType: viewType,
                layoutDirection: TextDirection.ltr,
                creationParams: creationParams,
                gestureRecognizers: Set()..add(Factory<PanGestureRecognizer>(() => PanGestureRecognizer())),
                onPlatformViewCreated: (int viewId) {
                  _channel = MethodChannel(
                      'io.atomic.sdk.singleCard/' + viewId.toString());
                  _channel.setMethodCallHandler(handleMethodCall);
                },
                creationParamsCodec: const JSONMessageCodec()));
      default:
        throw UnsupportedError(
            'The Atomic SDK Flutter wrapper supports iOS and Android only.');
    }
  }

  Future<dynamic> handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'requestAuthenticationToken':
        String token = await widget.sessionDelegate.authToken();
        return token;
      case 'sizeChanged':
        double width = call.arguments['width'];
        double height = call.arguments['height'];

        setState(() {
          singleCardHeight = height;
        });

        if (widget.onSizeChanged != null) {
          widget.onSizeChanged(width, height);
        }

        break;
    }
  }
}
