// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WideNote';

  @override
  String get tabHome => 'Home';

  @override
  String get tabChat => 'Chat';

  @override
  String get tabTodos => 'Todos';

  @override
  String get tabPlugins => 'Packs';

  @override
  String get homeSubtitle => 'quick capture -> timeline -> memory -> insight';

  @override
  String get homeOpenTimelineTooltip => 'Open Timeline';

  @override
  String get homeSearchTooltip => 'Search';

  @override
  String get homeOpenMemoryTooltip => 'Open Memory';

  @override
  String get homeOpenDailyRecapTooltip => 'Open Daily Recap';

  @override
  String get homeOpenSettingsTooltip => 'Open Settings';

  @override
  String get recapTitle => 'Daily Recap';

  @override
  String recapSubtitle(String date) {
    return 'Today from local object truth · $date';
  }

  @override
  String get recapBackTooltip => 'Close Daily Recap';

  @override
  String get recapUnavailableTitle => 'Daily Recap unavailable';

  @override
  String get recapEmptyTitle => 'Nothing recorded today yet.';

  @override
  String get recapEmptyBody =>
      'Capture a thought, voice draft, camera photo, or gallery image. Today\'s recap will stay source-linked here.';

  @override
  String get recapCapturesMetric => 'captures';

  @override
  String get recapMemoryMetric => 'Memory';

  @override
  String get recapTodoOpenMetric => 'open todos';

  @override
  String get recapTodoCompletedMetric => 'completed';

  @override
  String get recapCardsMetric => 'cards';

  @override
  String get recapInsightsMetric => 'insights';

  @override
  String get recapRecordsTitle => 'Records today';

  @override
  String get recapMemoryTitle => 'Memory today';

  @override
  String get recapTodosTitle => 'Todo activity';

  @override
  String get recapCardsTitle => 'Cards';

  @override
  String get recapInsightsTitle => 'Insights';

  @override
  String get recapSectionEmpty =>
      'No source-linked items in this section today.';

  @override
  String get recapEvidenceTitle => 'Local evidence';

  @override
  String recapEvidenceBody(int eventCount, int traceCount) {
    String _temp0 = intl.Intl.pluralLogic(
      eventCount,
      locale: localeName,
      other: '$eventCount events',
      one: '1 event',
    );
    String _temp1 = intl.Intl.pluralLogic(
      traceCount,
      locale: localeName,
      other: '$traceCount traces',
      one: '1 trace',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get quickCaptureTitle => 'Quick Capture';

  @override
  String get quickCaptureHint =>
      'Drop a thought, meeting note, promise, or raw memory...';

  @override
  String get captureModeText => 'Text';

  @override
  String get captureModeVoice => 'Voice';

  @override
  String get captureModeMedia => 'Media';

  @override
  String get captureModeTextTitle => 'Write first';

  @override
  String get captureModeTextBody =>
      'Fast local capture stays the default. Agents organize it after the raw record is saved.';

  @override
  String get captureVoiceHint =>
      'Add context while the voice recording is attached as local raw media...';

  @override
  String get captureVoiceTitle => 'Record voice';

  @override
  String get captureVoiceBody =>
      'WideNote requests microphone permission, stores the raw audio locally, and keeps transcript generation as a later agent step.';

  @override
  String get captureVoiceStartButton => 'Start recording';

  @override
  String get captureVoiceRecordingTitle => 'Recording';

  @override
  String get captureVoiceRecordingBody =>
      'Stop to attach the recording, or cancel to discard it without creating a record.';

  @override
  String get captureVoiceStopButton => 'Stop';

  @override
  String get captureVoiceCancelButton => 'Cancel';

  @override
  String get captureMediaHint =>
      'Add context for a camera photo or gallery image...';

  @override
  String get captureMediaTitle => 'Attach media';

  @override
  String get captureMediaBody =>
      'Camera and gallery use platform pickers. WideNote stores a local file reference, hash, and source metadata.';

  @override
  String get captureMediaCameraButton => 'Camera';

  @override
  String get captureMediaGalleryButton => 'Gallery';

  @override
  String get captureActionCamera => 'Camera';

  @override
  String get captureActionGallery => 'Gallery';

  @override
  String get captureActionVoice => 'Voice';

  @override
  String get captureUseTranscriptButton => 'Use transcript';

  @override
  String get captureRemoveAttachmentTooltip => 'Remove';

  @override
  String captureAttachmentReady(String preview) {
    return 'Ready · $preview';
  }

  @override
  String captureAttachmentNeedsReview(String preview) {
    return 'Transcript needs review · $preview';
  }

  @override
  String captureAttachmentBlocked(String reason) {
    return 'Blocked attachment · $reason · Preview hidden until review.';
  }

  @override
  String get captureEmptyMessage => 'Add text or an attachment before saving.';

  @override
  String get capturePhotoAttachedMessage =>
      'Photo attached. Review it, then save the record.';

  @override
  String get captureVoiceAttachedMessage =>
      'Voice draft attached. Review the transcript before saving.';

  @override
  String get captureShareAttachedMessage =>
      'Imported item attached. Review it, then save the record.';

  @override
  String get captureSavedMessage =>
      'Record saved. Local agents are organizing it now.';

  @override
  String get captureOpenTimelineAction => 'Timeline';

  @override
  String get recordButton => 'Record';

  @override
  String get recordButtonProcessing => 'Processing';

  @override
  String get stageProcessingTitle => 'Processing';

  @override
  String get stageProcessingRunning => 'running';

  @override
  String get stageProcessingIdle => 'idle';

  @override
  String stageProcessingProcessed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count processed',
      one: '1 processed',
    );
    return '$_temp0';
  }

  @override
  String get stageMemoryTitle => 'Memory';

  @override
  String get stageMemoryReady => 'ready';

  @override
  String stageMemoryAccepted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accepted',
      one: '1 accepted',
    );
    return '$_temp0';
  }

  @override
  String stageMemoryAcceptedReview(int acceptedCount, int reviewCount) {
    String _temp0 = intl.Intl.pluralLogic(
      acceptedCount,
      locale: localeName,
      other: '$acceptedCount accepted',
      one: '1 accepted',
    );
    String _temp1 = intl.Intl.pluralLogic(
      reviewCount,
      locale: localeName,
      other: '$reviewCount review',
      one: '1 review',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get stageCardsTitle => 'Cards';

  @override
  String get stageCardsWaiting => 'waiting';

  @override
  String stageCardsLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return '$_temp0';
  }

  @override
  String get stageInsightTitle => 'Insight';

  @override
  String get stageInsightDraftLane => 'draft lane';

  @override
  String get stageInsightWaiting => 'waiting';

  @override
  String stageInsightSourceLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count source-linked',
      one: '1 source-linked',
    );
    return '$_temp0';
  }

  @override
  String get stageTodoTitle => 'Todo';

  @override
  String stageTodoLinked(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count linked',
      one: '1 linked',
    );
    return '$_temp0';
  }

  @override
  String get cardsTitle => 'Cards';

  @override
  String get cardsEmpty => 'No source-linked cards yet.';

  @override
  String get insightsTitle => 'Insights';

  @override
  String get insightsEmpty => 'No source-linked insights yet.';

  @override
  String get recordsTitle => 'Records';

  @override
  String get recordsEmpty => 'No local records yet.';

  @override
  String get memoryReviewTitle => 'Memory Review';

  @override
  String get memoryReviewEmpty => 'No Memory candidates need review.';

  @override
  String get memoryReviewAccept => 'Accept';

  @override
  String get memoryReviewEdit => 'Edit';

  @override
  String get memoryReviewReject => 'Reject';

  @override
  String get memoryEditTitle => 'Edit Memory';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get saveButton => 'Save';

  @override
  String get memoryTitle => 'Memory';

  @override
  String get memoryEmpty => 'Memory queue is waiting for first capture.';

  @override
  String get memoryPageTitle => 'Memory';

  @override
  String get memoryPageSubtitle =>
      'Edit, tombstone, restore, and inspect local Memory with source links.';

  @override
  String get memorySearchHint =>
      'Search Memory body, type, status, or source...';

  @override
  String get memoryActiveSectionTitle => 'Active Memory';

  @override
  String get memoryActiveEmpty => 'No active Memory yet.';

  @override
  String get memoryDeletedSectionTitle => 'Deleted Memory';

  @override
  String get memoryDeletedEmpty => 'No tombstoned Memory.';

  @override
  String get memoryActionEdit => 'Edit';

  @override
  String get memoryActionDelete => 'Delete';

  @override
  String get memoryActionRestore => 'Restore';

  @override
  String memoryRevisionLabel(int revision) {
    return 'rev $revision';
  }

  @override
  String get traceTitle => 'Trace';

  @override
  String get traceEmpty =>
      'Local runtime events appear here after captures or pack runs.';

  @override
  String get recordStatusSavedProcessing => 'Saved locally, processing';

  @override
  String get recordStatusProcessed => 'Processed locally';

  @override
  String get recordStatusAgentFailed => 'Saved locally, agent failed';

  @override
  String get memoryAutoSavedTitle => 'Memory saved automatically';

  @override
  String get memoryNeedsReviewTitle => 'Memory needs review';

  @override
  String get memorySavedTitle => 'Memory saved';

  @override
  String get statusAutoAccepted => 'auto-accepted';

  @override
  String get statusNeedsReview => 'needs review';

  @override
  String get statusAccepted => 'accepted';

  @override
  String confidenceLabel(String confidence) {
    return '$confidence confidence';
  }

  @override
  String get confidenceHigh => 'high';

  @override
  String get confidenceMedium => 'medium';

  @override
  String get confidenceLow => 'low';

  @override
  String todoFollowUpTitle(String body) {
    return 'Follow up: $body';
  }

  @override
  String get todoSeedReviewMemory => 'Review generated Memory before export';

  @override
  String get todoSeedConfirmBackup => 'Confirm backup permission boundary';

  @override
  String todoSourceLabel(String sourceId) {
    return 'source: $sourceId';
  }

  @override
  String get todoStatusNeedsExplicitPermission => 'needs explicit permission';

  @override
  String get todoStatusSuggestedByAgent => 'suggested by agent';

  @override
  String get todoStatusOpen => 'open';

  @override
  String get todoStatusCompleted => 'completed';

  @override
  String get todoActionComplete => 'Complete';

  @override
  String get todoActionReopen => 'Reopen';

  @override
  String get chatTitle => 'Chat';

  @override
  String get chatSubtitle =>
      'Ask WideNote with local Memory, records, and todos as context.';

  @override
  String get chatSessionsTitle => 'Sessions';

  @override
  String get chatDailyReviewTitle => 'Daily review';

  @override
  String get chatDailyReviewSubtitle =>
      'Ask about today, linked records, and pending todos.';

  @override
  String get chatMemoryQaTitle => 'Memory QA';

  @override
  String get chatMemoryQaSubtitle =>
      'Query editable local Memory with visible provenance.';

  @override
  String get chatAgentPackSandboxTitle => 'Agent Pack sandbox';

  @override
  String get chatAgentPackSandboxSubtitle =>
      'Try pack actions after permission review.';

  @override
  String get chatInputTitle => 'Input';

  @override
  String get chatInputHint =>
      'Ask WideNote about a record, Memory item, or pack run...';

  @override
  String get chatLoadErrorTitle => 'Chat failed to load';

  @override
  String get chatLoadErrorBody =>
      'The local chat could not be opened. Please try again.';

  @override
  String get chatHistoryTitle => 'History';

  @override
  String get chatEmptySessions => 'No local sessions yet.';

  @override
  String get chatSessionSwitchDisabled =>
      'Wait for the current answer before switching sessions.';

  @override
  String get chatLocalConversationTitle => 'Local chat';

  @override
  String get chatEmptyConversation =>
      'Ask a question about records, Memory, or todos.';

  @override
  String get chatSendFailed => 'Send failed';

  @override
  String get retryButton => 'Retry';

  @override
  String get chatSourcesTitle => 'Sources';

  @override
  String get chatTyping => 'Answering with local context...';

  @override
  String get chatComposerTitle => 'Ask';

  @override
  String get chatComposerHint => 'Ask about local records, Memory, or todos...';

  @override
  String get chatSendButton => 'Send';

  @override
  String get chatGeneratingButton => 'Generating';

  @override
  String get chatAssistantEmptyReply =>
      'I don\'t have local records to cite yet. Add captures first, then I can answer from Memory, records, and todos.';

  @override
  String chatAssistantContextReply(int count, String lead, String sources) {
    return 'I found $count local context item(s). $lead\n\n$sources';
  }

  @override
  String chatAssistantLeadTodo(String excerpt) {
    return 'The closest match is a todo: $excerpt';
  }

  @override
  String chatAssistantLeadMemory(String excerpt) {
    return 'The closest match is a Memory item: $excerpt';
  }

  @override
  String chatAssistantLeadCapture(String excerpt) {
    return 'The closest match is a raw record: $excerpt';
  }

  @override
  String chatAssistantLeadGeneric(String excerpt) {
    return 'The closest match is: $excerpt';
  }

  @override
  String get chatContextMemoryTitle => 'Memory';

  @override
  String get chatContextRecordTitle => 'Record';

  @override
  String get chatContextTodoTitle => 'Todo';

  @override
  String get chatContextUntitledCapture => 'Untitled local capture';

  @override
  String get chatContextUntitledTodo => 'Untitled todo suggestion';

  @override
  String get todosTitle => 'Todos';

  @override
  String get todosSubtitle =>
      'Source-linked actions with visible record provenance.';

  @override
  String get todosSurfaceTitle => 'Source-linked todos';

  @override
  String get todosEmpty => 'No source-linked todos yet.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle =>
      'Privacy, permissions, models, backup, and traces.';

  @override
  String get settingsBackTooltip => 'Close Settings';

  @override
  String get settingsPrivacyTitle => 'Privacy';

  @override
  String get settingsPrivacyLocalFirstTitle => 'Local-first core';

  @override
  String get settingsPrivacyLocalFirstBody =>
      'Records, Memory, todos, cards, chat, and traces stay on this device unless you choose backup, sync, or a provider.';

  @override
  String get settingsPrivacyLocalFirstStatus => 'no account';

  @override
  String get settingsPrivacyPermissionsTitle => 'Revocable permissions';

  @override
  String get settingsPrivacyPermissionsBody =>
      'Built-in packs use narrow permissions; high-risk file, network, and script capabilities stay deferred until explicit approval exists.';

  @override
  String get settingsPrivacyPermissionsStatus => 'reviewable';

  @override
  String get settingsPrivacyBackupTitle => 'Backup secrets boundary';

  @override
  String get settingsPrivacyBackupBody =>
      'Safe export omits provider API keys. Encrypted full backup is the future secret-bearing restore path and has no action in this build.';

  @override
  String get settingsPrivacyBackupStatus => 'safe export';

  @override
  String get settingsControlsTitle => 'Controls';

  @override
  String get settingsPermissionsTitle => 'Privacy & Permissions';

  @override
  String get settingsPermissionsSubtitle =>
      'Review available pack permissions and deferred high-risk capabilities.';

  @override
  String get settingsPermissionsStatus => 'explicit';

  @override
  String settingsPermissionsStatusSummary(
    int availableCount,
    int deferredCount,
  ) {
    return '$availableCount available / $deferredCount deferred';
  }

  @override
  String get settingsModelProvidersTitle => 'Model Providers';

  @override
  String get settingsModelProvidersSubtitle =>
      'Configure local or BYOK model access for runtime and Agent Packs.';

  @override
  String get settingsBackupTitle => 'Backup & Restore';

  @override
  String get settingsBackupSubtitle =>
      'Export or import local records, Memory, cards, providers, todos, and traces.';

  @override
  String get settingsBackupStatus => 'local';

  @override
  String get settingsBackupStatusSafeOnly => 'safe only';

  @override
  String get settingsBackupStatusExportReady => 'export ready';

  @override
  String get settingsBackupStatusRestored => 'restored';

  @override
  String get settingsBackupStatusNeedsReview => 'review needed';

  @override
  String get settingsTraceConsoleTitle => 'Trace Console';

  @override
  String get settingsTraceConsoleSubtitle =>
      'Inspect local Agent Runtime runs, permission checks, and generated outputs.';

  @override
  String get settingsTraceConsoleStatus => 'read-only';

  @override
  String settingsTraceConsoleStatusSummary(int eventCount, int warningCount) {
    return '$eventCount events / $warningCount warnings';
  }

  @override
  String get pluginsTitle => 'Packs';

  @override
  String get pluginsSubtitle =>
      'Pack controls for permissions, models, backup, and traces.';

  @override
  String get pluginsControlEntriesTitle => 'Control entries';

  @override
  String get pluginsPackLibraryTitle => 'Pack Library';

  @override
  String get pluginsPackLibrarySubtitle =>
      'Install, inspect, and disable Agent Packs.';

  @override
  String get pluginsPackLibraryStatus => 'available';

  @override
  String get pluginsPermissionGateTitle => 'Permission Gate';

  @override
  String get pluginsPermissionGateSubtitle =>
      'Review sensitive capabilities before a pack can run.';

  @override
  String get pluginsPermissionGateStatus => 'explicit';

  @override
  String get pluginsModelProviderTitle => 'Model Provider';

  @override
  String get pluginsModelProviderSubtitle =>
      'Configure local or BYOK model access.';

  @override
  String get pluginsModelProviderStatus => 'not connected';

  @override
  String pluginsModelProviderConfigured(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count providers',
      one: '1 provider',
    );
    return '$_temp0';
  }

  @override
  String get pluginsBackupTitle => 'Backup';

  @override
  String get pluginsBackupSubtitle =>
      'Export or import the local WideNote backup.';

  @override
  String get pluginsBackupStatus => 'local-first';

  @override
  String get pluginsTraceConsoleTitle => 'Trace Console';

  @override
  String get pluginsTraceConsoleSubtitle =>
      'Inspect pack runs, permissions, and generated outputs.';

  @override
  String get pluginsTraceConsoleStatus => 'trace-ready';

  @override
  String get packLibraryTitle => 'Pack Library';

  @override
  String get packLibrarySubtitle =>
      'Inspect built-in official Agent Packs before dynamic installs exist.';

  @override
  String get packLibraryInstalledTitle => 'Installed official packs';

  @override
  String packLibraryVersion(String version) {
    return 'v$version';
  }

  @override
  String packLibraryPermissionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count permissions',
      one: '1 permission',
    );
    return '$_temp0';
  }

  @override
  String packLibraryOutputCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count outputs',
      one: '1 output',
    );
    return '$_temp0';
  }

  @override
  String get permissionGateTitle => 'Permission Gate';

  @override
  String get permissionGateSubtitle =>
      'Review local pack permission state and deferred high-risk capabilities.';

  @override
  String get permissionGateGrantedTitle => 'Built-in and available permissions';

  @override
  String get permissionGateDeferredTitle => 'Deferred high-risk permissions';

  @override
  String get permissionGateStatusAvailable => 'Built-in / available';

  @override
  String get permissionGateStatusGranted => 'Granted locally';

  @override
  String get permissionGateStatusDenied => 'Denied locally';

  @override
  String get permissionGateStatusRevoked => 'Revoked locally';

  @override
  String get permissionGateActionGrant => 'Grant';

  @override
  String get permissionGateActionDeny => 'Deny';

  @override
  String get permissionGateActionRevoke => 'Revoke';

  @override
  String get permissionGateActionDeferred => 'Deferred';

  @override
  String get agentPlatformTitle => 'Agent Observability';

  @override
  String get agentPlatformSubtitle =>
      'Read-only local runtime evidence from real trace events.';

  @override
  String get traceConsoleTitle => 'Trace Console';

  @override
  String get traceConsoleSubtitle =>
      'Inspect local Agent Runtime runs, permissions, and generated outputs.';

  @override
  String get traceConsoleSummaryTitle => 'Runtime summary';

  @override
  String traceConsoleEventCount(int count) {
    return 'Trace events: $count';
  }

  @override
  String traceConsoleRunCount(int count) {
    return 'Runs: $count';
  }

  @override
  String traceConsoleWarningCount(int count) {
    return 'Warnings: $count';
  }

  @override
  String get traceConsoleRefreshButton => 'Refresh';

  @override
  String get traceConsoleOpenButton => 'Open trace console';

  @override
  String get traceConsoleEventsTitle => 'Events';

  @override
  String get traceConsoleEmpty =>
      'No runtime traces yet. Capture or pack runs will appear here.';

  @override
  String get traceConsoleNoMessage => 'No message recorded.';

  @override
  String traceConsoleRun(String runId) {
    return 'run: $runId';
  }

  @override
  String traceConsolePack(String packId) {
    return 'pack: $packId';
  }

  @override
  String traceConsoleAgent(String agentId) {
    return 'agent: $agentId';
  }

  @override
  String traceConsoleDuration(num duration) {
    return 'duration: $duration ms';
  }

  @override
  String get providerSettingsTitle => 'Model Providers';

  @override
  String get providerSettingsSubtitle =>
      'Choose how WideNote agents reach models, what the default runtime model is, and which capabilities are safe to use.';

  @override
  String get providerSettingsAdd => 'Add provider';

  @override
  String get providerSettingsListTitle => 'Providers';

  @override
  String get providerSettingsEmpty => 'No providers configured.';

  @override
  String get providerSettingsDefaultTag => 'Default';

  @override
  String get providerSettingsStatusTitle => 'Runtime model access';

  @override
  String providerSettingsStatusConfigured(String provider) {
    return 'Using $provider';
  }

  @override
  String get providerSettingsStatusNotConfigured => 'Offline fallback active';

  @override
  String get providerSettingsStatusDescriptionConfigured =>
      'Capture, chat, and Agent Packs use this default unless a later role override says otherwise.';

  @override
  String get providerSettingsStatusDescriptionOffline =>
      'Core capture still works locally with deterministic summaries. Add a BYOK provider when you want live model calls.';

  @override
  String providerSettingsProviderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count providers',
      one: '1 provider',
    );
    return '$_temp0';
  }

  @override
  String get providerSettingsRolesTitle => 'Model roles';

  @override
  String get providerSettingsRolesDescription =>
      'WideNote keeps provider credentials separate from runtime roles so future Agent Packs can route safely.';

  @override
  String get providerSettingsTextRoleTitle => 'Default text model';

  @override
  String get providerSettingsTextRoleDescription =>
      'Used by capture summaries, chat answers, Memory extraction, and built-in Agent Packs in this slice.';

  @override
  String get providerSettingsAgentRoleTitle => 'Per-Agent overrides';

  @override
  String get providerSettingsAgentRoleDescription =>
      'Not enabled yet. For now, all built-in agents inherit the default model.';

  @override
  String get providerSettingsRoleFallback => 'Local deterministic fallback';

  @override
  String get providerSettingsCapabilitiesTitle => 'Capabilities and privacy';

  @override
  String get providerSettingsCapabilitiesDescription =>
      'Connection tests are user-initiated. API keys stay local and are included only in user-managed backups.';

  @override
  String get providerSettingsCapabilityChat => 'Chat';

  @override
  String get providerSettingsCapabilityCompletion => 'Completion';

  @override
  String get providerSettingsCapabilityOfflineFallback => 'Offline fallback';

  @override
  String get providerSettingsCapabilityByok => 'BYOK local storage';

  @override
  String get providerClearKeyTitle => 'Clear saved API key';

  @override
  String get providerClearKeySubtitle =>
      'Leave unchecked and keep this field blank to keep the saved key.';

  @override
  String get providerConnectionUntested => 'Untested';

  @override
  String get providerConnectionTesting => 'Testing';

  @override
  String get providerConnectionConnected => 'Connected';

  @override
  String get providerConnectionFailed => 'Failed';

  @override
  String get providerActionSetDefault => 'Set default';

  @override
  String get providerActionTestConnection => 'Test connection';

  @override
  String get providerActionEdit => 'Edit provider';

  @override
  String get providerDialogAddTitle => 'Add provider';

  @override
  String get providerDialogEditTitle => 'Edit provider';

  @override
  String get providerFieldProviderType => 'Provider type';

  @override
  String get providerFieldDisplayName => 'Display name';

  @override
  String get providerFieldEndpoint => 'Endpoint';

  @override
  String get providerFieldModel => 'Model';

  @override
  String get providerFieldApiKey => 'API key';

  @override
  String get providerApiKeyKeepSessionHelper =>
      'Leave blank to keep the session credential.';

  @override
  String get providerInvalidEndpoint => 'Endpoint is not a valid URI.';

  @override
  String get providerSaveFailed => 'Provider could not be saved.';

  @override
  String get backupTitle => 'Backup';

  @override
  String get backupSubtitle =>
      'Export and import local records, Memory, cards, chat, providers, todos, and trace data.';

  @override
  String get backupIdleStatus =>
      'Local data stays on this device until you export or paste a backup.';

  @override
  String get backupExportReadyStatus => 'Safe backup JSON is ready.';

  @override
  String get backupSavedFileStatus => 'Backup files saved locally.';

  @override
  String get backupImportDoneStatus => 'Backup imported into local storage.';

  @override
  String backupFailedStatus(String details) {
    return 'Backup failed: $details';
  }

  @override
  String get backupExportSectionTitle => 'Export and restore boundary';

  @override
  String get backupExportButton => 'Export safe restore JSON';

  @override
  String get backupExportEmpty =>
      'Export creates a safe, versioned restore JSON and a readable Owner Export Markdown projection.';

  @override
  String get backupSecretWarning =>
      'Safe export omits provider API keys. Re-enter provider keys after restore.';

  @override
  String get backupSafeRestoreBoundary =>
      'Safe restore JSON brings back records, Memory, todos, provider metadata, pack installs, permissions, runtime state, and traces. Provider keys are omitted.';

  @override
  String get backupOwnerExportBoundary =>
      'Owner Export Markdown is for reading and moving your data. It excludes secrets and is not a restore source.';

  @override
  String get backupFullSecretBoundary =>
      'Encrypted full backup will be the secret-bearing path for restoring API keys. It has no action in this build.';

  @override
  String backupSafeOmittedProviderKeys(int count) {
    return 'Provider keys omitted from safe export: $count';
  }

  @override
  String get backupManifestCountsTitle => 'Manifest counts';

  @override
  String backupCount(String section, int count) {
    return '$section: $count';
  }

  @override
  String get backupCopyJsonButton => 'Copy JSON';

  @override
  String get backupCopyMarkdownButton => 'Copy Markdown';

  @override
  String get backupSaveFilesButton => 'Save files';

  @override
  String get backupSavedJsonPath => 'JSON file';

  @override
  String get backupSavedMarkdownPath => 'Markdown file';

  @override
  String get backupCopiedStatus => 'Export copied.';

  @override
  String get backupExportJsonTitle => 'Safe backup JSON';

  @override
  String get backupExportMarkdownTitle => 'Owner Export Markdown';

  @override
  String get backupImportSectionTitle => 'Import';

  @override
  String get backupImportHint => 'Paste a WideNote local backup JSON...';

  @override
  String get backupImportButton => 'Import backup';

  @override
  String get backupImportLatestFileButton => 'Import latest saved file';

  @override
  String backupImportNeedsProviderKeys(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Provider metadata restored. Re-enter $count provider keys before model calls can use them.',
      one:
          'Provider metadata restored. Re-enter 1 provider key before model calls can use it.',
    );
    return '$_temp0';
  }

  @override
  String get backupImportSecretsRestored =>
      'Secret-bearing backup restored provider credentials.';

  @override
  String get backupImportNoProviderKeysNeeded =>
      'No provider keys need re-entry for this backup.';
}
