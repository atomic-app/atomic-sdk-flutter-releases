/**
 * Represents a runtime variable for a given card.
 * Runtime variables are resolved by the host app via `AACSessionDelegate`.
 */
class AACCardRuntimeVariable {
  /**
   * The name used to identify the runtime variable in a card.
   */
  final String name;

  /**
   * The default value to use for the runtime variable, used if the host app cannot provide a value.
   */
  final String defaultValue;

  AACCardRuntimeVariable.fromJson(dynamic arguments): name = arguments['name'], defaultValue=arguments['defaultValue'];
}

/**
 * Represents an individual card displayed to the end user.
 */
class AACCardInstance {
  /**
   * The name of the event, as defined in the Atomic Workbench, that caused this card
   * to be created.
   */
  final String eventName;

  /**
   * The lifecycle ID sent with the event that created this card.
   */
  final String lifecycleId;

  /**
   * All runtime variables in use by this card.
   */
  final List<AACCardRuntimeVariable> runtimeVariables;

  final Map<String, String> _variableValues = {};

  AACCardInstance(this.eventName, this.lifecycleId, this.runtimeVariables);

  AACCardInstance.fromJson(dynamic arguments):
        eventName = arguments['eventName'],
        lifecycleId = arguments['lifecycleId'],
        runtimeVariables = [] {
    for(var runtimeVarRaw in arguments['runtimeVariables']) {
      var runtimeVar = AACCardRuntimeVariable.fromJson(runtimeVarRaw);
      if (runtimeVar.name.isNotEmpty) {
        runtimeVariables.add(runtimeVar);
        _variableValues[runtimeVar.name] = runtimeVar.defaultValue;
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'eventName': eventName,
      'lifecycleId': lifecycleId,
      'runtimeVariables': [for (var e in _variableValues.entries) {'name': e.key, 'runtimeValue': e.value}]
    };
  }

  /**
   * Assigns the given `value` to the variable with the given `name`.
   * If the variable with the given name does not exist on this card, this method does nothing for that variable.
   */
  void resolveRuntimeVariable(String name, String value) {
    if(name.isNotEmpty && value.isNotEmpty && _variableValues[name] != null) {
      _variableValues[name] = value;
    }
  }
}