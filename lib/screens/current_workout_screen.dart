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
        final compact = MediaQuery.sizeOf(context).width < 430;
        final controlIconSize = compact ? 18.0 : 24.0;
        final controlTextStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: compact ? 12 : null,
        );
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
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 24),
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
                        padding: EdgeInsets.all(compact ? 10 : 14),
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
                              padding: EdgeInsets.symmetric(
                                horizontal: compact ? 8 : 12,
                                vertical: compact ? 8 : 10,
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
                                  Text('Sets:', style: controlTextStyle),
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
                                    iconSize: controlIconSize,
                                    visualDensity: compact
                                        ? VisualDensity.compact
                                        : null,
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints.tightFor(
                                      width: compact ? 28 : 40,
                                      height: compact ? 28 : 40,
                                    ),
                                  ),
                                  Text('${exercise.sets.length}', style: controlTextStyle),
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
                                    iconSize: controlIconSize,
                                    visualDensity: compact
                                        ? VisualDensity.compact
                                        : null,
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints.tightFor(
                                      width: compact ? 28 : 40,
                                      height: compact ? 28 : 40,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text('Weight:', style: controlTextStyle),
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
                                    iconSize: controlIconSize,
                                    visualDensity: compact
                                        ? VisualDensity.compact
                                        : null,
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints.tightFor(
                                      width: compact ? 28 : 40,
                                      height: compact ? 28 : 40,
                                    ),
                                  ),
                                  Text(
                                    '${exercise.configuredWeight.toStringAsFixed(1)} kg',
                                    style: controlTextStyle,
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
                                    iconSize: controlIconSize,
                                    visualDensity: compact
                                        ? VisualDensity.compact
                                        : null,
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints.tightFor(
                                      width: compact ? 28 : 40,
                                      height: compact ? 28 : 40,
                                    ),
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
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
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
                                              width: compact ? 44 : 56,
                                              child: Text(
                                                'Set ${setIndex + 1}',
                                                style: controlTextStyle,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: isLocked
                                                  ? null
                                                  : () => controller
                                                      .changeSetRepetitions(
                                                        exerciseId:
                                                            exercise.exerciseId,
                                                        setIndex: setIndex,
                                                        delta: -1,
                                                      ),
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                              ),
                                              iconSize: controlIconSize,
                                              visualDensity: compact
                                                  ? VisualDensity.compact
                                                  : null,
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints.tightFor(
                                                width: compact ? 28 : 40,
                                                height: compact ? 28 : 40,
                                              ),
                                            ),
                                            Text(
                                              '${setLine.repetitions} reps',
                                              style: controlTextStyle,
                                            ),
                                            if (isLocked)
                                              Padding(
                                                padding:
                                                    const EdgeInsets.only(left: 8),
                                                child: Text(
                                                  '@ ${(setLine.validatedWeight ?? exercise.configuredWeight).toStringAsFixed(1)} kg',
                                                  style: controlTextStyle,
                                                ),
                                              ),
                                            IconButton(
                                              onPressed: isLocked
                                                  ? null
                                                  : () => controller
                                                      .changeSetRepetitions(
                                                        exerciseId:
                                                            exercise.exerciseId,
                                                        setIndex: setIndex,
                                                        delta: 1,
                                                      ),
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                              ),
                                              iconSize: controlIconSize,
                                              visualDensity: compact
                                                  ? VisualDensity.compact
                                                  : null,
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints.tightFor(
                                                width: compact ? 28 : 40,
                                                height: compact ? 28 : 40,
                                              ),
                                            ),
                                            const Spacer(),
                                            FilledButton(
                                              onPressed: isLocked ||
                                                      controller.isSavingSet ||
                                                      exercise.isFinished
                                                  ? null
                                                  : () => controller.validateSet(
                                                        exerciseId:
                                                            exercise.exerciseId,
                                                        setIndex: setIndex,
                                                      ),
                                              style: compact
                                                  ? FilledButton.styleFrom(
                                                      minimumSize: const Size(0, 32),
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                    )
                                                  : null,
                                              child: Text(
                                                isLocked ? 'Validated' : 'Validate',
                                                style: compact
                                                    ? const TextStyle(fontSize: 12)
                                                    : null,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (exercise.timeSinceLastValidation != null &&
                                          exercise.timeSinceSetIndex == setIndex)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4,
                                            right: 4,
                                          ),
                                          child: Align(
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              'Time since ${_formatMmSs(exercise.timeSinceLastValidation!)}',
                                              style: controlTextStyle,
                                            ),
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
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  FilledButton(
                                    onPressed: exercise.isFinished ||
                                            controller.isSavingSet
                                        ? null
                                        : () => controller.finishExercise(
                                              exercise.exerciseId,
                                            ),
                                    style: compact
                                        ? FilledButton.styleFrom(
                                            minimumSize: const Size(0, 32),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            visualDensity: VisualDensity.compact,
                                          )
                                        : null,
                                    child: Text(
                                      exercise.isFinished
                                          ? 'Finished'
                                          : 'Finish Exercise',
                                      style: compact
                                          ? const TextStyle(fontSize: 12)
                                          : null,
                                    ),
                                  ),
                                  if (exercise.timeSinceLastValidation != null &&
                                      exercise.timeSinceSetIndex == null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Time since ${_formatMmSs(exercise.timeSinceLastValidation!)}',
                                        style: controlTextStyle,
                                        textAlign: TextAlign.right,
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
