import 'package:flutter/foundation.dart';
import '../../repositories/salesman/salesman_repository.dart';
import '../../models/salesman_model.dart';

/// Salesman Provider
/// Manages salesman screen state and operations
/// Converted from KMP's SalesManViewModel.kt
class SalesmanProvider extends ChangeNotifier {
  final SalesManRepository _salesManRepository;

  SalesmanProvider({
    required SalesManRepository salesManRepository,
  }) : _salesManRepository = salesManRepository;

  List<SalesMan> _salesmanList = [];
  List<SalesMan> get salesmanList => _salesmanList;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Load all salesmen with optional search key
  Future<void> loadSalesmen({String searchKey = ''}) async {
    _setLoading(true);
    _clearError();

    final result = await _salesManRepository.getAllSalesMan(searchKey: searchKey);

    result.fold(
      (failure) => _setError(failure.message),
      (salesmen) {
        _salesmanList = salesmen;
        notifyListeners();
      },
    );

    _setLoading(false);
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

