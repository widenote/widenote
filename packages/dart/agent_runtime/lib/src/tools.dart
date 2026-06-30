import 'package:widenote_core/widenote_core.dart';

import 'run_mode.dart';

typedef ToolHandler = Future<JsonMap> Function(ToolInvocation invocation);

enum ToolAccess { read, write, readWrite }

enum ToolRisk { low, medium, high }

enum ToolLocality { local, external }

enum ToolApprovalRequirement { automatic, always, perCall, deferred }

enum ToolExecution { local, fake, deferred, disabled }

final class ToolDefinition {
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.handler,
    this.requiredPermissions = const <String>{},
    this.access = ToolAccess.read,
    bool external = false,
    ToolLocality? locality,
    this.risk = ToolRisk.low,
    this.approvalRequirement = ToolApprovalRequirement.automatic,
    this.execution = ToolExecution.local,
    this.compatibleRunModes = const <RunMode>{
      RunMode.readOnly,
      RunMode.confirm,
      RunMode.auto,
    },
  }) : locality =
           locality ?? (external ? ToolLocality.external : ToolLocality.local);

  final String name;
  final String description;
  final Set<String> requiredPermissions;
  final ToolAccess access;
  final ToolLocality locality;
  final ToolRisk risk;
  final ToolApprovalRequirement approvalRequirement;
  final ToolExecution execution;
  final Set<RunMode> compatibleRunModes;
  final ToolHandler handler;

  bool get mutates =>
      access == ToolAccess.write || access == ToolAccess.readWrite;
  bool get external => locality == ToolLocality.external;
  bool get isHighRisk => risk == ToolRisk.high;
  bool get isExecutableLocally {
    return execution == ToolExecution.local || execution == ToolExecution.fake;
  }

  bool get isReadOnlySafe {
    return !mutates && !external && !isHighRisk && isExecutableLocally;
  }

  bool get requiresExplicitApproval {
    return approvalRequirement == ToolApprovalRequirement.always ||
        approvalRequirement == ToolApprovalRequirement.perCall ||
        approvalRequirement == ToolApprovalRequirement.deferred ||
        external ||
        isHighRisk ||
        !isExecutableLocally;
  }

  bool get requiresApproval {
    return requiresExplicitApproval || mutates;
  }

  bool get canAutoExecute {
    return !requiresExplicitApproval && risk == ToolRisk.low && !external;
  }
}

final class ToolInvocation {
  const ToolInvocation({
    required this.packId,
    required this.toolName,
    this.input = const <String, Object?>{},
    this.runId,
  });

  final String packId;
  final String toolName;
  final String? runId;
  final JsonMap input;
}

abstract interface class ToolRegistry {
  void register(ToolDefinition definition);
  ToolDefinition? lookup(String name);
  Future<WnResult<JsonMap>> invoke(ToolInvocation invocation);
}

final class InMemoryToolRegistry implements ToolRegistry {
  final Map<String, ToolDefinition> _tools = <String, ToolDefinition>{};

  @override
  void register(ToolDefinition definition) {
    _tools[definition.name] = definition;
  }

  @override
  ToolDefinition? lookup(String name) => _tools[name];

  @override
  Future<WnResult<JsonMap>> invoke(ToolInvocation invocation) async {
    final definition = _tools[invocation.toolName];
    if (definition == null) {
      return WnResult<JsonMap>.err(
        WnFailure(
          code: 'tool_not_found',
          message: 'Tool is not registered: ${invocation.toolName}',
        ),
      );
    }
    final output = await definition.handler(invocation);
    return WnResult<JsonMap>.ok(immutableJsonMap(output));
  }
}
