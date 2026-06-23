typedef JsonMap = Map<String, Object?>;
typedef JsonList = List<Object?>;

JsonMap immutableJsonMap([JsonMap value = const <String, Object?>{}]) {
  return Map<String, Object?>.unmodifiable(value);
}
