import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../data/repository_provider.dart';

/// The 18-hole **yardage** editor for one of a course's yardage sets (#36).
/// Pushed from the [CourseHolesScreen] sets list. The rows seed once from
/// [courseSetYardsStreamProvider]; **Save** rewrites the whole card via
/// `replaceCourseSetYards`. Par and stroke index live on the course (shared
/// across sets), so this screen is yards-only.
class CourseSetYardsScreen extends ConsumerStatefulWidget {
  const CourseSetYardsScreen({
    super.key,
    required this.setId,
    required this.setName,
  });

  final int setId;
  final String setName;

  @override
  ConsumerState<CourseSetYardsScreen> createState() =>
      _CourseSetYardsScreenState();
}

class _CourseSetYardsScreenState extends ConsumerState<CourseSetYardsScreen> {
  static const int _holeCount = 18;

  // Read directly on save; the text fields own their display state.
  final List<int> _yards = List<int>.filled(_holeCount, 0);
  bool _seeded = false;
  bool _saving = false;

  void _seedFromYards(List<CourseSetYard> yards) {
    final byHole = {for (final y in yards) y.holeNumber: y.yards};
    for (var i = 0; i < _holeCount; i++) {
      _yards[i] = byHole[i + 1] ?? 0;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final rows = [
      for (var i = 0; i < _holeCount; i++)
        CourseSetYardsCompanion.insert(
          courseSetId: widget.setId,
          holeNumber: i + 1,
          yards: _yards[i],
        ),
    ];
    try {
      await ref.read(repositoryProvider).replaceCourseSetYards(widget.setId, rows);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Yardages saved'),
          duration: Duration(seconds: 1),
        ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save yardages: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.setName, overflow: TextOverflow.ellipsis),
            Text(
              'Yardages',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('save_set_yards'),
        onPressed: _saving ? null : _save,
        icon: const Icon(Icons.save),
        label: const Text('Save yardages'),
      ),
      body: ref.watch(courseSetYardsStreamProvider(widget.setId)).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Failed to load yardages: $e')),
            data: (yards) {
              if (!_seeded) {
                _seedFromYards(yards);
                _seeded = true;
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                itemCount: _holeCount,
                itemBuilder: (context, i) {
                  final hole = i + 1;
                  return Card(
                    key: ValueKey('set_yards_row_$hole'),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              '$hole',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              key: ValueKey('set_yards_$hole'),
                              initialValue:
                                  _yards[i] == 0 ? '' : _yards[i].toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Yards',
                                isDense: true,
                                suffixText: 'yds',
                              ),
                              onChanged: (v) =>
                                  _yards[i] = (int.tryParse(v) ?? 0).clamp(0, 100000),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
    );
  }
}
