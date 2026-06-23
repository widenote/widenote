abstract interface class WnClock {
  DateTime now();
}

final class SystemWnClock implements WnClock {
  const SystemWnClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

final class FixedWnClock implements WnClock {
  const FixedWnClock(this.instant);

  final DateTime instant;

  @override
  DateTime now() => instant.toUtc();
}

final class TickingWnClock implements WnClock {
  TickingWnClock(
    DateTime initialInstant, {
    this.step = const Duration(milliseconds: 1),
  }) : _nextInstant = initialInstant.toUtc();

  DateTime _nextInstant;
  final Duration step;

  @override
  DateTime now() {
    final value = _nextInstant;
    _nextInstant = _nextInstant.add(step);
    return value;
  }
}
