import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hydrosentinel/core/app_styles.dart';

class DeleteVerificationDialog extends StatefulWidget {
  final String reportId;
  final String reportName;
  final Future<String?> Function() onRequestCode;
  final Future<bool> Function(String code) onVerifyAndDelete;

  const DeleteVerificationDialog({
    super.key,
    required this.reportId,
    required this.reportName,
    required this.onRequestCode,
    required this.onVerifyAndDelete,
  });

  @override
  State<DeleteVerificationDialog> createState() => _DeleteVerificationDialogState();
}

class _DeleteVerificationDialogState extends State<DeleteVerificationDialog> {
  final _codeController = TextEditingController();
  bool _codeSent = false;
  bool _isLoading = false;
  String? _error;
  int _remainingSeconds = 300; // 5 minutes
  bool _isTimerActive = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _isTimerActive = true;
      _remainingSeconds = 300;
    });

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_isTimerActive) return false;
      
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _isTimerActive = false;
          _error = 'Code expired. Request a new one.';
        }
      });
      
      return _isTimerActive && _remainingSeconds > 0;
    });
  }

  Future<void> _sendCode() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final code = await widget.onRequestCode();
      
      if (code != null && mounted) {
        setState(() {
          _codeSent = true;
          _isLoading = false;
        });
        _startTimer();
        
        // Show code in debug mode (remove in production)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification code sent! (DEBUG: $code)'),
            duration: const Duration(seconds: 5),
            backgroundColor: AppColors.riskLow,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyAndDelete() async {
    if (_codeController.text.length != 6) {
      setState(() {
        _error = 'Code must be 6 digits';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final success = await widget.onVerifyAndDelete(_codeController.text);
      
      if (success && mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Report'),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${widget.reportName}"?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'For security, enter the verification code sent to your email.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            
            if (!_codeSent) ...[
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _sendCode,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.email),
                label: const Text('Send Verification Code'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ] else ...[
              TextField(
                controller: _codeController,
                decoration: InputDecoration(
                  labelText: 'Verification Code',
                  hintText: '6-digit code',
                  border: const OutlineInputBorder(),
                  suffixIcon: _isTimerActive
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            _formatTime(_remainingSeconds),
                            style: TextStyle(
                              color: _remainingSeconds < 60
                                  ? AppColors.riskCritical
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isLoading ? null : _sendCode,
                      child: const Text('Resend Code'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyAndDelete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.riskCritical,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
            
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  color: AppColors.riskCritical,
                  fontSize: 12,
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
      ],
    );
  }
}
