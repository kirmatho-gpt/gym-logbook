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
        final hasValidatedSets = controller.exercises.any(
          (exercise) => exercise.sets.any((setLine) => setLine.isValidated),
        );

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.workoutName,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (!hasValidatedSets)
                    IconButton(
                      onPressed: controller.isSavingSet
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final deleted =
                                  await controller.deleteCurrentWorkoutIfEmpty();
                              if (!context.mounted) {
                                return;
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
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete workout',
                    ),
                ],
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
                          width: exercise.isFinished ? 4 : 0,
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
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isLocked
                                            ? Colors.green.shade300
                                            : Colors.transparent,
                                        width: isLocked ? 1.5 : 0,
                                      ),
                                    ),
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
                                        if (exercise.timeSinceLastValidation !=
                                                null &&
                                            exercise.timeSinceSetIndex ==
                                                setIndex)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 10,
                                            ),
                                            child: SizedBox(
                                              width: 110,
                                              child: Text(
                                                'Time since ${_formatMmSs(exercise.timeSinceLastValidation!)}',
                                                textAlign: TextAlign.right,
                                              ),
                                            ),
                                          ),
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
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (exercise.timeSinceLastValidation != null &&
                                      exercise.timeSinceSetIndex == null)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: SizedBox(
                                        width: 110,
                                        child: Text(
                                          'Time since ${_formatMmSs(exercise.timeSinceLastValidation!)}',
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ),
                                  FilledButton(
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
                                ],
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
    final setCount = exercise.lastSetCount;
    final maxWeight = exercise.lastMaxWeight;

    if (performedAt == null || setCount == null || maxWeight == null) {
      return 'Last time: no history yet';
    }

    final date =
        '${performedAt.year.toString().padLeft(4, '0')}-${performedAt.month.toString().padLeft(2, '0')}-${performedAt.day.toString().padLeft(2, '0')}';
    return 'Last time: $date, $setCount sets, max ${maxWeight.toStringAsFixed(1)} kg';
  }

  String _formatMmSs(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
