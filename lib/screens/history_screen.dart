import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../data/app_database.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int? _selectedMuscleGroupId;
  int? _selectedExerciseId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Last Month'),
              Tab(text: 'Effort'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildLastMonthTab(context),
                _buildEffortTab(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastMonthTab(BuildContext context) {
    return StreamBuilder<List<WorkoutHistoryListItem>>(
      stream: widget.database.watchWorkoutsFromLastMonth(),
      builder: (context, snapshot) {
        final workouts = snapshot.data ?? const <WorkoutHistoryListItem>[];
        if (snapshot.connectionState == ConnectionState.waiting &&
            workouts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (workouts.isEmpty) {
          return const Center(child: Text('No workouts in the last month.'));
        }

        final byDay = <String, List<WorkoutHistoryListItem>>{};
        for (final item in workouts) {
          final list = byDay.putIfAbsent(item.dayKey, () => []);
          if (list.length < 2) {
            list.add(item);
          }
        }

        final dayKeys = byDay.keys.toList(growable: false);
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: dayKeys.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final dayKey = dayKeys[index];
            final items = byDay[dayKey] ?? const <WorkoutHistoryListItem>[];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayKey,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final item in items) ...[
                      Text(item.workoutName),
                      const SizedBox(height: 2),
                      Text(
                        'Muscle group: ${item.muscleGroupName} • Exercises: ${item.exercisesCount} • Total time: ${_formatDuration(item.totalTimeSeconds)}',
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEffortTab(BuildContext context) {
    final muscleGroupsStream =
        (widget.database.select(widget.database.muscleGroups)
              ..orderBy([(tbl) => drift.OrderingTerm(expression: tbl.name)]))
            .watch();

    final selectedMuscleGroupId = _selectedMuscleGroupId;
    final exercisesStream = selectedMuscleGroupId == null
        ? const Stream<List<Exercise>>.empty()
        : (widget.database.select(widget.database.exercises)
              ..where((tbl) => tbl.muscleGroupId.equals(selectedMuscleGroupId))
              ..orderBy([(tbl) => drift.OrderingTerm(expression: tbl.name)]))
            .watch();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<List<MuscleGroup>>(
            stream: muscleGroupsStream,
            builder: (context, snapshot) {
              final muscleGroups = snapshot.data ?? const <MuscleGroup>[];
              return DropdownButtonFormField<int>(
                value: _selectedMuscleGroupId,
                decoration: const InputDecoration(
                  labelText: 'Muscle group',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final group in muscleGroups)
                    DropdownMenuItem<int>(
                      value: group.id,
                      child: Text(group.name),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedMuscleGroupId = value;
                    _selectedExerciseId = null;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<Exercise>>(
            stream: exercisesStream,
            builder: (context, snapshot) {
              final exercises = snapshot.data ?? const <Exercise>[];
              final selectedExerciseId = _selectedExerciseId;
              final hasSelectedExercise = exercises.any(
                (item) => item.id == selectedExerciseId,
              );

              if (!hasSelectedExercise && selectedExerciseId != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _selectedExerciseId = null;
                  });
                });
              }

              return DropdownButtonFormField<int>(
                value: hasSelectedExercise ? selectedExerciseId : null,
                decoration: const InputDecoration(
                  labelText: 'Exercise',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final exercise in exercises)
                    DropdownMenuItem<int>(
                      value: exercise.id,
                      child: Text(exercise.name),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedExerciseId = value;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _selectedExerciseId == null
                ? const Center(
                    child: Text('Select muscle group and exercise.'),
                  )
                : StreamBuilder<List<DailyExerciseEffort>>(
                    stream: widget.database.watchDailyAverageEffortForExercise(
                      _selectedExerciseId!,
                    ),
                    builder: (context, snapshot) {
                      final points =
                          snapshot.data ?? const <DailyExerciseEffort>[];
                      if (snapshot.connectionState ==
                              ConnectionState.waiting &&
                          points.isEmpty) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (points.isEmpty) {
                        return const Center(
                          child: Text('No effort data for this exercise.'),
                        );
                      }

                      return ListView.separated(
                        itemCount: points.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final point = points[index];
                          return ListTile(
                            title: Text(point.dayKey),
                            trailing: Text(
                              point.averageEffort.toStringAsFixed(1),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
