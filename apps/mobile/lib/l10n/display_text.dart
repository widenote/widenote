import 'generated/app_localizations.dart';

String localizedSourceKind(AppLocalizations l10n, String kind) {
  return switch (kind.trim()) {
    'capture' || 'record' => l10n.timelineKindCapture,
    'card' => l10n.timelineKindCard,
    'insight' => l10n.timelineKindInsight,
    'memory' => l10n.timelineKindMemory,
    'todo' => l10n.timelineKindTodo,
    'event' => l10n.timelineKindEvent,
    'file' => l10n.sourceKindFile,
    'raw_text' => l10n.sourceKindRawText,
    'capture_attachment' => l10n.sourceKindAttachment,
    _ => kind,
  };
}

String localizedSourceLabel(AppLocalizations l10n, String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) {
    return trimmed;
  }
  if (trimmed == 'unknown source' || trimmed == 'source: unknown') {
    return l10n.sourceUnknownLabel;
  }

  final match = RegExp(
    r'^(source|event|capture|memory|todo|card|insight|file):\s*(.+)$',
  ).firstMatch(trimmed);
  if (match == null) {
    return trimmed;
  }

  final prefix = match.group(1)!;
  final value = match.group(2)!.trim();
  if (prefix == 'source') {
    return _localizedSourceBody(l10n, value);
  }
  return _sourceKindIdLabel(l10n, prefix, value);
}

String localizedMemoryType(AppLocalizations l10n, String value) {
  return switch (value.trim()) {
    'preference' => l10n.memoryTypePreference,
    'project' => l10n.memoryTypeProject,
    'person' => l10n.memoryTypePerson,
    'health' => l10n.memoryTypeHealth,
    'finance' => l10n.memoryTypeFinance,
    'location' => l10n.memoryTypeLocation,
    'credential' => l10n.memoryTypeCredential,
    'insight' => l10n.memoryTypeInsight,
    'task_context' || 'taskContext' => l10n.memoryTypeTaskContext,
    _ => value,
  };
}

String localizedConfidenceValue(AppLocalizations l10n, String value) {
  return switch (value.trim()) {
    'high' => l10n.confidenceHigh,
    'medium' => l10n.confidenceMedium,
    'low' => l10n.confidenceLow,
    _ => value,
  };
}

String localizedSensitivityValue(AppLocalizations l10n, String value) {
  return switch (value.trim()) {
    'high' => l10n.memorySensitivityHigh,
    'medium' => l10n.memorySensitivityMedium,
    'low' => l10n.memorySensitivityLow,
    _ => value,
  };
}

String localizedCardKindLabel(AppLocalizations l10n, String value) {
  return switch (value.trim()) {
    'capture card' || 'capture_summary' => l10n.cardKindCapture,
    'Memory card' || 'memory_summary' => l10n.cardKindMemory,
    _ => value,
  };
}

String localizedInsightKindLabel(AppLocalizations l10n, String value) {
  return switch (value.trim()) {
    'summary insight' || 'summary' => l10n.insightKindSummary,
    'count insight' || 'count' => l10n.insightKindCount,
    'trend insight' || 'trend' => l10n.insightKindTrend,
    'source mix insight' || 'source_mix' => l10n.insightKindSourceMix,
    'action pattern insight' ||
    'action_pattern' => l10n.insightKindActionPattern,
    'attachment evidence insight' ||
    'attachment_evidence' => l10n.insightKindAttachmentEvidence,
    _ => value,
  };
}

String localizedMetricLabel(AppLocalizations l10n, String value) {
  if (value.trim() == 'source-linked') {
    return l10n.insightMetricSourceLinked;
  }
  return value;
}

String localizedSourceLinkCount(AppLocalizations l10n, String value) {
  final match = RegExp(r'^(\d+) source link\(s\)$').firstMatch(value.trim());
  if (match == null) {
    return value;
  }
  return l10n.sourceLinkCount(int.parse(match.group(1)!));
}

String localizedTodoTitle(AppLocalizations l10n, String title) {
  if (title.startsWith('Follow up: ')) {
    return l10n.todoFollowUpTitle(title.substring('Follow up: '.length));
  }
  return switch (title) {
    'Review generated Memory before export' => l10n.todoSeedReviewMemory,
    'Confirm backup permission boundary' => l10n.todoSeedConfirmBackup,
    'Review capture' => l10n.todoReviewCaptureTitle,
    _ => title,
  };
}

String localizedTodoStatusLabel(AppLocalizations l10n, String statusLabel) {
  return switch (statusLabel.trim()) {
    'needs explicit permission' => l10n.todoStatusNeedsExplicitPermission,
    'suggested by agent' => l10n.todoStatusSuggestedByAgent,
    'not suggested' => l10n.todoStatusNotSuggested,
    'open' => l10n.todoStatusOpen,
    'completed' => l10n.todoStatusCompleted,
    _ => statusLabel,
  };
}

String localizedChatError(AppLocalizations l10n, String message) {
  return switch (message.trim()) {
    'Model access is not configured. Add a provider in Settings, then retry.' =>
      l10n.chatErrorModelNotConfigured,
    'The model returned no answer. Retry or choose another provider.' =>
      l10n.chatErrorModelEmptyAnswer,
    'The model is unavailable. Check provider settings or retry.' =>
      l10n.chatErrorModelUnavailable,
    _ => message,
  };
}

String localizedCaptureError(AppLocalizations l10n, String message) {
  final trimmed = message.trim();
  if (trimmed.startsWith('Voice recording failed: ')) {
    return l10n.captureVoiceFailed(
      localizedMediaMessage(
        l10n,
        trimmed.substring('Voice recording failed: '.length),
      ),
    );
  }
  if (trimmed.startsWith('Voice recording cancel failed: ')) {
    return l10n.captureVoiceCancelFailed(
      localizedMediaMessage(
        l10n,
        trimmed.substring('Voice recording cancel failed: '.length),
      ),
    );
  }
  if (trimmed.startsWith('Attachment failed: ')) {
    return l10n.captureAttachmentFailed(
      localizedMediaMessage(
        l10n,
        trimmed.substring('Attachment failed: '.length),
      ),
    );
  }
  if (trimmed.startsWith('Memory review failed: ')) {
    return l10n.captureMemoryReviewFailed(
      trimmed.substring('Memory review failed: '.length),
    );
  }
  return switch (trimmed) {
    'Review or remove pending attachments before saving.' =>
      l10n.captureReviewPendingAttachments,
    'Stop or cancel the voice recording before saving.' =>
      l10n.captureStopVoiceBeforeSaving,
    'Remove blocked attachments before saving.' =>
      l10n.captureRemoveBlockedAttachments,
    'Review attachments before saving.' => l10n.captureReviewAttachments,
    'Voice recording cancelled.' => l10n.captureVoiceCancelled,
    'Record saved locally. Configure a model provider or retry after agent recovery to generate Memory, cards, insights, and todos.' =>
      l10n.captureRecordSavedModelRequired,
    'Record saved locally, but agent processing failed. Retry after model or permission recovery.' =>
      l10n.captureRecordSavedAgentFailed,
    _ => localizedMediaMessage(l10n, message),
  };
}

String localizedMediaMessage(AppLocalizations l10n, String message) {
  return switch (message.trim()) {
    'Camera capture cancelled.' => l10n.captureCameraCancelled,
    'Gallery selection cancelled.' => l10n.captureGalleryCancelled,
    'Camera permission denied.' => l10n.captureCameraPermissionDenied,
    'Photo library permission denied.' =>
      l10n.capturePhotoLibraryPermissionDenied,
    'Microphone permission denied.' => l10n.captureMicrophonePermissionDenied,
    'Camera is unavailable on this device.' => l10n.captureCameraUnavailable,
    'Photo library is unavailable on this device.' =>
      l10n.capturePhotoLibraryUnavailable,
    'Microphone is unavailable on this device.' =>
      l10n.captureMicrophoneUnavailable,
    'Camera capture failed.' => l10n.captureCameraFailed,
    'Gallery selection failed.' => l10n.captureGalleryFailed,
    'Voice recording failed.' => l10n.captureVoiceFailedSimple,
    'Voice recording failed to start.' => l10n.captureVoiceFailedToStart,
    'Voice recording failed to stop.' => l10n.captureVoiceFailedToStop,
    'Voice recording cancel failed.' => l10n.captureVoiceCancelFailedSimple,
    'Voice recording file was not created.' => l10n.captureVoiceFileNotCreated,
    'Voice recording produced an empty file.' => l10n.captureVoiceEmptyFile,
    'Voice recording file was not returned.' =>
      l10n.captureVoiceFileNotReturned,
    _ => message,
  };
}

String localizedAttachmentReason(AppLocalizations l10n, String? reason) {
  final value = reason?.trim();
  if (value == null || value.isEmpty) {
    return l10n.captureAttachmentAssetSafetyReason;
  }
  if (value.startsWith('unsupported_mime_type:')) {
    return l10n.captureAttachmentUnsupportedMimeType(
      value.substring('unsupported_mime_type:'.length),
    );
  }
  return switch (value) {
    'blocked_by_asset_safety' => l10n.captureAttachmentBlockedBySafety,
    'voice_transcript_requires_review' =>
      l10n.captureAttachmentVoiceTranscriptNeedsReview,
    'allowed' => l10n.captureAttachmentAllowed,
    'asset safety' => l10n.captureAttachmentAssetSafetyReason,
    _ => value,
  };
}

String localizedAttachmentKind(AppLocalizations l10n, String kind) {
  return switch (kind.trim()) {
    'photo' => l10n.captureAttachmentKindPhoto,
    'voice' => l10n.captureAttachmentKindVoice,
    'share' => l10n.captureAttachmentKindShare,
    _ => kind,
  };
}

String localizedProviderSettingsError(AppLocalizations l10n, String message) {
  final trimmed = message.trim();
  if (trimmed.startsWith('Provider config invalid: ')) {
    return l10n.providerConfigInvalid(
      _stripTrailingPeriod(
        trimmed.substring('Provider config invalid: '.length),
      ),
    );
  }
  if (trimmed == 'Provider not found.') {
    return l10n.providerNotFound;
  }
  return message;
}

String localizedProviderConnectionMessage(
  AppLocalizations l10n,
  String message,
) {
  final trimmed = message.trim();
  final templates = <RegExp, String Function(RegExpMatch)>{
    RegExp(r'^(.+) validated offline\. No live request sent\.$'): (match) =>
        l10n.providerConnectionValidatedOffline(match.group(1)!),
    RegExp(r'^(.+) connection test succeeded\.$'): (match) =>
        l10n.providerConnectionSucceeded(match.group(1)!),
    RegExp(r'^(.+) configuration is incomplete: (.+)\.$'): (match) =>
        l10n.providerConnectionIncomplete(match.group(1)!, match.group(2)!),
    RegExp(
      r'^(.+) cannot run the chat connection probe with this capability set\.$',
    ): (match) =>
        l10n.providerConnectionUnsupportedProbe(match.group(1)!),
    RegExp(r'^(.+) connection test failed unexpectedly\.$'): (match) =>
        l10n.providerConnectionProviderUnexpectedFailure(match.group(1)!),
  };
  for (final entry in templates.entries) {
    final match = entry.key.firstMatch(trimmed);
    if (match != null) {
      return entry.value(match);
    }
  }
  return switch (trimmed) {
    'Testing connection...' => l10n.providerTestingConnectionMessage,
    'Provider connection test failed unexpectedly.' =>
      l10n.providerConnectionUnexpectedFailure,
    'Saved API key cleared. Add a key before testing.' =>
      l10n.providerSavedKeyClearedMessage,
    'Connection test has not run for these saved settings.' =>
      l10n.providerConnectionNotRunMessage,
    _ => message,
  };
}

String localizedBackupErrorDetails(AppLocalizations l10n, String details) {
  return switch (details.trim()) {
    'Invalid backup format.' => l10n.backupInvalidFormat,
    'Unsupported backup version.' => l10n.backupUnsupportedVersion,
    'No saved backup file found.' => l10n.backupNoSavedFile,
    'Backup conflicts with local data.' => l10n.backupLocalConflict,
    'Unexpected backup error.' => l10n.backupUnexpectedError,
    _ => details,
  };
}

String localizedRecapEntryTitle(AppLocalizations l10n, String title) {
  return switch (title.trim()) {
    'Record' => l10n.recapEntryRecordTitle,
    'Memory' => l10n.recapEntryMemoryTitle,
    'Open todo' => l10n.recapEntryOpenTodoTitle,
    'Completed todo' => l10n.recapEntryCompletedTodoTitle,
    'Untitled capture' => l10n.recapUntitledCapture,
    'Untitled todo' => l10n.recapUntitledTodo,
    _ => title,
  };
}

String localizedTimelineItemTitle(AppLocalizations l10n, String title) {
  return switch (title.trim()) {
    'Capture' => l10n.timelineKindCapture,
    'Memory' => l10n.timelineKindMemory,
    'Todo' => l10n.timelineKindTodo,
    'Untitled capture' => l10n.timelineUntitledCapture,
    'Untitled todo' => l10n.timelineUntitledTodo,
    _ => title,
  };
}

String localizedMemoryError(AppLocalizations l10n, String message) {
  return switch (message.trim()) {
    'Memory body cannot be empty.' => l10n.memoryBodyCannotBeEmpty,
    'Memory update failed.' => l10n.memoryUpdateFailed,
    _ => message,
  };
}

String localizedTodoError(AppLocalizations l10n, String message) {
  return switch (message.trim()) {
    'Todo update failed.' => l10n.todoUpdateFailed,
    _ => message,
  };
}

String _localizedSourceBody(AppLocalizations l10n, String body) {
  final extraMatch = RegExp(r'^(.*)\s+\+(\d+)$').firstMatch(body);
  final base = (extraMatch?.group(1) ?? body).trim();
  final extraCount = extraMatch == null
      ? null
      : int.parse(extraMatch.group(2)!);
  if (base == 'unknown') {
    return l10n.sourceUnknownLabel;
  }

  final separator = base.indexOf(':');
  if (separator > 0) {
    final kind = base.substring(0, separator).trim();
    final id = base.substring(separator + 1).trim();
    return _sourceKindIdLabel(l10n, kind, id, extraCount: extraCount);
  }
  final label = l10n.sourceLabel(base);
  return extraCount == null ? label : '$label +$extraCount';
}

String _sourceKindIdLabel(
  AppLocalizations l10n,
  String kind,
  String id, {
  int? extraCount,
}) {
  final kindLabel = localizedSourceKind(l10n, kind);
  if (extraCount != null) {
    return l10n.sourceKindIdExtraLabel(kindLabel, id, extraCount);
  }
  return l10n.sourceKindIdLabel(kindLabel, id);
}

String _stripTrailingPeriod(String value) {
  return value.endsWith('.') ? value.substring(0, value.length - 1) : value;
}
