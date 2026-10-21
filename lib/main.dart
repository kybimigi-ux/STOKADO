import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/auth_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/navigation_service.dart';
import 'services/offline_queue_service.dart';
import 'services/settings_service.dart';
import 'services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: 'https://cunrimpeugkvejtjouhw.supabase.co',
      publishableKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN1bnJpbXBldWdrdmVqdGpvdWh3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI0MjU1MzAsImV4cCI6MjEwODAwMTUzMH0.ZpBQBbkKZR4gYhfvrUzF7WBUlhZyq7KhdRDYEl6_RDw',
    );

    await SettingsService.instance.init();
    await AuthService.instance.init();

    await Hive.initFlutter();
    await OfflineQueueService.instance.init();
    await ConnectivityService.instance.init();

    if (ConnectivityService.instance.lastKnownOnline) {
      SyncService.instance.syncPendingTransactions();
    }

    ConnectivityService.instance.onOnlineStatusChanged.listen((isOnline) {
      if (isOnline) {
        SyncService.instance.syncPendingTransactions();
      }
    });

    runApp(const InventoryApp());
  } catch (e) {
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Failed to initialize:\n$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Make sure Supabase credentials are correct.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
  }
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      title: 'STOKADO — Inventory Management',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}
