import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'muscle_workout_screen.dart';

class StartWorkoutScreen extends StatefulWidget {
  const StartWorkoutScreen({
    super.key,
    required this.database,
    required this.onWorkoutStarted,
  });

  final AppDatabase database;
  final Future<void> Function(int workoutSessionId) onWorkoutStarted;

  @override
  State<StartWorkoutScreen> createState() => _StartWorkoutScreenState();
}

class _StartWorkoutScreenState extends State<StartWorkoutScreen> {
  bool _showContinueList = false;
  int? _selectedWorkoutSessionId;
  bool _isContinuingWorkout = false;

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
                  builder: (_) => MuscleWorkoutScreen(
                    database: widget.database,
                    onWorkoutStarted: widget.onWorkoutStarted,
                  ),
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
            onPressed: () {
              setState(() {
                _showContinueList = !_showContinueList;
              });
            },
            child: const Text('Continue Workout'),
          ),
          if (_showContinueList) ...[
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<UnfinishedWorkoutSessionSummary>>(
                stream: widget.database.watchLatestUnfinishedWorkouts(limit: 5),
                builder: (context, snapshot) {
                  final unfinished =
                      snapshot.data ?? const <UnfinishedWorkoutSessionSummary>[];
                  final hasSelection = unfinished.any(
                    (item) => item.workoutSessionId == _selectedWorkoutSessionId,
                  );

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      unfinished.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (unfinished.isEmpty) {
                    return const Center(
                      child: Text('No unfinished workouts to continue.'),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Last unfinished workouts',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: unfinished.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final session = unfinished[index];
                            final isSelected = session.workoutSessionId ==
                                _selectedWorkoutSessionId;
                            return Card(
                              child: RadioListTile<int>(
                                value: session.workoutSessionId,
                                groupValue: _selectedWorkoutSessionId,
                                onChanged: _isContinuingWorkout
                                    ? null
                                    : (value) {
                                        if (value == null) {
                                          return;
                                        }
                                        setState(() {
                                          _selectedWorkoutSessionId = value;
                                        });
                                      },
                                title: Text(session.workoutName),
                                subtitle: Text(
                                  '${_formatDateTime(session.performedAt)} • ${session.unfinishedExerciseCount} unfinished exercise(s)',
                                ),
                                selected: isSelected,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: !hasSelection || _isContinuingWorkout
                              ? null
                              : () async {
                                  final selectedWorkoutSessionId =
                                      _selectedWorkoutSessionId;
                                  if (selectedWorkoutSessionId == null) {
                                    return;
                                  }

                                  setState(() {
                                    _isContinuingWorkout = true;
                                  });

                                  try {
                                    await widget.onWorkoutStarted(
                                      selectedWorkoutSessionId,
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _isContinuingWorkout = false;
                                      });
                                    }
                                  }
                                },
                          child: _isContinuingWorkout
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Confirm Continue'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}
