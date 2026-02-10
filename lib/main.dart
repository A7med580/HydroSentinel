import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_styles.dart';
import 'core/app_constants.dart';
import 'core/navigation/main_navigation.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/auth_providers.dart';
import 'features/auth/presentation/email_verification_screen.dart';

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
    
    // Force validate session on startup
    ref.watch(currentUserProvider);

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
             home = const MainNavigation();
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
