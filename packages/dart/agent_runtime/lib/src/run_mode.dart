enum RunMode { readOnly, confirm, auto }

extension RunModeWireName on RunMode {
  String get wireName {
    return switch (this) {
      RunMode.readOnly => 'read_only',
      RunMode.confirm => 'confirm',
      RunMode.auto => 'auto',
    };
  }
}

RunMode runModeFromWireName(String value) {
  final normalized = value.replaceAll('-', '_');
  return switch (normalized) {
    'read_only' || 'readOnly' => RunMode.readOnly,
    'confirm' => RunMode.confirm,
    'auto' => RunMode.auto,
    _ => throw StateError('Unknown run mode: $value'),
  };
}
