import 'package:flutter/material.dart';

import 'screens/main_navigation_screen.dart';
import 'services/hive_service.dart';
import 'services/location_service.dart';
import 'services/reminder_service.dart';
import 'theme/app_theme.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await HiveService.init();
  await ReminderService.init(navigatorKey: appNavigatorKey);

  // Start periodic GPS departure check (low-power, default 10 minutes)
  LocationService.startPeriodicDepartureMonitoring(
    interval: const Duration(minutes: 10),
  );

  runApp(const BeforeYouLeaveApp());
}

class BeforeYouLeaveApp extends StatelessWidget {
  const BeforeYouLeaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: HiveService.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Before You Leave',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: const MainNavigationScreen(),
        );
      },
    );
  }
}
