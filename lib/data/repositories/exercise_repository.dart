import 'package:drift/drift.dart';

import '../app_database.dart';

class ExerciseRepository {
  ExerciseRepository(this.database);

  final AppDatabase database;

  Future<int> createExercise({
    required String name,
    int? muscleGroupId,
    String? notes,
  }) {
    return database.into(database.exercises).insert(
          ExercisesCompanion.insert(
            name: name,
            muscleGroupId: Value(muscleGroupId),
            notes: Value(notes),
          ),
        );
  }

  Stream<List<Exercise>> watchExercises() {
    return database.select(database.exercises).watch();
  }

  Future<List<Exercise>> fetchExercises() {
    return database.select(database.exercises).get();
  }
}
