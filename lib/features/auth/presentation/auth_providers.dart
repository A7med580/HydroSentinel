import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_repository_impl.dart';
import '../data/supabase_data_source.dart';
import '../domain/auth_repository.dart';
import '../domain/user_entity.dart';
import '../../../core/services/otp_verification_service.dart';

// Data Source Provider
final authDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return SupabaseAuthDataSource(Supabase.instance.client);
});

// Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(authDataSourceProvider));
});

// Auth State Provider (Stream)
final authStateProvider = StreamProvider<UserEntity?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// Current User Provider (Future)
final currentUserProvider = FutureProvider<UserEntity?>((ref) async {
  final result = await ref.watch(authRepositoryProvider).getCurrentUser();
  return result.fold((l) => null, (r) => r);
});

// OTP Service Provider
final otpVerificationServiceProvider = Provider<OtpVerificationService>((ref) {
  return OtpVerificationService(Supabase.instance.client);
});
