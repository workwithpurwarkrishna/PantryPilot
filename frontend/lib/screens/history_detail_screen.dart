import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';

class HistoryDetailScreen extends ConsumerStatefulWidget {
  const HistoryDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  ConsumerState<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends ConsumerState<HistoryDetailScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _session;
  List<Map<String, dynamic>> _followups = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final token = ref.read(currentSessionProvider)?.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'You must be logged in';
      });
      return;
    }
    try {
      final payload = await ref.read(apiClientProvider).getHistoryDetail(
            accessToken: token,
            sessionId: widget.sessionId,
          );
      if (!mounted) return;
      setState(() {
        _session = (payload['session'] as Map<String, dynamic>? ?? {});
        _followups = (payload['followups'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final recipeSnapshot = session?['recipe_snapshot'];
    final recipe = recipeSnapshot is Map<String, dynamic> ? recipeSnapshot : null;
    final ingredients =
        (recipe?['ingredients'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final steps = (recipe?['steps'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final tips = (recipe?['chef_tips'] as List<dynamic>? ?? []).cast<dynamic>();
    return Scaffold(
      appBar: AppBar(title: const Text('Cook History')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (session?['dish_name'] ?? 'Dish').toString(),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text((session?['cooked_at_ist'] ?? '').toString()),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (session?['people_count'] != null)
                                  Chip(label: Text('People: ${session?['people_count']}')),
                                if ((session?['extra_budget_inr'] ?? '').toString().isNotEmpty)
                                  Chip(label: Text('Budget: ₹${session?['extra_budget_inr']}')),
                                if (session?['max_time_minutes'] != null)
                                  Chip(label: Text('Max: ${session?['max_time_minutes']}m')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (recipe != null) ...[
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recipe Snapshot',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text((recipe['title'] ?? session?['dish_name'] ?? 'Recipe').toString()),
                              const SizedBox(height: 6),
                              Text((recipe['description'] ?? '').toString()),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  Chip(label: Text('Prep ${recipe['prep_time_minutes'] ?? 0}m')),
                                  Chip(label: Text('Cook ${recipe['cook_time_minutes'] ?? 0}m')),
                                  Chip(label: Text('Serves ${recipe['servings'] ?? 1}')),
                                  Chip(label: Text('${recipe['difficulty'] ?? 'Easy'}')),
                                  if (recipe['calories_per_serving'] != null)
                                    Chip(label: Text('${recipe['calories_per_serving']} kcal')),
                                ],
                              ),
                              if (ingredients.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text('Ingredients', style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 4),
                                ...ingredients.map((item) {
                                  final name = (item['name'] ?? 'Ingredient').toString();
                                  final quantity = (item['quantity'] ?? '').toString();
                                  final notes = (item['notes'] ?? '').toString();
                                  final base = quantity.isEmpty ? name : '$name ($quantity)';
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      notes.isEmpty ? '• $base' : '• $base - $notes',
                                    ),
                                  );
                                }),
                              ],
                              if (steps.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text('Steps', style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 4),
                                ...steps.map((step) {
                                  final stepNo = step['step_number'];
                                  final instruction = (step['instruction'] ?? '').toString();
                                  final timer = step['timer_seconds'];
                                  final timerText =
                                      timer == null ? '' : ' (${timer.toString()}s)';
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text('• Step ${stepNo ?? ''}: $instruction$timerText'),
                                  );
                                }),
                              ],
                              if (tips.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text('Chef Tips', style: Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 4),
                                ...tips.map(
                                  (tip) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text('• ${tip.toString()}'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text('Follow-up Chat', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (_followups.isEmpty)
                      const Text('No follow-up questions were asked.')
                    else
                      ..._followups.map(
                        (item) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You: ${(item['question'] ?? '').toString()}',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                Text((item['answer'] ?? '').toString()),
                                const SizedBox(height: 6),
                                Text(
                                  (item['created_at_ist'] ?? '').toString(),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }
}
