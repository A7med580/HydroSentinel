import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_styles.dart';
import 'login_screen.dart';
import 'auth_providers.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Listen for auth state changes (e.g. creating session from deep link)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null && data.session!.user.emailConfirmedAt != null) {
        if (mounted) {
           // Main app Listeners will handle the routing, but we can force refresh if needed
           ref.refresh(authStateProvider);
        }
      }
    });
  }

  Future<void> _checkVerification() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Try to fetch the latest user details. 
      // This works even if the session is stale, as long as the refresh token is valid.
      final response = await Supabase.instance.client.auth.getUser();
      final user = response.user;

      if (user != null && user.emailConfirmedAt != null) {
         // Verified!
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Verified! Redirecting...'), backgroundColor: Colors.green),
           );
           // Force refresh of auth state to trigger main navigation
           ref.refresh(authStateProvider);
         }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not verified yet. Please check your email.')),
          );
        }
      }
    } on AuthException catch (e) {
      // If session is missing (400 or 401), we might need to ask user to login again
      if (e.message.contains('session missing') || e.statusCode == '403') {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Session expired. Please sign in again.')),
            );
            // Redirect to Login
            await ref.read(authRepositoryProvider).signOut();
         }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Error: ${e.message}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendEmail() async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) return;

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: 'hydrosentinel://login-callback',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email resent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email ?? 'your email';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppStyles.paddingL),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_unread, size: 80, color: AppColors.primary),
              const SizedBox(height: 24),
              const Text(
                'Verify your Email',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'We sent a verification link to:\n$email',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please check your inbox and click the link to secure your account.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: _isLoading ? null : _checkVerification,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('I HAVE VERIFIED', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading ? null : _resendEmail,
                child: const Text('Resend Email'),
              ),
              const SizedBox(height: 24),
              // Explicit "Back to Login" button as requested
              OutlinedButton.icon(
                onPressed: () async {
                   // Ensure we clear any stale state
                   await ref.read(authRepositoryProvider).signOut();
                   // Main auth state listener will handle redirection to Login
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back to Login'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
