import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schedule_frontend_flutter/presentation/features/sync/sync_screen.dart';
import '../provider/sync_provider.dart';

/// Sync Refresh Button Widget
/// Reusable widget showing last sync date and refresh button to open SyncScreen.
/// Used on HomeScreen, OrdersScreen (checker/biller/driver), and
/// OutOfStockListSupplierScreen (supplier) so all roles can access sync.
class SyncRefreshButton extends StatelessWidget {
  const SyncRefreshButton({super.key});

  Future<void> _onRefresh(BuildContext context) async {
    final syncProvider = Provider.of<SyncProvider>(context, listen: false);
    if (!syncProvider.isSyncing) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SyncScreen()),
      );
      if (context.mounted) {
        syncProvider.loadLastSyncDate();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncProvider>(
      builder: (context, syncProvider, _) {
        // Load last sync date on first build
        if (syncProvider.lastSyncDate == null && !syncProvider.isSyncing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            syncProvider.loadLastSyncDate();
          });
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Last sync date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Last Synced:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      syncProvider.lastSyncDate ?? 'Never',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              // Refresh button
              IconButton(
                icon: syncProvider.isSyncing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 20),
                onPressed:
                    syncProvider.isSyncing ? null : () => _onRefresh(context),
                tooltip: 'Sync Data',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        );
      },
    );
  }
}
