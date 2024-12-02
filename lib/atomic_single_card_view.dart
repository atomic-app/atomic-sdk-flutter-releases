import 'package:atomic_sdk_flutter/atomic_stream_container.dart';
import 'package:atomic_sdk_flutter/src/atomic_view.dart';

/// Creates an Atomic single card view, rendering the most recent card in the container.
/// You must supply a `containerId` and `configuration` object.
final class AACSingleCardView
    extends AACSizeChangingView<AACSingleCardConfiguration> {
  const AACSingleCardView({
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

/// Specialised configuration object for use with a single card view.
class AACSingleCardConfiguration extends AACStreamContainerConfiguration {
  /// Whether the single card view should automatically display the next card in the list, if there is one,
  /// once the current card is actioned.
  /// Defaults to `false`.
  bool automaticallyLoadNextCard = false;

  @override
  Map<String, dynamic> toJson() {
    final jsonValue = super.toJson();
    jsonValue["automaticallyLoadNextCard"] = automaticallyLoadNextCard;
    return jsonValue;
  }
}
