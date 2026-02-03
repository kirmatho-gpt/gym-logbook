import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../data/repositories/exercise_repository.dart';

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
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _insertExercise() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an exercise name first.')),
      );
      return;
    }

    await widget.exerciseRepository.createExercise(name: name);
    _nameController.clear();
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
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Exercise name',
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
            const SizedBox(height: 24),
            Text(
              'Saved exercises',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: StreamBuilder<List<Exercise>>(
                stream: widget.exerciseRepository.watchExercises(),
                builder: (context, snapshot) {
                  final exercises = snapshot.data ?? [];
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      exercises.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (exercises.isEmpty) {
                    return const Center(
                      child: Text('No exercises yet. Add one above.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: exercises.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final exercise = exercises[index];
                      return ListTile(
                        title: Text(exercise.name),
                        subtitle: Text('ID: ${exercise.id}'),
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
