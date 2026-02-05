import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_styles.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/parameters/parameters_screen.dart';
import 'features/indices/indices_screen.dart';
import 'features/alerts/alerts_screen.dart';
import 'features/simulation/simulation_screen.dart';
import 'features/trends/trends_screen.dart';

void main() {
  runApp(const ProviderScope(child: HydroSentinelApp()));
}

class HydroSentinelApp extends StatelessWidget {
  const HydroSentinelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HydroSentinel',
      debugShowCheckedModeBanner: false,
      theme: AppStyles.industrialTheme,
      home: const MainNavigationHolder(),
    );
  }
}

class MainNavigationHolder extends StatefulWidget {
  const MainNavigationHolder({super.key});

  @override
  State<MainNavigationHolder> createState() => _MainNavigationHolderState();
}

class _MainNavigationHolderState extends State<MainNavigationHolder> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const ParametersScreen(),
    const IndicesScreen(),
    const AlertsScreen(),
    const TrendsScreen(),
    const SimulationScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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
          BottomNavigationBarItem(icon: Icon(Icons.water_drop), label: 'Parameters'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Intelligence'),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: 'Alerts'),
          BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: 'Trends'),
          BottomNavigationBarItem(icon: Icon(Icons.science), label: 'Simulate'),
        ],
      ),
    );
  }
}
