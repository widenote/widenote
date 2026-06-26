import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS Info.plist declares phase-one capture permission descriptions', () {
    final infoPlist = File('ios/Runner/Info.plist');

    expect(infoPlist.existsSync(), isTrue);
    final contents = infoPlist.readAsStringSync();
    expect(contents, contains('NSCameraUsageDescription'));
    expect(contents, contains('NSMicrophoneUsageDescription'));
    expect(contents, contains('NSPhotoLibraryUsageDescription'));
    expect(contents, contains('local raw capture attachments'));
    expect(contents, contains('source metadata'));
  });
}
