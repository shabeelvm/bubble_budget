import 'package:flutter_test/flutter_test.dart';
import 'package:bubble_budget/models/bubble.dart';

void main() {
  group('Bubble Model Tests', () {
    test('Constructor and Properties initialization', () {
      const bubble = Bubble(
        id: 'food_id',
        categoryName: 'Food',
        monthlySpend: 150.0,
        budgetLimit: 500.0,
        x: 100.0,
        y: 200.0,
        vx: 1.0,
        vy: -1.0,
        radius: 50.0,
      );

      expect(bubble.id, 'food_id');
      expect(bubble.categoryName, 'Food');
      expect(bubble.monthlySpend, 150.0);
      expect(bubble.budgetLimit, 500.0);
      expect(bubble.x, 100.0);
      expect(bubble.y, 200.0);
      expect(bubble.vx, 1.0);
      expect(bubble.vy, -1.0);
      expect(bubble.radius, 50.0);
    });

    test('spendRatio calculation', () {
      const bubble1 = Bubble(
        id: '1',
        categoryName: 'Food',
        monthlySpend: 150.0,
        budgetLimit: 500.0,
        x: 100.0,
        y: 200.0,
        radius: 50.0,
      );
      expect(bubble1.spendRatio, 0.3);

      const bubble2 = Bubble(
        id: '2',
        categoryName: 'Zero Limit',
        monthlySpend: 150.0,
        budgetLimit: 0.0,
        x: 100.0,
        y: 200.0,
        radius: 50.0,
      );
      expect(bubble2.spendRatio, 0.0);
    });

    test('copyWith functionality', () {
      const bubble = Bubble(
        id: 'food_id',
        categoryName: 'Food',
        monthlySpend: 150.0,
        budgetLimit: 500.0,
        x: 100.0,
        y: 200.0,
        radius: 50.0,
      );

      final updated = bubble.copyWith(
        monthlySpend: 200.0,
        x: 120.0,
        vx: 0.5,
      );

      expect(updated.id, 'food_id');
      expect(updated.categoryName, 'Food');
      expect(updated.monthlySpend, 200.0);
      expect(updated.budgetLimit, 500.0);
      expect(updated.x, 120.0);
      expect(updated.y, 200.0);
      expect(updated.vx, 0.5);
      expect(updated.radius, 50.0);
    });

    test('JSON serialization and deserialization', () {
      const bubble = Bubble(
        id: 'ent_id',
        categoryName: 'Entertainment',
        monthlySpend: 50.0,
        budgetLimit: 100.0,
        x: 10.0,
        y: 20.0,
        vx: 0.1,
        vy: 0.2,
        radius: 30.0,
      );

      final json = bubble.toJson();
      expect(json['id'], 'ent_id');
      expect(json['categoryName'], 'Entertainment');
      expect(json['monthlySpend'], 50.0);
      expect(json['budgetLimit'], 100.0);
      expect(json['x'], 10.0);
      expect(json['y'], 20.0);
      expect(json['vx'], 0.1);
      expect(json['vy'], 0.2);
      expect(json['radius'], 30.0);

      final fromJson = Bubble.fromJson(json);
      expect(fromJson.id, bubble.id);
      expect(fromJson.categoryName, bubble.categoryName);
      expect(fromJson.monthlySpend, bubble.monthlySpend);
      expect(fromJson.budgetLimit, bubble.budgetLimit);
      expect(fromJson.x, bubble.x);
      expect(fromJson.y, bubble.y);
      expect(fromJson.vx, bubble.vx);
      expect(fromJson.vy, bubble.vy);
      expect(fromJson.radius, bubble.radius);
    });
  });
}
