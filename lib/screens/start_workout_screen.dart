import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'custom_workout_screen.dart';
import 'muscle_workout_screen.dart';

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
  bool _showContinueList = false;
  int? _selectedWorkoutSessionId;
  bool _isContinuingWorkout = false;
  final Set<int> _deletingWorkoutSessionIds = <int>{};

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
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final session = unfinished[index];
                            final isSelected = session.workoutSessionId ==
                                _selectedWorkoutSessionId;
                            final isDeleting = _deletingWorkoutSessionIds.contains(
                              session.workoutSessionId,
                            );
                            return Card(
                              child: ListTile(
                                onTap: _isContinuingWorkout || isDeleting
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedWorkoutSessionId =
                                              session.workoutSessionId;
                                        });
                                      },
                                leading: Radio<int>(
                                  value: session.workoutSessionId,
                                  groupValue: _selectedWorkoutSessionId,
                                  onChanged: _isContinuingWorkout || isDeleting
                                      ? null
                                      : (value) {
                                          if (value == null) {
                                            return;
                                          }
                                          setState(() {
                                            _selectedWorkoutSessionId = value;
                                          });
                                        },
                                ),
                                title: Text(session.workoutName),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${_formatDateTime(session.performedAt)} • ${session.unfinishedExerciseCount} unfinished exercise(s)',
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: LinearProgressIndicator(
                                              value: session.progressRatio,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text('${session.progressPercent}%'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                selected: isSelected,
                                trailing: session.validatedSetCount == 0
                                    ? IconButton(
                                        onPressed: isDeleting ||
                                                _isContinuingWorkout
                                            ? null
                                            : () async {
                                                final messenger =
                                                    ScaffoldMessenger.of(
                                                  context,
                                                );
                                                setState(() {
                                                  _deletingWorkoutSessionIds.add(
                                                    session.workoutSessionId,
                                                  );
                                                });

                                                final deleted = await widget.database
                                                    .deleteWorkoutSessionIfEmpty(
                                                  session.workoutSessionId,
                                                );

                                                if (!mounted) {
                                                  return;
                                                }

                                                setState(() {
                                                  _deletingWorkoutSessionIds.remove(
                                                    session.workoutSessionId,
                                                  );
                                                  if (deleted &&
                                                      _selectedWorkoutSessionId ==
                                                          session.workoutSessionId) {
                                                    _selectedWorkoutSessionId =
                                                        null;
                                                  }
                                                });

                                                if (deleted) {
                                                  widget.onWorkoutSessionDeleted
                                                      ?.call(
                                                    session.workoutSessionId,
                                                  );
                                                }

                                                messenger.showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      deleted
                                                          ? 'Workout deleted.'
                                                          : 'Could not delete workout.',
                                                    ),
                                                  ),
                                                );
                                              },
                                        icon: isDeleting
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(Icons.delete_outline),
                                        tooltip: 'Delete workout',
                                      )
                                    : null,
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
