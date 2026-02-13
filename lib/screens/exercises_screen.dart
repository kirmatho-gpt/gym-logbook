import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';

import '../data/app_database.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key, required this.database});

  final AppDatabase database;

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  int? _selectedMuscleGroupId;
  int? _selectedExerciseId;

  @override
  Widget build(BuildContext context) {
    final muscleGroupsStream = (widget.database.select(widget.database.muscleGroups)
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
          Text(
            'Exercises',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _selectedMuscleGroupId == null
                ? const Center(
                    child: Text('Select a muscle group to see exercises.'),
                  )
                : StreamBuilder<List<Exercise>>(
                    stream: exercisesStream,
                    builder: (context, snapshot) {
                      final exercises = snapshot.data ?? const <Exercise>[];
                      final selectedExerciseId = _selectedExerciseId;

                      if (snapshot.connectionState == ConnectionState.waiting &&
                          exercises.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (selectedExerciseId != null &&
                          !exercises.any((exercise) => exercise.id == selectedExerciseId)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) {
                            return;
                          }
                          setState(() {
                            _selectedExerciseId = null;
                          });
                        });
                      }

                      if (exercises.isEmpty) {
                        return const Center(
                          child: Text('No exercises for this muscle group.'),
                        );
                      }

                      return Column(
                        children: [
                          Expanded(
                            child: ListView.separated(
                              itemCount: exercises.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final exercise = exercises[index];
                                final isSelected = exercise.id == selectedExerciseId;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ListTile(
                                      selected: isSelected,
                                      title: Text(exercise.name),
                                      onTap: () {
                                        setState(() {
                                          _selectedExerciseId = exercise.id;
                                        });
                                      },
                                    ),
                                    if (isSelected)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          16,
                                          0,
                                          16,
                                          10,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary.withValues(
                                                    alpha: 0.35,
                                                  ),
                                            ),
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primaryContainer
                                                .withValues(alpha: 0.22),
                                          ),
                                          child: FutureBuilder<String?>(
                                            future: widget.database
                                                .fetchExerciseImagePath(
                                              exercise.id,
                                            ),
                                            builder: (context, imageSnapshot) {
                                              final imagePath =
                                                  imageSnapshot.data;
                                              final expectedPath = widget
                                                  .database
                                                  .buildStandardExerciseImagePath(
                                                exercise.id,
                                              );
                                              final resolvedImagePath =
                                                  imagePath ?? expectedPath;

                                              return Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'Exercise ID: ${exercise.id}\nNotes: ${(exercise.notes == null || exercise.notes!.trim().isEmpty) ? '-' : exercise.notes!}\nCreated: ${_formatDateTime(exercise.createdAt)}',
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  _ExerciseImagePreview(
                                                    imagePath: resolvedImagePath,
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
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

class _ExerciseImagePreview extends StatelessWidget {
  const _ExerciseImagePreview({required this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final imagePath = this.imagePath;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      clipBehavior: Clip.antiAlias,
      child: imagePath == null
          ? Icon(
              Icons.image_outlined,
              color: Theme.of(context).colorScheme.outline,
            )
          : Image.asset(
              imagePath,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                Icons.image_outlined,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
    );
  }
}
