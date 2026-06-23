import 'package:test/test.dart';
import 'package:widenote_core/widenote_core.dart';

void main() {
  test('ticking clock advances by a stable step', () {
    final clock = TickingWnClock(
      DateTime.utc(2026, 6, 23, 1),
      step: const Duration(seconds: 2),
    );

    expect(clock.now(), DateTime.utc(2026, 6, 23, 1));
    expect(clock.now(), DateTime.utc(2026, 6, 23, 1, 0, 2));
  });

  test('sequence id generator is deterministic', () {
    final ids = SequenceWnIdGenerator(seed: 'runtime');

    expect(ids.nextId('evt'), 'evt-runtime-000001');
    expect(ids.nextId('run'), 'run-runtime-000002');
  });

  test('result folds success and failure paths', () {
    const ok = WnResult<int>.ok(42);
    const err = WnResult<int>.err(
      WnFailure(code: 'missing', message: 'Value is missing.'),
    );

    expect(ok.when(ok: (value) => value + 1, err: (_) => 0), 43);
    expect(
      err.when(ok: (value) => value, err: (failure) => failure.code),
      'missing',
    );
  });
}
