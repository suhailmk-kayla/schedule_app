import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// Toast Type Enum
/// Defines different types of toast messages
enum ToastType {
  success,
  error,
  warning,
  info,
}

/// Toast Helper
/// Custom wrapper around fluttertoast for showing toast messages
/// Usage: ToastHelper.show('Message', ToastType.success)
class ToastHelper {
  /// Show a toast message with the specified type
  /// 
  /// [message] - The message to display
  /// [type] - The type of toast (success, error, warning, info)
  /// [duration] - How long to show the toast (default: Toast.lengthShort)
  /// [gravity] - Position of the toast (default: ToastGravity.BOTTOM)
  static void show(
    String message, {
    ToastType type = ToastType.info,
    Toast length = Toast.LENGTH_SHORT,
    ToastGravity gravity = ToastGravity.TOP,
  }) {
    final toastConfig = _getToastConfig(type);
    
    Fluttertoast.showToast(
      msg: message,
      toastLength: length,
      gravity: gravity,
      backgroundColor: toastConfig.backgroundColor,
      textColor: toastConfig.textColor,
      fontSize: 16.0,
    );
  }

  /// Show success toast
  static void showSuccess(String message) {
    show(message, type: ToastType.success);
  }

  /// Show error toast
  static void showError(String message) {
    show(message, type: ToastType.error);
  }

  /// Show warning toast
  static void showWarning(String message) {
    show(message, type: ToastType.warning);
  }

  /// Show info toast
  static void showInfo(String message) {
    show(message, type: ToastType.info);
  }

  /// Get toast configuration based on type
  static _ToastConfig _getToastConfig(ToastType type) {
    switch (type) {
      case ToastType.success:
        return const _ToastConfig(
          backgroundColor: Color(0xFF4CAF50), // Green
          textColor: Colors.white,
        );
      case ToastType.error:
        return const _ToastConfig(
          backgroundColor: Color(0xFFF44336), // Red
          textColor: Colors.white,
        );
      case ToastType.warning:
        return const _ToastConfig(
          backgroundColor: Color(0xFFFF9800), // Orange
          textColor: Colors.white,
        );
      case ToastType.info:
        return const _ToastConfig(
          backgroundColor: Color(0xFF2196F3), // Blue
          textColor: Colors.white,
        );
    }
  }
}

/// Toast Configuration
/// Internal class to hold toast styling configuration
class _ToastConfig {
  final Color backgroundColor;
  final Color textColor;

  const _ToastConfig({
    required this.backgroundColor,
    required this.textColor,
  });
}

