import 'package:flutter/material.dart';

import 'app.dart';
import 'app_dependencies.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.create();
  runApp(App(dependencies: dependencies));
}
