import 'package:flutter/material.dart';
import '../../../../core/app_styles.dart';
import '../domain/factory_entity.dart';
import 'factory_dashboard_screen.dart';
import 'factory_trends_screen.dart';
import 'factory_alerts_screen.dart';
import 'factory_indices_screen.dart';
import 'factory_details_screen.dart';
import '../../analytics/presentation/analytics_dashboard.dart';

class FactoryHomeScreen extends StatefulWidget {
  final FactoryEntity factory;

  const FactoryHomeScreen({super.key, required this.factory});

  @override
  State<FactoryHomeScreen> createState() => _FactoryHomeScreenState();
}

class _FactoryHomeScreenState extends State<FactoryHomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      FactoryDashboardScreen(factoryId: widget.factory.id),
      FactoryTrendsScreen(factoryId: widget.factory.id),
      FactoryAlertsScreen(factoryId: widget.factory.id),
      FactoryIndicesScreen(factoryId: widget.factory.id),
      // We can also include the "raw report list" as the last tab or somewhere else
      FactoryDetailsScreen(factory: widget.factory),
      AnalyticsDashboard(factoryId: widget.factory.id), // V2 Analytics
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Trends'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.psychology), label: 'Intelligent'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Analytics'),
        ],
      ),
    );
  }
}
