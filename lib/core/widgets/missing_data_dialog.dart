import 'package:flutter/material.dart';
import '../app_styles.dart';

/// Result of user's choice when missing data is detected
enum MissingDataChoice {
  /// Skip incomplete rows entirely
  safeMode,
  /// Use averages of available data (requires OTP)
  acceptedRiskMode,
  /// User cancelled - do not proceed
  cancelled,
}

/// Shows a dialog warning the user about missing parameters in uploaded Excel data.
/// Returns the user's chosen handling strategy.
class MissingDataDialog extends StatelessWidget {
  final List<String> missingParameters;
  final int affectedRowCount;
  final int totalRowCount;

  const MissingDataDialog({
    super.key,
    required this.missingParameters,
    required this.affectedRowCount,
    required this.totalRowCount,
  });

  static Future<MissingDataChoice> show(
    BuildContext context, {
    required List<String> missingParameters,
    required int affectedRowCount,
    required int totalRowCount,
  }) async {
    final result = await showDialog<MissingDataChoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MissingDataDialog(
        missingParameters: missingParameters,
        affectedRowCount: affectedRowCount,
        totalRowCount: totalRowCount,
      ),
    );
    return result ?? MissingDataChoice.cancelled;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Missing Parameters Detected',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade900.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$affectedRowCount of $totalRowCount rows are missing data. '
                'Calculations may be inaccurate if these rows are included without correction.',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 16),

            // Missing parameter list
            const Text(
              'Missing Parameters:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            ...missingParameters.map((param) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  const Icon(Icons.remove_circle_outline, size: 16, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(param, style: const TextStyle(fontSize: 13))),
                ],
              ),
            )),

            const SizedBox(height: 16),

            // Impact explanation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Why This Matters:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getImpactExplanation(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Choose action
            const Text(
              'Choose how to proceed:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 12),

            // Option A: Safe Mode
            _buildOptionCard(
              context,
              icon: Icons.shield_outlined,
              color: Colors.green,
              title: 'Safe Mode',
              description: 'Skip incomplete rows. Only use rows with all parameters present. No data replacement.',
              onTap: () => Navigator.of(context).pop(MissingDataChoice.safeMode),
            ),

            const SizedBox(height: 10),

            // Option C: Accepted Risk Mode
            _buildOptionCard(
              context,
              icon: Icons.warning_outlined,
              color: Colors.orange,
              title: 'Accepted Risk Mode',
              description: 'Replace missing values with averages from available data. Requires email confirmation.',
              onTap: () => Navigator.of(context).pop(MissingDataChoice.acceptedRiskMode),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(MissingDataChoice.cancelled),
          child: const Text('Cancel Upload', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }

  String _getImpactExplanation() {
    final explanations = <String>[];
    for (final param in missingParameters) {
      final lower = param.toLowerCase();
      if (lower.contains('ph')) {
        explanations.add('• Missing pH affects all index calculations (LSI, RSI, PSI)');
      } else if (lower.contains('alkalinity')) {
        explanations.add('• Missing Alkalinity skews scaling and corrosion risk assessment');
      } else if (lower.contains('hardness')) {
        explanations.add('• Missing Hardness invalidates scaling risk calculation');
      } else if (lower.contains('conductivity')) {
        explanations.add('• Missing Conductivity prevents TDS estimation and CoC calculation');
      } else if (lower.contains('chloride')) {
        explanations.add('• Missing Chloride affects Larson-Skold corrosion index');
      } else if (lower.contains('zinc')) {
        explanations.add('• Missing Zinc prevents corrosion inhibitor effectiveness assessment');
      } else if (lower.contains('iron')) {
        explanations.add('• Missing Iron cannot be assessed for fouling/deposition risk');
      } else if (lower.contains('phosphate')) {
        explanations.add('• Missing Phosphates prevents fouling balance evaluation');
      } else if (lower.contains('date')) {
        explanations.add('• Missing Date prevents time-based aggregation');
      } else {
        explanations.add('• Missing $param may affect related calculations');
      }
    }
    return explanations.join('\n');
  }
}
