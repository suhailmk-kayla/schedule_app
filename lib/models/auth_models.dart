import 'package:json_annotation/json_annotation.dart';

part 'auth_models.g.dart';

/// Login Request Model
/// Converted from KMP's login params
@JsonSerializable()
class LoginRequest {
  @JsonKey(name: 'token')
  final String deviceToken;

  @JsonKey(name: 'code')
  final String userCode;

  @JsonKey(name: 'password')
  final String password;

  const LoginRequest({
    required this.deviceToken,
    required this.userCode,
    required this.password,
  });

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

/// Login Response Data Model
/// Converted from KMP's login response data
@JsonSerializable()
class LoginResponseData {
  @JsonKey(defaultValue: -1)
  final int id;

  @JsonKey(defaultValue: '')
  final String name;

  @JsonKey(defaultValue: '')
  final String token;

  @JsonKey(name: 'cat_id', defaultValue: 0)
  final int catId; // 1-Admin 2-Storekeeper 3-SalesMan 4-supplier 5-Biller 6-Checker

  const LoginResponseData({
    this.id = -1,
    this.name = '',
    this.token = '',
    this.catId = 0,
  });

  factory LoginResponseData.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseDataFromJson(json);
  Map<String, dynamic> toJson() => _$LoginResponseDataToJson(this);
}

/// Login Response Model
/// Converted from KMP's login response
@JsonSerializable()
class LoginResponse {
  @JsonKey(defaultValue: 2)
  final int status; // 1 = success, 2 = failure

  @JsonKey(defaultValue: '')
  final String message;

  @JsonKey(name: 'error', defaultValue: '')
  final String error; // Some responses use 'error' instead of 'message'

  @JsonKey(
    defaultValue: null,
    fromJson: _dataFromJson, // Custom converter
  )
  final LoginResponseData? data;

  const LoginResponse({
    this.status = 2,
    this.message = '',
    this.error = '',
    this.data,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) =>
      _$LoginResponseFromJson(json);
  Map<String, dynamic> toJson() => _$LoginResponseToJson(this);

  bool get isSuccess => status == 1;
  
  // Get error message - check both 'error' and 'message' fields
  String get errorMessage {
    if (error.isNotEmpty) return error;
    if (message.isNotEmpty) return message;
    return 'Login failed. Please try again.';
  }
  
  // Custom converter to handle data field when it's a List or not a Map
  static LoginResponseData? _dataFromJson(dynamic json) {
    if (json == null) return null;
    if (json is List) return null; // Empty array or list means no data
    if (json is Map<String, dynamic>) {
      return LoginResponseData.fromJson(json);
    }
    return null; // Invalid type, return null
  }
}