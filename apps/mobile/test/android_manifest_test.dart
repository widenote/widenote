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

  test('Android flavors separate development and production packages', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    final gradleFile = File('android/app/build.gradle.kts');

    expect(manifest.existsSync(), isTrue);
    expect(gradleFile.existsSync(), isTrue);

    final manifestContents = manifest.readAsStringSync();
    final gradleContents = gradleFile.readAsStringSync();

    expect(manifestContents, contains('android:label="\${appLabel}"'));
    expect(gradleContents, contains('flavorDimensions += "releaseChannel"'));
    expect(
      gradleContents,
      contains('val productionApplicationId = "app.widenote"'),
    );
    expect(gradleContents, contains('create("prod")'));
    expect(gradleContents, contains('applicationId = productionApplicationId'));
    expect(gradleContents, contains('create("dev")'));
    expect(
      gradleContents,
      contains('applicationId = "\$productionApplicationId.dev"'),
    );
    expect(
      gradleContents,
      contains('manifestPlaceholders["appLabel"] = "WideNote Dev"'),
    );
  });
}
