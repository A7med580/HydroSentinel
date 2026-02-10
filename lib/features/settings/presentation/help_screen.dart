import 'package:flutter/material.dart';
import '../../../../core/app_styles.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help & Documentation'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppStyles.paddingM),
        children: [
          _buildSection(
            context,
            'Getting Started',
            'Upload your Excel laboratory reports to monitor water quality. Sync your factories with Google Drive or upload files directly from your device.',
          ),
          _buildSection(
            context,
            'Default Values & Assumptions',
            'HydroSentinel uses industry-standard default values when certain parameters are not measured:\n\n'
            '• Temperature: Defaults to 35°C (95°F) if not provided.\n'
            '  - Impact: Affects LSI/RSI/PSI calculations (~0.15 units per 10°C).\n'
            '  - Recommendation: Include "Temperature" in your Excel file for accuracy.\n\n'
            '• Makeup Water Conductivity: Assumed 200 µS/cm.\n'
            '  - Impact: Affects Cycles of Concentration (CoC).\n\n'
            '• Sulfate Estimation: Estimated as 50% of Chloride if missing.\n'
            '  - Impact: Affects Larson-Skold corrosion index.\n'
            '  - Recommendation: Measure sulfate directly for critical systems.\n\n'
            '• TDS Estimation: Calculated as Conductivity × 0.67.',
          ),
          _buildSection(
            context,
            'Excel File Best Practices',
            'For best results, your Excel files should include:\n\n'
            'REQUIRED COLUMNS:\n'
            '• Date (e.g., 2026-01-15)\n'
            '• pH (6.0-9.0)\n'
            '• Alkalinity (ppm as CaCO₃)\n'
            '• Conductivity (µS/cm)\n'
            '• Total Hardness (ppm as CaCO₃)\n'
            '• Chloride (ppm)\n\n'
            'RECOMMENDED:\n'
            '• Temperature, Zinc, Phosphate, Iron, Free Chlorine, Sulfate\n\n'
            'TIPS:\n'
            '• Headers can be in any row (auto-detected)\n'
            '• Extra columns are ignored',
          ),
          _buildSection(
            context,
            'Understanding Your Data Quality',
            'FILE SYNC SUMMARY:\n'
            '• Green checkmark = All data processed\n'
            '• Yellow warning = Rows skipped due to missing parameters\n'
            '• Red error = Parse failure\n\n'
            'MISSING DATA OPTIONS:\n'
            '1. SAFE MODE (Recommended): Skips incomplete rows. No assumptions made.\n'
            '2. ACCEPTED RISK MODE: Fills missing values using averages from the same file. Requires OTP verification.\n\n'
            'ALERT INDICATORS:\n'
            'Alerts based on estimated values (e.g., estimated sulfate) will clearly note this in the explanation.',
          ),
          _buildSection(
            context,
            'Understanding Indices',
            '• LSI (Langelier Saturation Index): Predicts scaling/corrosion.\n'
            '  - > +0.5: Scaling tendency\n'
            '  - < -0.5: Corrosive tendency\n\n'
            '• RSI (Ryznar Stability Index): Empiric index.\n'
            '  - < 6: Scaling\n'
            '  - > 7: Corrosive\n\n'
            '• PSI (Puckorius Scaling Index): Accounts for buffering capacity.',
          ),
          _buildSection(
            context,
            'Risk Levels',
            '• Low (Green): Optimal operation.\n'
            '• Medium (Yellow): Parameters deviating. Monitor closely.\n'
            '• High (Red): Critical deviation. Immediate action required.',
          ),
        ],
      ),
    );
  }
  
  Widget _buildSection(BuildContext context, String title, String content) {
    return Card(
      color: AppColors.card,
      margin: const EdgeInsets.only(bottom: AppStyles.paddingM),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppStyles.borderRadius)),
      child: Padding(
        padding: const EdgeInsets.all(AppStyles.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title, 
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              )
            ),
            const SizedBox(height: AppStyles.paddingS),
            Text(
              content,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
