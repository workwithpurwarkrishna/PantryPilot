import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';

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
                child: Text(_thought!, style: Theme.of(context).textTheme.titleMedium),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _dishes.length,
                itemBuilder: (context, index) {
                  final dish = _dishes[index];
                  return Card(
                    child: ListTile(
                      title: Text(dish['name'] as String? ?? 'Dish'),
                      subtitle: Text(
                        'Match: ${dish['match_score']} • Time: ${dish['cooking_time']}',
                      ),
                    ),
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
