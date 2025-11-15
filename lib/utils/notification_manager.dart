import 'package:flutter/foundation.dart';

/// Notification Manager
/// Manages UI refresh triggers when push notifications are received
/// Converted from KMP's NotificationManager.kt
class NotificationManager extends ChangeNotifier {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  bool _notificationTrigger = false;
  bool _notificationLogoutTrigger = false;
  bool _storekeeperAlreadyCheckingTrigger = false;
  int _orderId = 0;

  bool get notificationTrigger => _notificationTrigger;
  bool get notificationLogoutTrigger => _notificationLogoutTrigger;
  bool get storekeeperAlreadyCheckingTrigger => _storekeeperAlreadyCheckingTrigger;
  int get orderId => _orderId;

  /// Trigger UI refresh (notifies listeners)
  void triggerRefresh() {
    _notificationTrigger = true;
    notifyListeners();
  }

  /// Reset refresh trigger
  void resetTrigger() {
    _notificationTrigger = false;
    notifyListeners();
  }

  /// Trigger logout
  void triggerLogout() {
    _notificationLogoutTrigger = true;
    notifyListeners();
  }

  /// Reset logout trigger
  void resetLogoutTrigger() {
    _notificationLogoutTrigger = false;
    notifyListeners();
  }

  /// Trigger storekeeper already checking notification
  void triggerStorekeeperAlreadyChecking(int orderId) {
    _orderId = orderId;
    _storekeeperAlreadyCheckingTrigger = true;
    notifyListeners();
  }

  /// Reset storekeeper checking trigger
  void resetStorekeeperAlreadyCheckingTrigger() {
    _orderId = 0;
    _storekeeperAlreadyCheckingTrigger = false;
    notifyListeners();
  }
}

