import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import '../utils/config.dart';
import '../utils/api_endpoints.dart';
import '../models/master_data_api.dart';

/// Helper to register a new admin user
/// Use this when you're stuck and need to create a new admin account
/// 
/// Usage:
/// ```dart
/// final result = await registerAdmin(
///   code: 'ADMIN001',
///   name: 'New Admin',
///   phoneNo: '1234567890',
///   password: 'password123',
///   address: 'Address here',
/// );
/// ```
Future<Map<String, dynamic>> registerAdmin({
  required String code,
  required String name,
  required String phoneNo,
  required String password,
  required String tpin,
  String address = '',
  String? deviceToken,
}) async {
  // Create a new Dio instance (without auth interceptor since we're not logged in)
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  final Map<String, dynamic> body = {
    'tpin': tpin,
    'cat_id': 1, // Admin category ID
    'code': code,
    'name': name,
    'phone_no': phoneNo,
    'address': address,
    'password': password,
    'confirm_password': password, // KMP sends same password for both
  };

  // Add device token if provided (optional)
  if (deviceToken != null && deviceToken.isNotEmpty) {
    body['device_token'] = deviceToken;
  }

  try {
    final response = await dio.post(
      ApiEndpoints.register,
      data: body,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    final responseData = response.data;

    if (response.statusCode == 200) {
      // Parse response using UserSuccessApi model
      try {
        final userSuccessApi = UserSuccessApi.fromJson(
          responseData is Map<String, dynamic>
              ? responseData
              : Map<String, dynamic>.from(responseData),
        );

        if (userSuccessApi.status == 1) {
          return {
            'success': true,
            'message': userSuccessApi.message,
            'user': userSuccessApi.user,
          };
        } else {
          return {
            'success': false,
            'message': userSuccessApi.message,
          };
        }
      } catch (e) {
        // Fallback if parsing fails
        final status = responseData['status'] ?? 2;
        final message = responseData['message'] ?? 'Unknown error';
        
        return {
          'success': status == 1,
          'message': message.toString(),
          'rawResponse': responseData,
        };
      }
    } else {
      return {
        'success': false,
        'message': 'Request failed with status ${response.statusCode}',
      };
    }
  } on DioException catch (e) {
    String errorMessage = 'Network error';
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map && data['message'] != null) {
        errorMessage = data['message'].toString();
      } else if (data is Map && data['data'] != null) {
        // KMP sometimes returns errors in 'data' array
        final errorData = data['data'];
        if (errorData is List && errorData.isNotEmpty) {
          errorMessage = errorData.first.toString();
        }
      }
    } else {
      errorMessage = e.message ?? 'Network error';
    }

    return {
      'success': false,
      'message': errorMessage,
    };
  } catch (e) {
    return {
      'success': false,
      'message': 'Error: ${e.toString()}',
    };
  }
}

/// Example usage function (you can call this from main or a test)
/// Uncomment and modify the values, then run:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await createAdminAccount();
/// }
/// ```
Future<void> createAdminAccount() async {
  print('Creating new admin account...');
  
  final result = await registerAdmin(
    tpin: '1234',
    code: 'TESTTPIN', // Change this to a unique code
    name: 'TESTTPIN', // Change this
    phoneNo: '7306548087', // Change this
    password: '123456', // Change this to a secure password
    address: 'Admin Address', // Optional
  );

  if (result['success']) {
    developer.log('✅ Admin created successfully!');
    developer.log('User: ${result['user']}');
    developer.log('You can now login with:');
    developer.log('  Code: ADMIN001'); // Use the code you provided
    developer.log('  Password: admin123'); // Use the password you provided
  } else {
    print('❌ Error: ${result['message']}');
    if (result['rawResponse'] != null) {
      developer.log('Response: ${result['rawResponse']}');
    }
  }
}

