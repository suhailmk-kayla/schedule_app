/// API Configuration
/// Converted from KMP's Config.kt
class ApiConfig {
  static const String baseUrl = 'https://schedulefoms.in/schedule/mobileApp/';
  // For development/testing, use environment variables or build flavors
  // static const String baseUrl="http://192.168.2.8:8000/";
  static const bool isProductionMode = false;
  static const String noteSplitDel = '***###***';
  static const String replacedSubDelOrderSubId = '***\$###\$***OrderSubId=';
}