import 'dart:convert';

import 'json.dart';

String encodeJsonMap(JsonMap value) => jsonEncode(value);

String encodeJsonList(JsonList value) => jsonEncode(value);

JsonMap decodeJsonMap(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! Map) {
    throw const FormatException('Expected a JSON object.');
  }
  return _normalizeMap(decoded);
}

JsonList decodeJsonList(String value) {
  final decoded = jsonDecode(value);
  if (decoded is! List) {
    throw const FormatException('Expected a JSON array.');
  }
  return _normalizeList(decoded);
}

JsonMap _normalizeMap(Map<dynamic, dynamic> value) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw const FormatException('Expected string JSON object keys.');
    }
    result[key] = _normalizeValue(entry.value);
  }
  return Map<String, Object?>.unmodifiable(result);
}

JsonList _normalizeList(List<dynamic> value) {
  return List<Object?>.unmodifiable(value.map(_normalizeValue));
}

Object? _normalizeValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is Map) {
    return _normalizeMap(value);
  }
  if (value is List) {
    return _normalizeList(value);
  }
  throw FormatException('Unsupported JSON value: $value.');
}
