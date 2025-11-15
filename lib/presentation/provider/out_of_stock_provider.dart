import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import '../../repositories/out_of_stock/out_of_stock_repository.dart';
import '../../repositories/packed_subs/packed_subs_repository.dart';
import '../../models/master_data_api.dart';
import '../../utils/storage_helper.dart';
import 'package:intl/intl.dart';

/// OutOfStock Provider
/// Manages out of stock state and operations
/// Converted from KMP's OutOfStockViewModel.kt
class OutOfStockProvider extends ChangeNotifier {
  final OutOfStockRepository _outOfStockRepository;
  final PackedSubsRepository _packedSubsRepository;

  OutOfStockProvider({
    required OutOfStockRepository outOfStockRepository,
    required PackedSubsRepository packedSubsRepository,
  })  : _outOfStockRepository = outOfStockRepository,
        _packedSubsRepository = packedSubsRepository {
    // Initialize date to today (matching KMP pattern)
    _date = _getDBFormatDate();
  }

  String _getDBFormatDate() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  String _getYesterdayDBFormatDate() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 1)));
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
}

