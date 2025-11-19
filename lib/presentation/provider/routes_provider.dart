import 'package:flutter/foundation.dart';
import 'package:either_dart/either.dart';
import 'dart:developer' as developer;
import '../../repositories/routes/routes_repository.dart';
import '../../repositories/salesman/salesman_repository.dart';
import '../../models/master_data_api.dart';
import '../../models/salesman_model.dart';
import '../../helpers/errors/failures.dart';
import '../../models/push_data.dart';
import '../../utils/push_notification_sender.dart';
import '../../utils/notification_id.dart';

/// Routes Provider
/// Manages routes screen state and operations
/// Converted from KMP's UsersViewModel routes methods
class RoutesProvider extends ChangeNotifier {
  final RoutesRepository _routesRepository;
  final SalesManRepository _salesManRepository;
  final PushNotificationSender _pushNotificationSender;

  RoutesProvider({
    required RoutesRepository routesRepository,
    required SalesManRepository salesManRepository,
    required PushNotificationSender pushNotificationSender,
  })  : _routesRepository = routesRepository,
        _salesManRepository = salesManRepository,
        _pushNotificationSender = pushNotificationSender;

  List<RouteWithSalesman> _routesList = [];
  List<RouteWithSalesman> get routesList => _routesList;

  List<SalesMan> _salesmanList = [];
  List<SalesMan> get salesmanList => _salesmanList;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  /// Load all routes with salesman (join query)
  Future<void> loadRoutes({String searchKey = ''}) async {
    _setLoading(true);
    _clearError();

    final result = await _routesRepository.getAllRoutesWithSalesman(
      searchKey: searchKey,
    );

    result.fold(
      (failure) => _setError(failure.message),
      (routes) {
        _routesList = routes;
        notifyListeners();
      },
    );

    _setLoading(false);
  }

  /// Load all salesmen (for checker selection)
  Future<void> loadSalesmen() async {
    final result = await _salesManRepository.getAllSalesMan();

    result.fold(
      (failure) {
        // ignore: avoid_print
        print('RoutesProvider: loadSalesmen failed - ${failure.message}');
        _setError(failure.message);
      },
      (salesmen) {
        // ignore: avoid_print
        print('RoutesProvider: loadSalesmen success - ${salesmen.length} salesmen loaded');
        _salesmanList = salesmen;
        notifyListeners();
      },
    );
  }

  /// Create new route
  Future<Either<Failure, Route>> createRoute({
    required String name,
    required int salesmanId,
  }) async {
    _setLoading(true);
    _clearError();

    // Check if route name already exists
    final existingResult = await _routesRepository.getRouteByName(name);
    final existing = existingResult.fold(
      (_) => <Route>[],
      (routes) => routes,
    );

    if (existing.isNotEmpty) {
      _setLoading(false);
      _setError('Route name already exist');
      return Left(ValidationFailure(message: 'Route name already exist'));
    }

    final result = await _routesRepository.createRoute(
      name: name,
      code: '', // KMP sends empty code
      salesmanId: salesmanId,
    );

    result.fold(
      (failure) {
        _setError(failure.message);
        _setLoading(false);
        return Left(failure);
      },
      (route) {
        // Send push notification (matches KMP lines 138-140)
        final dataIds = [
          PushData(table: NotificationId.routes, id: route.id),
        ];
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'Route updates',
        ).catchError((e) {
          developer.log('RoutesProvider: Error sending push notification: $e');
        });

        _setLoading(false);
        // Reload routes list
        loadRoutes();
        return Right(route);
      },
    );

    return result;
  }

  /// Update route
  Future<Either<Failure, Route>> updateRoute({
    required int routeId,
    required String name,
  }) async {
    _setLoading(true);
    _clearError();

    // Check if route name already exists (excluding current route)
    final existingResult = await _routesRepository.getRouteByNameAndId(
      name: name,
      routeId: routeId,
    );
    final existing = existingResult.fold(
      (_) => <Route>[],
      (routes) => routes,
    );

    if (existing.isNotEmpty) {
      _setLoading(false);
      _setError('Route name already exist');
      return Left(ValidationFailure(message: 'Route name already exist'));
    }

    final result = await _routesRepository.updateRoute(
      routeId: routeId,
      name: name,
    );

    result.fold(
      (failure) {
        _setError(failure.message);
        _setLoading(false);
        return Left(failure);
      },
      (route) {
        // Send push notification (matches KMP lines 165-167)
        final dataIds = [
          PushData(table: NotificationId.routes, id: route.id),
        ];
        _pushNotificationSender.sendPushNotification(
          dataIds: dataIds,
          message: 'Route updates',
        ).catchError((e) {
          developer.log('RoutesProvider: Error sending push notification: $e');
        });

        _setLoading(false);
        // Reload routes list
        loadRoutes();
        return Right(route);
      },
    );

    return result;
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

