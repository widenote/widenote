import 'memory_models.dart';

enum MemoryPolicyAction { autoAccept, review }

final class MemoryPolicyDecision {
  const MemoryPolicyDecision({required this.action, required this.reasons});

  final MemoryPolicyAction action;
  final List<String> reasons;

  bool get shouldAutoAccept => action == MemoryPolicyAction.autoAccept;
}

final class MemoryPolicyContext {
  const MemoryPolicyContext({required this.hasConflict});

  final bool hasConflict;
}

abstract interface class MemoryPolicy {
  MemoryPolicyDecision evaluate(
    MemoryProposal proposal,
    MemoryPolicyContext context,
  );
}

final class DefaultMemoryPolicy implements MemoryPolicy {
  const DefaultMemoryPolicy();

  static const _reviewOnlyTypes = <MemoryType>{
    MemoryType.credential,
    MemoryType.finance,
    MemoryType.health,
    MemoryType.location,
  };
  static const _policyUnclearReasons = <String>{
    'policy_unclear',
    'model_metadata_missing',
    'model_output_unstructured',
  };

  @override
  MemoryPolicyDecision evaluate(
    MemoryProposal proposal,
    MemoryPolicyContext context,
  ) {
    final reviewReasons = <String>[
      if (!proposal.hasEvidence) 'missing_evidence',
      if (context.hasConflict) 'conflict',
      if (_reviewOnlyTypes.contains(proposal.memoryType)) 'review_only_type',
      if (proposal.sensitivity != MemorySensitivity.low) 'sensitive',
      if (proposal.confidence == MemoryConfidence.low) 'low_confidence',
      if (proposal.durability != MemoryDurability.durable) 'not_durable',
      if (proposal.policyReasons.any(_policyUnclearReasons.contains))
        'policy_unclear',
    ];

    if (reviewReasons.isNotEmpty) {
      return MemoryPolicyDecision(
        action: MemoryPolicyAction.review,
        reasons: reviewReasons,
      );
    }

    return const MemoryPolicyDecision(
      action: MemoryPolicyAction.autoAccept,
      reasons: ['low_risk_durable_supported'],
    );
  }
}
