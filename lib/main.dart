import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'data/repositories/exercise_repository.dart';
import 'debug/debug_database_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase.open();
  runApp(MyApp(database: database));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.database});

  final AppDatabase database;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final ExerciseRepository _exerciseRepository =
      ExerciseRepository(widget.database);

  @override
  void dispose() {
    widget.database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Logbook',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: DebugDatabaseScreen(
        exerciseRepository: _exerciseRepository,
      ),
    );
  }
}
