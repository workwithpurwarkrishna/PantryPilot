import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadHistory);
  }

  Future<void> _loadHistory() async {
    final token = ref.read(currentSessionProvider)?.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'You must be logged in';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(apiClientProvider).getHistory(accessToken: token);
      if (!mounted) return;
      setState(() {
        _items = items;
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
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(onPressed: _loadHistory, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
              : _items.isEmpty
                  ? const Center(child: Text('No dishes cooked yet'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final dish = (item['dish_name'] ?? 'Dish').toString();
                        final day = (item['cooked_day_ist'] ?? '').toString();
                        final date = (item['cooked_date_ist'] ?? '').toString();
                        final time = (item['cooked_time_ist'] ?? '').toString();
                        final people = item['people_count'];
                        final budget = (item['extra_budget_inr'] ?? '').toString();
                        final maxTime = item['max_time_minutes'];
                        return Card(
                          child: ListTile(
                            title: Text(dish),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('$day • $date • $time'),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (people != null) Chip(label: Text('People: $people')),
                                    if (budget.isNotEmpty) Chip(label: Text('Budget: ₹$budget')),
                                    if (maxTime != null) Chip(label: Text('Max: ${maxTime}m')),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () {
                              final id = (item['id'] ?? '').toString();
                              if (id.isEmpty) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => HistoryDetailScreen(sessionId: id),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
    );
  }
}
