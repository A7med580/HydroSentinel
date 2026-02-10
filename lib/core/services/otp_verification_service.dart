import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../failures.dart';
import 'package:dartz/dartz.dart';

class OtpVerificationService {
  final SupabaseClient _supabase;
  
  // In-memory store for OTPs: Email -> {code, expiresAt}
  final Map<String, _OtpData> _otps = {};

  OtpVerificationService(this._supabase);

  /// Generates a 6-digit OTP and sends it via Supabase Edge Function
  Future<Either<Failure, void>> sendOtp(String email) async {
    String? code; 
    try {
      // 1. Generate 6-digit code
      code = (Random().nextInt(900000) + 100000).toString();
      
      // 2. Store with expiry (5 minutes)
      _otps[email] = _OtpData(
        code: code,
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );
      
      if (kDebugMode) {
        print('DEBUG: Generated OTP for $email: $code');
        print('DEBUG: Invoking Edge Function "send-delete-otp"...');
      }

      // 3. Call Edge Function (Secure Bridge)
      await _supabase.functions.invoke(
        'send-delete-otp',
        body: {
          'email': email,
          'otp': code,
        },
      );
      
      if (kDebugMode) {
        print('DEBUG: Edge Function invoked successfully.');
      }
      return const Right(null);
      
    } catch (e) {
      if (kDebugMode) {
        print('DEBUG: OTP Send Failed: $e');
      }
      // FALLBACK: Return the code in the error so UI can show it in debug/fallback mode
      return Left(ServerFailure('EMAIL_FAILED:$code'));
    }
  }

  /// Verifies the OTP code locally
  Future<Either<Failure, bool>> verifyOtp(String email, String code) async {
    try {
      final otpData = _otps[email];
      
      if (otpData == null) {
        return Left(ServerFailure('No OTP found. Please request a new one.'));
      }
      
      if (DateTime.now().isAfter(otpData.expiresAt)) {
        _otps.remove(email);
        return Left(ServerFailure('OTP has expired. Please request a new one.'));
      }
      
      if (otpData.code == code) {
         _otps.remove(email); // consume OTP
         return const Right(true);
      } else {
         return Left(ServerFailure('Invalid Code'));
      }
    } catch (e) {
      return Left(ServerFailure('Verification Error: $e'));
    }
  }
}

class _OtpData {
  final String code;
  final DateTime expiresAt;
  
  _OtpData({required this.code, required this.expiresAt});
}
