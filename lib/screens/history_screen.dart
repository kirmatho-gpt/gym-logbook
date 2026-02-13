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
              Tab(text: 'Progress'),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.45),
                  width: 0.9,
                ),
              ),
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
                      Row(
                        children: [
                          Expanded(child: Text(item.workoutName)),
                          if (item.isNew)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'New',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimary,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Muscle Group: ${item.muscleGroupName} • Exercises: ${item.exercisesCount} • Total time: ${_formatDuration(item.totalTimeSeconds)}',
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
                isDense: true,
                itemHeight: 48,
                menuMaxHeight: 280,
                decoration: _dropdownDecoration(
                  context,
                  label: 'Muscle group',
                ),
                items: [
                  for (final group in muscleGroups)
                    DropdownMenuItem<int>(
                      value: group.id,
                      child: Text(
                        group.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
                isDense: true,
                itemHeight: 48,
                menuMaxHeight: 280,
                decoration: _dropdownDecoration(context, label: 'Exercise'),
                items: [
                  for (final exercise in exercises)
                    DropdownMenuItem<int>(
                      value: exercise.id,
                      child: Text(
                        exercise.name,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
                          child: Text('No progress data for this exercise.'),
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
                            'Progress over last $_defaultEffortHistoryDays days',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 240,
                            child: _EffortLineChart(
                              labels: chartSeries.labels,
                              averageEffortValues:
                                  chartSeries.averageEffortValues,
                              totalLiftedValues: chartSeries.totalLiftedValues,
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

    final averageEffortByDay = <String, double>{
      for (final point in points) point.dayKey: point.averageEffort,
    };
    final totalLiftedByDay = <String, double>{
      for (final point in points) point.dayKey: point.totalLifted,
    };

    final labels = <String>[];
    final averageEffortValues = <double?>[];
    final totalLiftedValues = <double?>[];
    for (var i = 0; i < historyDays; i++) {
      final day = start.add(Duration(days: i));
      final dayKey = _dayKey(day);
      labels.add(dayKey);
      averageEffortValues.add(averageEffortByDay[dayKey]);
      totalLiftedValues.add(totalLiftedByDay[dayKey]);
    }

    return _EffortChartSeries(
      labels: labels,
      averageEffortValues: averageEffortValues,
      totalLiftedValues: totalLiftedValues,
    );
  }

  String _dayKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  InputDecoration _dropdownDecoration(
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

class _EffortChartSeries {
  const _EffortChartSeries({
    required this.labels,
    required this.averageEffortValues,
    required this.totalLiftedValues,
  });

  final List<String> labels;
  final List<double?> averageEffortValues;
  final List<double?> totalLiftedValues;
}

class _EffortLineChart extends StatelessWidget {
  const _EffortLineChart({
    required this.labels,
    required this.averageEffortValues,
    required this.totalLiftedValues,
  });

  final List<String> labels;
  final List<double?> averageEffortValues;
  final List<double?> totalLiftedValues;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty ||
        averageEffortValues.isEmpty ||
        totalLiftedValues.isEmpty) {
      return const SizedBox.shrink();
    }

    final textTheme = Theme.of(context).textTheme.bodySmall;
    final tickIndexes = _buildTickIndexes(labels.length, tickCount: 5);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LegendItem(
                color: Theme.of(context).colorScheme.primary,
                label: 'Average Per Set',
              ),
              _LegendItem(
                color: Theme.of(context).colorScheme.tertiary,
                label: 'Total Lifted',
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _EffortLineChartPainter(
              leftValues: averageEffortValues,
              rightValues: totalLiftedValues,
              axisColor: Theme.of(context).colorScheme.outline,
              leftLineColor: Theme.of(context).colorScheme.primary,
              leftPointColor: Theme.of(context).colorScheme.primary,
              rightLineColor: Theme.of(context).colorScheme.tertiary,
              rightPointColor: Theme.of(context).colorScheme.tertiary,
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
    required this.leftValues,
    required this.rightValues,
    required this.axisColor,
    required this.leftLineColor,
    required this.leftPointColor,
    required this.rightLineColor,
    required this.rightPointColor,
  });

  final List<double?> leftValues;
  final List<double?> rightValues;
  final Color axisColor;
  final Color leftLineColor;
  final Color leftPointColor;
  final Color rightLineColor;
  final Color rightPointColor;

  @override
  void paint(Canvas canvas, Size size) {
    const yTickCount = 5;
    const left = 40.0;
    const top = 8.0;
    const right = 40.0;
    const bottom = 8.0;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    if (chartWidth <= 0 ||
        chartHeight <= 0 ||
        leftValues.length < 2 ||
        rightValues.length < 2) {
      return;
    }

    final leftMinMax = _findMinMax(leftValues);
    final rightMinMax = _findMinMax(rightValues);
    if (leftMinMax == null || rightMinMax == null) {
      return;
    }

    final (leftMinY, leftMaxY) = _expandRange(leftMinMax.$1, leftMinMax.$2);
    final (rightMinY, rightMaxY) =
        _expandRange(rightMinMax.$1, rightMinMax.$2);

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(
      const Offset(left, top),
      Offset(left, top + chartHeight),
      axisPaint,
    );
    canvas.drawLine(
      Offset(left + chartWidth, top),
      Offset(left + chartWidth, top + chartHeight),
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

    _drawLineSeries(
      canvas: canvas,
      values: leftValues,
      minY: leftMinY,
      maxY: leftMaxY,
      left: left,
      top: top,
      chartWidth: chartWidth,
      chartHeight: chartHeight,
      lineColor: leftLineColor,
      pointColor: leftPointColor,
    );
    _drawLineSeries(
      canvas: canvas,
      values: rightValues,
      minY: rightMinY,
      maxY: rightMaxY,
      left: left,
      top: top,
      chartWidth: chartWidth,
      chartHeight: chartHeight,
      lineColor: rightLineColor,
      pointColor: rightPointColor,
    );

    for (var i = 0; i < yTickCount; i++) {
      final ratio = i / (yTickCount - 1);
      final y = top + (chartHeight * ratio);
      final leftValue = leftMaxY - ((leftMaxY - leftMinY) * ratio);
      final rightValue = rightMaxY - ((rightMaxY - rightMinY) * ratio);
      _drawYLabelLeft(canvas, _formatLabel(leftValue), left - 6, y);
      _drawYLabelRight(
        canvas,
        _formatLabel(rightValue),
        left + chartWidth + 6,
        y,
      );
    }
  }

  void _drawLineSeries({
    required Canvas canvas,
    required List<double?> values,
    required double minY,
    required double maxY,
    required double left,
    required double top,
    required double chartWidth,
    required double chartHeight,
    required Color lineColor,
    required Color pointColor,
  }) {
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

  (double, double) _expandRange(double minY, double maxY) {
    if ((maxY - minY).abs() < 0.0001) {
      return (minY - 1, maxY + 1);
    }
    return (minY, maxY);
  }

  void _drawYLabelLeft(Canvas canvas, String text, double rightX, double centerY) {
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

  void _drawYLabelRight(
    Canvas canvas,
    String text,
    double leftX,
    double centerY,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 11, color: Colors.black54),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final offset = Offset(leftX, centerY - (painter.height / 2));
    painter.paint(canvas, offset);
  }

  String _formatLabel(double value) {
    final roundedToTen = (value / 10).round() * 10;
    return roundedToTen.toString();
  }

  @override
  bool shouldRepaint(covariant _EffortLineChartPainter oldDelegate) {
    return oldDelegate.leftValues != leftValues ||
        oldDelegate.rightValues != rightValues ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.leftLineColor != leftLineColor ||
        oldDelegate.leftPointColor != leftPointColor ||
        oldDelegate.rightLineColor != rightLineColor ||
        oldDelegate.rightPointColor != rightPointColor;
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
