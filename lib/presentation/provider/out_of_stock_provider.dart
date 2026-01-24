import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import '../../repositories/out_of_stock/out_of_stock_repository.dart';
import '../../repositories/packed_subs/packed_subs_repository.dart';
import '../../repositories/users/users_repository.dart';
import '../../repositories/orders/orders_repository.dart';
import '../../models/master_data_api.dart';
import '../../models/order_api.dart';
import '../../utils/storage_helper.dart';
import '../../utils/api_endpoints.dart';
import '../../utils/push_notification_sender.dart';
import '../../models/push_data.dart';
import '../../utils/order_flags.dart';
import 'package:intl/intl.dart';

/// OutOfStock Provider
/// Manages out of stock state and operations
/// Converted from KMP's OutOfStockViewModel.kt
class OutOfStockProvider extends ChangeNotifier {
  final OutOfStockRepository _outOfStockRepository;
  final PackedSubsRepository _packedSubsRepository;
  final Dio _dio;

  // Get repositories lazily to avoid circular dependency
  UsersRepository get _usersRepository => GetIt.instance<UsersRepository>();
  OrdersRepository get _ordersRepository => GetIt.instance<OrdersRepository>();
  PushNotificationSender get _pushNotificationSender =>
      GetIt.instance<PushNotificationSender>();

  OutOfStockProvider({
    required OutOfStockRepository outOfStockRepository,
    required PackedSubsRepository packedSubsRepository,
    required Dio dio,
  })  : _outOfStockRepository = outOfStockRepository,
        _packedSubsRepository = packedSubsRepository,
        _dio = dio {
    // Initialize date to today (matching KMP pattern)
    _date = _getDBFormatDate();
  }

  String _getDBFormatDate() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }


  // ============================================================================
  // State Variables
  // ============================================================================

  List<OutOfStockMasterWithDetails> _oospList = [];
  List<OutOfStockMasterWithDetails> get oospList => _oospList;

  List<OutOfStockSubWithDetails> _oospSubList = [];
  List<OutOfStockSubWithDetails> get oospSubList => _oospSubList;

  String _searchKey = '';
  String get searchKey => _searchKey;
  set searchKey(String value) {
    _searchKey = value;
    notifyListeners();
  }

  String _date = '';
  String get date => _date;
  set date(String value) {
    _date = value;
    notifyListeners();
  }

  int _dateFilterIndex = 1; // 0=All, 1=Today, 2=Yesterday, 3=Custom
  int get dateFilterIndex => _dateFilterIndex;
  set dateFilterIndex(int value) {
    _dateFilterIndex = value;
    notifyListeners();
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ============================================================================
  // Public Methods
  // ============================================================================

  /// Get all out of stock masters (matching KMP's getAllOosp)
  Future<void> getAllOosp({String? searchKey, String? date}) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final search = searchKey ?? _searchKey;
      final dateFilter = date ?? _date;

      final result = await _outOfStockRepository.getOutOfStockMastersWithDetails(
        searchKey: search,
        date: dateFilter,
      );

      result.fold(
        (failure) {
          _errorMessage = failure.message;
          developer.log('OutOfStockProvider: Failed to get OOSP masters: ${failure.message}');
        },
        (list) {
          _oospList = list;
          developer.log('OutOfStockProvider: Loaded ${list.length} OOSP masters');
        },
      );
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      developer.log('OutOfStockProvider: Error in getAllOosp: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get all out of stock subs for supplier (matching KMP's getAllOospSub)
  Future<void> getAllOospSub({
    required int supplierId,
    String? searchKey,
    String? date,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final search = searchKey ?? _searchKey;
      final dateFilter = date ?? _date;

      final result = await _outOfStockRepository.getOutOfStockSubsWithDetailsBySupplier(
        supplierId: supplierId,
        searchKey: search,
        date: dateFilter,
      );

      result.fold(
        (failure) {
          _errorMessage = failure.message;
          developer.log('OutOfStockProvider: Failed to get OOSP subs: ${failure.message}');
        },
        (list) {
          _oospSubList = list;
          developer.log('OutOfStockProvider: Loaded ${list.length} OOSP subs');
        },
      );
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      developer.log('OutOfStockProvider: Error in getAllOospSub: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get out of stock subs by master ID (matching KMP's getOopsSub)
  Future<void> getOopsSub(int masterId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final result = await _outOfStockRepository.getOutOfStockSubsWithDetailsByMasterId(masterId);

      result.fold(
        (failure) {
          _errorMessage = failure.message;
          developer.log('OutOfStockProvider: Failed to get OOSP subs by master: ${failure.message}');
        },
        (list) {
          _oospSubList = list;
          developer.log('OutOfStockProvider: Loaded ${list.length} OOSP subs for master $masterId');
        },
      );
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      developer.log('OutOfStockProvider: Error in getOopsSub: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get out of stock master by ID (matching KMP's getOopsMaster)
  Future<OutOfStockMasterWithDetails?> getOopsMaster(int masterId) async {
    try {
      final result = await _outOfStockRepository.getOutOfStockMasterWithDetailsById(masterId);

      return result.fold(
        (failure) {
          _errorMessage = failure.message;
          developer.log('OutOfStockProvider: Failed to get OOSP master: ${failure.message}');
          return null;
        },
        (master) {
          developer.log('OutOfStockProvider: Loaded OOSP master $masterId');
          return master;
        },
      );
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      developer.log('OutOfStockProvider: Error in getOopsMaster: $e');
      return null;
    }
  }

  /// Add packed sub (matching KMP's addPackedSub)
  Future<void> addPackedSub(int orderSubId, double qty) async {
    try {
      final result = await _packedSubsRepository.addPackedSub(
        orderSubId: orderSubId,
        quantity: qty,
      );

      result.fold(
        (failure) {
          _errorMessage = failure.message;
          developer.log('OutOfStockProvider: Failed to add packed sub: ${failure.message}');
          notifyListeners();
        },
        (_) {
          developer.log('OutOfStockProvider: Added packed sub for orderSubId $orderSubId');
        },
      );
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      developer.log('OutOfStockProvider: Error in addPackedSub: $e');
      notifyListeners();
    }
  }

  /// Delete packed sub (matching KMP's deletePackedSub)
  Future<void> deletePackedSub(int orderSubId) async {
    try {
      final result = await _packedSubsRepository.deletePackedSub(orderSubId);

      result.fold(
        (failure) {
          _errorMessage = failure.message;
          developer.log('OutOfStockProvider: Failed to delete packed sub: ${failure.message}');
          notifyListeners();
        },
        (_) {
          developer.log('OutOfStockProvider: Deleted packed sub for orderSubId $orderSubId');
        },
      );
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      developer.log('OutOfStockProvider: Error in deletePackedSub: $e');
      notifyListeners();
    }
  }

  /// Get out of stock sub by sub ID with details (matching KMP's getOopsSubBySub)
  Future<OutOfStockSubWithDetails?> getOopsSubBySub(int oospId) async {
    try {
      final result =
          await _outOfStockRepository.getOutOfStockSubWithDetailsBySubId(oospId);

      return result.fold(
        (failure) {
          _errorMessage = failure.message;
          developer.log(
            'OutOfStockProvider: Failed to get OOSP sub by sub ID: ${failure.message}',
          );
          return null;
        },
        (sub) {
          developer.log('OutOfStockProvider: Loaded OOSP sub $oospId');
          return sub;
        },
      );
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      developer.log('OutOfStockProvider: Error in getOopsSubBySub: $e');
      return null;
    }
  }

  /// Update is viewed flag for master (matching KMP's updateIsMasterViewedFlag)
  Future<void> updateIsMasterViewedFlag({
    required int oospMasterId,
    required int isViewed,
  }) async {
    try {
      final result = await _outOfStockRepository.updateIsMasterViewedFlag(
        oospMasterId: oospMasterId,
        isViewed: isViewed,
      );

      result.fold(
        (failure) {
          _errorMessage = failure.message;
          developer.log(
            'OutOfStockProvider: Failed to update master viewed flag: ${failure.message}',
          );
          notifyListeners();
        },
        (_) {
          developer.log(
            'OutOfStockProvider: Updated master viewed flag for $oospMasterId',
          );
        },
      );
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      developer.log('OutOfStockProvider: Error in updateIsMasterViewedFlag: $e');
      notifyListeners();
    }
  }

  /// Update is viewed flag for sub (matching KMP's updateIsSubViewedFlag)
  Future<void> updateIsSubViewedFlag({
    required int oospId,
    required int isViewed,
  }) async {
    try {
      final result = await _outOfStockRepository.updateIsSubViewedFlagBySubId(
        oospId: oospId,
        isViewed: isViewed,
      );

      result.fold(
        (failure) {
          _errorMessage = failure.message;
          developer.log(
            'OutOfStockProvider: Failed to update sub viewed flag: ${failure.message}',
          );
          notifyListeners();
        },
        (_) {
          developer.log('OutOfStockProvider: Updated sub viewed flag for $oospId');
        },
      );
    } catch (e) {
      _errorMessage = 'An unexpected error occurred: $e';
      developer.log('OutOfStockProvider: Error in updateIsSubViewedFlag: $e');
      notifyListeners();
    }
  }

  /// Update supplier for out of stock product (matching KMP's updateSupplier)
  Future<bool> updateSupplier({
    required int oospId,
    required int supplierId,
  }) async {
    _setLoading(true);
    _clearError();

    // Check if supplier already exists in sub list
    for (final sub in _oospSubList) {
      if (sub.supplierId == supplierId) {
        _setError('Already send to this supplier');
        _setLoading(false);
        return false;
      }
    }

    try {
      // Update supplier in local DB
      final updateResult = await _outOfStockRepository.updateSupplier(
        oospId: oospId,
        supplierId: supplierId,
      );

      if (updateResult.isLeft) {
        _setError(updateResult.left.message);
        _setLoading(false);
        return false;
      }

      // If supplier was -1, update flag to 4, otherwise update flag
      final sub = _oospSubList.firstWhere(
        (s) => s.oospId == oospId,
        orElse: () => throw Exception('Sub not found'),
      );

      if (sub.supplierId == -1) {
        // Just update supplier
      } else {
        // Update flag to 4 (replaced)
        await _outOfStockRepository.updateOospFlag(
          oospId: oospId,
          oospFlag: 4,
        );
      }

      // Reload subs
      if (sub.oospMasterId != -1) {
        await getOopsSub(sub.oospMasterId);
      }

      _setLoading(false);
      return true;
    } catch (e) {
      _setError('Error updating supplier: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Update out of stock product flag (matching KMP's updateOospFlag)
  Future<void> updateOospFlag({
    required int oospId,
    required int oospFlag,
    required int masterId,
    required Function() onSuccess,
  }) async {
    try {
      final result = await _outOfStockRepository.updateOospFlag(
        oospId: oospId,
        oospFlag: oospFlag,
      );

      result.fold(
        (failure) {
          _setError(failure.message);
          notifyListeners();
        },
        (_) {
          getOopsSub(masterId);
          onSuccess();
        },
      );
    } catch (e) {
      _setError('Error updating flag: $e');
      notifyListeners();
    }
  }

  /// Mark as not available (matching KMP's notAvailable)
  /// Calls API first to update server, then updates local DB
  /// Server is the source of truth - fixes KMP's design flaw
  Future<void> notAvailable({
    required int oospId,
    required int masterId,
    required OutOfStockSubWithDetails subItem,
    required Function(String) onFailure,
    required Function() onSuccess,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Call API first to update server (flag 5 = not available)
      final payload = _buildUpdateOutOfStockSubParams(
        subItem: subItem,
        flag: OutOfStockFlag.notAvailable,
        isChecked: 1,
        note: subItem.note,
        availQty: 0.0,
      );

      final response = await _dio.post(
        ApiEndpoints.updateOutOfStockSub,
        data: payload,
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] != 1) {
        final errorMsg = responseData['message']?.toString() ??
            responseData['data']?.toString() ??
            'Failed to mark as not available';
        _setError(errorMsg);
        _setLoading(false);
        onFailure(errorMsg);
        return;
      }

      // Update local DB after successful API call (server is source of truth)
      await _outOfStockRepository.rejectAvailableQty(
        oospId: oospId,
        availQty: 0.0,
        note: subItem.note,
        oospFlag: OutOfStockFlag.notAvailable, // Not available flag
      );

      await getOopsSub(masterId);

      // Send push notifications to admins, storekeepers, and salesman
      final currentUserId = await StorageHelper.getUserId();
      final adminsResult = await _usersRepository.getUsersByCategory(1);
      final storekeepersResult = await _usersRepository.getUsersByCategory(2);
      final List<Map<String, dynamic>> userIds = [];

      // Add admins (silent push, excluding current user)
      adminsResult.fold(
        (_) {},
        (admins) {
          for (final admin in admins) {
            if (admin.userId != currentUserId) {
              userIds.add({'user_id': admin.userId ?? -1, 'silent_push': 1});
            }
          }
        },
      );

      // Add storekeepers (silent push, excluding current user)
      storekeepersResult.fold(
        (_) {},
        (storekeepers) {
          for (final storekeeper in storekeepers) {
            if (storekeeper.userId != currentUserId) {
              userIds.add({'user_id': storekeeper.userId ?? -1, 'silent_push': 1});
            }
          }
        },
      );

      // Add salesman (visible notification)
      if (subItem.salesmanId != -1) {
        userIds.add({'user_id': subItem.salesmanId, 'silent_push': 0});
      } else if (subItem.storekeeperId != -1) {
        // If no salesman, notify storekeeper (visible notification)
        userIds.add({'user_id': subItem.storekeeperId, 'silent_push': 0});
      }

      // Fire-and-forget: don't await, just trigger in background
      _pushNotificationSender.sendPushNotification(
        dataIds: [
          PushData(table: 11, id: subItem.oospMasterId),
          PushData(table: 12, id: subItem.oospId),
        ],
        customUserIds: userIds,
        message: 'Order cancelled',
      ).catchError((e) {
        developer.log('OutOfStockProvider: Error sending push notification in notAvailable: $e');
      });

      _setLoading(false);
      onSuccess();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    } catch (e) {
      final errorMsg = 'Error marking as not available: $e';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    }
  }

  /// Send order to supplier (matching KMP's sendOrderToSupplier)
  Future<void> sendOrderToSupplier({
    required OutOfStockSubWithDetails subItem,
    required Function(String) onFailure,
    required Function() onSuccess,
  }) async {
    _setLoading(true);
    _clearError();
    //if no supplier is selected return earlier
    if (subItem.supplierId == -1) {
      _setError('No supplier selected');
      _setLoading(false);
      onFailure('No supplier selected');
      return;
    }
    try {
      final payload = _buildUpdateOutOfStockSubParams(
        subItem: subItem,
        flag: 1,
        isChecked: 0,
      );

      final response = await _dio.post(
        ApiEndpoints.updateOutOfStockSub,
        data: payload,
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] != 1) {
        final errorMsg = responseData['message']?.toString() ??
            responseData['data']?.toString() ??
            'Failed to send order to supplier';
        _setError(errorMsg);
        _setLoading(false);
        onFailure(errorMsg);
        return;
      }

      await updateOospFlag(
        oospId: subItem.oospId,
        oospFlag: 1,
        masterId: subItem.oospMasterId,
        onSuccess: () {
          _pushNotificationSender.sendPushNotification(
            dataIds: [PushData(table: 12, id: subItem.oospId)],
            customUserIds: [
              {'user_id': subItem.supplierId, 'silent_push': 0}
            ],
            message: 'Out of stock order received',
          );
          _setLoading(false);
          onSuccess();
        },
      );
    } on DioException catch (e) {
      final errorMsg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    } catch (e) {
      final errorMsg = 'Error sending order to supplier: $e';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    }
  }

  /// Accept available quantity (matching KMP's acceptAvailableQty)
  Future<void> acceptAvailableQty({
    required OutOfStockSubWithDetails subItem,
    required String note,
    required Function(String) onFailure,
    required Function() onSuccess,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final payload = _buildUpdateOutOfStockSubParams(
        subItem: subItem,
        flag: 2,
        isChecked: 1,
        note: note,
        availQty: 0.0,
        qty: subItem.availQty,
      );

      final response = await _dio.post(
        ApiEndpoints.updateOutOfStockSub,
        data: payload,
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] != 1) {
        final errorMsg = responseData['message']?.toString() ??
            responseData['data']?.toString() ??
            'Failed to accept available quantity';
        _setError(errorMsg);
        _setLoading(false);
        onFailure(errorMsg);
        return;
      }

      await _createNewSub(
        subItem: subItem,
        qty: subItem.qty - subItem.availQty,
        availQty: subItem.qty - subItem.availQty,
        onFailure: onFailure,
        onSuccess: () async {
          await _outOfStockRepository.updateOospFlag(
            oospId: subItem.oospId,
            oospFlag: 2,
          );
          await getOopsSub(subItem.oospMasterId);

          final currentUserId = await StorageHelper.getUserId();
          final adminsResult = await _usersRepository.getUsersByCategory(1);
          final List<Map<String, dynamic>> userIds = [];

          adminsResult.fold(
            (_) {},
            (admins) {
              for (final admin in admins) {
                if (admin.userId != currentUserId) {
                  userIds.add({'user_id': admin.userId ?? -1, 'silent_push': 1});
                }
              }
            },
          );

          userIds.add({'user_id': subItem.supplierId, 'silent_push': 0});

          // Fire-and-forget: don't await, just trigger in background
          _pushNotificationSender.sendPushNotification(
            dataIds: [PushData(table: 12, id: subItem.oospId)],
            customUserIds: userIds,
            message: 'Order confirmed',
          ).catchError((e) {
            developer.log('OutOfStockProvider: Error sending push notification: $e');
          });

          _setLoading(false);
          onSuccess();
        },
      );
    } on DioException catch (e) {
      final errorMsg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    } catch (e) {
      final errorMsg = 'Error accepting available quantity: $e';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    }
  }

  /// Reject available quantity (matching KMP's rejectAvailableQty)
  Future<void> rejectAvailableQty({
    required OutOfStockSubWithDetails subItem,
    required String note,
    int supplierId = -1,
    required Function(String) onFailure,
    required Function() onSuccess,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final payload = _buildUpdateOutOfStockSubParams(
        subItem: subItem,
        flag: 5,
        isChecked: 1,
        note: note,
      );

      final response = await _dio.post(
        ApiEndpoints.updateOutOfStockSub,
        data: payload,
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] != 1) {
        final errorMsg = responseData['message']?.toString() ??
            responseData['data']?.toString() ??
            'Failed to reject available quantity';
        _setError(errorMsg);
        _setLoading(false);
        onFailure(errorMsg);
        return;
      }

      await _createNewSub(
        subItem: subItem,
        qty: subItem.qty,
        availQty: 0.0,
        supplierId: supplierId == -1 ? subItem.supplierId : supplierId,
        onFailure: onFailure,
        onSuccess: () async {
          await _outOfStockRepository.updateOospFlag(
            oospId: subItem.oospId,
            oospFlag: 5,
          );
          await getOopsSub(subItem.oospMasterId);

          final currentUserId = await StorageHelper.getUserId();
          final adminsResult = await _usersRepository.getUsersByCategory(1);
          final List<Map<String, dynamic>> userIds = [
            {'user_id': subItem.supplierId, 'silent_push': 0}
          ];

          adminsResult.fold(
            (_) {},
            (admins) {
              for (final admin in admins) {
                if (admin.userId != currentUserId) {
                  userIds.add({'user_id': admin.userId ?? -1, 'silent_push': 1});
                }
              }
            },
          );

          // Fire-and-forget: don't await, just trigger in background
          _pushNotificationSender.sendPushNotification(
            dataIds: [PushData(table: 12, id: subItem.oospId)],
            customUserIds: userIds,
            message: 'Order cancelled',
          ).catchError((e) {
            developer.log('OutOfStockProvider: Error sending push notification: $e');
          });

          _setLoading(false);
          onSuccess();
        },
      );
    } on DioException catch (e) {
      final errorMsg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    } catch (e) {
      final errorMsg = 'Error rejecting available quantity: $e';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    }
  }

  /// Mark available quantity (matching KMP's markAvailableQty)
  Future<void> markAvailableQty({
    required OutOfStockSubWithDetails subItem,
    required String note,
    required Function(String) onFailure,
    required Function() onSuccess,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final payload = _buildUpdateOutOfStockSubParams(
        subItem: subItem,
        flag: 2,
        isChecked: 1,
        note: note,
      );

      final response = await _dio.post(
        ApiEndpoints.updateOutOfStockSub,
        data: payload,
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] != 1) {
        final errorMsg = responseData['message']?.toString() ??
            responseData['data']?.toString() ??
            'Failed to mark available quantity';
        _setError(errorMsg);
        _setLoading(false);
        onFailure(errorMsg);
        return;
      }

      await _outOfStockRepository.updateOospFlag(
        oospId: subItem.oospId,
        oospFlag: 2,
      );
      await getOopsSub(subItem.oospMasterId);

      final currentUserId = await StorageHelper.getUserId();
      final adminsResult = await _usersRepository.getUsersByCategory(1);
      final List<Map<String, dynamic>> userIds = [];

      adminsResult.fold(
        (_) {},
        (admins) {
          for (final admin in admins) {
            if (admin.userId != currentUserId) {
              userIds.add({'user_id': admin.userId ?? -1, 'silent_push': 1});
            }
          }
        },
      );

      userIds.add({'user_id': subItem.supplierId, 'silent_push': 0});

      // Fire-and-forget: don't await, just trigger in background
      _pushNotificationSender.sendPushNotification(
        dataIds: [PushData(table: 12, id: subItem.oospId)],
        customUserIds: userIds,
        message: 'Order confirmed',
      ).catchError((e) {
        developer.log('OutOfStockProvider: Error sending push notification: $e');
      });

      _setLoading(false);
      onSuccess();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    } catch (e) {
      final errorMsg = 'Error marking available quantity: $e';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    }
  }

  /// Mark decide available quantity (matching KMP's markDecideAvailableQty)
  Future<void> markDecideAvailableQty({
    required OutOfStockSubWithDetails subItem,
    required String note,
    required Function(String) onFailure,
    required Function() onSuccess,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final payload = _buildUpdateOutOfStockSubParams(
        subItem: subItem,
        flag: 2,
        isChecked: 1,
        note: note,
        qty: subItem.availQty,
        availQty: 0.0,
      );

      final response = await _dio.post(
        ApiEndpoints.updateOutOfStockSub,
        data: payload,
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] != 1) {
        final errorMsg = responseData['message']?.toString() ??
            responseData['data']?.toString() ??
            'Failed to mark decide available quantity';
        _setError(errorMsg);
        _setLoading(false);
        onFailure(errorMsg);
        return;
      }

      await _createNewSub(
        subItem: subItem,
        qty: subItem.qty - subItem.availQty,
        availQty: subItem.qty - subItem.availQty,
        onFailure: onFailure,
        onSuccess: () async {
          await _outOfStockRepository.updateOospFlag(
            oospId: subItem.oospId,
            oospFlag: 2,
          );
          await getOopsSub(subItem.oospMasterId);

          final currentUserId = await StorageHelper.getUserId();
          final adminsResult = await _usersRepository.getUsersByCategory(1);
          final List<Map<String, dynamic>> userIds = [];

          adminsResult.fold(
            (_) {},
            (admins) {
              for (final admin in admins) {
                if (admin.userId != currentUserId) {
                  userIds.add({'user_id': admin.userId ?? -1, 'silent_push': 1});
                }
              }
            },
          );

          userIds.add({'user_id': subItem.supplierId, 'silent_push': 0});

          // Fire-and-forget: don't await, just trigger in background
          _pushNotificationSender.sendPushNotification(
            dataIds: [PushData(table: 12, id: subItem.oospId)],
            customUserIds: userIds,
            message: 'Order confirmed',
          ).catchError((e) {
            developer.log('OutOfStockProvider: Error sending push notification: $e');
          });

          _setLoading(false);
          onSuccess();
        },
      );
    } on DioException catch (e) {
      final errorMsg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    } catch (e) {
      final errorMsg = 'Error marking decide available quantity: $e';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    }
  }

  /// Inform admin from supplier (matching KMP's informAdminFromSupplier)
  Future<void> informAdminFromSupplier({
    required OutOfStockSubWithDetails subItem,
    required double availQty,
    required String note,
    required int oospFlag,
    required Function(String) onFailure,
    required Function() onSuccess,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final payload = _buildUpdateOutOfStockSubParams(
        subItem: subItem,
        flag: oospFlag,
        isChecked: 1,
        note: note,
        availQty: availQty,
      );

      final response = await _dio.post(
        ApiEndpoints.updateOutOfStockSub,
        data: payload,
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] != 1) {
        final errorMsg = responseData['message']?.toString() ??
            responseData['data']?.toString() ??
            'Failed to inform admin';
        _setError(errorMsg);
        _setLoading(false);
        onFailure(errorMsg);
        return;
      }

      await _outOfStockRepository.updateOospFlag(
        oospId: subItem.oospId,
        oospFlag: oospFlag,
      );
      await _outOfStockRepository.updateIsCheckedFlag(
        oospId: subItem.oospId,
        isCheckedFlag: 1,
      );

      await getOopsSubBySub(subItem.oospId);

      final adminsResult = await _usersRepository.getUsersByCategory(1);
      final List<Map<String, dynamic>> userIds = [];

      adminsResult.fold(
        (_) {},
        (admins) {
          for (final admin in admins) {
            userIds.add({'user_id': admin.userId ?? -1, 'silent_push': 0});
          }
        },
      );

      // Fire-and-forget: don't await, just trigger in background
      _pushNotificationSender.sendPushNotification(
        dataIds: [PushData(table: 12, id: subItem.oospId)],
        customUserIds: userIds,
        message: 'Supplier response',
      ).catchError((e) {
        developer.log('OutOfStockProvider: Error sending push notification: $e');
      });

      _setLoading(false);
      onSuccess();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    } catch (e) {
      final errorMsg = 'Error informing admin: $e';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    }
  }

  /// Not available quantity (matching KMP's notAvailableQty)
  Future<void> notAvailableQty({
    required OutOfStockSubWithDetails subItem,
    required String note,
    required Function(String) onFailure,
    required Function() onSuccess,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final payload = _buildUpdateOutOfStockSubParams(
        subItem: subItem,
        flag: 4,
        isChecked: 1,
        note: note,
        availQty: 0.0,
      );

      final response = await _dio.post(
        ApiEndpoints.updateOutOfStockSub,
        data: payload,
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] != 1) {
        final errorMsg = responseData['message']?.toString() ??
            responseData['data']?.toString() ??
            'Failed to mark as not available';
        _setError(errorMsg);
        _setLoading(false);
        onFailure(errorMsg);
        return;
      }

      await updateCompleteFlag(
        oospMasterId: subItem.oospMasterId,
        onFailure: onFailure,
        onSuccess: () async {
          // Update local DB: availQty, note, oospFlag, and isCheckedflag together
          // Matching KMP's rejectAvailableQty SQL query
          final updateResult = await _outOfStockRepository.rejectAvailableQty(
            oospId: subItem.oospId,
            availQty: 0.0,
            note: note,
            oospFlag: 4,
          );

          if (updateResult.isLeft) {
            _setError(updateResult.left.message);
            _setLoading(false);
            onFailure(updateResult.left.message);
            return;
          }

          await getOopsSub(subItem.oospMasterId);

          final currentUserId = await StorageHelper.getUserId();
          final adminsResult = await _usersRepository.getUsersByCategory(1);
          final List<Map<String, dynamic>> userIds = [];

          adminsResult.fold(
            (_) {},
            (admins) {
              for (final admin in admins) {
                if (admin.userId != currentUserId) {
                  userIds.add({'user_id': admin.userId ?? -1, 'silent_push': 1});
                }
              }
            },
          );

          if (subItem.salesmanId != -1) {
            userIds.add({'user_id': subItem.salesmanId, 'silent_push': 0});
          } else {
            userIds.add({'user_id': subItem.storekeeperId, 'silent_push': 0});
          }

          // Fire-and-forget: don't await, just trigger in background
          _pushNotificationSender.sendPushNotification(
            dataIds: [
              PushData(table: 11, id: subItem.oospMasterId),
              PushData(table: 12, id: subItem.oospId),
            ],
            customUserIds: userIds,
            message: 'Order cancelled',
          );

          _setLoading(false);
          onSuccess();
        },
      );
    } on DioException catch (e) {
      final errorMsg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    } catch (e) {
      final errorMsg = 'Error marking as not available: $e';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    }
  }

  /// Inform salesman (matching KMP's informSalesman)
  Future<void> informSalesman({
    required OutOfStockMasterWithDetails master,
    required double availableQty,
    required Function(String) onFailure,
    required Function() onSuccess,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Get order sub by sub ID - need to find order sub with matching orderSubId
      final orderResult = await _ordersRepository.getOrderWithNamesById(master.oospMasterId);
      if (orderResult.isLeft || orderResult.right == null) {
        _setError('Order not found');
        _setLoading(false);
        onFailure('Order not found');
        return;
      }

      final orderWithName = orderResult.right!;
      final orderSubsResult = await _ordersRepository.getAllOrderSubAndDetails(
        orderWithName.order.orderId,
      );

      if (orderSubsResult.isLeft) {
        _setError('Order sub not found');
        _setLoading(false);
        onFailure('Order sub not found');
        return;
      }

      final orderSubs = orderSubsResult.right;
      final orderSub = orderSubs.firstWhere(
        (sub) => sub.orderSub.id == master.orderSubId,
        orElse: () {
          if (orderSubs.isNotEmpty) return orderSubs.first;
          throw Exception('Order sub not found');
        },
      );

      final order = orderWithName.order;

      // Build user IDs for push notification
      final currentUserId = await StorageHelper.getUserId();
      final List<Map<String, dynamic>> userIds = [];

      if (master.salesmanId != -1) {
        userIds.add({'user_id': master.salesmanId, 'silent_push': 0});
      } else {
        userIds.add({'user_id': master.storekeeperId, 'silent_push': 0});
      }

      final adminsResult = await _usersRepository.getUsersByCategory(1);
      adminsResult.fold(
        (_) {},
        (admins) {
          for (final admin in admins) {
            if (admin.userId != currentUserId) {
              userIds.add({'user_id': admin.userId ?? -1, 'silent_push': 1});
            }
          }
        },
      );

      if (order.orderApproveFlag != OrderApprovalFlag.completed) {
        if (order.orderApproveFlag != OrderApprovalFlag.checkerIsChecking &&
            order.orderApproveFlag != OrderApprovalFlag.sendToChecker &&
            order.orderCheckerId != -1) {
          final checkersResult = await _usersRepository.getUsersByCategory(6);
          checkersResult.fold(
            (_) {},
            (checkers) {
              for (final checker in checkers) {
                userIds.add({'user_id': checker.userId ?? -1, 'silent_push': 1});
              }
            },
          );
        }

        if (order.orderBillerId != -1 &&
            order.orderApproveFlag >= OrderApprovalFlag.verifiedByStorekeeper) {
          final billersResult = await _usersRepository.getUsersByCategory(5);
          billersResult.fold(
            (_) {},
            (billers) {
              for (final biller in billers) {
                userIds.add({'user_id': biller.userId ?? -1, 'silent_push': 1});
              }
            },
          );
        }
      }

      // Calculate needed qty and last qty
      final neededQty = order.orderApproveFlag == OrderApprovalFlag.completed
          ? orderSub.orderSub.orderSubAvailableQty
          : orderSub.orderSub.orderSubQty - orderSub.orderSub.orderSubAvailableQty;
      final lastQty = order.orderApproveFlag == OrderApprovalFlag.completed
          ? orderSub.orderSub.orderSubAvailableQty
          : neededQty - availableQty;

      // Determine update order flag
      final updateOrderFlag = (availableQty == neededQty &&
              order.orderApproveFlag != OrderApprovalFlag.completed)
          ? OrderSubFlag.inStock
          : OrderSubFlag.notAvailable;

      // Build order sub update payload
      final orderSubPayload = {
        'id': orderSub.orderSub.orderSubId,
        'order_sub_prd_id': orderSub.orderSub.orderSubPrdId,
        'order_sub_unit_id': orderSub.orderSub.orderSubUnitId,
        'order_sub_car_id': orderSub.orderSub.orderSubCarId,
        'order_sub_rate': orderSub.orderSub.orderSubRate,
        'order_sub_date_time': orderSub.orderSub.orderSubDateTime,
        'order_sub_update_rate': orderSub.orderSub.orderSubUpdateRate,
        'order_sub_qty': orderSub.orderSub.orderSubQty,
        'order_sub_available_qty': lastQty,
        'order_sub_unit_base_qty': orderSub.orderSub.orderSubUnitBaseQty,
        'order_sub_ordr_flag': updateOrderFlag,
        'order_sub_is_checked_flag': orderSub.orderSub.orderSubIsCheckedFlag,
        'order_sub_note': orderSub.orderSub.orderSubNote ?? '',
        'order_sub_cust_id': orderSub.orderSub.orderSubCustId,
        'order_sub_salesman_id': orderSub.orderSub.orderSubSalesmanId,
        'order_sub_stock_keeper_id': orderSub.orderSub.orderSubStockKeeperId,
      };

      // Call API to update order sub
      final orderSubResponse = await _dio.post(
        ApiEndpoints.updateOrderSub,
        data: orderSubPayload,
      );

      final orderSubResponseData = orderSubResponse.data as Map<String, dynamic>;
      if (orderSubResponseData['status'] != 1) {
        final errorMsg = orderSubResponseData['message']?.toString() ??
            orderSubResponseData['data']?.toString() ??
            'Failed to update order sub';
        _setError(errorMsg);
        _setLoading(false);
        onFailure(errorMsg);
        return;
      }

      await updateCompleteFlag(
        oospMasterId: master.oospMasterId,
        onFailure: onFailure,
        onSuccess: () async {
          final orderSubApi = OrderSubApi.fromJson(orderSubResponseData);
          await _ordersRepository.addOrderSub(orderSubApi.data);
          await _outOfStockRepository.updateCompleteFlag(master.oospMasterId);

          // Fire-and-forget: don't await, just trigger in background
          _pushNotificationSender.sendPushNotification(
            dataIds: [PushData(table: 9, id: orderSubApi.data.orderSubId)],
            customUserIds: userIds,
            message: 'Update from admin',
          ).catchError((e) {
            developer.log('OutOfStockProvider: Error sending push notification: $e');
          });

          _setLoading(false);
          onSuccess();
        },
      );
    } on DioException catch (e) {
      final errorMsg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    } catch (e) {
      final errorMsg = 'Error informing salesman: $e';
      _setError(errorMsg);
      _setLoading(false);
      onFailure(errorMsg);
    }
  }

  /// Update complete flag (matching KMP's updateCompleteFlag)
  Future<void> updateCompleteFlag({
    required int oospMasterId,
    required Function(String) onFailure,
    required Function() onSuccess,
  }) async {
    try {
      final payload = {
        'id': oospMasterId,
        'is_completed_flag': 1,
      };

      final response = await _dio.post(
        ApiEndpoints.updateOutOfStockMasterFlag,
        data: payload,
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] != 1) {
        final errorMsg = responseData['message']?.toString() ??
            responseData['data']?.toString() ??
            'Failed to update complete flag';
        onFailure(errorMsg);
        return;
      }

      await _outOfStockRepository.updateCompleteFlag(oospMasterId);
      onSuccess();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      onFailure(errorMsg);
    } catch (e) {
      onFailure('Error updating complete flag: $e');
    }
  }

  /// Update complete flag and inform (matching KMP's updateCompleteFlagAndInform)
  Future<void> updateCompleteFlagAndInform({
    required OutOfStockMasterWithDetails master,
    required Function(String) onFailure,
    required Function() onSuccess,
  }) async {
    try {
      final payload = {
        'id': master.oospMasterId,
        'is_completed_flag': 1,
      };

      final response = await _dio.post(
        ApiEndpoints.updateOutOfStockMasterFlag,
        data: payload,
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] != 1) {
        final errorMsg = responseData['message']?.toString() ??
            responseData['data']?.toString() ??
            'Failed to update complete flag';
        onFailure(errorMsg);
        return;
      }

      await _outOfStockRepository.updateCompleteFlag(master.oospMasterId);

      final currentUserId = await StorageHelper.getUserId();
      final adminsResult = await _usersRepository.getUsersByCategory(1);
      final List<Map<String, dynamic>> userIds = [];

      adminsResult.fold(
        (_) {},
        (admins) {
          for (final admin in admins) {
            if (admin.userId != currentUserId) {
              userIds.add({'user_id': admin.userId ?? -1, 'silent_push': 1});
            }
          }
        },
      );

      if (master.salesmanId != -1) {
        userIds.add({'user_id': master.salesmanId, 'silent_push': 0});
      } else {
        userIds.add({'user_id': master.storekeeperId, 'silent_push': 0});
      }

      // Fire-and-forget: don't await, just trigger in background
      _pushNotificationSender.sendPushNotification(
        dataIds: [PushData(table: 11, id: master.oospMasterId)],
        customUserIds: userIds,
        message: 'Order cancelled',
      ).catchError((e) {
        developer.log('OutOfStockProvider: Error sending push notification: $e');
      });

      onSuccess();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      onFailure(errorMsg);
    } catch (e) {
      onFailure('Error updating complete flag: $e');
    }
  }

  /// Clear provider state (matching KMP's clear)
  void clear() {
    _oospList = [];
    _oospSubList = [];
    _searchKey = '';
    _date = '';
    _dateFilterIndex = 1;
    _errorMessage = null;
    notifyListeners();
  }

  // ============================================================================
  // Private Helper Methods
  // ============================================================================

  /// Build update out of stock sub params (matching KMP's updateOutOfStockSubParams)
  Map<String, dynamic> _buildUpdateOutOfStockSubParams({
    required OutOfStockSubWithDetails subItem,
    required int flag,
    required int isChecked,
    String? note,
    double? availQty,
    double? qty,
  }) {
    return {
      'id': subItem.oospId,
      'outos_sub_outos_id': subItem.oospMasterId,
      'outos_sub_order_sub_id': subItem.orderSubId,
      'outos_sub_cust_id': subItem.custId,
      'outos_sub_sales_man_id': subItem.salesmanId,
      'outos_sub_stock_keeper_id': subItem.storekeeperId,
      'outos_sub_date_and_time': subItem.dateAndTime,
      'outos_sub_supp_id': subItem.supplierId,
      'outos_sub_prod_id': subItem.productId,
      'outos_sub_unit_id': subItem.unitId,
      'outos_sub_car_id': subItem.carId,
      'outos_sub_rate': subItem.rate,
      'outos_sub_updated_rate': subItem.updateRate,
      'outos_sub_qty': qty ?? subItem.qty,
      'outos_sub_available_qty': availQty ?? subItem.availQty,
      'outos_sub_unit_base_qty': subItem.baseQty,
      'outos_sub_status_flag': flag,
      'outos_sub_is_checked_flag': isChecked,
      'outos_sub_note': note ?? subItem.note,
      'outos_sub_narration': subItem.narration,
    };
  }

  /// Create new out of stock sub (matching KMP's createNewSub)
  Future<void> _createNewSub({
    required OutOfStockSubWithDetails subItem,
    required double qty,
    required double availQty,
    int supplierId = -1,
    required Function(String) onFailure,
    required Function() onSuccess,
  }) async {
    try {
      final now = DateTime.now();
      final dateTimeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      final payload = {
        'id': -1,
        'outos_sub_outos_id': subItem.oospMasterId,
        'outos_sub_order_sub_id': subItem.orderSubId,
        'outos_sub_cust_id': subItem.custId,
        'outos_sub_sales_man_id': subItem.salesmanId,
        'outos_sub_stock_keeper_id': subItem.storekeeperId,
        'outos_sub_date_and_time': dateTimeStr,
        'outos_sub_supp_id': supplierId == -1 ? subItem.supplierId : supplierId,
        'outos_sub_prod_id': subItem.productId,
        'outos_sub_unit_id': subItem.unitId,
        'outos_sub_car_id': subItem.carId,
        'outos_sub_rate': subItem.rate,
        'outos_sub_updated_rate': subItem.updateRate,
        'outos_sub_qty': qty,
        'outos_sub_available_qty': availQty,
        'outos_sub_unit_base_qty': subItem.baseQty,
        'outos_sub_status_flag': 0,
        'outos_sub_is_checked_flag': 0,
        'outos_sub_note': '',
        'outos_sub_narration': subItem.narration,
      };

      final response = await _dio.post(
        ApiEndpoints.updateOutOfStockSub,
        data: payload,
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['status'] != 1) {
        final errorMsg = responseData['message']?.toString() ??
            responseData['data']?.toString() ??
            'Failed to create new sub';
        onFailure(errorMsg);
        return;
      }

      final outOfStockSubApi = OutOfStockSubApi.fromJson(responseData);
      await _outOfStockRepository.addOutOfStockProduct(outOfStockSubApi.data);

      onSuccess();
    } on DioException catch (e) {
      final errorMsg = e.response?.data?.toString() ?? e.message ?? 'Network error';
      onFailure(errorMsg);
    } catch (e) {
      onFailure('Error creating new sub: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }
}

