import 'package:flutter/material.dart';
import '../../../../core/app_styles.dart';

class RiskAcceptanceDialog extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onContinue;

  const RiskAcceptanceDialog({
    super.key,
    required this.onCancel,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.riskCritical),
          SizedBox(width: 8),
          Text('Missing Data Detected'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'The uploaded file contains missing values in required columns.',
            style: TextStyle(height: 1.5),
          ),
          SizedBox(height: 12),
          Text(
            'We can attempt to fix this by calculating averages from valid rows, but this introduces data risk.',
            style: TextStyle(height: 1.5, color: AppColors.textSecondary),
          ),
          SizedBox(height: 12),
          Text(
            'Do you want to proceed at your own risk?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel,
          child: const Text('Cancel Upload'),
        ),
        ElevatedButton(
          onPressed: onContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.riskCritical,
            foregroundColor: Colors.white,
          ),
          child: const Text('Continue (Risk Accepted)'),
        ),
      ],
    );
  }
}
