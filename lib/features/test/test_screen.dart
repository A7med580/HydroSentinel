import 'package:flutter/material.dart';
import '../../core/app_styles.dart';

/// Empty Test Screen placeholder
/// Content will be added by user later
class TestScreen extends StatelessWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Test'),
      ),
      body: Container(
        decoration: AppStyles.backgroundGradient,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppStyles.borderRadiusL),
                  boxShadow: AppShadows.card,
                ),
                child: const Icon(
                  Icons.science_outlined,
                  size: 40,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppStyles.paddingL),
              Text(
                'Test Screen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppStyles.paddingS),
              Text(
                'This screen is empty. Content will be added later.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
