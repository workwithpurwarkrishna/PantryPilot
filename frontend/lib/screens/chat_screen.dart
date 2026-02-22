import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/recipe_card.dart';
import 'recipe_assistant_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _budgetController = TextEditingController();
  final _peopleController = TextEditingController();
  final _maxTimeController = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _thought;
  String? _lastQuery;
  List<Map<String, dynamic>> _dishes = [];

  @override
  void dispose() {
    _controller.dispose();
    _budgetController.dispose();
    _peopleController.dispose();
    _maxTimeController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final token = ref.read(currentSessionProvider)?.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'You must be logged in';
      });
      return;
    }

    final groqKey = await ref.read(groqApiKeyProvider.future);
    final budget = _budgetController.text.trim();
    final peopleInput = _peopleController.text.trim();
    final maxTimeInput = _maxTimeController.text.trim();
    final peopleCount = peopleInput.isEmpty ? null : int.tryParse(peopleInput);
    final maxTimeMinutes = maxTimeInput.isEmpty ? null : int.tryParse(maxTimeInput);
    if (peopleInput.isNotEmpty && (peopleCount == null || peopleCount < 1)) {
      setState(() {
        _error = 'People count must be a valid number (1 or more)';
      });
      return;
    }
    if (maxTimeInput.isNotEmpty && (maxTimeMinutes == null || maxTimeMinutes < 1)) {
      setState(() {
        _error = 'Max time must be a valid number of minutes (1 or more)';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ref.read(apiClientProvider).sendMessage(
            text: text,
            accessToken: token,
            groqApiKey: groqKey,
            extraBudgetInr: budget.isEmpty ? null : budget,
            peopleCount: peopleCount,
            maxTimeMinutes: maxTimeMinutes,
          );
      if (!mounted) return;
      setState(() {
        _thought = result['thought'] as String?;
        _lastQuery = text;
        _dishes = (result['dishes'] as List<dynamic>).cast<Map<String, dynamic>>();
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

  void _openRecipeAssistant(Map<String, dynamic> dish) {
    final dishName = (dish['name'] ?? 'Dish').toString();
    final peopleCount = int.tryParse(_peopleController.text.trim());
    final maxTimeMinutes = int.tryParse(_maxTimeController.text.trim());
    final budget = _budgetController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeAssistantScreen(
          dishName: dishName,
          sourceQuery: _lastQuery,
          peopleCount: peopleCount,
          maxTimeMinutes: maxTimeMinutes,
          extraBudgetInr: budget.isEmpty ? null : budget,
          dishCardSnapshot: dish,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('The Chef')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Ask for recipe suggestions...',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _budgetController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Extra Budget (INR) - optional',
                          prefixText: '₹ ',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 132,
                      child: TextField(
                        controller: _maxTimeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Max Time (min)',
                          hintText: 'e.g. 30',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 132,
                      child: TextField(
                        controller: _peopleController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'People',
                          hintText: 'e.g. 4',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _loading ? null : _send,
                      child: const Text('Send'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (_thought != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _thought!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _dishes.length,
                itemBuilder: (context, index) {
                  final dish = _dishes[index];
                  final dishName = (dish['name'] ?? 'Dish').toString();
                  return RecipeCard(
                    name: dishName,
                    matchScore: (dish['match_score'] as num?)?.toInt() ?? 0,
                    cookingTime: (dish['cooking_time'] ?? 'N/A').toString(),
                    missingItems: (dish['missing_items'] as List<dynamic>? ?? [])
                        .cast<Map<String, dynamic>>(),
                    onViewRecipe: () => _openRecipeAssistant(dish),
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
