import 'package:flutter/material.dart';

/// This class isn't particularly intended for external access.
@protected
class AACUtils {
  static String toLocalIsoStr(DateTime dateTime) {
    return dateTime.toLocal().toIso8601String();
  }
}
