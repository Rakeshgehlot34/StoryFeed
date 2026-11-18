import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/constants.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'shared/services/app_messenger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ShortsSplitterApp()));
}

class ShortsSplitterApp extends ConsumerWidget {
  const ShortsSplitterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final accentColor = ref.watch(accentColorProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppMessenger.scaffoldMessengerKey,
      themeMode: themeMode,
      theme: AppTheme.lightTheme(accentColor.seedColor),
      darkTheme: AppTheme.darkTheme(accentColor.seedColor),
      routerConfig: router,
    );
  }
}
