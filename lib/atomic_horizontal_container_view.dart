import 'package:atomic_sdk_flutter/atomic_stream_container.dart';
import 'package:atomic_sdk_flutter/src/atomic_view.dart';

/// Creates a view designed to display a horizontal list of cards for a given stream container.
/// Cards in a horizontal list have the same card width, which must be specified during initialisation.
/// The stream container it displays is identified by its ID in the Workbench.

final class AACHorizontalContainerView
    extends AACSizeChangingView<AACHorizontalContainerConfiguration> {
  const AACHorizontalContainerView({
    required super.containerId,
    required super.configuration,
    super.key,
    super.runtimeVariableDelegate,
    super.actionDelegate,
    super.eventDelegate,
    super.onSizeChanged,
    super.onViewLoaded,
  });
}

/// Specialised configuration object for use with a horizontal container view.
class AACHorizontalContainerConfiguration
    extends AACStreamContainerConfiguration {
  AACHorizontalContainerConfiguration({
    required this.cardWidth,
  });

  /// The width of every card displayed in the horizontal container view.
  final double cardWidth;

  /// The empty style of a horizontal container view. It determines how the view displays
  /// when there are no cards. Defaults to [AACHorizontalContainerConfigurationEmptyStyle.standard].
  AACHorizontalContainerConfigurationEmptyStyle emptyStyle =
      AACHorizontalContainerConfigurationEmptyStyle.standard;

  /// The option for aligning the title of the header horizontally.
  /// Defaults to [AACHorizontalContainerConfigurationHeaderAlignment.center].
  AACHorizontalContainerConfigurationHeaderAlignment headerAlignment =
      AACHorizontalContainerConfigurationHeaderAlignment.center;

  /// The option for aligning the last card in a horizontal container.
  /// Defaults to [AACHorizontalContainerConfigurationLastCardAlignment.left].
  AACHorizontalContainerConfigurationLastCardAlignment lastCardAlignment =
      AACHorizontalContainerConfigurationLastCardAlignment.left;

  /// The option for controlling the scroll mode of the container. Defaults to [AACHorizontalContainerConfigurationScrollMode.snap].
  AACHorizontalContainerConfigurationScrollMode scrollMode =
      AACHorizontalContainerConfigurationScrollMode.snap;

  @override
  Map<String, dynamic> toJson() {
    final jsonValue = super.toJson();
    jsonValue["cardWidth"] = cardWidth;
    jsonValue["emptyStyle"] = emptyStyle.value;
    jsonValue["headerAlignment"] = headerAlignment.value;
    jsonValue["lastCardAlignment"] = lastCardAlignment.value;
    jsonValue["scrollMode"] = scrollMode.value;
    return jsonValue;
  }
}

/// The style of empty state (when there are no cards) for the horizontal container.
enum AACHorizontalContainerConfigurationEmptyStyle {
  /// The horizontal container should always display a no card user interface.
  standard("standard"),

  /// The horizontal container should shrink itself when there are no cards.
  shrink("shrink");

  const AACHorizontalContainerConfigurationEmptyStyle(this.value);
  final String value;
}

/// Options that specify the alignment of the title in the horizontal header.
enum AACHorizontalContainerConfigurationHeaderAlignment {
  /// The title is aligned in the middle of the header.
  center("center"),

  /// The title is aligned to the left of the header.
  left("left");

  const AACHorizontalContainerConfigurationHeaderAlignment(this.value);
  final String value;
}

/// Options that control the alignment of the last card in the horizontal container.
/// This option only applies when there is only one card in the container.
enum AACHorizontalContainerConfigurationLastCardAlignment {
  /// The last card is aligned to the left of the container.
  left("left"),

  /// The last card is aligned in the middle of the container.
  center("center");

  const AACHorizontalContainerConfigurationLastCardAlignment(this.value);
  final String value;
}

/// Options that control the scroll mode of the horizontal container.
enum AACHorizontalContainerConfigurationScrollMode {
  /// The container scrolls over one card at a time, where applicable the card is placed
  /// in the middle of the view port when the scroll terminates.
  snap("snap"),

  /// The container scrolls freely.
  free("free");

  const AACHorizontalContainerConfigurationScrollMode(this.value);
  final String value;
}
