import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'atomic_card_event.dart';
import 'atomic_card_runtime_variable.dart';
import 'atomic_stream_container.dart';

/**
 * Creates an Atomic single card view, rendering the most recent card in the container.
 * You must supply a `containerId` and `configuration` object.
 */
class AACSingleCardView extends StatefulWidget {
  final String containerId;
  final AACSingleCardConfiguration configuration;
  final AACRuntimeVariableDelegate? runtimeVariableDelegate;
  final Function(double width, double height)? onSizeChanged;
  final AACStreamContainerActionDelegate? actionDelegate;
  final AACCardEventDelegate? eventDelegate;
  final Function(AACSingleCardViewState containerState)? onViewLoaded;

  AACSingleCardView(
      {Key? key,
        required this.containerId,
        required this.configuration,
        this.runtimeVariableDelegate,
        this.actionDelegate,
        this.eventDelegate,
        this.onSizeChanged,
        this.onViewLoaded})
      : super(key: key);

  @override
  AACSingleCardViewState createState() => AACSingleCardViewState();
}

class AACSingleCardViewState extends State<AACSingleCardView> {
  late MethodChannel _channel;
  double singleCardHeight = 1;

  @override
  Widget build(BuildContext context) {
    final String viewType = 'io.atomic.sdk.singleCard';
    final Map<String, dynamic> creationParams = <String, dynamic>{"containerId": widget.containerId, "configuration": widget.configuration};

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return SizedBox(
          width: double.infinity,
          height: singleCardHeight,
          child: PlatformViewLink(
              viewType: viewType,
              surfaceFactory: (BuildContext context, PlatformViewController controller) {
                return AndroidViewSurface(
                  controller: controller as AndroidViewController,
                  gestureRecognizers: Set()..add(Factory<PanGestureRecognizer>(() => PanGestureRecognizer())),
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
          ),
        );
      case TargetPlatform.iOS:
        return SizedBox(
            width: double.infinity,
            height: singleCardHeight,
            child: UiKitView(
                viewType: viewType,
                layoutDirection: TextDirection.ltr,
                creationParams: creationParams,
                gestureRecognizers: Set()..add(Factory<PanGestureRecognizer>(() => PanGestureRecognizer())),
                onPlatformViewCreated: (int viewId) => _createMethodChannel(viewId),
                creationParamsCodec: const JSONMessageCodec()));
      default:
        throw UnsupportedError('The Atomic SDK Flutter wrapper supports iOS and Android only.');
    }
  }

  void _createMethodChannel(int viewId) {
    _channel = MethodChannel('io.atomic.sdk.singleCard/' + viewId.toString());
    _channel.setMethodCallHandler(handleMethodCall);
  }

  void refresh() {
    _channel.invokeMethod("refresh");
  }

  void applyFilter(AACCardFilter filter) {
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
      case 'sizeChanged':
        double width = call.arguments['width'].toDouble();
        double height = call.arguments['height'].toDouble();
        setState(() {
          singleCardHeight = height;
        });
        widget.onSizeChanged?.call(width, height);
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
