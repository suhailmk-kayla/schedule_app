import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../helpers/user_type_helper.dart';
import '../../provider/users_provider.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final TextEditingController _searchController = TextEditingController();

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
                      title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Code: ${u.code}'),
                          if (u.phoneNo.isNotEmpty) Text('Phone: ${u.phoneNo}'),
                          Text('Category: ${UserTypeHelper.nameFromCatId(u.catId)}'),
                        ],
                      ),
                      // onTap: () { /* Admin could edit user - out of scope */ },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
