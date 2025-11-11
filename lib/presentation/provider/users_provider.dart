import 'package:flutter/foundation.dart';
import '../../repositories/users/users_repository.dart';
import '../../models/master_data_api.dart';

class UsersProvider extends ChangeNotifier {
  final UsersRepository _usersRepository;

  UsersProvider({required UsersRepository usersRepository})
      : _usersRepository = usersRepository;

  List<User> _users = [];
  List<User> get users => _users;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> loadUsers({String searchKey = ''}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final result = await _usersRepository.getAllUsers(searchKey: searchKey);
    result.fold(
      (failure) => _errorMessage = failure.message,
      (list) => _users = list,
    );

    _isLoading = false;
    notifyListeners();
  }
}
