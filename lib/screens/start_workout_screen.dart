import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'continue_workout_screen.dart';
import 'custom_workout_screen.dart';
import 'muscle_workout_screen.dart';
import 'settings_screen.dart';

class StartWorkoutScreen extends StatefulWidget {
  const StartWorkoutScreen({
    super.key,
    required this.database,
    required this.onWorkoutStarted,
    this.onWorkoutSessionDeleted,
  });

  final AppDatabase database;
  final Future<void> Function(int workoutSessionId) onWorkoutStarted;
  final void Function(int workoutSessionId)? onWorkoutSessionDeleted;

  @override
  State<StartWorkoutScreen> createState() => _StartWorkoutScreenState();
}

class _StartWorkoutScreenState extends State<StartWorkoutScreen> {
  static const List<String> _motivationalMessages = [
    'You’re here. Let’s make it count.',
    'Consistency beats intensity.',
    'One workout closer to your goal.',
    'Show up. Do the work. Log it.',
    'Progress starts with this session.',
    'Train it. Track it. Improve it.',
    'Every rep you log builds progress.',
    'Strong sessions start with good records.',
    'Your training, clearly logged.',
  ];

  String? _motivationalMessage;

  @override
  Widget build(BuildContext context) {
    _motivationalMessage ??=
        _motivationalMessages[math.Random().nextInt(_motivationalMessages.length)];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.center,
                child: FractionallySizedBox(
                  widthFactor: 0.85,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          .withValues(alpha: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Text('💪'),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _motivationalMessage!,
                            style: Theme.of(context).textTheme.titleSmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('💪'),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: FractionallySizedBox(
                          widthFactor: 0.75,
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => MuscleWorkoutScreen(
                                    database: widget.database,
                                    onWorkoutStarted: widget.onWorkoutStarted,
                                  ),
                                ),
                              );
                            },
                            child: const Text('New Muscle Workout'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.center,
                        child: FractionallySizedBox(
                          widthFactor: 0.75,
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => CustomWorkoutScreen(
                                    database: widget.database,
                                    onWorkoutStarted: widget.onWorkoutStarted,
                                  ),
                                ),
                              );
                            },
                            child: const Text('New Custom Workout'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.center,
                        child: FractionallySizedBox(
                          widthFactor: 0.75,
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ContinueWorkoutScreen(
                                    database: widget.database,
                                    onWorkoutStarted: widget.onWorkoutStarted,
                                    onWorkoutSessionDeleted:
                                        widget.onWorkoutSessionDeleted,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Continue Workout'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: FloatingActionButton.small(
              tooltip: 'Settings',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(database: widget.database),
                  ),
                );
              },
              child: const Icon(Icons.settings),
            ),
          ),
        ],
      ),
    );
  }
}
