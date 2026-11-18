import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';

/// Legacy HomeScreen entrypoint delegating to the unified DashboardScreen.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DashboardScreen();
  }
}
