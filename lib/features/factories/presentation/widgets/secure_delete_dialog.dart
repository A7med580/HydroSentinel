import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hydrosentinel/core/app_styles.dart';
import 'package:hydrosentinel/features/auth/presentation/auth_providers.dart';

/// Secure delete confirmation dialog with OTP verification
class SecureDeleteDialog extends ConsumerStatefulWidget {
  final String reportName;
  final Future<void> Function() onDelete;

  const SecureDeleteDialog({
    super.key,
    required this.reportName,
    required this.onDelete,
  });

  @override
  ConsumerState<SecureDeleteDialog> createState() => _SecureDeleteDialogState();
}

class _SecureDeleteDialogState extends ConsumerState<SecureDeleteDialog> {
  // Steps: 0 = Confirm, 1 = OTP Entry
  int _step = 0;
  bool _isLoading = false;
  String? _error;
  final TextEditingController _otpController = TextEditingController();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.email == null) {
      setState(() => _error = 'User not authenticated');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ref.read(otpVerificationServiceProvider).sendOtp(user.email!);
      
      if (mounted) {
        result.fold(
          (failure) {
            // Check for Debug fallback
            if (failure.message.startsWith('EMAIL_FAILED:')) {
              final code = failure.message.split(':')[1];
              setState(() {
                _step = 1; // Move to OTP entry
                _isLoading = false;
                _error = null;
              });
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('DEBUG: Email failed. Code is: $code'),
                  duration: const Duration(seconds: 20),
                  backgroundColor: Colors.orange,
                  action: SnackBarAction(
                    label: 'COPY', 
                    onPressed: () {
                      // Optional: clipboard copy
                    }
                  ),
                ),
              );
            } else {
              setState(() {
                _error = failure.message;
                _isLoading = false;
              });
            }
          },
          (_) {
            setState(() {
              _step = 1; // Move to OTP entry
              _isLoading = false;
            });
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to send OTP: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyAndDelete() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter a valid 6-digit code');
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.email == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final verifyResult = await ref.read(otpVerificationServiceProvider).verifyOtp(user.email!, otp);
      
      verifyResult.fold(
        (failure) {
          if (mounted) {
            setState(() {
              _error = failure.message;
              _isLoading = false;
            });
          }
        },
        (isValid) async {
          if (isValid) {
            // OTP Verified, proceed to delete
            try {
              await widget.onDelete();
              if (mounted) {
                Navigator.of(context).pop(true);
              }
            } catch (e) {
               if (mounted) {
                setState(() {
                  _error = 'Delete failed: $e';
                  _isLoading = false;
                });
               }
            }
          } else {
             if (mounted) {
              setState(() {
                _error = 'Invalid OTP. Please try again.';
                _isLoading = false;
              });
             }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Verification failed: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _step == 0 ? Icons.warning_amber_rounded : Icons.lock_outline, 
            color: AppColors.riskCritical, 
            size: 28
          ),
          const SizedBox(width: 8),
          Text(_step == 0 ? 'Delete Report' : 'Verify Identity'),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_step == 0) ...[
              Text(
                'Are you sure you want to delete:',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.reportName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This action cannot be undone. To proceed, we will send an OTP to your email.',
                style: TextStyle(
                  color: AppColors.riskCritical,
                  fontSize: 13,
                ),
              ),
            ] else ...[
              const Text(
                'An OTP has been sent to your email. Enter it below to confirm deletion.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Enter 6-digit OTP',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.riskCritical.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.riskCritical, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: AppColors.riskCritical, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading 
            ? null 
            : (_step == 0 ? _sendOtp : _verifyAndDelete),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.riskCritical,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_step == 0 ? 'Send OTP' : 'Verify & Delete'),
        ),
      ],
    );
  }
}
