import 'package:flutter/material.dart';

import 'app.dart';
import 'app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.create();
  await dependencies.media.clearDrafts();
  // Reminders are a convenience: whatever goes wrong here (even an Error
  // thrown by the plugin) must never stop the app from reaching runApp.
  try {
    await dependencies.reminders.topUp();
  } catch (error) {
    debugPrint('$error');
  }
  runApp(App(dependencies: dependencies));
}
