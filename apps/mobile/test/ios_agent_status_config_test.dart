import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS declares Agent status notification and Live Activity bridge', () {
    final infoPlist = File('ios/Runner/Info.plist');
    final appDelegate = File('ios/Runner/AppDelegate.swift');
    final bridge = File('ios/Runner/AgentStatusBridge.swift');
    final attributes = File('ios/Runner/AgentStatusActivityAttributes.swift');
    final podfile = File('ios/Podfile');

    expect(infoPlist.readAsStringSync(), contains('NSSupportsLiveActivities'));
    expect(podfile.readAsStringSync(), contains("platform :ios, '14.0'"));
    expect(
      appDelegate.readAsStringSync(),
      contains('AgentStatusBridge.register'),
    );
    final bridgeContents = bridge.readAsStringSync();
    expect(bridgeContents, contains('app.widenote/agent_status'));
    expect(bridgeContents, contains('requestAuthorization'));
    expect(bridgeContents, contains('app.widenote.agent_status.current'));
    expect(bridgeContents, contains('removeDeliveredNotifications'));
    expect(bridgeContents, contains('Activity<AgentStatusActivityAttributes>'));
    expect(bridgeContents, contains('disabled_ended'));
    expect(bridgeContents, contains('dismissalPolicy: .immediate'));
    expect(bridgeContents, contains('dismissalPolicy: .after'));
    expect(bridgeContents, contains('terminalDismissalDate'));
    expect(bridgeContents, isNot(contains('10 * 60')));
    expect(attributes.readAsStringSync(), contains('ActivityAttributes'));
  });

  test('iOS project embeds the Agent status Widget extension', () {
    final project = File('ios/Runner.xcodeproj/project.pbxproj');
    final widget = File(
      'ios/AgentStatusWidgetExtension/AgentStatusLiveActivity.swift',
    );
    final widgetInfo = File('ios/AgentStatusWidgetExtension/Info.plist');

    expect(widget.existsSync(), isTrue);
    expect(widgetInfo.existsSync(), isTrue);
    final contents = project.readAsStringSync();
    expect(contents, contains('AgentStatusWidgetExtension.appex'));
    expect(contents, contains('Embed App Extensions'));
    expect(contents, contains('app.widenote.dev.AgentStatusWidgetExtension'));
    expect(contents, contains('app.widenote.AgentStatusWidgetExtension'));
    expect(widget.readAsStringSync(), contains('DynamicIslandExpandedRegion'));
    expect(
      widgetInfo.readAsStringSync(),
      contains('com.apple.widgetkit-extension'),
    );
  });
}
