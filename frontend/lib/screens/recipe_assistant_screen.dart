import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class RecipeAssistantScreen extends ConsumerStatefulWidget {
  const RecipeAssistantScreen({
    super.key,
    required this.dishName,
    this.sourceQuery,
    this.peopleCount,
    this.extraBudgetInr,
    this.maxTimeMinutes,
    this.dishCardSnapshot,
  });

  final String dishName;
  final String? sourceQuery;
  final int? peopleCount;
  final String? extraBudgetInr;
  final int? maxTimeMinutes;
  final Map<String, dynamic>? dishCardSnapshot;

  @override
  ConsumerState<RecipeAssistantScreen> createState() => _RecipeAssistantScreenState();
}

class _RecipeAssistantScreenState extends ConsumerState<RecipeAssistantScreen> {
  final _controller = TextEditingController();
  final List<_RecipeMessage> _messages = [];
  final Set<int> _checkedIngredients = <int>{};
  final Set<int> _checkedSteps = <int>{};
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _recipe;
  Timer? _timer;
  int? _remainingSeconds;
  int? _activeTimerStepIndex;
  bool _isTimerPaused = false;
  String? _historySessionId;
  bool _savingHistory = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadInitialRecipe);
  }

  @override
  void dispose() {
    _stopTimer();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadInitialRecipe() async {
    final token = ref.read(currentSessionProvider)?.accessToken;
    final groqKey = await ref.read(groqApiKeyProvider.future);
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'You must be logged in';
      });
      return;
    }

    try {
      final data = await ref.read(apiClientProvider).getRecipeAssistant(
            accessToken: token,
            dishName: widget.dishName,
            groqApiKey: groqKey,
            sessionId: _historySessionId,
          );
      if (!mounted) return;

      setState(() {
        final recipe = data['recipe'];
        if (recipe is Map<String, dynamic>) {
          _recipe = recipe;
        }
        final answer = (data['answer'] ?? '').toString();
        if (answer.isNotEmpty) {
          _messages.add(_RecipeMessage(role: _MsgRole.assistant, text: answer));
        }
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

  Future<void> _askFollowup() async {
    final q = _controller.text.trim();
    if (q.isEmpty || _loading) return;

    final token = ref.read(currentSessionProvider)?.accessToken;
    final groqKey = await ref.read(groqApiKeyProvider.future);
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'You must be logged in';
      });
      return;
    }

    setState(() {
      _messages.add(_RecipeMessage(role: _MsgRole.user, text: q));
      _controller.clear();
      _loading = true;
      _error = null;
    });

    try {
      final data = await ref.read(apiClientProvider).getRecipeAssistant(
            accessToken: token,
            dishName: widget.dishName,
            question: q,
            groqApiKey: groqKey,
            sessionId: _historySessionId,
          );
      if (!mounted) return;

      setState(() {
        final answer = (data['answer'] ?? '').toString();
        if (answer.isNotEmpty) {
          _messages.add(_RecipeMessage(role: _MsgRole.assistant, text: answer));
        }
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

  void _startTimer(int stepIndex, int seconds) {
    _timer?.cancel();
    setState(() {
      _activeTimerStepIndex = stepIndex;
      _remainingSeconds = seconds;
      _isTimerPaused = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if ((_remainingSeconds ?? 0) <= 1) {
        timer.cancel();
        setState(() {
          _activeTimerStepIndex = null;
          _remainingSeconds = 0;
          _isTimerPaused = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Step timer finished')),
        );
      } else {
        setState(() {
          _remainingSeconds = (_remainingSeconds ?? 1) - 1;
        });
      }
    });
  }

  void _pauseTimer() {
    if (_timer == null || _isTimerPaused) return;
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    setState(() {
      _isTimerPaused = true;
    });
  }

  void _resumeTimer() {
    final stepIndex = _activeTimerStepIndex;
    final seconds = _remainingSeconds;
    if (stepIndex == null || seconds == null || seconds <= 0 || !_isTimerPaused) return;
    _startTimer(stepIndex, seconds);
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    setState(() {
      _activeTimerStepIndex = null;
      _remainingSeconds = null;
      _isTimerPaused = false;
    });
  }

  Future<void> _markAsCooked() async {
    if (_savingHistory || _historySessionId != null) return;
    final token = ref.read(currentSessionProvider)?.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'You must be logged in';
      });
      return;
    }

    setState(() {
      _savingHistory = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).createCookedHistory(
            accessToken: token,
            dishName: widget.dishName,
            sourceQuery: widget.sourceQuery,
            peopleCount: widget.peopleCount,
            extraBudgetInr: widget.extraBudgetInr,
            maxTimeMinutes: widget.maxTimeMinutes,
            recipeSnapshot: _recipe,
            dishCardSnapshot: widget.dishCardSnapshot,
          );
      if (!mounted) return;
      setState(() {
        _historySessionId = (response['id'] ?? '').toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved in history')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _savingHistory = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ingredients = (_recipe?['ingredients'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final steps = (_recipe?['steps'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final tips = (_recipe?['chef_tips'] as List<dynamic>? ?? []).cast<dynamic>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.dishName)),
      body: _loading && _recipe == null && _messages.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (_recipe != null) ...[
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (_recipe?['title'] ?? widget.dishName).toString(),
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 6),
                                Text((_recipe?['description'] ?? '').toString()),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    Chip(label: Text('Prep ${_recipe?['prep_time_minutes'] ?? 0}m')),
                                    Chip(label: Text('Cook ${_recipe?['cook_time_minutes'] ?? 0}m')),
                                    Chip(label: Text('Serves ${_recipe?['servings'] ?? 1}')),
                                    Chip(label: Text('${_recipe?['difficulty'] ?? 'Easy'}')),
                                    if (_recipe?['calories_per_serving'] != null)
                                      Chip(label: Text('${_recipe?['calories_per_serving']} kcal')),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    FilledButton.icon(
                                      onPressed: _savingHistory || _historySessionId != null
                                          ? null
                                          : _markAsCooked,
                                      icon: const Icon(Icons.check_circle_outline),
                                      label: Text(
                                        _historySessionId == null
                                            ? 'Mark as Cooked'
                                            : 'Saved to History',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text('Ingredients', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        ...List.generate(ingredients.length, (index) {
                          final item = ingredients[index];
                          final qty = (item['quantity'] ?? '').toString();
                          final notes = (item['notes'] ?? '').toString();
                          return CheckboxListTile(
                            value: _checkedIngredients.contains(index),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _checkedIngredients.add(index);
                                } else {
                                  _checkedIngredients.remove(index);
                                }
                              });
                            },
                            title: Text('${item['name'] ?? 'Ingredient'} ($qty)'),
                            subtitle: notes.isEmpty ? null : Text(notes),
                            contentPadding: EdgeInsets.zero,
                          );
                        }),
                        const SizedBox(height: 10),
                        Text('Steps', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        ...List.generate(steps.length, (index) {
                          final step = steps[index];
                          final timerSeconds = (step['timer_seconds'] as num?)?.toInt();
                          final isActiveTimerStep = _activeTimerStepIndex == index;
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: _checkedSteps.contains(index),
                                        onChanged: (v) {
                                          setState(() {
                                            if (v == true) {
                                              _checkedSteps.add(index);
                                            } else {
                                              _checkedSteps.remove(index);
                                            }
                                          });
                                        },
                                      ),
                                      Expanded(
                                        child: Text(
                                          'Step ${step['step_number'] ?? (index + 1)}',
                                          style: Theme.of(context).textTheme.titleSmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text((step['instruction'] ?? '').toString()),
                                  if (timerSeconds != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: _loading
                                              ? null
                                              : () => _startTimer(index, timerSeconds),
                                          icon: const Icon(Icons.timer),
                                          label: Text('Start ${timerSeconds}s Timer'),
                                        ),
                                        if (isActiveTimerStep && _remainingSeconds != null)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 10),
                                            child: Text(
                                              _isTimerPaused
                                                  ? 'Paused at $_remainingSeconds s'
                                                  : '$_remainingSeconds s left',
                                            ),
                                          ),
                                        if (isActiveTimerStep && _remainingSeconds != null)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8),
                                            child: TextButton(
                                              onPressed: _isTimerPaused ? _resumeTimer : _pauseTimer,
                                              child: Text(_isTimerPaused ? 'Resume' : 'Pause'),
                                            ),
                                          ),
                                        if (isActiveTimerStep && _remainingSeconds != null)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8),
                                            child: TextButton(
                                              onPressed: _stopTimer,
                                              child: const Text('Stop'),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                        if (tips.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Chef Tips',
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 6),
                                  ...tips.map(
                                    (t) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Text('• ${t.toString()}'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                      Text('Recipe Chat', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      ..._messages.map((msg) {
                        final isUser = msg.role == _MsgRole.user;
                        return Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.78,
                            ),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SelectableText(msg.text),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Ask more about this recipe...',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _askFollowup(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _loading ? null : _askFollowup,
                        child: const Text('Ask'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

enum _MsgRole { user, assistant }

class _RecipeMessage {
  const _RecipeMessage({required this.role, required this.text});

  final _MsgRole role;
  final String text;
}
