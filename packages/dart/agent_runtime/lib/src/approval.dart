import 'run_mode.dart';
import 'tools.dart';

abstract interface class ApprovalBroker {
  Future<ApprovalDecision> requestApproval(ApprovalRequest request);
}

abstract interface class ApprovalStore {
  Future<void> saveRequest(ApprovalRequest request);
  Future<ApprovalRequest?> readRequest(String id);
  Future<List<ApprovalRequest>> readPending({
    DateTime? now,
    String? packId,
    String? runId,
  });
  Future<void> saveDecision(ApprovalDecision decision);
  Future<ApprovalDecision?> readDecision(String requestId);
}

final class PendingApprovalBroker implements ApprovalBroker {
  const PendingApprovalBroker(this.store);

  final ApprovalStore store;

  @override
  Future<ApprovalDecision> requestApproval(ApprovalRequest request) async {
    await store.saveRequest(request);
    return ApprovalDecision.pending(requestId: request.id);
  }
}

final class InMemoryApprovalStore implements ApprovalStore {
  final Map<String, ApprovalRequest> _requestsById =
      <String, ApprovalRequest>{};
  final Map<String, ApprovalDecision> _decisionsByRequestId =
      <String, ApprovalDecision>{};
  final List<String> _requestOrder = <String>[];

  @override
  Future<void> saveRequest(ApprovalRequest request) async {
    if (!_requestsById.containsKey(request.id)) {
      _requestOrder.add(request.id);
    }
    _requestsById[request.id] = request;
    _decisionsByRequestId.putIfAbsent(
      request.id,
      () => ApprovalDecision.pending(requestId: request.id),
    );
  }

  @override
  Future<ApprovalRequest?> readRequest(String id) async {
    return _requestsById[id];
  }

  @override
  Future<List<ApprovalRequest>> readPending({
    DateTime? now,
    String? packId,
    String? runId,
  }) async {
    return List<ApprovalRequest>.unmodifiable(
      _requestOrder
          .map((id) => _requestsById[id])
          .whereType<ApprovalRequest>()
          .where((request) => packId == null || request.packId == packId)
          .where((request) => runId == null || request.runId == runId)
          .where((request) {
            final decision = _decisionsByRequestId[request.id];
            if (decision?.state != ApprovalDecisionState.pending) {
              return false;
            }
            final expiresAt = request.expiresAt;
            return now == null || expiresAt == null || expiresAt.isAfter(now);
          }),
    );
  }

  @override
  Future<void> saveDecision(ApprovalDecision decision) async {
    if (!_requestsById.containsKey(decision.requestId)) {
      throw StateError('Approval request not found: ${decision.requestId}');
    }
    _decisionsByRequestId[decision.requestId] = decision;
  }

  @override
  Future<ApprovalDecision?> readDecision(String requestId) async {
    return _decisionsByRequestId[requestId];
  }
}

final class ApprovalRequest {
  ApprovalRequest({
    required this.id,
    required this.packId,
    required this.agentId,
    required this.taskId,
    required this.runId,
    required this.toolName,
    required this.runMode,
    required this.toolAccess,
    required this.toolRisk,
    required this.isExternal,
    required Iterable<String> requiredPermissions,
    required Iterable<String> inputKeys,
    required this.createdAt,
    Iterable<Object?> sourceRefs = const <Object?>[],
    this.actionSummary,
    this.expiresAt,
    this.reason,
  }) : requiredPermissions = List<String>.unmodifiable(requiredPermissions),
       inputKeys = List<String>.unmodifiable(inputKeys),
       sourceRefs = List<Object?>.unmodifiable(sourceRefs);

  final String id;
  final String packId;
  final String agentId;
  final String taskId;
  final String runId;
  final String toolName;
  final RunMode runMode;
  final ToolAccess toolAccess;
  final ToolRisk toolRisk;
  final bool isExternal;
  final List<String> requiredPermissions;
  final List<String> inputKeys;
  final DateTime createdAt;
  final List<Object?> sourceRefs;
  final String? actionSummary;
  final DateTime? expiresAt;
  final String? reason;

  bool get isHighRisk => toolRisk == ToolRisk.high;

  DateTime get requestedAt => createdAt;

  ApprovalRequest copyWith({
    Iterable<Object?>? sourceRefs,
    String? actionSummary,
    DateTime? expiresAt,
    String? reason,
  }) {
    return ApprovalRequest(
      id: id,
      packId: packId,
      agentId: agentId,
      taskId: taskId,
      runId: runId,
      toolName: toolName,
      runMode: runMode,
      toolAccess: toolAccess,
      toolRisk: toolRisk,
      isExternal: isExternal,
      requiredPermissions: requiredPermissions,
      inputKeys: inputKeys,
      createdAt: createdAt,
      sourceRefs: sourceRefs ?? this.sourceRefs,
      actionSummary: actionSummary ?? this.actionSummary,
      expiresAt: expiresAt ?? this.expiresAt,
      reason: reason ?? this.reason,
    );
  }
}

enum ApprovalDecisionState { pending, approved, denied, canceled, expired }

final class ApprovalDecision {
  const ApprovalDecision({
    required this.requestId,
    required this.state,
    this.reason,
    this.decidedAt,
  });

  const ApprovalDecision.approved({
    required String requestId,
    String? reason,
    DateTime? decidedAt,
  }) : this(
         requestId: requestId,
         state: ApprovalDecisionState.approved,
         reason: reason,
         decidedAt: decidedAt,
       );

  const ApprovalDecision.denied({
    required String requestId,
    String? reason,
    DateTime? decidedAt,
  }) : this(
         requestId: requestId,
         state: ApprovalDecisionState.denied,
         reason: reason,
         decidedAt: decidedAt,
       );

  final String requestId;
  final ApprovalDecisionState state;
  final String? reason;
  final DateTime? decidedAt;

  const ApprovalDecision.pending({
    required String requestId,
    String? reason,
    DateTime? decidedAt,
  }) : this(
         requestId: requestId,
         state: ApprovalDecisionState.pending,
         reason: reason,
         decidedAt: decidedAt,
       );

  bool get isApproved => state == ApprovalDecisionState.approved;
  bool get isPending => state == ApprovalDecisionState.pending;
  bool get isDenied => state == ApprovalDecisionState.denied;
  bool get isCanceled => state == ApprovalDecisionState.canceled;
  bool get isExpired => state == ApprovalDecisionState.expired;

  const ApprovalDecision.canceled({
    required String requestId,
    String? reason,
    DateTime? decidedAt,
  }) : this(
         requestId: requestId,
         state: ApprovalDecisionState.canceled,
         reason: reason,
         decidedAt: decidedAt,
       );

  const ApprovalDecision.expired({
    required String requestId,
    String? reason,
    DateTime? decidedAt,
  }) : this(
         requestId: requestId,
         state: ApprovalDecisionState.expired,
         reason: reason,
         decidedAt: decidedAt,
       );
}
