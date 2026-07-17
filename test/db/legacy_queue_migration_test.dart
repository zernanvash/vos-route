import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vosroute/db/app_database.dart';

void main() {
  test('legacy seed uses typed outbox table and is repeatable', () async {
    final rows = <Map<String, Object?>>[
      {
        'action_type': 'submit_sos',
        'batch_priority': 1,
        'action_payload': '{"report_no":"SOS-1"}',
        'status': 'pending',
        'retry_count': 0,
        'max_retries': 5,
        'created_at': '2026-07-14T01:02:03.000Z',
        'last_attempt': null,
        'last_error': null,
      },
    ];
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(),
      legacyQueueReader: () async => rows,
    );
    addTearDown(db.close);

    await db.executor.ensureOpen(db);
    await db.seedFromLegacyQueue();

    final seeded = await db.select(db.outboxActions).get();
    expect(seeded, hasLength(1));
    expect(seeded.single.action, 'submit_sos');
    expect(seeded.single.priority, 1);
  });
}
