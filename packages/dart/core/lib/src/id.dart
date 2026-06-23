import 'clock.dart';

abstract interface class WnIdGenerator {
  String nextId([String prefix = 'id']);
}

final class MonotonicWnIdGenerator implements WnIdGenerator {
  MonotonicWnIdGenerator({required this.clock});

  final WnClock clock;
  int _counter = 0;

  @override
  String nextId([String prefix = 'id']) {
    final millis = clock.now().millisecondsSinceEpoch;
    final timePart = millis.toRadixString(36).padLeft(9, '0');
    final countPart = (_counter++).toRadixString(36).padLeft(6, '0');
    return '$prefix-$timePart-$countPart';
  }
}

final class SequenceWnIdGenerator implements WnIdGenerator {
  SequenceWnIdGenerator({this.seed = 'test', int startAt = 1})
    : _next = startAt;

  final String seed;
  int _next;

  @override
  String nextId([String prefix = 'id']) {
    final value = _next.toString().padLeft(6, '0');
    _next += 1;
    return '$prefix-$seed-$value';
  }
}
