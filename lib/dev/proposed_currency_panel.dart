// DEV-ONLY mock of the proposed currency picker. Nothing in the app imports it.
//
// Keeps the Settings row as a normal ListTile showing the current selection;
// tapping it opens the grouped panel in a bottom sheet. A sheet rather than a
// dialog because AlertDialog insets leave ~260px usable on a 390pt phone -
// 3 tiles per row - while a sheet is full width and fits 5.
//
// Replaces the DropdownButton in Settings > Preferences with a grouped panel of
// symbol tiles, each carrying its ISO code so colliding glyphs (JPY vs CNY, the
// four Nordic "kr", the several "Rs") are distinguishable without a search box.
//
// The live example at the bottom is the point of the mock: it shows what the
// canvas label would actually read, including the zero-decimal problem that
// ships the moment JPY, KRW, VND or IDR becomes selectable.

import 'package:flutter/material.dart';

class CurrencyOption {
  final String symbol;
  final String code;

  /// Minor-unit digits. 0 for currencies with no subunit in practice.
  final int decimals;

  const CurrencyOption(this.symbol, this.code, this.decimals);
}

class CurrencyGroup {
  final String title;
  final List<CurrencyOption> items;

  const CurrencyGroup(this.title, this.items);
}

const List<CurrencyGroup> kCurrencyGroups = <CurrencyGroup>[
  CurrencyGroup('Americas & Europe', <CurrencyOption>[
    CurrencyOption('\$', 'USD', 2),
    CurrencyOption('€', 'EUR', 2),
    CurrencyOption('£', 'GBP', 2),
    CurrencyOption('C\$', 'CAD', 2),
    CurrencyOption('CHF', 'CHF', 2),
    CurrencyOption('kr', 'SEK', 2),
    CurrencyOption('zł', 'PLN', 2),
    CurrencyOption('R\$', 'BRL', 2),
    CurrencyOption('Mex\$', 'MXN', 2),
    CurrencyOption('₽', 'RUB', 2),
  ]),
  CurrencyGroup('Asia-Pacific', <CurrencyOption>[
    CurrencyOption('A\$', 'AUD', 2),
    CurrencyOption('NZ\$', 'NZD', 2),
    CurrencyOption('₹', 'INR', 2),
    CurrencyOption('¥', 'JPY', 0),
    CurrencyOption('CN¥', 'CNY', 2),
    CurrencyOption('₩', 'KRW', 0),
    CurrencyOption('S\$', 'SGD', 2),
    CurrencyOption('HK\$', 'HKD', 2),
    CurrencyOption('Rp', 'IDR', 0),
    CurrencyOption('₱', 'PHP', 2),
    CurrencyOption('฿', 'THB', 2),
    CurrencyOption('₫', 'VND', 0),
    CurrencyOption('RM', 'MYR', 2),
    CurrencyOption('₨', 'PKR', 2),
    CurrencyOption('৳', 'BDT', 2),
  ]),
  CurrencyGroup('Middle East & Africa', <CurrencyOption>[
    // SR and AED rather than ﷼ and د.إ: Arabic glyphs inside an LTR Text can
    // render with unexpected directionality.
    CurrencyOption('SR', 'SAR', 2),
    CurrencyOption('AED', 'AED', 2),
    CurrencyOption('₺', 'TRY', 2),
    CurrencyOption('₪', 'ILS', 2),
    CurrencyOption('R', 'ZAR', 2),
    CurrencyOption('₦', 'NGN', 2),
    CurrencyOption('E£', 'EGP', 2),
  ]),
];

class ProposedCurrencyPanel extends StatefulWidget {
  const ProposedCurrencyPanel({super.key});

  @override
  State<ProposedCurrencyPanel> createState() => _ProposedCurrencyPanelState();
}

class _ProposedCurrencyPanelState extends State<ProposedCurrencyPanel> {
  CurrencyOption _selected = kCurrencyGroups[1].items[0]; // AUD

  Future<void> _openPicker() async {
    final CurrencyOption? picked = await showModalBottomSheet<CurrencyOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext _) => _CurrencySheet(initial: _selected),
    );
    if (picked != null && mounted) setState(() => _selected = picked);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color t1 = isDark ? Colors.white : const Color(0xFF1F2937);
    final Color t2 = isDark ? Colors.white54 : const Color(0xFF6B7280);
    final Color accent =
        isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Preferences',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
          const SizedBox(height: 8),
          // The row behaves like the dropdown it replaces: shows the current
          // value, opens the picker on tap.
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Currency', style: TextStyle(color: t1)),
            subtitle: Text(
              'Symbol shown on bubbles and reports',
              style: TextStyle(color: t2, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${_selected.symbol}  ${_selected.code}',
                  style: TextStyle(
                    color: t1,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: t2),
              ],
            ),
            onTap: _openPicker,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Sound Effects', style: TextStyle(color: t1)),
            value: true,
            activeThumbColor: accent,
            onChanged: (bool _) {},
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Haptic Feedback', style: TextStyle(color: t1)),
            value: true,
            activeThumbColor: accent,
            onChanged: (bool _) {},
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Show Total Budget Header', style: TextStyle(color: t1)),
            subtitle: Text(
              'Display total monthly budget progress at the top',
              style: TextStyle(color: t2, fontSize: 12),
            ),
            value: true,
            activeThumbColor: accent,
            onChanged: (bool _) {},
          ),
        ],
      ),
    );
  }
}

class _CurrencySheet extends StatefulWidget {
  final CurrencyOption initial;

  const _CurrencySheet({required this.initial});

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  late CurrencyOption _local = widget.initial;

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
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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
                        for (final CurrencyOption c in g.items)
                          _Tile(
                            option: c,
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
                  const SizedBox(height: 22),
                  _ExampleCard(option: _local, isDark: isDark, t1: t1, t2: t2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final CurrencyOption option;
  final bool selected;
  final bool isDark;
  final Color accent;
  final Color t1;
  final Color t2;
  final VoidCallback onTap;

  const _Tile({
    required this.option,
    required this.selected,
    required this.isDark,
    required this.accent,
    required this.t1,
    required this.t2,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color card =
        isDark ? Colors.white.withAlpha(13) : Colors.white;
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
              option.symbol,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: selected ? accent : t1,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              option.code,
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

class _ExampleCard extends StatelessWidget {
  final CurrencyOption option;
  final bool isDark;
  final Color t1;
  final Color t2;

  const _ExampleCard({
    required this.option,
    required this.isDark,
    required this.t1,
    required this.t2,
  });

  @override
  Widget build(BuildContext context) {
    final String s = option.symbol;
    final String shipped =
        '$s${240.0.toStringAsFixed(2)} / $s${300.0.toStringAsFixed(2)}';
    final String correct =
        '$s${240.0.toStringAsFixed(option.decimals)} / $s${300.0.toStringAsFixed(option.decimals)}';
    final bool differs = shipped != correct;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(10) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(20) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'HOW A BUBBLE LABEL WOULD READ',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
              color: t2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            shipped,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: differs ? const Color(0xFFFF5A5F) : t1,
            ),
          ),
          if (differs) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              '$correct  <- correct for ${option.code}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${option.code} has no minor unit. The shipped code calls '
              'toStringAsFixed(2) everywhere.',
              style: TextStyle(fontSize: 11.5, height: 1.35, color: t2),
            ),
          ],
        ],
      ),
    );
  }
}
