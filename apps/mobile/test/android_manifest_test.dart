import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android manifest allows model provider network calls', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');

    expect(manifest.existsSync(), isTrue);
    expect(
      manifest.readAsStringSync(),
      contains('android.permission.INTERNET'),
    );
  });
}
