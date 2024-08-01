import 'package:atomic_sdk_flutter/atomic_card_event.dart';
import 'package:atomic_sdk_flutter/atomic_stream_container.dart';
import 'package:atomic_sdk_flutter/atomic_view_state.dart';
import 'package:flutter/material.dart';
import 'package:meta/meta.dart';

/// This class isn't intended for external access.
@internal
abstract base class AACView<C extends AACStreamContainerConfiguration>
    extends StatefulWidget {
  const AACView({
    required this.containerId,
    required this.configuration,
    super.key,
    this.runtimeVariableDelegate,
    this.actionDelegate,
    this.eventDelegate,
    this.onViewLoaded,
  });
  final String containerId;
  final C configuration;
  final AACRuntimeVariableDelegate? runtimeVariableDelegate;
  final AACStreamContainerActionDelegate? actionDelegate;
  final AACCardEventDelegate? eventDelegate;
  final void Function(AACViewState containerState)? onViewLoaded;

  @override
  AACViewState createState() => AACViewState();
}

/// This class isn't intended for external access.
@internal
abstract base class AACSizeChangingView<
    C extends AACStreamContainerConfiguration> extends AACView<C> {
  const AACSizeChangingView({
    required super.containerId,
    required super.configuration,
    super.key,
    super.runtimeVariableDelegate,
    super.actionDelegate,
    super.eventDelegate,
    this.onSizeChanged,
    super.onViewLoaded,
  });
  final void Function(double width, double height)? onSizeChanged;
}
