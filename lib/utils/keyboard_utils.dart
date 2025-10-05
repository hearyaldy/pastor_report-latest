import 'package:flutter/material.dart';

/// A utility class to help manage keyboard focus and navigation
class KeyboardUtils {
  /// Hide the keyboard
  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  /// Move focus to the next field
  static void nextFocus(BuildContext context) {
    FocusScope.of(context).nextFocus();
  }

  /// Move focus to the previous field
  static void previousFocus(BuildContext context) {
    FocusScope.of(context).previousFocus();
  }

  /// Request focus for a specific field
  static void requestFocus(BuildContext context, FocusNode focusNode) {
    FocusScope.of(context).requestFocus(focusNode);
  }

  /// Check if keyboard is visible
  static bool isKeyboardVisible(BuildContext context) {
    return MediaQuery.of(context).viewInsets.bottom > 0;
  }
}
