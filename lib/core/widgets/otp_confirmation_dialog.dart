import 'package:flutter/material.dart';
import '../app_styles.dart';

/// OTP Confirmation dialog for Accepted Risk Mode.
/// Shows a text field for OTP entry and handles verification.
class OtpConfirmationDialog extends StatefulWidget {
  final String userEmail;
  final String expectedOtp;

  const OtpConfirmationDialog({
    super.key,
    required this.userEmail,
    required this.expectedOtp,
  });

  static Future<bool> show(
    BuildContext context, {
    required String userEmail,
    required String expectedOtp,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => OtpConfirmationDialog(
        userEmail: userEmail,
        expectedOtp: expectedOtp,
      ),
    );
    return result ?? false;
  }

  @override
  State<OtpConfirmationDialog> createState() => _OtpConfirmationDialogState();
}

class _OtpConfirmationDialogState extends State<OtpConfirmationDialog> {
  final _controller = TextEditingController();
  String? _error;
  int _attempts = 0;
  static const _maxAttempts = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _verify() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() => _error = 'Please enter the OTP code');
      return;
    }

    if (input == widget.expectedOtp) {
      Navigator.of(context).pop(true);
    } else {
      _attempts++;
      if (_attempts >= _maxAttempts) {
        Navigator.of(context).pop(false);
        return;
      }
      setState(() => _error = 'Invalid OTP. ${_maxAttempts - _attempts} attempts remaining.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.security, color: AppColors.primary, size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Security Verification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'A verification code has been sent to:',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            widget.userEmail,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade900.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'By entering this code, you accept that missing parameter '
              'values will be replaced with averages. This may affect '
              'calculation accuracy.',
              style: TextStyle(fontSize: 12),
            ),
          ),

          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: '------',
              errorText: _error,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              counterText: '',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _verify,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Verify', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
