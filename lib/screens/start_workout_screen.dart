import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'muscle_workout_screen.dart';

class StartWorkoutScreen extends StatelessWidget {
  const StartWorkoutScreen({
    super.key,
    required this.database,
  });

  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => MuscleWorkoutScreen(database: database),
                ),
              );
            },
            child: const Text('Muscle Workout'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {},
            child: const Text('Custom Workout'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {},
            child: const Text('Continue Workout'),
          ),
        ],
      ),
    );
  }
}
