import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../data/app_database.dart';

class CustomWorkoutScreen extends StatefulWidget {
  const CustomWorkoutScreen({
    super.key,
    required this.database,
    required this.onWorkoutStarted,
  });

  final AppDatabase database;
  final Future<void> Function(int workoutSessionId) onWorkoutStarted;

  @override
  State<CustomWorkoutScreen> createState() => _CustomWorkoutScreenState();
}

class _CustomWorkoutScreenState extends State<CustomWorkoutScreen> {
  final Set<int> _selectedExerciseIds = {};
  late final TextEditingController _workoutNameController;
  bool _isCreatingWorkout = false;

  @override
  void initState() {
    super.initState();
    _workoutNameController =
        TextEditingController(text: _buildDefaultWorkoutName());
  }

  @override
  void dispose() {
    _workoutNameController.dispose();
    super.dispose();
  }

  String _buildDefaultWorkoutName() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final year = now.year.toString().padLeft(4, '0');
    return 'VirginActive $day-$month-$year';
  }

  @override
  Widget build(BuildContext context) {
    final muscleGroupsStream = (widget.database.select(widget.database.muscleGroups)
          ..orderBy([(tbl) => drift.OrderingTerm(expression: tbl.name)]))
        .watch();
    final exercisesStream = (widget.database.select(widget.database.exercises)
          ..orderBy([
            (tbl) => drift.OrderingTerm(
                  expression: tbl.muscleGroupId,
                ),
            (tbl) => drift.OrderingTerm(expression: tbl.name),
          ]))
        .watch();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Workout'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _workoutNameController,
              decoration: _textFieldDecoration(
                context,
                label: 'Workout name',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select exercises',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<MuscleGroup>>(
                stream: muscleGroupsStream,
                builder: (context, muscleGroupsSnapshot) {
                  final muscleGroups =
                      muscleGroupsSnapshot.data ?? const <MuscleGroup>[];
                  return StreamBuilder<List<Exercise>>(
                    stream: exercisesStream,
                    builder: (context, exercisesSnapshot) {
                      final exercises =
                          exercisesSnapshot.data ?? const <Exercise>[];

                      if (muscleGroupsSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          exercisesSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          muscleGroups.isEmpty &&
                          exercises.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (exercises.isEmpty) {
                        return const Center(child: Text('No exercises yet.'));
                      }

                      final muscleGroupById = <int, MuscleGroup>{
                        for (final group in muscleGroups) group.id: group,
                      };

                      final grouped = <int?, List<Exercise>>{};
                      for (final exercise in exercises) {
                        final list = grouped.putIfAbsent(
                          exercise.muscleGroupId,
                          () => <Exercise>[],
                        );
                        list.add(exercise);
                      }

                      final orderedGroupIds = <int?>[
                        ...muscleGroups
                            .where((group) => grouped.containsKey(group.id))
                            .map((group) => group.id),
                        if (grouped.containsKey(null)) null,
                      ];

                      return ListView.separated(
                        itemCount: orderedGroupIds.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final groupId = orderedGroupIds[index];
                          final groupExercises = grouped[groupId] ?? const <Exercise>[];
                          if (groupExercises.isEmpty) {
                            return const SizedBox.shrink();
                          }

                          final groupName = groupId == null
                              ? 'Other'
                              : muscleGroupById[groupId]?.name ?? 'Unknown';

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      groupName,
                                      style: Theme.of(context).textTheme.titleSmall,
                                    ),
                                  ),
                                  for (final exercise in groupExercises)
                                    CheckboxListTile(
                                      value: _selectedExerciseIds.contains(exercise.id),
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked ?? false) {
                                            _selectedExerciseIds.add(exercise.id);
                                          } else {
                                            _selectedExerciseIds.remove(exercise.id);
                                          }
                                        });
                                      },
                                      title: Text(exercise.name),
                                      dense: true,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _isCreatingWorkout || _selectedExerciseIds.isEmpty
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);

                        setState(() {
                          _isCreatingWorkout = true;
                        });

                        try {
                          final workoutSessionId =
                              await widget.database.createCustomWorkout(
                            exerciseIds: _selectedExerciseIds.toList(),
                            nameOverride:
                                _workoutNameController.text.trim().isEmpty
                                    ? _buildDefaultWorkoutName()
                                    : _workoutNameController.text.trim(),
                          );
                          await widget.onWorkoutStarted(workoutSessionId);

                          if (!mounted) {
                            return;
                          }

                          messenger.showSnackBar(
                            const SnackBar(content: Text('Workout started.')),
                          );
                          navigator.pop();
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isCreatingWorkout = false;
                            });
                          }
                        }
                      },
                child: _isCreatingWorkout
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Start workout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _textFieldDecoration(
    BuildContext context, {
    required String label,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
      ),
    );
    return InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.4),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
