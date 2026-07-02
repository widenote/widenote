import 'package:widenote_agent_runtime/widenote_agent_runtime.dart' as runtime;

import 'json.dart';

const runtimeTaskRunModeKey = 'runtime_task_run_mode';
const runtimeRunModeKey = 'runtime_run_mode';

String storedRuntimeRunMode(JsonMap payload, String key) {
  final value = payload[key];
  if (value is String && value.isNotEmpty) {
    return runtime.runModeFromWireName(value).wireName;
  }
  return runtime.RunMode.auto.wireName;
}

JsonMap payloadWithRuntimeRunMode(
  JsonMap payload,
  String key,
  String? runMode,
) {
  final mode = runMode == null
      ? storedRuntimeRunMode(payload, key)
      : runtime.runModeFromWireName(runMode).wireName;
  return <String, Object?>{...payload, key: mode};
}

JsonMap payloadWithTaskRunMode(JsonMap payload, runtime.RuntimeTask task) {
  return <String, Object?>{
    ...payload,
    runtimeTaskRunModeKey: task.runMode.wireName,
  };
}

runtime.RunMode runtimeTaskRunModeFromPayload(JsonMap payload) {
  return runtimeRunModeFromPayload(
    payload,
    key: runtimeTaskRunModeKey,
    fallbackKey: runtimeRunModeKey,
  );
}

runtime.RunMode runtimeRunModeFromPayload(
  JsonMap payload, {
  String key = runtimeRunModeKey,
  String? fallbackKey,
}) {
  final value =
      payload[key] ?? (fallbackKey == null ? null : payload[fallbackKey]);
  if (value == null) {
    return runtime.RunMode.auto;
  }
  if (value is String) {
    return runtime.runModeFromWireName(value);
  }
  throw StateError('$key must be a string.');
}
