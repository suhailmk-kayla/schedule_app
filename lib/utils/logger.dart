import 'dart:developer';

class Logger {
  static void info(String message) => log('ℹ️ INFO: $message');
  static void error(String message) => log('❌ ERROR: $message');
}
