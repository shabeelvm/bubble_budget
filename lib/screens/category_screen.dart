import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bubble.dart';
import '../services/settings_service.dart';
import '../providers/bubble_provider.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() => _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  final SettingsService _settings = SettingsService();

  // A full hue wheel plus two neutrals. Every swatch carries the white bubble
  // label at 3:1 or better - the previous Material set included Yellow
  // (FFFFEB3B) and Grey (FF9E9E9E), on which white text was effectively
  // invisible. The six seeded defaults all appear here, so a category can
  // always be set back to the colour it shipped with.
  final List<String> _colorPalette = [
    'FFFF5722', // Coral
    'FFDC2626', // Red
    'FFE11D48', // Rose
    'FFEC4899', // Pink
    'FFC026D3', // Fuchsia
    'FF9333EA', // Purple
    'FF7C3AED', // Violet
    'FF4F46E5', // Indigo
    'FF2563EB', // Blue
    'FF0284C7', // Sky
    'FF0891B2', // Cyan
    'FF0D9488', // Teal
    'FF059669', // Emerald
    'FF16A34A', // Green
    'FF65A30D', // Lime
    'FFA16207', // Gold
    'FFD97706', // Amber
    'FFEA580C', // Orange
    'FF78716C', // Stone
    'FF475569', // Slate
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BubbleProvider>();
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Manage Bubbles'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Categories (${provider.bubbles.length}/25)', [
            ...provider.bubbles.map((cat) => ListTile(
              leading: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Color(int.parse(cat.colorHex, radix: 16)),
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(cat.categoryName, style: const TextStyle(color: Colors.white)),
              subtitle: Text(
                cat.budgetLimit > 0
                    ? 'Spent: ${_settings.currencySymbol}${cat.monthlySpend.toStringAsFixed(2)} / ${_settings.currencySymbol}${cat.budgetLimit.toStringAsFixed(2)}'
                    : 'Spent: ${_settings.currencySymbol}${cat.monthlySpend.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.white70),
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white54),
              onTap: () => _showCategoryDialog(bubble: cat),
            )),
            if (provider.bubbles.length < 25)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextButton.icon(
                  icon: const Icon(Icons.add, color: Colors.blueAccent),
                  label: const Text('Add Custom Category', style: TextStyle(color: Colors.blueAccent)),
                  onPressed: () => _showCategoryDialog(),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  void _showCategoryDialog({Bubble? bubble}) {
    final nameController = TextEditingController(text: bubble?.categoryName ?? '');
    final limitController = TextEditingController(
      text: (bubble == null || bubble.budgetLimit <= 0)
          ? ''
          : (bubble.budgetLimit == bubble.budgetLimit.roundToDouble()
              ? bubble.budgetLimit.round().toString()
              : bubble.budgetLimit.toString()),
    );
    String selectedColor = bubble?.colorHex ?? _colorPalette[0];
    bool isBudgetToggled = (bubble != null && bubble.budgetLimit > 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(bubble == null ? 'Add Category' : 'Edit ${bubble.categoryName}', style: const TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController, 
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Category Name', labelStyle: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Set Monthly Budget', style: TextStyle(color: Colors.white, fontSize: 14)),
                    value: isBudgetToggled,
                    onChanged: (val) {
                      setDialogState(() {
                        isBudgetToggled = val;
                      });
                    },
                    activeThumbColor: Colors.blueAccent,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (isBudgetToggled) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: limitController, 
                      keyboardType: TextInputType.number, 
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Monthly Budget Limit', 
                        labelStyle: TextStyle(color: Colors.white70),
                        helperText: 'Enter target amount',
                        helperStyle: TextStyle(color: Colors.white54),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Text('Pick Color', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: _colorPalette.map((color) => GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = color),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Color(int.parse(color, radix: 16)),
                          shape: BoxShape.circle,
                          border: selectedColor == color
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                        child: selectedColor == color
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (bubble != null)
              TextButton(
                onPressed: () async {
                  final provider = context.read<BubbleProvider>();
                  final navigator = Navigator.of(context);
                  await provider.deleteCategory(bubble.id);
                  navigator.pop();
                },
                child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final limitText = limitController.text.trim();
                final limit = (isBudgetToggled && limitText.isNotEmpty) ? (double.tryParse(limitText) ?? 0.0) : 0.0;
                
                if (isBudgetToggled && limit >= 10000000) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Entry error: Budget limit must be less than 10,000,000"),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }

                if (name.isNotEmpty) {
                  final provider = context.read<BubbleProvider>();
                  final navigator = Navigator.of(context);
                  if (bubble == null) {
                    await provider.addCategory(name, limit, selectedColor);
                  } else {
                    await provider.updateCategory(bubble.id, name: name, budgetLimit: limit, colorHex: selectedColor);
                  }
                  navigator.pop();
                }
              },
              child: Text(bubble == null ? 'Add' : 'Save', style: const TextStyle(color: Colors.blueAccent)),
            ),
          ],
        ),
      ),
    );
  }
}
