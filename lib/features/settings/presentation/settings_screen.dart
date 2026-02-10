import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_styles.dart';
import '../../../core/services/excel_template_generator.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../auth/presentation/login_screen.dart';
import 'help_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    // Since package_info_plus might not be in pubspec, we'll try hardcodng for now based on pubspec
    // Or if it is, we use it. 
    // Plan said "Set version... display in UI".
    // I'll assume we can use package_info_plus if available, or just hardcode for this task if I don't want to add deps.
    // The user rules say "Avoid adding new dependencies unless explicitly asked".
    // So I will HARDCODE it or parse it?
    // Hardcoding is safer to avoid build issues if package absent.
    // "1.0.0+1" from pubspec.
    
    setState(() {
      _version = '1.0.0+1'; 
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.help_outline, color: AppColors.primary),
            title: const Text('Help & Documentation'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.download_rounded, color: AppColors.primary),
            title: const Text('Download Excel Template'),
            subtitle: const Text('Get a sample file for your data'),
            onTap: () async {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Generating template...')),
                );
                await ExcelTemplateGenerator.generateAndShare();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to generate template: $e')),
                  );
                }
              }
            },
          ),
          const Divider(),
          const SizedBox(height: AppStyles.paddingS),
          ListTile(
            leading: const Icon(Icons.info, color: AppColors.primary),
            title: const Text('About HydroSentinel'),
            subtitle: Text('Version $_version'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'HydroSentinel',
                applicationVersion: _version,
                applicationIcon: const Icon(Icons.water_drop, size: 48, color: AppColors.primary),
                children: [
                   const Text(
                    'Industrial water treatment monitoring system.\n\n'
                    'Scientifically validated for cooling tower and RO system analysis.\n\n'
                    'Calculations based on ASTM and ASHRAE standards.'
                  ),
                ],
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
            onTap: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: const Text('Are you sure you want to sign out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: AppColors.error),
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true) {
                await ref.read(authRepositoryProvider).signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
