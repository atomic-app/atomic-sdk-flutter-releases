import 'package:atomic_sdk_flutter/atomic_card_event.dart';
import 'package:atomic_sdk_flutter/atomic_card_filter.dart';
import 'package:atomic_sdk_flutter/atomic_card_runtime_variable.dart';
import 'package:atomic_sdk_flutter/atomic_horizontal_container_view.dart';
import 'package:atomic_sdk_flutter/atomic_single_card_view.dart';
import 'package:atomic_sdk_flutter/atomic_stream_container.dart';
import 'package:atomic_sdk_flutter/src/atomic_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// An [AACViewState] instance can be retrieved from one of the three Atomic views' `onViewLoaded` callback:
/// - [AACStreamContainer.onViewLoaded]
/// - [AACSingleCardView.onViewLoaded]
/// - [AACHorizontalContainerView.onViewLoaded]
final class AACViewState extends State<AACView> {
  late final String _viewType;
  late final Map<String, dynamic> _creationParams;
  late MethodChannel _channel;
  AndroidViewController? _androidController;
  double _viewHeight = 1;

  @override
  void initState() {
    _initCreationParams();
    _initViewType();
    super.initState();
  }

  @override
  void dispose() {
    _androidController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        if (widget is AACHorizontalContainerView) {
          throw UnimplementedError(
            "Horizontal container is not available on Android yet.",
          );
        }
        return SizedBox(
          width: double.infinity,
          height: widget is AACSizeChangingView ? _viewHeight : null,
          child: PlatformViewLink(
            viewType: _viewType,
            surfaceFactory:
                (BuildContext context, PlatformViewController controller) {
              return AndroidViewSurface(
                controller: controller as AndroidViewController,
                gestureRecognizers: <Factory<PanGestureRecognizer>>{}..add(
                    const Factory<PanGestureRecognizer>(
                      PanGestureRecognizer.new,
                    ),
                  ),
                hitTestBehavior: PlatformViewHitTestBehavior.opaque,
              );
            },
            onCreatePlatformView: (PlatformViewCreationParams params) {
              return _androidController =
                  PlatformViewsService.initExpensiveAndroidView(
                id: params.id,
                viewType: _viewType,
                layoutDirection: TextDirection.ltr,
                creationParams: _creationParams,
                creationParamsCodec: const JSONMessageCodec(),
              )
                    ..addOnPlatformViewCreatedListener(
                      params.onPlatformViewCreated,
                    )
                    ..addOnPlatformViewCreatedListener(_createMethodChannel);
            },
          ),
        );
      case TargetPlatform.iOS:
        return SizedBox(
          width: double.infinity,
          height: widget is AACSizeChangingView ? _viewHeight : null,
          child: UiKitView(
            viewType: _viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: _creationParams,
            gestureRecognizers: <Factory<PanGestureRecognizer>>{}..add(
                const Factory<PanGestureRecognizer>(
                  PanGestureRecognizer.new,
                ),
              ),
            onPlatformViewCreated: _createMethodChannel,
            creationParamsCodec: const JSONMessageCodec(),
          ),
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        throw UnsupportedError(
          'The Atomic SDK Flutter wrapper supports iOS and Android only.',
        );
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    final args = (call.arguments as Map?)?.cast<String, dynamic>();
    switch (call.method) {
      case 'viewLoaded':
        // Indicate that the native container has been completely loaded
        widget.onViewLoaded?.call(this);
      case 'didTapActionButton':
        widget.actionDelegate?.didTapActionButton();
      case 'sizeChanged':
        if (args
            case {
              "width": final num width,
              "height": final num height,
            } when widget is AACSizeChangingView) {
          setState(() {
            _viewHeight = height.toDouble();
          });
          (widget as AACSizeChangingView)
              .onSizeChanged
              ?.call(width.toDouble(), _viewHeight);
        }
      case 'didTapLinkButton':
        if (args
            case {
              "cardInstanceId": final String cardInstanceId,
              "containerId": final String containerId,
              "actionPayload": final Map<dynamic, dynamic> actionPayload,
            } when widget.actionDelegate != null) {
          final action = AACCardCustomAction(
            cardInstanceId: cardInstanceId,
            containerId: containerId,
            actionPayload: actionPayload.cast<String, dynamic>(),
          );
          widget.actionDelegate!.didTapLinkButton(action);
        }
      case 'didTapSubmitButton':
        if (args
            case {
              "cardInstanceId": final String cardInstanceId,
              "containerId": final String containerId,
              "actionPayload": final Map<dynamic, dynamic> actionPayload,
            } when widget.actionDelegate != null) {
          final action = AACCardCustomAction(
            cardInstanceId: cardInstanceId,
            containerId: containerId,
            actionPayload: actionPayload.cast<String, dynamic>(),
          );
          widget.actionDelegate!.didTapSubmitButton(action);
        }
      case 'requestRuntimeVariables':
        if (args
            case {"cardsToResolve": final List<dynamic> cardsToResolveRaw}) {
          final cards = <AACCardInstance>[];
          for (final cardJson
              in cardsToResolveRaw.cast<Map<dynamic, dynamic>>()) {
            final card = AACCardInstance.fromJson(
              cardJson.cast<String, dynamic>(),
            );
            cards.add(card);
          }
          final results = await widget.runtimeVariableDelegate
                  ?.requestRuntimeVariables(cards) ??
              cards;
          return results.map((e) => e.toJson()).toList();
        }
      case 'didTriggerCardEvent':
        if (args case {"cardEvent": final Map<dynamic, dynamic> cardEvent}
            when widget.eventDelegate != null) {
          final event = AACCardEvent.fromJson(
            cardEvent.cast<String, dynamic>(),
          );
          widget.eventDelegate!.didTriggerCardEvent(event);
        }
    }
  }

  void _createMethodChannel(int viewId) {
    _channel = MethodChannel("$_viewType/$viewId");
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  // NOTICE this doesn't do anything at the moment
  Future<void> refresh() async {
    await _channel.invokeMethod("refresh");
  }

  Future<void> updateVariables() async {
    await _channel.invokeMethod("updateVariables");
  }

  Future<void> applyFilter(AACCardFilter? filter) async {
    /// Applies a specified filter to the card list, showing only cards that match this filters.
    /// Each `applyFilter` call overrides the previous call (not incremental). So use `applyFilter`s to apply multiple filters at the same time.
    /// To remove all filters, pass `null` to the [filter] argument.
    await applyFilters(filter == null ? null : [filter]);
  }

  Future<void> applyFilters(List<AACCardFilter>? filters) async {
    /// Applies the specified filters to the card list, showing only cards that match these filters.
    /// Each `applyFilter` call overrides the previous call (not incremental). So use this method, `applyFilter`s, to apply multiple filters at the same time.
    /// To remove all filters, pass `null` or an empty list `[]` to the [filters] argument.
    await _channel.invokeMethod(
      "applyFilters",
      // Arguments explanation: argument is passed as an array to native wrapper, to align with other channel methods.
      // The first argument is a [List] of [AACCardFilter] objects, future arguments can be added in line with it
      [AACCardFilter.toJsonList(filters ?? [])],
    );
  }

  void _initCreationParams() {
    _creationParams = <String, dynamic>{
      "containerId": widget.containerId,
      "configuration": widget.configuration,
    };
  }

  void _initViewType() {
    const prefix = "io.atomic.sdk.";
    final String suffix;
    if (widget is AACHorizontalContainerView) {
      suffix = "horizontalContainer";
    } else if (widget is AACSingleCardView) {
      suffix = "singleCard";
    } else if (widget is AACStreamContainer) {
      suffix = "streamContainer";
    } else {
      throw Exception("Unsupported ACCView subclass: ${widget.runtimeType}");
    }
    _viewType = prefix + suffix;
  }
}
