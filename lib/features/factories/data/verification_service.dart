import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/sendgrid_config.dart';

class VerificationService {
  final SupabaseClient _supabase;

  VerificationService(this._supabase);

  /// Generate a 6-digit verification code
  String _generateCode() {
    final random = Random.secure();
    return (100000 + random.nextInt(900000)).toString();
  }

  /// Request a deletion verification code
  /// Returns the generated code (for testing) or null on error
  Future<String?> requestDeletionCode(String reportId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Check rate limiting (max 3 requests per hour)
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      final recentCodes = await _supabase
          .from('verification_codes')
          .select('id')
          .eq('user_id', user.id)
          .eq('purpose', 'delete_report')
          .gte('created_at', oneHourAgo.toIso8601String());

      if ((recentCodes as List).length >= 3) {
        throw Exception('Rate limit exceeded. Try again in 1 hour.');
      }

      // Generate code
      final code = _generateCode();
      final expiresAt = DateTime.now().add(const Duration(minutes: 5));

      // Store in database
      await _supabase.from('verification_codes').insert({
        'user_id': user.id,
        'code': code,
        'purpose': 'delete_report',
        'report_id': reportId,
        'expires_at': expiresAt.toIso8601String(),
        'used': false,
      });

      // Send email via Supabase (using auth email)
      // Note: This uses Supabase's built-in email service
      await _sendVerificationEmail(user.email!, code);

      return code;
    } catch (e) {
      print('Error requesting deletion code: $e');
      rethrow;
    }
  }

  /// Send verification email via SendGrid
  Future<void> _sendVerificationEmail(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.sendgrid.com/v3/mail/send'),
        headers: {
          'Authorization': 'Bearer ${SendGridConfig.apiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'personalizations': [
            {
              'to': [
                {'email': email}
              ],
              'subject': SendGridConfig.subject,
            }
          ],
          'from': {
            'email': SendGridConfig.fromEmail,
            'name': SendGridConfig.fromName,
          },
          'content': [
            {
              'type': 'text/html',
              'value': '''
                <!DOCTYPE html>
                <html>
                <body style="font-family: Arial, sans-serif; padding: 20px; background-color: #f5f5f5;">
                  <div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 30px; border-radius: 10px;">
                    <h2 style="color: #333;">Delete Verification Code</h2>
                    <p style="font-size: 16px; color: #666;">You requested to delete a report in HydroSentinel.</p>
                    <div style="background-color: #f0f0f0; padding: 20px; border-radius: 5px; margin: 20px 0;">
                      <p style="margin: 0; font-size: 14px; color: #888;">Your verification code is:</p>
                      <h1 style="margin: 10px 0; color: #007bff; font-size: 36px; letter-spacing: 5px;">$code</h1>
                    </div>
                    <p style="font-size: 14px; color: #888;">This code will expire in <strong>5 minutes</strong>.</p>
                    <p style="font-size: 14px; color: #888;">If you didn't request this deletion, please ignore this email.</p>
                    <hr style="border: none; border-top: 1px solid #eee; margin: 30px 0;">
                    <p style="font-size: 12px; color: #aaa;">HydroSentinel - Water Chemistry Monitoring</p>
                  </div>
                </body>
                </html>
              ''',
            }
          ],
        }),
      );

      if (response.statusCode != 202) {
        throw Exception('Failed to send email: ${response.body}');
      }

      print('✅ Verification email sent successfully to $email');
    } catch (e) {
      print('❌ Error sending email: $e');
      // Still show code in debug for fallback
      print('DEBUG - Verification code: $code');
      rethrow;
    }
  }

  /// Verify code and delete report
  Future<bool> verifyAndDeleteReport(String reportId, String enteredCode) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No authenticated user');

      // Find valid code
      final codesResponse = await _supabase
          .from('verification_codes')
          .select()
          .eq('user_id', user.id)
          .eq('code', enteredCode)
          .eq('purpose', 'delete_report')
          .eq('report_id', reportId)
          .eq('used', false)
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (codesResponse == null) {
        throw Exception('Invalid or expired code');
      }

      // Mark code as used
      await _supabase
          .from('verification_codes')
          .update({'used': true})
          .eq('id', codesResponse['id']);

      // Get report details to delete file from storage
      final report = await _supabase
          .from('reports')
          .select('file_id, factory_id')
          .eq('id', reportId)
          .single();

      // Delete from database
      await _supabase
          .from('reports')
          .delete()
          .eq('id', reportId);

      // Delete from storage
      try {
        await _supabase.storage
            .from('factories')
            .remove([report['file_id']]);
      } catch (e) {
        print('Warning: Could not delete file from storage: $e');
        // Continue even if storage deletion fails
      }

      return true;
    } catch (e) {
      print('Error verifying and deleting: $e');
      rethrow;
    }
  }
}
