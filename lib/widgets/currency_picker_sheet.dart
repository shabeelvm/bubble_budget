import 'package:flutter/material.dart';
import '../constants/currencies.dart';

/// Grouped currency panel, shown as a bottom sheet from Settings.
///
/// A sheet rather than a dialog: AlertDialog insets leave roughly 260px usable
/// on a 390pt phone, which fits three tiles per row; a sheet is full width and
/// fits five. Each tile shows its ISO code under the glyph, which is what makes
/// JPY and CNY - both yen signs - and the four Nordic "kr" distinguishable.
///
/// Returns the chosen [Currency], or null if dismissed without choosing.
Future<Currency?> showCurrencyPicker(
  BuildContext context, {
  required String selectedCode,
}) {
  return showModalBottomSheet<Currency>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext _) => _CurrencySheet(selectedCode: selectedCode),
  );
}

class _CurrencySheet extends StatefulWidget {
  final String selectedCode;

  const _CurrencySheet({required this.selectedCode});

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  late Currency _local = currencyForCode(widget.selectedCode);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color surface = isDark ? const Color(0xFF141618) : Colors.white;
    final Color t1 = isDark ? Colors.white : const Color(0xFF1F2937);
    final Color t2 = isDark ? Colors.white54 : const Color(0xFF6B7280);
    final Color accent =
        isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t2.withAlpha(90),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Currency',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: t1,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, _local),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: <Widget>[
                    for (final CurrencyGroup g in kCurrencyGroups) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 9),
                        child: Text(
                          g.title.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w600,
                            color: t2,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: <Widget>[
                          for (final Currency c in g.items)
                            _Tile(
                              currency: c,
                              selected: c.code == _local.code,
                              isDark: isDark,
                              accent: accent,
                              t1: t1,
                              t2: t2,
                              onTap: () => setState(() => _local = c),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Currency currency;
  final bool selected;
  final bool isDark;
  final Color accent;
  final Color t1;
  final Color t2;
  final VoidCallback onTap;

  const _Tile({
    required this.currency,
    required this.selected,
    required this.isDark,
    required this.accent,
    required this.t1,
    required this.t2,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color card = isDark ? Colors.white.withAlpha(13) : Colors.white;
    final Color line =
        isDark ? Colors.white.withAlpha(26) : const Color(0xFFE5E7EB);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 62,
        height: 56,
        decoration: BoxDecoration(
          color: selected ? accent.withAlpha(isDark ? 40 : 26) : card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              currency.symbol,
              maxLines: 1,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: selected ? accent : t1,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              currency.code,
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.4,
                color: selected ? accent : t2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
