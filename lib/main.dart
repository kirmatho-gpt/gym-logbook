import 'package:flutter/material.dart';

import 'data/app_database.dart';
import 'screens/current_workout_screen.dart';
import 'screens/exercises_screen.dart';
import 'screens/history_screen.dart';
import 'screens/start_workout_screen.dart';
import 'state/current_workout_controller.dart';

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
  late final CurrentWorkoutController _currentWorkoutController =
      CurrentWorkoutController(database: widget.database);
  int _selectedIndex = 0;

  Future<void> _onWorkoutStarted(int workoutSessionId) async {
    await _currentWorkoutController.startWorkout(workoutSessionId);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedIndex = 1;
    });
  }

  void _onWorkoutSessionDeleted(int workoutSessionId) {
    if (_currentWorkoutController.workoutSessionId == workoutSessionId) {
      _currentWorkoutController.clear();
    }
  }

  @override
  void dispose() {
    _currentWorkoutController.dispose();
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
                      icon: Icon(Icons.directions_run),
                      label: Text('Current Workout'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.history),
                      label: Text('History'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.list_alt),
                      label: Text('Exercises'),
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
                  StartWorkoutScreen(
                    database: widget.database,
                    onWorkoutStarted: _onWorkoutStarted,
                    onWorkoutSessionDeleted: _onWorkoutSessionDeleted,
                  ),
                  CurrentWorkoutScreen(controller: _currentWorkoutController),
                  HistoryScreen(database: widget.database),
                  ExercisesScreen(database: widget.database),
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
                  icon: Icon(Icons.directions_run),
                  label: 'Current Workout',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history),
                  label: 'History',
                ),
                NavigationDestination(
                  icon: Icon(Icons.list_alt),
                  label: 'Exercises',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
