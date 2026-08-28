class Bubble {
  final String id;
  final String categoryName;
  final double monthlySpend;
  final double budgetLimit;
  final double x;
  final double y;
  final double vx;
  final double vy;
  final double radius;
  final String colorHex;
  final bool isDragged;

  const Bubble({
    required this.id,
    required this.categoryName,
    required this.monthlySpend,
    required this.budgetLimit,
    required this.x,
    required this.y,
    this.vx = 0.0,
    this.vy = 0.0,
    required this.radius,
    this.colorHex = 'FF448AFF',
    this.isDragged = false,
  });

  /// Calculates the progress of budget spent (0.0 to 1.0 or more).
  double get spendRatio => budgetLimit > 0 ? monthlySpend / budgetLimit : 0.0;

  /// Creates a copy of this Bubble but with the given fields replaced with the new values.
  Bubble copyWith({
    String? id,
    String? categoryName,
    double? monthlySpend,
    double? budgetLimit,
    double? x,
    double? y,
    double? vx,
    double? vy,
    double? radius,
    String? colorHex,
    bool? isDragged,
  }) {
    return Bubble(
      id: id ?? this.id,
      categoryName: categoryName ?? this.categoryName,
      monthlySpend: monthlySpend ?? this.monthlySpend,
      budgetLimit: budgetLimit ?? this.budgetLimit,
      x: x ?? this.x,
      y: y ?? this.y,
      vx: vx ?? this.vx,
      vy: vy ?? this.vy,
      radius: radius ?? this.radius,
      colorHex: colorHex ?? this.colorHex,
      isDragged: isDragged ?? this.isDragged,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'categoryName': categoryName,
      'monthlySpend': monthlySpend,
      'budgetLimit': budgetLimit,
      'x': x,
      'y': y,
      'vx': vx,
      'vy': vy,
      'radius': radius,
      'colorHex': colorHex,
    };
  }

  /// Create from JSON
  factory Bubble.fromJson(Map<String, dynamic> json) {
    return Bubble(
      id: json['id'] as String,
      categoryName: json['categoryName'] as String,
      monthlySpend: (json['monthlySpend'] as num).toDouble(),
      budgetLimit: (json['budgetLimit'] as num).toDouble(),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      vx: (json['vx'] ?? 0.0 as num).toDouble(),
      vy: (json['vy'] ?? 0.0 as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
      colorHex: json['colorHex'] as String? ?? 'FF448AFF',
    );
  }
}
