import 'package:widenote_core/widenote_core.dart';

typedef ToolHandler = Future<JsonMap> Function(ToolInvocation invocation);

enum ToolAccess { read, write }

enum ToolRisk { low, high }

enum ToolApprovalRequirement { automatic, always }

final class ToolDefinition {
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.handler,
    this.requiredPermissions = const <String>{},
    this.access = ToolAccess.read,
    this.external = false,
    this.risk = ToolRisk.low,
    this.approvalRequirement = ToolApprovalRequirement.automatic,
  });

  final String name;
  final String description;
  final Set<String> requiredPermissions;
  final ToolAccess access;
  final bool external;
  final ToolRisk risk;
  final ToolApprovalRequirement approvalRequirement;
  final ToolHandler handler;

  bool get mutates => access == ToolAccess.write;
  bool get isHighRisk => risk == ToolRisk.high;
  bool get isReadOnlySafe => !mutates && !external && !isHighRisk;

  bool get requiresExplicitApproval {
    return approvalRequirement == ToolApprovalRequirement.always ||
        external ||
        isHighRisk;
  }

  bool get requiresApproval {
    return requiresExplicitApproval || mutates;
  }

  bool get canAutoExecute {
    return !requiresExplicitApproval;
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
