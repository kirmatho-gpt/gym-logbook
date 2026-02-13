import 'dart:math' as math;

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
  static const int _defaultEffortHistoryDays = 30;

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
          separatorBuilder: (_, index) => const SizedBox(height: 12),
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
                      historyDays: _defaultEffortHistoryDays,
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

                      final chartSeries = _buildEffortChartSeries(
                        points,
                        _defaultEffortHistoryDays,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Average Effort over last $_defaultEffortHistoryDays days',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 240,
                            child: _EffortLineChart(
                              labels: chartSeries.labels,
                              values: chartSeries.values,
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

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  _EffortChartSeries _buildEffortChartSeries(
    List<DailyExerciseEffort> points,
    int historyDays,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: historyDays - 1));

    final valuesByDay = <String, double>{
      for (final point in points) point.dayKey: point.averageEffort,
    };

    final labels = <String>[];
    final values = <double?>[];
    for (var i = 0; i < historyDays; i++) {
      final day = start.add(Duration(days: i));
      final dayKey = _dayKey(day);
      labels.add(dayKey);
      values.add(valuesByDay[dayKey]);
    }

    return _EffortChartSeries(labels: labels, values: values);
  }

  String _dayKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class _EffortChartSeries {
  const _EffortChartSeries({
    required this.labels,
    required this.values,
  });

  final List<String> labels;
  final List<double?> values;
}

class _EffortLineChart extends StatelessWidget {
  const _EffortLineChart({
    required this.labels,
    required this.values,
  });

  final List<String> labels;
  final List<double?> values;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty || values.isEmpty) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme.bodySmall;
    final tickIndexes = _buildTickIndexes(labels.length, tickCount: 5);

    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _EffortLineChartPainter(
              values: values,
              axisColor: Theme.of(context).colorScheme.outline,
              lineColor: Theme.of(context).colorScheme.primary,
              pointColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final index in tickIndexes)
              Text(_shortLabel(labels[index]), style: textTheme),
          ],
        ),
      ],
    );
  }

  List<int> _buildTickIndexes(int length, {required int tickCount}) {
    if (length <= 1 || tickCount <= 1) {
      return [0];
    }

    final maxTicks = math.min(tickCount, length);
    final indexes = <int>{};
    for (var i = 0; i < maxTicks; i++) {
      final ratio = i / (maxTicks - 1);
      indexes.add((ratio * (length - 1)).round());
    }
    final sorted = indexes.toList()..sort();
    return sorted;
  }

  String _shortLabel(String value) {
    final parts = value.split('-');
    if (parts.length != 3) {
      return value;
    }
    return '${parts[1]}/${parts[2]}';
  }
}

class _EffortLineChartPainter extends CustomPainter {
  const _EffortLineChartPainter({
    required this.values,
    required this.axisColor,
    required this.lineColor,
    required this.pointColor,
  });

  final List<double?> values;
  final Color axisColor;
  final Color lineColor;
  final Color pointColor;

  @override
  void paint(Canvas canvas, Size size) {
    const yTickCount = 5;
    const left = 40.0;
    const top = 8.0;
    const right = 8.0;
    const bottom = 8.0;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    if (chartWidth <= 0 || chartHeight <= 0 || values.length < 2) {
      return;
    }

    final minMax = _findMinMax(values);
    if (minMax == null) {
      return;
    }

    var minY = minMax.$1;
    var maxY = minMax.$2;
    if ((maxY - minY).abs() < 0.0001) {
      minY -= 1;
      maxY += 1;
    }

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(
      const Offset(left, top),
      Offset(left, top + chartHeight),
      axisPaint,
    );
    canvas.drawLine(
      Offset(left, top + chartHeight),
      Offset(left + chartWidth, top + chartHeight),
      axisPaint,
    );

    final gridPaint = Paint()
      ..color = axisColor.withAlpha(70)
      ..strokeWidth = 1;
    for (var i = 1; i < yTickCount - 1; i++) {
      final y = top + chartHeight * (i / (yTickCount - 1));
      canvas.drawLine(Offset(left, y), Offset(left + chartWidth, y), gridPaint);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = pointColor
      ..style = PaintingStyle.fill;

    final path = Path();
    var hasPathPoint = false;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      if (value == null) {
        continue;
      }

      final x = left + chartWidth * (i / (values.length - 1));
      final y = top + ((maxY - value) / (maxY - minY)) * chartHeight;
      if (!hasPathPoint) {
        path.moveTo(x, y);
        hasPathPoint = true;
      } else {
        path.lineTo(x, y);
      }

      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }

    if (hasPathPoint) {
      canvas.drawPath(path, linePaint);
    }

    for (var i = 0; i < yTickCount; i++) {
      final ratio = i / (yTickCount - 1);
      final y = top + (chartHeight * ratio);
      final value = maxY - ((maxY - minY) * ratio);
      _drawYLabel(canvas, _formatLabel(value), left - 6, y);
    }
  }

  (double, double)? _findMinMax(List<double?> data) {
    double? minValue;
    double? maxValue;
    for (final value in data) {
      if (value == null) {
        continue;
      }
      minValue = minValue == null ? value : math.min(minValue, value);
      maxValue = maxValue == null ? value : math.max(maxValue, value);
    }
    if (minValue == null || maxValue == null) {
      return null;
    }
    return (minValue, maxValue);
  }

  void _drawYLabel(Canvas canvas, String text, double rightX, double centerY) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 11, color: Colors.black54),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final offset = Offset(rightX - painter.width, centerY - (painter.height / 2));
    painter.paint(canvas, offset);
  }

  String _formatLabel(double value) {
    final roundedToTen = (value / 10).round() * 10;
    return roundedToTen.toString();
  }

  @override
  bool shouldRepaint(covariant _EffortLineChartPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.pointColor != pointColor;
  }
}
