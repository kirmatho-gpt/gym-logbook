import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'data/repositories/exercise_repository.dart';
import 'debug/debug_database_screen.dart';
import 'screens/history_screen.dart';
import 'screens/start_workout_screen.dart';

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
  int _selectedIndex = 0;

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
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Gym Logbook'),
        ),
        body: Row(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 600) {
                  return const SizedBox.shrink();
                }

                return NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _selectedIndex = index;
                    });
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.fitness_center),
                      label: Text('Start Workout'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history),
                      label: Text('History'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.bug_report),
                      label: Text('Debug'),
                    ),
                  ],
                );
              },
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: [
                  StartWorkoutScreen(database: widget.database),
                  const HistoryScreen(),
                  DebugDatabaseScreen(
                    exerciseRepository: _exerciseRepository,
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 600) {
              return const SizedBox.shrink();
            }

            return NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.fitness_center),
                  label: 'Start Workout',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bug_report),
                  label: 'Debug',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
