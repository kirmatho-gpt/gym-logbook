import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/repositories/exercise_repository.dart';
import 'package:drift/drift.dart' as drift;

class DebugDatabaseScreen extends StatefulWidget {
  const DebugDatabaseScreen({
    super.key,
    required this.exerciseRepository,
  });

  final ExerciseRepository exerciseRepository;

  @override
  State<DebugDatabaseScreen> createState() => _DebugDatabaseScreenState();
}

class _DebugDatabaseScreenState extends State<DebugDatabaseScreen> {
  final TextEditingController _muscleGroupNameController =
      TextEditingController();
  final TextEditingController _exerciseNameController = TextEditingController();
  final TextEditingController _exerciseMuscleGroupIdController =
      TextEditingController();
  final TextEditingController _exerciseNotesController =
      TextEditingController();
  final TextEditingController _exerciseCreatedAtController =
      TextEditingController();

  _DebugTable _selectedTable = _DebugTable.muscleGroups;

  @override
  void initState() {
    super.initState();
    _exerciseCreatedAtController.text = DateTime.now().toIso8601String();
  }

  @override
  void dispose() {
    _muscleGroupNameController.dispose();
    _exerciseNameController.dispose();
    _exerciseMuscleGroupIdController.dispose();
    _exerciseNotesController.dispose();
    _exerciseCreatedAtController.dispose();
    super.dispose();
  }

  AppDatabase get _database => widget.exerciseRepository.database;

  Future<void> _insertMuscleGroup() async {
    final name = _muscleGroupNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a muscle group name first.')),
      );
      return;
    }

    await _database.into(_database.muscleGroups).insert(
          MuscleGroupsCompanion.insert(name: name),
        );
    _muscleGroupNameController.clear();
  }

  Future<void> _insertExercise() async {
    final name = _exerciseNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an exercise name first.')),
      );
      return;
    }

    final muscleGroupIdText = _exerciseMuscleGroupIdController.text.trim();
    final int? muscleGroupId = muscleGroupIdText.isEmpty
        ? null
        : int.tryParse(muscleGroupIdText);
    if (muscleGroupIdText.isNotEmpty && muscleGroupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Muscle group id must be a valid integer.'),
        ),
      );
      return;
    }

    final createdAtText = _exerciseCreatedAtController.text.trim();
    DateTime? createdAt;
    if (createdAtText.isNotEmpty) {
      createdAt = DateTime.tryParse(createdAtText);
      if (createdAt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Created at must be an ISO-8601 datetime.'),
          ),
        );
        return;
      }
    }

    await _database.into(_database.exercises).insert(
          ExercisesCompanion.insert(
            name: name,
            muscleGroupId: drift.Value(muscleGroupId),
            notes: drift.Value(_exerciseNotesController.text.trim().isEmpty
                ? null
                : _exerciseNotesController.text.trim()),
            createdAt:
                createdAt == null ? const drift.Value.absent() : drift.Value(createdAt),
          ),
        );

    _exerciseNameController.clear();
    _exerciseMuscleGroupIdController.clear();
    _exerciseNotesController.clear();
    _exerciseCreatedAtController.text = DateTime.now().toIso8601String();
  }

  Future<void> _wipeDatabase() async {
    final shouldWipe = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Wipe database?'),
        content: const Text(
          'This will delete the local database file. You will need to restart the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Wipe'),
          ),
        ],
      ),
    );

    if (shouldWipe != true) {
      return;
    }

    await _database.close();
    await AppDatabase.wipeFile();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Database wiped. Restart the app.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Database'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<_DebugTable>(
              value: _selectedTable,
              items: const [
                DropdownMenuItem(
                  value: _DebugTable.muscleGroups,
                  child: Text('Muscle groups'),
                ),
                DropdownMenuItem(
                  value: _DebugTable.exercises,
                  child: Text('Exercises'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedTable = value;
                });
              },
              decoration: const InputDecoration(
                labelText: 'Table to populate',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedTable == _DebugTable.muscleGroups) ...[
              TextField(
                controller: _muscleGroupNameController,
                decoration: const InputDecoration(
                  labelText: 'Muscle group name',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _insertMuscleGroup(),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _insertMuscleGroup,
                icon: const Icon(Icons.add),
                label: const Text('Insert muscle group'),
              ),
            ] else ...[
              TextField(
                controller: _exerciseNameController,
                decoration: const InputDecoration(
                  labelText: 'Exercise name',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _exerciseMuscleGroupIdController,
                decoration: const InputDecoration(
                  labelText: 'Muscle group id',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _exerciseNotesController,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _exerciseCreatedAtController,
                decoration: const InputDecoration(
                  labelText: 'Created at (ISO-8601)',
                  border: OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _insertExercise(),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _insertExercise,
                icon: const Icon(Icons.add),
                label: const Text('Insert exercise'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: _wipeDatabase,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Wipe database'),
            ),
            const SizedBox(height: 24),
            Text(
              _selectedTable == _DebugTable.muscleGroups
                  ? 'Saved muscle groups'
                  : 'Saved exercises',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _selectedTable == _DebugTable.muscleGroups
                  ? StreamBuilder<List<MuscleGroup>>(
                      stream: _database.select(_database.muscleGroups).watch(),
                      builder: (context, snapshot) {
                        final muscleGroups = snapshot.data ?? [];
                        if (snapshot.connectionState ==
                                ConnectionState.waiting &&
                            muscleGroups.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (muscleGroups.isEmpty) {
                          return const Center(
                            child: Text('No muscle groups yet. Add one above.'),
                          );
                        }

                        return ListView.separated(
                          itemCount: muscleGroups.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final muscleGroup = muscleGroups[index];
                            return ListTile(
                              title: Text(muscleGroup.name),
                              subtitle: Text('ID: ${muscleGroup.id}'),
                            );
                          },
                        );
                      },
                    )
                  : StreamBuilder<List<Exercise>>(
                      stream: widget.exerciseRepository.watchExercises(),
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
                            child: Text('No exercises yet. Add one above.'),
                          );
                        }

                        return ListView.separated(
                          itemCount: exercises.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final exercise = exercises[index];
                            final subtitleLines = [
                              'ID: ${exercise.id}',
                              if (exercise.muscleGroupId != null)
                                'Muscle group id: ${exercise.muscleGroupId}',
                              if ((exercise.notes ?? '').isNotEmpty)
                                'Notes: ${exercise.notes}',
                              'Created at: ${exercise.createdAt.toIso8601String()}',
                            ];

                            return ListTile(
                              title: Text(exercise.name),
                              subtitle: Text(subtitleLines.join('\n')),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DebugTable {
  muscleGroups,
  exercises,
}
