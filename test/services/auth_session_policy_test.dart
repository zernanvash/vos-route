import 'package:flutter_test/flutter_test.dart';
import 'package:vosroute/services/auth_session_policy.dart';

void main() {
  final startedAt = DateTime.utc(2026, 7, 1, 12);

  test('session remains valid immediately before fifteen-day boundary', () {
    expect(
      AuthSessionPolicy.isExpired(
        startedAt: startedAt,
        now: startedAt
            .add(const Duration(days: 15))
            .subtract(const Duration(microseconds: 1)),
      ),
      isFalse,
    );
  });

  test('session expires exactly at fifteen-day boundary', () {
    expect(
      AuthSessionPolicy.isExpired(
        startedAt: startedAt,
        now: startedAt.add(const Duration(days: 15)),
      ),
      isTrue,
    );
  });
}
