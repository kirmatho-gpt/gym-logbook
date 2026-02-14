import 'package:flutter/material.dart';

import '../data/app_database.dart';

class ContinueWorkoutScreen extends StatefulWidget {
  const ContinueWorkoutScreen({
    super.key,
    required this.database,
    required this.onWorkoutStarted,
    this.onWorkoutSessionDeleted,
  });

  final AppDatabase database;
  final Future<void> Function(int workoutSessionId) onWorkoutStarted;
  final void Function(int workoutSessionId)? onWorkoutSessionDeleted;

  @override
  State<ContinueWorkoutScreen> createState() => _ContinueWorkoutScreenState();
}

class _ContinueWorkoutScreenState extends State<ContinueWorkoutScreen> {
  int? _selectedWorkoutSessionId;
  bool _isContinuingWorkout = false;
  final Set<int> _deletingWorkoutSessionIds = <int>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Continue Workout'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
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
                      final isSelected =
                          session.workoutSessionId == _selectedWorkoutSessionId;
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
                                  onPressed: isDeleting || _isContinuingWorkout
                                      ? null
                                      : () async {
                                          final messenger =
                                              ScaffoldMessenger.of(context);
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
                                              _selectedWorkoutSessionId = null;
                                            }
                                          });

                                          if (deleted) {
                                            widget.onWorkoutSessionDeleted?.call(
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
                                          child: CircularProgressIndicator(
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isContinuingWorkout
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Back'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
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
                                if (mounted) {
                                  Navigator.of(context).pop();
                                }
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
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Confirm Continue'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
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
