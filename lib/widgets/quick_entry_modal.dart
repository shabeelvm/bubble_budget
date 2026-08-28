import 'package:flutter/material.dart';
import '../models/bubble.dart';
import '../services/audio_service.dart';

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
  String _amountString = '0';
  final AudioService _audio = AudioService();

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
        if (_amountString == '0') {
          _amountString = key;
        } else {
          _amountString += key;
        }
      }
    });
  }

  void _addQuick(double value) {
    _audio.triggerHapticMedium();
    _audio.playTap();
    double current = double.tryParse(_amountString) ?? 0;
    setState(() {
      _amountString = (current + value).toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '');
    });
  }

  void _submit() {
    _audio.triggerHapticHeavy();
    _audio.playSuccess();
    double amount = double.tryParse(_amountString) ?? 0;
    if (amount > 0) {
      widget.onDone(amount);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.bubble.categoryName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            '\$$_amountString',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _QuickChip(label: '+\$5', onTap: () => _addQuick(5)),
              _QuickChip(label: '+\$10', onTap: () => _addQuick(10)),
              _QuickChip(label: '+\$20', onTap: () => _addQuick(20)),
            ],
          ),
          const SizedBox(height: 24),
          GridView.count(
            shrinkWrap: true,
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
                color: Colors.redAccent.withAlpha(50),
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
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Icon(Icons.check, size: 32, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.white10,
      onPressed: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color? color;

  const _KeyButton({this.label, this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.white.withAlpha(15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
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
