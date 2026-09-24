import 'package:flutter/material.dart';
import '../models/bubble.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';

class QuickEntryModal extends StatefulWidget {
  final Bubble bubble;
  final Function(double) onDone;

  const QuickEntryModal({
    super.key,
    required this.bubble,
    required this.onDone,
  });

  @override
  State<QuickEntryModal> createState() => _QuickEntryModalState();
}

class _QuickEntryModalState extends State<QuickEntryModal> {
  // This sheet paints itself #1A1A1A in both app themes, so it is dark by
  // design. Pinning the dark theme makes that honest: Material components
  // inside it (ActionChip above all) resolve their defaults against the dark
  // ColorScheme instead of the ambient one. Without this, the chips took a
  // near-white Material 3 default in Soft Light and their white labels
  // vanished, while the neighbouring plain-Material keypad was unaffected.
  // Built once, not per frame.
  static final ThemeData _theme = AppTheme.darkTheme;

  /// The sheet's own near-black, unchanged from before - the tint fades into
  /// this rather than replacing it.
  static const Color _sheetGround = Color(0xFF1A1A1A);

  String _amountString = '0';
  bool _isNegative = false;
  final AudioService _audio = AudioService();
  // The pad and the quick chips hard-coded a dollar sign, so they showed "$"
  // and "+$5" no matter what currency was selected.
  final String _symbol = SettingsService().currencySymbol;

  /// The category's own colour, so the sheet can carry the same identity the
  /// bubble does. Falls back to the app blue if the stored hex is malformed.
  Color get _categoryColor {
    final hex = widget.bubble.colorHex;
    try {
      final value = int.parse(hex, radix: 16);
      return Color(hex.length == 6 ? (0xFF000000 | value) : value);
    } catch (_) {
      return const Color(0xFF2563EB);
    }
  }

  void _handleKeyPress(String key) {
    _audio.triggerHapticLight();
    _audio.playTap();
    setState(() {
      if (key == 'back') {
        if (_amountString.length > 1) {
          _amountString = _amountString.substring(0, _amountString.length - 1);
        } else {
          _amountString = '0';
        }
      } else if (key == '.') {
        if (!_amountString.contains('.')) {
          _amountString += '.';
        }
      } else {
        // Construct the pending amount string to validate before applying
        final pendingString = _amountString == '0' ? key : _amountString + key;
        final pendingVal = double.tryParse(pendingString) ?? 0.0;
        if (pendingVal >= 10000000) {
          _audio.triggerHapticHeavy();
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Maximum limit is 10,000,000 per transaction"),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        if (_amountString == '0') {
          _amountString = key;
        } else {
          _amountString += key;
        }
      }
    });
  }

  void _clearAll() {
    _audio.triggerHapticMedium();
    _audio.playTap();
    setState(() {
      _amountString = '0';
      _isNegative = false;
    });
  }

  void _addQuick(double value) {
    _audio.triggerHapticMedium();
    _audio.playTap();
    double current = double.tryParse(_amountString) ?? 0;
    final pendingVal = current + value;
    if (pendingVal >= 10000000) {
      _audio.triggerHapticHeavy();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Maximum limit is 10,000,000 per transaction"),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      _amountString = (current + value).toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    });
  }

  void _toggleSign() {
    _audio.triggerHapticLight();
    _audio.playTap();
    setState(() {
      _isNegative = !_isNegative;
    });
  }

  void _submit() {
    _audio.triggerHapticHeavy();
    double amount = double.tryParse(_amountString) ?? 0;
    if (amount >= 10000000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Entry error: Amount must be less than 10,000,000"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    _audio.playSuccess();
    if (amount > 0) {
      widget.onDone(_isNegative ? -amount : amount);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayColor = _isNegative ? Colors.tealAccent : Colors.blueAccent;
    final sign = _isNegative ? '-' : '+';

    return Theme(
      data: _theme,
      child: Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        // H: a wash of the category's colour at the top, fading to the sheet's
        // normal near-black. Colour means identity on the canvas, so the sheet
        // visibly belongs to the bubble that opened it.
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const <double>[0.0, 0.45],
          colors: <Color>[
            Color.lerp(_categoryColor, _sheetGround, 0.78) ?? _sheetGround,
            _sheetGround,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // G: the same glass rendering as the canvas, shrunk. Unlike a
                // flash on tap, this stays put while the amount is typed.
                _MiniBubble(color: _categoryColor),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    widget.bubble.categoryName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 60,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      sign,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: displayColor.withAlpha(150)),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_symbol$_amountString',
                      style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: displayColor),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickChip(
                  label: '± Refund', 
                  onTap: _toggleSign, 
                  color: _isNegative ? Colors.tealAccent.withAlpha(50) : null,
                  icon: _isNegative ? Icons.remove_circle_outline : Icons.add_circle_outline,
                ),
                _QuickChip(label: '+${_symbol}5', onTap: () => _addQuick(5)),
                _QuickChip(label: '+${_symbol}10', onTap: () => _addQuick(10)),
                _QuickChip(label: '+${_symbol}25', onTap: () => _addQuick(25)),
              ],
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              childAspectRatio: 1.5,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                ...['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0'].map((key) => _KeyButton(
                      label: key,
                      onTap: () => _handleKeyPress(key),
                    )),
                _KeyButton(
                  icon: Icons.backspace_outlined,
                  onTap: () => _handleKeyPress('back'),
                  onLongPress: _clearAll,
                  color: Colors.redAccent.withAlpha(40),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: displayColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Icon(Icons.check, size: 32, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;

  const _QuickChip({required this.label, required this.onTap, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: icon != null ? Icon(icon, size: 16, color: Colors.white) : null,
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color ?? Colors.white10,
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? color;

  const _KeyButton({this.label, this.icon, required this.onTap, this.onLongPress, this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.white.withAlpha(15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: label != null
              ? Text(label!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))
              : Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

/// A 40pt echo of a canvas bubble: radial gradient lit from the upper left,
/// a specular catch-light, and a thin rim. Same visual language as
/// BubblePainter, without the physics.
class _MiniBubble extends StatelessWidget {
  final Color color;

  const _MiniBubble({required this.color});

  static const double _size = 40.0;

  @override
  Widget build(BuildContext context) {
    final Color glint = Color.lerp(color, Colors.white, 0.50) ?? color;
    final Color shade = Color.lerp(color, Colors.black, 0.42) ?? color;

    return SizedBox(
      width: _size,
      height: _size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.32, -0.38),
            radius: 0.95,
            colors: <Color>[glint, color, shade],
            stops: const <double>[0.0, 0.55, 1.0],
          ),
          border: Border.all(color: Colors.white24, width: 1.0),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withAlpha(90),
              blurRadius: 10.0,
              offset: const Offset(0.0, 3.0),
            ),
          ],
        ),
        child: Align(
          alignment: const Alignment(-0.40, -0.48),
          child: FractionallySizedBox(
            widthFactor: 0.34,
            heightFactor: 0.22,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(66),
                borderRadius: BorderRadius.circular(_size),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
