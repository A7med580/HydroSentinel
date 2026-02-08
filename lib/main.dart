import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_styles.dart';
import 'core/app_constants.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'features/auth/presentation/email_verification_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/parameters/parameters_screen.dart';
import 'features/indices/indices_screen.dart';
import 'features/alerts/alerts_screen.dart';
import 'features/simulation/simulation_screen.dart';
import 'features/trends/trends_screen.dart';
import 'features/factories/presentation/factories_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: HydroSentinelApp()));
}

class HydroSentinelApp extends ConsumerWidget {
  const HydroSentinelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the auth state changes
    final authState = ref.watch(authStateProvider);

    return authState.when(
      data: (user) {
        Widget home;
        if (user == null) {
          home = const LoginScreen();
        } else {
          // Check actual Supabase user for methods not on our Entity
          final supabaseUser = Supabase.instance.client.auth.currentUser;
          if (supabaseUser != null && supabaseUser.emailConfirmedAt == null) {
             home = const EmailVerificationScreen();
          } else {
             home = const MainNavigationHolder();
          }
        }
        
        return MaterialApp(
          title: 'HydroSentinel',
          debugShowCheckedModeBanner: false,
          theme: AppStyles.industrialTheme,
          home: home,
        );
      },
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (err, stack) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Error: $err'))),
      ),
    );
  }
}

class MainNavigationHolder extends StatefulWidget {
  const MainNavigationHolder({super.key});

  @override
  State<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends State<MainNavigationHolder> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const FactoriesScreen(),
    const ParametersScreen(),
    const IndicesScreen(),
    const AlertsScreen(),
    const TrendsScreen(),
    const SimulationScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.factory), label: 'Factories'),
          BottomNavigationBarItem(icon: Icon(Icons.water_drop), label: 'Parameters'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Intelligence'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Trends'),
          BottomNavigationBarItem(icon: Icon(Icons.science), label: 'Simulate'),
        ],
      ),
    );
  }
}
