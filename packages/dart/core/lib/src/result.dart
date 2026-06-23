import 'json.dart';

final class WnFailure {
  const WnFailure({
    required this.code,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final String code;
  final String message;
  final JsonMap details;

  @override
  String toString() => 'WnFailure($code, $message)';
}

sealed class WnResult<T> {
  const WnResult();

  const factory WnResult.ok(T value) = WnOk<T>;
  const factory WnResult.err(WnFailure failure) = WnErr<T>;

  bool get isOk;
  bool get isErr => !isOk;

  T get value;
  WnFailure get failure;

  R when<R>({
    required R Function(T value) ok,
    required R Function(WnFailure failure) err,
  });
}

final class WnOk<T> extends WnResult<T> {
  const WnOk(this._value);

  final T _value;

  @override
  bool get isOk => true;

  @override
  T get value => _value;

  @override
  WnFailure get failure => throw StateError('Ok result has no failure.');

  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(WnFailure failure) err,
  }) {
    return ok(_value);
  }
}

final class WnErr<T> extends WnResult<T> {
  const WnErr(this._failure);

  final WnFailure _failure;

  @override
  bool get isOk => false;

  @override
  T get value => throw StateError('Err result has no value.');

  @override
  WnFailure get failure => _failure;

  @override
  R when<R>({
    required R Function(T value) ok,
    required R Function(WnFailure failure) err,
  }) {
    return err(_failure);
  }
}
