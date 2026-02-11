import 'package:flutter/material.dart';

import '../data/app_database.dart';
import 'package:drift/drift.dart' as drift;

class MuscleWorkoutScreen extends StatefulWidget {
  const MuscleWorkoutScreen({
    super.key,
    required this.database,
  });

  final AppDatabase database;

  @override
  State<MuscleWorkoutScreen> createState() => _MuscleWorkoutScreenState();
}

class _MuscleWorkoutScreenState extends State<MuscleWorkoutScreen> {
  int? _selectedMuscleGroupId;
  final Set<int> _selectedExerciseIds = {};
  bool _isCreatingWorkout = false;

  void _selectMuscleGroup(int id) {
    setState(() {
      _selectedMuscleGroupId = id;
      _selectedExerciseIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final muscleGroupsStream =
        widget.database.select(widget.database.muscleGroups).watch();
    final selectedMuscleGroupId = _selectedMuscleGroupId;
    final exercisesStream = selectedMuscleGroupId == null
        ? const Stream<List<Exercise>>.empty()
        : (widget.database.select(widget.database.exercises)
              ..where(
                (tbl) => tbl.muscleGroupId.equals(selectedMuscleGroupId),
              )
              ..orderBy([
                (tbl) => drift.OrderingTerm(expression: tbl.name),
              ]))
            .watch();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Muscle Workout'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select muscle group',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<MuscleGroup>>(
              stream: muscleGroupsStream,
              builder: (context, snapshot) {
                final muscleGroups = snapshot.data ?? [];
                if (snapshot.connectionState == ConnectionState.waiting &&
                    muscleGroups.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (muscleGroups.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('No muscle groups yet.'),
                  );
                }

                return Column(
                  children: muscleGroups
                      .map(
                        (group) => RadioListTile<int>(
                          value: group.id,
                          groupValue: _selectedMuscleGroupId,
                          onChanged: (value) {
                            if (value == null) return;
                            _selectMuscleGroup(value);
                          },
                          title: Text(group.name),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Select exercises',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _selectedMuscleGroupId == null
                  ? const Center(
                      child: Text('Pick a muscle group to see exercises.'),
                    )
                  : StreamBuilder<List<Exercise>>(
                      stream: exercisesStream,
                      builder: (context, snapshot) {
                        final exercises = snapshot.data ?? [];
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            exercises.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (exercises.isEmpty) {
                          return const Center(
                            child: Text('No exercises for this muscle group.'),
                          );
                        }

                        return ListView.separated(
                          itemCount: exercises.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final exercise = exercises[index];
                            final isSelected =
                                _selectedExerciseIds.contains(exercise.id);
                            return CheckboxListTile(
                              value: isSelected,
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
                onPressed: _isCreatingWorkout ||
                        _selectedMuscleGroupId == null ||
                        _selectedExerciseIds.isEmpty
                    ? null
                    : () async {
                        final muscleGroupId = _selectedMuscleGroupId;
                        if (muscleGroupId == null) {
                          return;
                        }

                        setState(() {
                          _isCreatingWorkout = true;
                        });

                        try {
                          await widget.database.createWorkoutForMuscleGroup(
                            muscleGroupId: muscleGroupId,
                            exerciseIds: _selectedExerciseIds.toList(),
                          );

                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Workout started.'),
                            ),
                          );
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
}
