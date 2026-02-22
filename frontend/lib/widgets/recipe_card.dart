import 'package:flutter/material.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.name,
    required this.matchScore,
    required this.cookingTime,
    required this.missingItems,
    required this.onViewRecipe,
  });

  final String name;
  final int matchScore;
  final String cookingTime;
  final List<Map<String, dynamic>> missingItems;
  final VoidCallback onViewRecipe;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Text(name),
        subtitle: Text('Match $matchScore% • $cookingTime'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          if (missingItems.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('No missing ingredients'),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: missingItems
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '- ${item['name'] ?? 'Unknown'} (~${item['cost_est'] ?? 'N/A'})',
                      ),
                    ),
                  )
                  .toList(),
            ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: onViewRecipe,
              child: const Text('View Recipe / Ask More'),
            ),
          ),
        ],
      ),
    );
  }
}
