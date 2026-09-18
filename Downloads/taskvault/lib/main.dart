import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/task_provider.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'utils/constants.dart';

/// Entry point — must be async so [WidgetsFlutterBinding] is initialised
/// before Hive and flutter_secure_storage touch any platform channels.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskVaultApp());
}

class TaskVaultApp extends StatelessWidget {
  const TaskVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // load() is async but safe to call here — the HomeScreen shows a
      // loading indicator while it's in progress.
      create: (_) => TaskProvider()..load(),
      child: Consumer<TaskProvider>(
        builder: (context, provider, _) {
          return MaterialApp(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: provider.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
