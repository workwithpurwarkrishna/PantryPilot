import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/recipe_card.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _thought;
  List<Map<String, dynamic>> _dishes = [];

  @override
  void dispose() {
    _controller.dispose();
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

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ref.read(apiClientProvider).sendMessage(
            text: text,
            accessToken: token,
            groqApiKey: groqKey,
          );
      if (!mounted) return;
      setState(() {
        _thought = result['thought'] as String?;
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

  Future<void> _openRecipeAssistant(String dishName) async {
    final token = ref.read(currentSessionProvider)?.accessToken;
    if (token == null || token.isEmpty) return;

    final groqKey = await ref.read(groqApiKeyProvider.future);
    final followupController = TextEditingController();
    final answers = <String>[];
    var busy = true;

    try {
      final initial = await ref.read(apiClientProvider).getRecipeAssistantAnswer(
            accessToken: token,
            dishName: dishName,
            groqApiKey: groqKey,
          );
      answers.add(initial);
      busy = false;
    } catch (e) {
      answers.add('Failed to generate recipe: $e');
      busy = false;
    }

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> askMore() async {
              final q = followupController.text.trim();
              if (q.isEmpty || busy) return;
              setModalState(() => busy = true);
              try {
                final response = await ref.read(apiClientProvider).getRecipeAssistantAnswer(
                      accessToken: token,
                      dishName: dishName,
                      question: q,
                      groqApiKey: groqKey,
                    );
                if (!context.mounted) return;
                setModalState(() {
                  answers.add('Q: $q');
                  answers.add(response);
                  followupController.clear();
                });
              } catch (e) {
                if (!context.mounted) return;
                setModalState(() {
                  answers.add('Failed: $e');
                });
              } finally {
                if (context.mounted) {
                  setModalState(() => busy = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.78,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dishName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        itemCount: answers.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(answers[index]),
                        ),
                      ),
                    ),
                    if (busy) const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: followupController,
                            decoration: const InputDecoration(
                              hintText: 'Ask more about this recipe...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: busy ? null : askMore,
                          child: const Text('Ask'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    followupController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('The Chef')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask for recipe suggestions...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _send,
                  child: const Text('Send'),
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
                    onViewRecipe: () => _openRecipeAssistant(dishName),
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
