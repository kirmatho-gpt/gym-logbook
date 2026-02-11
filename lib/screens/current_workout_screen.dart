import 'package:flutter/material.dart';

import '../state/current_workout_controller.dart';

class CurrentWorkoutScreen extends StatelessWidget {
  const CurrentWorkoutScreen({
    super.key,
    required this.controller,
  });

  final CurrentWorkoutController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.hasActiveWorkout) {
          return const Center(
            child: Text('No active workout. Start one from Start Workout.'),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                controller.workoutName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  itemCount: controller.exercises.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final exercise = controller.exercises[index];
                    final lastInfo = _formatLastInfo(exercise);

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: exercise.isFinished
                              ? Colors.green
                              : Colors.transparent,
                          width: exercise.isFinished ? 2 : 0,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise.exerciseName,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(lastInfo),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.35),
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.18),
                              ),
                              child: Row(
                                children: [
                                  const Text('Global'),
                                  const SizedBox(width: 10),
                                  const Text('Sets:'),
                                  IconButton(
                                    onPressed: exercise.isFinished
                                        ? null
                                        : () {
                                            controller.setTargetSets(
                                              exercise.exerciseId,
                                              exercise.sets.length - 1,
                                            );
                                          },
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                  Text('${exercise.sets.length}'),
                                  IconButton(
                                    onPressed: exercise.isFinished
                                        ? null
                                        : () {
                                            controller.setTargetSets(
                                              exercise.exerciseId,
                                              exercise.sets.length + 1,
                                            );
                                          },
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                  const Spacer(),
                                  const Text('Weight:'),
                                  IconButton(
                                    onPressed: exercise.isFinished
                                        ? null
                                        : () {
                                            controller.changeExerciseWeight(
                                              exerciseId: exercise.exerciseId,
                                              delta: -0.5,
                                            );
                                          },
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                  Text(
                                    '${exercise.configuredWeight.toStringAsFixed(1)} kg',
                                  ),
                                  IconButton(
                                    onPressed: exercise.isFinished
                                        ? null
                                        : () {
                                            controller.changeExerciseWeight(
                                              exerciseId: exercise.exerciseId,
                                              delta: 0.5,
                                            );
                                          },
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Divider(height: 20),
                            ...List<Widget>.generate(
                              exercise.sets.length,
                              (setIndex) {
                                final setLine = exercise.sets[setIndex];
                                final isLocked = setLine.isValidated;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 56,
                                        child: Text('Set ${setIndex + 1}'),
                                      ),
                                      IconButton(
                                        onPressed: isLocked
                                            ? null
                                            : () => controller
                                                .changeSetRepetitions(
                                                  exerciseId: exercise.exerciseId,
                                                  setIndex: setIndex,
                                                  delta: -1,
                                                ),
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                      ),
                                      Text('${setLine.repetitions} reps'),
                                      if (isLocked)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 8),
                                          child: Text(
                                            '@ ${(setLine.validatedWeight ?? exercise.configuredWeight).toStringAsFixed(1)} kg',
                                          ),
                                        ),
                                      IconButton(
                                        onPressed: isLocked
                                            ? null
                                            : () => controller
                                                .changeSetRepetitions(
                                                  exerciseId: exercise.exerciseId,
                                                  setIndex: setIndex,
                                                  delta: 1,
                                                ),
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                      ),
                                      const Spacer(),
                                      FilledButton(
                                        onPressed: isLocked ||
                                                controller.isSavingSet ||
                                                exercise.isFinished
                                            ? null
                                            : () => controller.validateSet(
                                                  exerciseId: exercise.exerciseId,
                                                  setIndex: setIndex,
                                                ),
                                        child: Text(
                                          isLocked ? 'Validated' : 'Validate',
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: exercise.isFinished ||
                                        controller.isSavingSet
                                    ? null
                                    : () => controller.finishExercise(
                                          exercise.exerciseId,
                                        ),
                                child: Text(
                                  exercise.isFinished
                                      ? 'Finished'
                                      : 'Finish Exercise',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatLastInfo(CurrentWorkoutExerciseState exercise) {
    final performedAt = exercise.lastPerformedAt;
    final repetitions = exercise.lastRepetitions;
    final weight = exercise.lastWeight;

    if (performedAt == null || repetitions == null || weight == null) {
      return 'Last time: no history yet';
    }

    final date =
        '${performedAt.year.toString().padLeft(4, '0')}-${performedAt.month.toString().padLeft(2, '0')}-${performedAt.day.toString().padLeft(2, '0')}';
    return 'Last time: $date, $repetitions reps @ ${weight.toStringAsFixed(1)} kg';
  }
}
