import 'package:bookself_/models/riwayat_pencarian.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'pages/login_page.dart';
import 'pages/main_nav.dart';
import 'services/session_service.dart';
import 'models/app_user.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  await Hive.initFlutter(); 
  Hive.registerAdapter(RiwayatPencarianAdapter());
  await Hive.openBox<RiwayatPencarian>('riwayat');

  await Supabase.initialize(
    url: 'https://ioibwzbdgkwkzpgvyyeh.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlvaWJ3emJkZ2t3a3pwZ3Z5eWVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAzMjUwMDcsImV4cCI6MjA5NTkwMTAwN30.n1C9nTt4IF55p3mtsA8iDq6aC31x7HHLmR72XRh99oU',
  );

  await NotificationService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BookShelf',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff9E421E)),
      ),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  Future<AppUser?> _loadUser() async {
    return SessionService.getCurrentUser();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser?>(
      future: _loadUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const MainNavigation();
        }

        return const LoginPage();
      },
    );
  }
}
