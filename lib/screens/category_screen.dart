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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
    final textSecondary = isDark ? Colors.white70 : const Color(0xFF4B5563);
    final textMuted = isDark ? Colors.white54 : const Color(0xFF6B7280);
    final accent = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    return Scaffold(
      // Was hard-coded Colors.black, which left this page dark while the rest
      // of the app followed Soft Light.
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Manage Bubbles'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Categories (${provider.bubbles.length}/25)', accent, [
            ...provider.bubbles.map((cat) => ListTile(
              leading: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Color(int.parse(cat.colorHex, radix: 16)),
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(cat.categoryName, style: TextStyle(color: textPrimary)),
              subtitle: Text(
                cat.budgetLimit > 0
                    ? 'Spent: ${_settings.currencySymbol}${cat.monthlySpend.toStringAsFixed(2)} / ${_settings.currencySymbol}${cat.budgetLimit.toStringAsFixed(2)}'
                    : 'Spent: ${_settings.currencySymbol}${cat.monthlySpend.toStringAsFixed(2)}',
                style: TextStyle(color: textSecondary),
              ),
              trailing: Icon(Icons.chevron_right, color: textMuted),
              onTap: () => _showCategoryDialog(bubble: cat),
            )),
            if (provider.bubbles.length < 25)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextButton.icon(
                  icon: Icon(Icons.add, color: accent),
                  label: Text('Add Custom Category', style: TextStyle(color: accent)),
                  onPressed: () => _showCategoryDialog(),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Color accent, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // blueAccent measured 3.0:1 on the cream ground - below AA.
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: accent)),
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
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          final textPrimary = isDark ? Colors.white : const Color(0xFF1F2937);
          final textSecondary = isDark ? Colors.white70 : const Color(0xFF4B5563);
          final accent = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
          final danger = isDark ? const Color(0xFFFF6B6B) : const Color(0xFFDC2626);

          return AlertDialog(
          // Surface comes from dialogTheme now. It was pinned to #1A1A1A, which
          // is what put white-on-white text in Soft Light: the hard-coded dark
          // surface stayed dark while the TextField took filled:true and
          // fillColor:#FFFFFF from lightTheme.inputDecorationTheme.
          title: Text(bubble == null ? 'Add Category' : 'Edit ${bubble.categoryName}', style: TextStyle(color: textPrimary)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      labelStyle: TextStyle(color: textSecondary),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: Text('Set Monthly Budget', style: TextStyle(color: textPrimary, fontSize: 14)),
                    value: isBudgetToggled,
                    onChanged: (val) {
                      setDialogState(() {
                        isBudgetToggled = val;
                      });
                    },
                    activeThumbColor: accent,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (isBudgetToggled) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: limitController, 
                      keyboardType: TextInputType.number, 
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Monthly Budget Limit',
                        labelStyle: TextStyle(color: textSecondary),
                        helperText: 'Enter target amount',
                        helperStyle: TextStyle(color: textSecondary),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('Pick Color', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
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
                              ? Border.all(color: textPrimary, width: 3)
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
                child: Text('Delete', style: TextStyle(color: danger)),
              ),
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: textSecondary))),
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
              child: Text(bubble == null ? 'Add' : 'Save', style: TextStyle(color: accent)),
            ),
          ],
          );
        },
      ),
    );
  }
}
