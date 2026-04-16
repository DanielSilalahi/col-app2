import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/customer_detail_screen.dart';
import 'screens/submit_collection_screen.dart';
import 'screens/va_request_screen.dart';
import 'core/constants.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  
  NotificationService().selectNotificationStream.stream.listen((payload) {
    if (payload != null) {
      try {
        final data = jsonDecode(payload);
        final custId = data['customer_id'];
        final nav = navigatorKey.currentState;
        final ctx = navigatorKey.currentContext;
        if (nav != null && ctx != null && custId != null) {
          final provider = ctx.read<AppProvider>();
          try {
            final cust = provider.customers.firstWhere((c) => c.id == custId);
            nav.pushNamed('/va-request', arguments: cust);
          } catch (e) {
            nav.pushNamed('/home');
          }
        }
      } catch (e) {}
    }
  });

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppProvider(),
      child: const CollectionApp(),
    ),
  );
}

class CollectionApp extends StatelessWidget {
  const CollectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Collection P2P',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      home: const _SplashGate(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
        '/customer-detail': (_) => const CustomerDetailScreen(),
        '/submit-collection': (_) => const SubmitCollectionScreen(),
        '/va-request': (_) => const VaRequestScreen(),
      },
    );
  }
}

/// Auto-login check on app start
class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final provider = context.read<AppProvider>();
    final loggedIn = await provider.tryAutoLogin();
    if (mounted) {
      Navigator.pushReplacementNamed(
          context, loggedIn ? '/home' : '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Collection P2P',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
