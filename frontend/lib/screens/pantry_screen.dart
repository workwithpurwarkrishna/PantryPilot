import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_provider.dart';
import '../providers/auth_provider.dart';

class PantryScreen extends ConsumerStatefulWidget {
  const PantryScreen({super.key});

  @override
  ConsumerState<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends ConsumerState<PantryScreen> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadPantry);
  }

  Future<void> _loadPantry() async {
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
      final items = await ref.read(apiClientProvider).getPantry(accessToken: token);
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

  Future<void> _toggle(Map<String, dynamic> item, bool value) async {
    final token = ref.read(currentSessionProvider)?.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'You must be logged in';
      });
      return;
    }

    try {
      final updated = await ref.read(apiClientProvider).togglePantryItem(
            accessToken: token,
            ingredientId: item['ingredient_id'] as int,
            status: value,
          );
      if (!mounted) return;
      setState(() {
        _items = updated;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('The Kitchen'),
        actions: [
          IconButton(onPressed: _loadPantry, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final inStock = item['is_in_stock'] as bool? ?? false;
                    return SwitchListTile(
                      title: Text(item['name'] as String? ?? 'Unknown'),
                      subtitle: Text(
                        '${item['category']} • ${item['default_unit']}',
                      ),
                      value: inStock,
                      onChanged: (value) => _toggle(item, value),
                    );
                  },
                ),
    );
  }
}
