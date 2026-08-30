import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/audio_service.dart';

class DonutSlice {
  final String name;
  final double amount;
  final double percentage;
  final Color color;
  final double startAngle;
  final double sweepAngle;

  DonutSlice({
    required this.name,
    required this.amount,
    required this.percentage,
    required this.color,
    required this.startAngle,
    required this.sweepAngle,
  });
}

class _SliceData {
  final String name;
  final double amount;
  final double percentage;
  final String colorHex;

  _SliceData({
    required this.name,
    required this.amount,
    required this.percentage,
    required this.colorHex,
  });
}

class CategoryDonutChart extends StatefulWidget {
  final List<Map<String, dynamic>> categoryData;

  const CategoryDonutChart({super.key, required this.categoryData});

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  final SettingsService _settings = SettingsService();
  
  List<DonutSlice> _slices = [];
  double _totalSpend = 0.0;
  int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();
    _prepareSlices();
  }

  @override
  void didUpdateWidget(covariant CategoryDonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryData != widget.categoryData) {
      _prepareSlices();
      _selectedIndex = -1; // Reset selection on data change
    }
  }

  void _prepareSlices() {
    final rawData = widget.categoryData;
    if (rawData.isEmpty) {
      _slices = [];
      _totalSpend = 0.0;
      return;
    }

    _totalSpend = rawData.fold<double>(0, (sum, item) => sum + (item['total'] as num).toDouble());
    if (_totalSpend == 0) {
      _slices = [];
      return;
    }

    // Sort descending by total spend
    final sortedData = List<Map<String, dynamic>>.from(rawData)
      ..sort((a, b) => (b['total'] as num).toDouble().compareTo((a['total'] as num).toDouble()));

    List<_SliceData> prepared = [];
    double otherSpend = 0.0;

    for (int i = 0; i < sortedData.length; i++) {
      final item = sortedData[i];
      final spend = (item['total'] as num).toDouble();
      final percentage = spend / _totalSpend;

      // Group categories into "Other" if there are more than 5 distinct categories, spend percentage < 5%,
      // AND the category is NOT a core/default category ('Coffee', 'Food & Dining', 'Groceries', 'Transport', 'Subscriptions', 'Dining Out').
      final name = item['category_name'] as String;
      final isCoreCategory = name == 'Coffee' ||
          name == 'Food & Dining' ||
          name == 'Groceries' ||
          name == 'Transport' ||
          name == 'Subscriptions' ||
          name == 'Dining Out';

      if (sortedData.length > 5 && percentage < 0.05 && !isCoreCategory) {
        otherSpend += spend;
      } else {
        prepared.add(_SliceData(
          name: name,
          amount: spend,
          percentage: percentage,
          colorHex: item['color_hex'] as String? ?? 'FF9E9E9E',
        ));
      }
    }

    if (otherSpend > 0) {
      prepared.add(_SliceData(
        name: 'Other',
        amount: otherSpend,
        percentage: otherSpend / _totalSpend,
        colorHex: 'FF9E9E9E', // Gray for general "Other" category
      ));
    }

    // Map to DonutSlices with starting/sweeping angles
    double currentAngle = -math.pi / 2; // Start from 12 o'clock (top)
    _slices = prepared.map((slice) {
      final sweep = slice.percentage * 2 * math.pi;
      final start = currentAngle;
      currentAngle += sweep;
      return DonutSlice(
        name: slice.name,
        amount: slice.amount,
        percentage: slice.percentage,
        color: Color(int.parse(slice.colorHex, radix: 16)),
        startAngle: start,
        sweepAngle: sweep,
      );
    }).toList();
  }

  void _handleTap(TapUpDetails details, Size size) {
    if (_slices.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final dx = details.localPosition.dx - center.dx;
    final dy = details.localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    final baseRadius = math.min(size.width, size.height) / 2 - 16;
    const strokeWidth = 32.0;

    // Check if within donut active ring bounds with some touch padding
    final innerBound = baseRadius - strokeWidth / 2 - 16;
    final outerBound = baseRadius + strokeWidth / 2 + 16;

    if (distance < innerBound || distance > outerBound) {
      if (_selectedIndex != -1) {
        setState(() => _selectedIndex = -1);
        AudioService().playTap();
      }
      return;
    }

    // Determine polar angle [0, 2*pi]
    double angle = math.atan2(dy, dx);
    if (angle < 0) {
      angle += 2 * math.pi;
    }

    // Normalize with respect to starting from top (-pi / 2)
    double normalizedAngle = (angle + math.pi / 2) % (2 * math.pi);

    int tappedIndex = -1;
    for (int i = 0; i < _slices.length; i++) {
      final slice = _slices[i];
      final startNormal = (slice.startAngle + math.pi / 2) % (2 * math.pi);
      final endNormal = (startNormal + slice.sweepAngle) % (2 * math.pi);

      bool isInside = false;
      if (startNormal < endNormal) {
        isInside = normalizedAngle >= startNormal && normalizedAngle <= endNormal;
      } else {
        // Wraps around boundary
        isInside = normalizedAngle >= startNormal || normalizedAngle <= endNormal;
      }

      if (isInside) {
        tappedIndex = i;
        break;
      }
    }

    if (tappedIndex != -1) {
      setState(() {
        if (_selectedIndex == tappedIndex) {
          _selectedIndex = -1; // Deselect on double-tap
        } else {
          _selectedIndex = tappedIndex;
        }
      });
      AudioService().playTap();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimaryColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final textSecondaryColor = isDark ? Colors.white54 : const Color(0xFF6B7280);
    final emptyRingColor = isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE5E7EB);

    final bool isEmpty = _slices.isEmpty || _totalSpend == 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(10) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withAlpha(10) : const Color(0xFFE5E7EB)),
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: AspectRatio(
        aspectRatio: 1.3,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            
            return GestureDetector(
              onTapUp: (details) => _handleTap(details, size),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: size,
                    painter: isEmpty
                      ? EmptyDonutChartPainter(color: emptyRingColor)
                      : DonutChartPainter(
                          slices: _slices,
                          selectedIndex: _selectedIndex,
                          borderColor: isDark ? Colors.black : Colors.white,
                        ),
                  ),
                  // Centered Readout
                  IgnorePointer(
                    child: Container(
                      width: math.min(size.width, size.height) * 0.55,
                      height: math.min(size.width, size.height) * 0.55,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isEmpty) ...[
                            Text(
                              '${_settings.currencySymbol}0',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textPrimaryColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'No Spend',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textSecondaryColor,
                                fontSize: 13,
                              ),
                            ),
                          ] else if (_selectedIndex == -1) ...[
                            Text(
                              '${_settings.currencySymbol}${_totalSpend.toStringAsFixed(0)}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textPrimaryColor,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Total Spent',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textSecondaryColor,
                                fontSize: 13,
                              ),
                            ),
                          ] else ...[
                            Text(
                              _slices[_selectedIndex].name,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textPrimaryColor,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_settings.currencySymbol}${_slices[_selectedIndex].amount.toStringAsFixed(0)}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _slices[_selectedIndex].color,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${(_slices[_selectedIndex].percentage * 100).toStringAsFixed(0)}%',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: textSecondaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<DonutSlice> slices;
  final int selectedIndex;
  final Color borderColor;

  DonutChartPainter({
    required this.slices,
    required this.selectedIndex,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) / 2 - 20;
    const strokeWidth = 32.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..isAntiAlias = true;

    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final isSelected = i == selectedIndex;

      double radius = baseRadius;
      Offset arcCenter = center;

      if (isSelected) {
        paint.strokeWidth = strokeWidth + 6;
        // Visual outward pop-out along mid-angle vector
        final midAngle = slice.startAngle + slice.sweepAngle / 2;
        arcCenter = center + Offset(math.cos(midAngle) * 6, math.sin(midAngle) * 6);
      } else {
        paint.strokeWidth = strokeWidth;
      }

      paint.color = slice.color;
      final rect = Rect.fromCircle(center: arcCenter, radius: radius);

      // Leaves visual space boundary between distinct slices
      double sweep = slice.sweepAngle;
      if (slices.length > 1) {
        sweep -= 0.03; // Slice visual separation border angle gap
      }

      canvas.drawArc(rect, slice.startAngle, sweep, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DonutChartPainter oldDelegate) {
    return oldDelegate.slices != slices || oldDelegate.selectedIndex != selectedIndex || oldDelegate.borderColor != borderColor;
  }
}

class EmptyDonutChartPainter extends CustomPainter {
  final Color color;

  EmptyDonutChartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 20;
    const strokeWidth = 24.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color
      ..isAntiAlias = true;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant EmptyDonutChartPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
