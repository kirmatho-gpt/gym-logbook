import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class CurrentWorkoutSessionData {
  const CurrentWorkoutSessionData({
    required this.workoutName,
    required this.exercises,
  });

  final String workoutName;
  final List<CurrentWorkoutExerciseData> exercises;
}

class CurrentWorkoutExerciseData {
  const CurrentWorkoutExerciseData({
    required this.exerciseEntryId,
    required this.exerciseId,
    required this.exerciseName,
    required this.savedSets,
    this.lastPerformedAt,
    this.lastSetCount,
    this.lastMaxWeight,
  });

  final int exerciseEntryId;
  final int exerciseId;
  final String exerciseName;
  final List<SavedExerciseSetData> savedSets;
  final DateTime? lastPerformedAt;
  final int? lastSetCount;
  final double? lastMaxWeight;
}

class SavedExerciseSetData {
  const SavedExerciseSetData({
    required this.repetitions,
    required this.weight,
  });

  final int repetitions;
  final double weight;
}

class ExerciseLastPerformanceData {
  const ExerciseLastPerformanceData({
    required this.performedAt,
    required this.setCount,
    required this.maxWeight,
  });

  final DateTime performedAt;
  final int setCount;
  final double maxWeight;
}

class UnfinishedWorkoutSessionSummary {
  const UnfinishedWorkoutSessionSummary({
    required this.workoutSessionId,
    required this.workoutName,
    required this.performedAt,
    required this.unfinishedExerciseCount,
  });

  final int workoutSessionId;
  final String workoutName;
  final DateTime performedAt;
  final int unfinishedExerciseCount;
}

class WorkoutHistoryListItem {
  const WorkoutHistoryListItem({
    required this.workoutSessionId,
    required this.dayKey,
    required this.workoutName,
    required this.muscleGroupName,
    required this.exercisesCount,
    required this.totalTimeSeconds,
  });

  final int workoutSessionId;
  final String dayKey;
  final String workoutName;
  final String muscleGroupName;
  final int exercisesCount;
  final int totalTimeSeconds;
}

class DailyExerciseEffort {
  const DailyExerciseEffort({
    required this.dayKey,
    required this.averageEffort,
  });

  final String dayKey;
  final double averageEffort;
}

class WorkoutDefinitions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get muscleGroupId =>
      integer().nullable().references(MuscleGroups, #id)();
  BoolColumn get isCustom => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class MuscleGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  IntColumn get muscleGroupId =>
      integer().nullable().references(MuscleGroups, #id)();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutDefinitionId =>
      integer().references(WorkoutDefinitions, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {workoutDefinitionId, exerciseId},
      ];
}

class WorkoutSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutDefinitionId =>
      integer().nullable().references(WorkoutDefinitions, #id)();
  TextColumn get nameOverride => text().nullable()();
  DateTimeColumn get performedAt => dateTime()();
  TextColumn get notes => text().nullable()();
}

class ExerciseEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workoutSessionId =>
      integer().references(WorkoutSessions, #id)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get notes => text().nullable()();
}

class SetEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get exerciseEntryId =>
      integer().references(ExerciseEntries, #id)();
  IntColumn get setIndex => integer().withDefault(const Constant(0))();
  RealColumn get weight => real().withDefault(const Constant(0))();
  IntColumn get repetitions => integer().withDefault(const Constant(0))();
  DateTimeColumn get validatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isWarmup => boolean().withDefault(const Constant(false))();
  TextColumn get notes => text().nullable()();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'gym_logbook.sqlite'));
    return NativeDatabase.createInBackground(file, logStatements: true);
  });
}

@DriftDatabase(
  tables: [
    WorkoutDefinitions,
    MuscleGroups,
    Exercises,
    WorkoutExercises,
    WorkoutSessions,
    ExerciseEntries,
    SetEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  static final RegExp _nameCounterSuffixPattern = RegExp(r'^(.*) #(\d+)$');

  AppDatabase(super.executor);

  AppDatabase.open() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {},
        beforeOpen: (details) async {
          await _ensureSetValidatedAtColumn();
        },
      );

  static Future<void> wipeFile() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'gym_logbook.sqlite'));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _ensureSetValidatedAtColumn() async {
    try {
      await customStatement(
        "ALTER TABLE set_entries ADD COLUMN validated_at INTEGER NOT NULL DEFAULT (strftime('%s','now'))",
      );
    } catch (_) {
      // Column already exists on upgraded databases.
    }

    await customStatement(
      '''
UPDATE set_entries
SET validated_at = COALESCE(
  validated_at,
  (
    SELECT ws.performed_at
    FROM exercise_entries ee
    INNER JOIN workout_sessions ws ON ws.id = ee.workout_session_id
    WHERE ee.id = set_entries.exercise_entry_id
    LIMIT 1
  ),
  strftime('%s','now')
)
WHERE validated_at IS NULL;
''',
    );
  }

  Future<int> createWorkoutForMuscleGroup({
    required int muscleGroupId,
    required List<int> exerciseIds,
    String? nameOverride,
    DateTime? performedAt,
  }) async {
    return transaction(() async {
      final workoutDefinitionId =
          await _getOrCreateWorkoutDefinitionForMuscleGroup(muscleGroupId);
      final baseName = nameOverride?.trim();
      final resolvedBaseName =
          (baseName != null && baseName.isNotEmpty) ? baseName : null;
      final uniqueNameOverride = resolvedBaseName == null
          ? null
          : await _buildUniqueWorkoutSessionName(resolvedBaseName);

      await batch((batch) {
        batch.insertAll(
          workoutExercises,
          [
            for (var i = 0; i < exerciseIds.length; i++)
              WorkoutExercisesCompanion.insert(
                workoutDefinitionId: workoutDefinitionId,
                exerciseId: exerciseIds[i],
                sortOrder: Value(i),
              ),
          ],
          mode: InsertMode.insertOrIgnore,
        );
      });

      final workoutSessionId = await into(workoutSessions).insert(
        WorkoutSessionsCompanion.insert(
          workoutDefinitionId: Value(workoutDefinitionId),
          nameOverride: Value(uniqueNameOverride),
          performedAt: performedAt ?? DateTime.now(),
        ),
      );

      await batch((batch) {
        batch.insertAll(
          exerciseEntries,
          [
            for (var i = 0; i < exerciseIds.length; i++)
              ExerciseEntriesCompanion.insert(
                workoutSessionId: workoutSessionId,
                exerciseId: exerciseIds[i],
                sortOrder: Value(i),
              ),
          ],
        );
      });

      return workoutSessionId;
    });
  }

  Future<String> _buildUniqueWorkoutSessionName(String baseName) async {
    final normalizedBaseName = _stripCounterSuffix(baseName);
    final existingRows = await (select(workoutSessions)
          ..where((tbl) => tbl.nameOverride.like('$normalizedBaseName%')))
        .get();

    var hasBaseName = false;
    var highestCounter = 1;
    for (final row in existingRows) {
      final existingName = row.nameOverride?.trim();
      if (existingName == null || existingName.isEmpty) {
        continue;
      }
      if (existingName == normalizedBaseName) {
        hasBaseName = true;
        continue;
      }

      final match = _nameCounterSuffixPattern.firstMatch(existingName);
      if (match == null) {
        continue;
      }

      final suffixBaseName = match.group(1)?.trim();
      final suffixCounter = int.tryParse(match.group(2) ?? '');
      if (suffixBaseName == normalizedBaseName && suffixCounter != null) {
        if (suffixCounter > highestCounter) {
          highestCounter = suffixCounter;
        }
      }
    }

    if (!hasBaseName && highestCounter == 1) {
      return normalizedBaseName;
    }

    return '$normalizedBaseName #${highestCounter + 1}';
  }

  String _stripCounterSuffix(String name) {
    final trimmed = name.trim();
    final match = _nameCounterSuffixPattern.firstMatch(trimmed);
    if (match == null) {
      return trimmed;
    }

    final base = match.group(1)?.trim();
    return (base == null || base.isEmpty) ? trimmed : base;
  }

  Future<int> _getOrCreateWorkoutDefinitionForMuscleGroup(
    int muscleGroupId,
  ) async {
    final existingDefinition = await (select(workoutDefinitions)
          ..where((tbl) => tbl.muscleGroupId.equals(muscleGroupId))
          ..limit(1))
        .getSingleOrNull();

    if (existingDefinition != null) {
      return existingDefinition.id;
    }

    final muscleGroup = await (select(muscleGroups)
          ..where((tbl) => tbl.id.equals(muscleGroupId))
          ..limit(1))
        .getSingle();

    return into(workoutDefinitions).insert(
      WorkoutDefinitionsCompanion.insert(
        name: muscleGroup.name,
        muscleGroupId: Value(muscleGroupId),
        isCustom: const Value(false),
      ),
    );
  }

  Future<CurrentWorkoutSessionData> loadCurrentWorkoutSessionData(
    int workoutSessionId,
  ) async {
    final session = await (select(workoutSessions)
          ..where((tbl) => tbl.id.equals(workoutSessionId))
          ..limit(1))
        .getSingle();

    String workoutName = session.nameOverride?.trim() ?? '';
    if (workoutName.isEmpty && session.workoutDefinitionId != null) {
      final definition = await (select(workoutDefinitions)
            ..where((tbl) => tbl.id.equals(session.workoutDefinitionId!))
            ..limit(1))
          .getSingleOrNull();
      workoutName = definition?.name ?? '';
    }
    if (workoutName.isEmpty) {
      workoutName = 'Current Workout';
    }

    final entryRows = await (select(exerciseEntries).join([
      innerJoin(exercises, exercises.id.equalsExp(exerciseEntries.exerciseId)),
    ])
          ..where(exerciseEntries.workoutSessionId.equals(workoutSessionId))
          ..orderBy([
            OrderingTerm(expression: exerciseEntries.sortOrder),
            OrderingTerm(expression: exerciseEntries.id),
          ]))
        .get();

    final exercisesWithHistory = <CurrentWorkoutExerciseData>[];
    for (final row in entryRows) {
      final entry = row.readTable(exerciseEntries);
      final exercise = row.readTable(exercises);
      final lastPerformance = await fetchLastPerformanceForExercise(
        exercise.id,
        excludeWorkoutSessionId: workoutSessionId,
      );

      exercisesWithHistory.add(
        CurrentWorkoutExerciseData(
          exerciseEntryId: entry.id,
          exerciseId: exercise.id,
          exerciseName: exercise.name,
          savedSets: await _loadSavedSetsForExerciseEntry(entry.id),
          lastPerformedAt: lastPerformance?.performedAt,
          lastSetCount: lastPerformance?.setCount,
          lastMaxWeight: lastPerformance?.maxWeight,
        ),
      );
    }

    return CurrentWorkoutSessionData(
      workoutName: workoutName,
      exercises: exercisesWithHistory,
    );
  }

  Future<List<SavedExerciseSetData>> _loadSavedSetsForExerciseEntry(
    int exerciseEntryId,
  ) async {
    final rows = await (select(setEntries)
          ..where((tbl) => tbl.exerciseEntryId.equals(exerciseEntryId))
          ..orderBy([
            (tbl) => OrderingTerm(expression: tbl.setIndex),
            (tbl) => OrderingTerm(expression: tbl.id),
          ]))
        .get();

    return [
      for (final row in rows)
        SavedExerciseSetData(
          repetitions: row.repetitions,
          weight: row.weight,
        ),
    ];
  }

  Stream<List<UnfinishedWorkoutSessionSummary>> watchLatestUnfinishedWorkouts({
    int limit = 5,
  }) {
    final safeLimit = limit.clamp(1, 50).toInt();

    final query = customSelect(
      '''
SELECT
  ws.id AS workout_session_id,
  COALESCE(NULLIF(TRIM(ws.name_override), ''), wd.name, 'Current Workout') AS workout_name,
  ws.performed_at AS performed_at,
  SUM(CASE WHEN IFNULL(sc.set_count, 0) = 0 THEN 1 ELSE 0 END) AS unfinished_exercise_count
FROM workout_sessions ws
LEFT JOIN workout_definitions wd ON wd.id = ws.workout_definition_id
INNER JOIN exercise_entries ee ON ee.workout_session_id = ws.id
LEFT JOIN (
  SELECT exercise_entry_id, COUNT(*) AS set_count
  FROM set_entries
  GROUP BY exercise_entry_id
) sc ON sc.exercise_entry_id = ee.id
GROUP BY ws.id, ws.name_override, wd.name, ws.performed_at
HAVING SUM(CASE WHEN IFNULL(sc.set_count, 0) = 0 THEN 1 ELSE 0 END) > 0
ORDER BY ws.performed_at DESC, ws.id DESC
LIMIT ?
''',
      variables: [Variable<int>(safeLimit)],
      readsFrom: {workoutSessions, workoutDefinitions, exerciseEntries, setEntries},
    );

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => UnfinishedWorkoutSessionSummary(
                  workoutSessionId: row.read<int>('workout_session_id'),
                  workoutName: row.read<String>('workout_name'),
                  performedAt: row.read<DateTime>('performed_at'),
                  unfinishedExerciseCount:
                      row.read<int>('unfinished_exercise_count'),
                ),
              )
              .toList(growable: false),
        );
  }

  Stream<List<WorkoutHistoryListItem>> watchWorkoutsFromLastMonth() {
    final since = DateTime.now().subtract(const Duration(days: 30));

    final query = customSelect(
      '''
SELECT
  ws.id AS workout_session_id,
  date(ws.performed_at, 'unixepoch') AS day_key,
  COALESCE(NULLIF(TRIM(ws.name_override), ''), wd.name, 'Current Workout') AS workout_name,
  COALESCE(mg.name, 'Unknown') AS muscle_group_name,
  COUNT(DISTINCT ee.id) AS exercises_count,
  COALESCE(
    MAX(CAST(se.validated_at AS INTEGER)) - MIN(CAST(se.validated_at AS INTEGER)),
    0
  ) AS total_time_seconds
FROM workout_sessions ws
LEFT JOIN workout_definitions wd ON wd.id = ws.workout_definition_id
LEFT JOIN muscle_groups mg ON mg.id = wd.muscle_group_id
INNER JOIN exercise_entries ee ON ee.workout_session_id = ws.id
LEFT JOIN set_entries se ON se.exercise_entry_id = ee.id
WHERE ws.performed_at >= ?
GROUP BY ws.id, day_key, ws.name_override, wd.name, mg.name
ORDER BY day_key DESC, ws.performed_at DESC, ws.id DESC
''',
      variables: [Variable<DateTime>(since)],
      readsFrom: {
        workoutSessions,
        workoutDefinitions,
        muscleGroups,
        exerciseEntries,
        setEntries,
      },
    );

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => WorkoutHistoryListItem(
                  workoutSessionId: row.read<int>('workout_session_id'),
                  dayKey: row.read<String>('day_key'),
                  workoutName: row.read<String>('workout_name'),
                  muscleGroupName: row.read<String>('muscle_group_name'),
                  exercisesCount: row.read<int>('exercises_count'),
                  totalTimeSeconds: row.read<int>('total_time_seconds'),
                ),
              )
              .toList(growable: false),
        );
  }

  Stream<List<DailyExerciseEffort>> watchDailyAverageEffortForExercise(
    int exerciseId, {
    int historyDays = 30,
  }
  ) {
    final safeHistoryDays = historyDays.clamp(1, 365).toInt();
    final since = DateTime.now().subtract(Duration(days: safeHistoryDays - 1));

    final query = customSelect(
      '''
WITH per_workout AS (
  SELECT
    ws.id AS workout_session_id,
    date(ws.performed_at, 'unixepoch') AS day_key,
    SUM(se.weight * se.repetitions) / COUNT(se.id) AS workout_effort
  FROM workout_sessions ws
  INNER JOIN exercise_entries ee ON ee.workout_session_id = ws.id
  INNER JOIN set_entries se ON se.exercise_entry_id = ee.id
  WHERE ee.exercise_id = ?
    AND ws.performed_at >= ?
  GROUP BY ws.id, day_key
)
SELECT
  day_key,
  CAST(AVG(workout_effort) AS REAL) AS average_effort
FROM per_workout
GROUP BY day_key
ORDER BY day_key ASC
''',
      variables: [
        Variable<int>(exerciseId),
        Variable<DateTime>(since),
      ],
      readsFrom: {workoutSessions, exerciseEntries, setEntries},
    );

    return query.watch().map(
          (rows) => rows
              .map(
                (row) => DailyExerciseEffort(
                  dayKey: row.read<String>('day_key'),
                  averageEffort: row.read<double>('average_effort'),
                ),
              )
              .toList(growable: false),
        );
  }

  Future<ExerciseLastPerformanceData?> fetchLastPerformanceForExercise(
    int exerciseId, {
    int? excludeWorkoutSessionId,
  }) async {
    final latestEntryQuery = select(exerciseEntries).join([
      innerJoin(
        workoutSessions,
        workoutSessions.id.equalsExp(exerciseEntries.workoutSessionId),
      ),
    ])
      ..where(exerciseEntries.exerciseId.equals(exerciseId));

    if (excludeWorkoutSessionId != null) {
      latestEntryQuery.where(workoutSessions.id.isNotValue(excludeWorkoutSessionId));
    }

    latestEntryQuery
      ..orderBy([
        OrderingTerm(
          expression: workoutSessions.performedAt,
          mode: OrderingMode.desc,
        ),
        OrderingTerm(expression: exerciseEntries.id, mode: OrderingMode.desc),
      ])
      ..limit(1);

    final latestEntryRow = await latestEntryQuery.getSingleOrNull();
    if (latestEntryRow == null) {
      return null;
    }

    final latestEntry = latestEntryRow.readTable(exerciseEntries);
    final latestSession = latestEntryRow.readTable(workoutSessions);

    final setCountExpression = setEntries.id.count();
    final maxWeightExpression = setEntries.weight.max();
    final aggregateRow = await (selectOnly(setEntries)
          ..addColumns([setCountExpression, maxWeightExpression])
          ..where(setEntries.exerciseEntryId.equals(latestEntry.id)))
        .getSingle();

    final setCount = aggregateRow.read(setCountExpression);
    final maxWeight = aggregateRow.read(maxWeightExpression);
    if (setCount == null || maxWeight == null || setCount <= 0) {
      return null;
    }

    return ExerciseLastPerformanceData(
      performedAt: latestSession.performedAt,
      setCount: setCount,
      maxWeight: maxWeight,
    );
  }

  Future<void> addSetForExerciseEntry({
    required int exerciseEntryId,
    required int repetitions,
    required double weight,
  }) async {
    final maxSetIndexExpression = setEntries.setIndex.max();
    final maxSetIndexRow = await (selectOnly(setEntries)
          ..addColumns([maxSetIndexExpression])
          ..where(setEntries.exerciseEntryId.equals(exerciseEntryId)))
        .getSingle();
    final maxSetIndex = maxSetIndexRow.read(maxSetIndexExpression);

    await into(setEntries).insert(
      SetEntriesCompanion.insert(
        exerciseEntryId: exerciseEntryId,
        setIndex: Value((maxSetIndex ?? -1) + 1),
        weight: Value(weight),
        repetitions: Value(repetitions),
      ),
    );
  }

  Future<bool> deleteWorkoutSessionIfEmpty(int workoutSessionId) async {
    return transaction(() async {
      final sessionExists = await (select(workoutSessions)
            ..where((tbl) => tbl.id.equals(workoutSessionId))
            ..limit(1))
          .getSingleOrNull();
      if (sessionExists == null) {
        return false;
      }

      final hasAnySet = await (select(setEntries).join([
        innerJoin(
          exerciseEntries,
          exerciseEntries.id.equalsExp(setEntries.exerciseEntryId),
        ),
      ])
            ..where(exerciseEntries.workoutSessionId.equals(workoutSessionId))
            ..limit(1))
          .getSingleOrNull();

      if (hasAnySet != null) {
        return false;
      }

      await (delete(exerciseEntries)
            ..where((tbl) => tbl.workoutSessionId.equals(workoutSessionId)))
          .go();
      await (delete(workoutSessions)..where((tbl) => tbl.id.equals(workoutSessionId)))
          .go();
      return true;
    });
  }
}
