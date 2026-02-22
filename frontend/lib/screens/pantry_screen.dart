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
  static const _categories = <String>[
    'Vegetables',
    'Fruits',
    'Grains & Cereals',
    'Dairy',
    'Proteins',
    'Spices & Seasonings',
    'Oils',
    'Sauces',
    'Others',
  ];

  final _searchController = TextEditingController();
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadPantry);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
            sendQuantity: false,
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

  Future<void> _editPantryItem(Map<String, dynamic> item) async {
    final token = ref.read(currentSessionProvider)?.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'You must be logged in';
      });
      return;
    }

    bool inStock = item['is_in_stock'] as bool? ?? false;
    final quantityController = TextEditingController(text: (item['quantity'] ?? '').toString());

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Edit ${item['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('In stock'),
                  const Spacer(),
                  StatefulBuilder(
                    builder: (context, setDialogState) => Switch(
                      value: inStock,
                      onChanged: (value) {
                        setDialogState(() {
                          inStock = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity (e.g. 1 kg)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (saved != true) return;

      final updated = await ref.read(apiClientProvider).togglePantryItem(
            accessToken: token,
            ingredientId: item['ingredient_id'] as int,
            status: inStock,
            quantity: quantityController.text.trim(),
            sendQuantity: true,
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
    } finally {
      quantityController.dispose();
    }
  }

  Future<void> _showAddIngredientDialog() async {
    final token = ref.read(currentSessionProvider)?.accessToken;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'You must be logged in';
      });
      return;
    }

    final nameController = TextEditingController();
    final unitController = TextEditingController();
    String selectedCategory = _categories.first;

    try {
      final created = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (context) {
          final bottom = MediaQuery.of(context).viewInsets.bottom;
          return StatefulBuilder(
            builder: (context, setSheetState) => Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Ingredient', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    items: _categories
                        .map((c) => DropdownMenuItem<String>(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setSheetState(() {
                        selectedCategory = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: 'Default Unit',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Add'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (created != true) return;

      await ref.read(apiClientProvider).createIngredient(
            accessToken: token,
            name: nameController.text.trim(),
            category: selectedCategory,
            defaultUnit: unitController.text.trim(),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingredient added')),
      );
      await _loadPantry();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      nameController.dispose();
      unitController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? _items
        : _items
            .where(
              (item) => (item['name'] as String? ?? '').toLowerCase().contains(query),
            )
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Kitchen'),
        actions: [
          IconButton(onPressed: _loadPantry, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search ingredients',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _showAddIngredientDialog,
                icon: const Icon(Icons.add),
                label: const Text('Add New Ingredient'),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(_error!, textAlign: TextAlign.center),
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(child: Text('No matching ingredients'))
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 1.2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final inStock = item['is_in_stock'] as bool? ?? false;
                              final quantity = (item['quantity'] ?? '').toString();
                              return InkWell(
                                onTap: () => _editPantryItem(item),
                                borderRadius: BorderRadius.circular(12),
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'] as String? ?? 'Unknown',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context).textTheme.titleSmall,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${item['category']} • ${item['default_unit']}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          quantity.isEmpty ? 'Qty: not set' : 'Qty: $quantity',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            Text(
                                              inStock ? 'In stock' : 'Out',
                                              style: TextStyle(
                                                color: inStock
                                                    ? Colors.green.shade700
                                                    : Colors.grey.shade700,
                                              ),
                                            ),
                                            const Spacer(),
                                            Switch(
                                              value: inStock,
                                              onChanged: (value) => _toggle(item, value),
                                            ),
                                          ],
                                        ),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton(
                                            onPressed: () => _editPantryItem(item),
                                            child: const Text('Edit Qty'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
