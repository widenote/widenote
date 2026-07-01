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

  test('Android manifest declares phase-one capture permissions', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');

    expect(manifest.existsSync(), isTrue);
    final contents = manifest.readAsStringSync();
    expect(contents, contains('android.permission.CAMERA'));
    expect(contents, contains('android.permission.RECORD_AUDIO'));
    expect(
      contents,
      isNot(contains('android.permission.READ_EXTERNAL_STORAGE')),
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

  test('Android app can open .widenote backup files without storage scope', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    final activity = File(
      'android/app/src/main/kotlin/app/widenote/MainActivity.kt',
    );
    final handler = File(
      'android/app/src/main/kotlin/app/widenote/channels/'
      'BackupImportChannelHandler.kt',
    );
    final exportHandler = File(
      'android/app/src/main/kotlin/app/widenote/channels/'
      'BackupExportChannelHandler.kt',
    );
    final providerPaths = File(
      'android/app/src/main/res/xml/backup_file_paths.xml',
    );

    expect(manifest.existsSync(), isTrue);
    expect(activity.existsSync(), isTrue);
    expect(handler.existsSync(), isTrue);
    expect(exportHandler.existsSync(), isTrue);
    expect(providerPaths.existsSync(), isTrue);

    final manifestContents = manifest.readAsStringSync();
    expect(manifestContents, contains('android.intent.action.VIEW'));
    expect(manifestContents, contains('android.intent.action.SEND'));
    expect(manifestContents, contains('application/x-widenote-backup'));
    expect(manifestContents, contains('.*\\\\.widenote'));
    expect(manifestContents, contains('android:launchMode="singleTask"'));
    expect(manifestContents, contains('androidx.core.content.FileProvider'));
    expect(manifestContents, contains('.backup_file_provider'));
    expect(manifestContents, contains('@xml/backup_file_paths'));
    expect(
      manifestContents,
      isNot(contains('android.permission.MANAGE_EXTERNAL_STORAGE')),
    );

    final activityContents = activity.readAsStringSync();
    expect(activityContents, contains('BackupImportChannelHandler'));
    expect(activityContents, contains('BackupExportChannelHandler'));
    expect(activityContents, contains('onNewIntent'));
    expect(activityContents, contains('onActivityResult'));

    final handlerContents = handler.readAsStringSync();
    expect(handlerContents, contains('app.widenote/backup_import'));
    expect(handlerContents, contains('ByteArray(8 * 1024)'));
    expect(handlerContents, contains('Intent.EXTRA_STREAM'));

    final exportContents = exportHandler.readAsStringSync();
    expect(exportContents, contains('app.widenote/backup_export'));
    expect(exportContents, contains('Intent.ACTION_SEND'));
    expect(exportContents, contains('Intent.ACTION_CREATE_DOCUMENT'));
    expect(exportContents, contains('Intent.ACTION_OPEN_DOCUMENT'));
    expect(exportContents, contains('ByteArray(8 * 1024)'));
    expect(exportContents, contains('FileProvider.getUriForFile'));
    expect(providerPaths.readAsStringSync(), contains('<files-path'));
  });
}
