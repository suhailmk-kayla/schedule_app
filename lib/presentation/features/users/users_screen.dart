import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/utils/asset_images.dart';
import 'package:schedule_frontend_flutter/utils/storage_helper.dart';
import 'package:schedule_frontend_flutter/utils/notification_manager.dart';
import '../../../helpers/user_type_helper.dart';
import '../../provider/users_provider.dart';
import 'user_details_screen.dart';
import 'create_user_screen.dart';
import 'dart:developer' as developer;

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();

  void _handleAddNew() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateUserScreen(),
      ),
    ).then((_) {
      developer.log('CreateUserScreen returned');
      // Refresh users list after returning
      Provider.of<UsersProvider>(context, listen: false).loadUsers();
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<UsersProvider>(context, listen: false);
      provider.loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationManager>(
      builder: (context, notificationManager, _) {
        // Listen to notification trigger and refresh data
        if (notificationManager.notificationTrigger) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final provider = Provider.of<UsersProvider>(context, listen: false);
            provider.loadUsers(searchKey: _searchController.text.trim());
            notificationManager.resetTrigger();
          });
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Users'),
          ),
          body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by name or code',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => Provider.of<UsersProvider>(context, listen: false)
                  .loadUsers(searchKey: v.trim()),
              onSubmitted: (v) => Provider.of<UsersProvider>(context, listen: false)
                  .loadUsers(searchKey: v.trim()),
            ),
          ),
          Expanded(
            child: Consumer<UsersProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (provider.errorMessage != null) {
                  return Center(
                    child: Text(provider.errorMessage!, style: const TextStyle(color: Colors.red)),
                  );
                }
                if (provider.users.isEmpty) {
                  return const Center(child: Text('No users'));
                }
                return ListView.separated(
                  itemCount: provider.users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final u = provider.users[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: AssetImage(AssetImages.imagesUsers),
                        
                      ),
                      title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Code: ${u.code}'),
                          if (u.phoneNo.isNotEmpty) Text('Phone: ${u.phoneNo}'),
                          Text('Category: ${UserTypeHelper.nameFromCatId(u.catId)}'),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => UserDetailsScreen(userId: u.id),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<int>(
        future: StorageHelper.getUserType(),
        builder: (context, snapshot) {
          final isAdmin = snapshot.data == 1;
          if (isAdmin) {
            return FloatingActionButton(
              onPressed: _handleAddNew,
              backgroundColor: Colors.black,
              child: const Icon(Icons.add, color: Colors.white),
            );
          }
          return const SizedBox.shrink();
        },
      ),
        );
      },
    );
  }
}
