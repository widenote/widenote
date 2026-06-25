// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'WideNote / 广记';

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
  String get quickCaptureTitle => 'Quick Capture';

  @override
  String get quickCaptureHint =>
      'Drop a thought, meeting note, promise, or raw memory...';

  @override
  String get captureModeText => 'Text';

  @override
  String get captureModeVoice => 'Voice draft';

  @override
  String get captureModeImport => 'Import';

  @override
  String get captureModeTextTitle => 'Write first';

  @override
  String get captureModeTextBody =>
      'Fast local capture stays the default. Agents organize it after the raw record is saved.';

  @override
  String get captureVoiceHint =>
      'Add optional context while a voice draft waits for transcript review...';

  @override
  String get captureVoiceDraftTitle => 'Voice draft';

  @override
  String get captureVoiceDraftBody =>
      'This slice uses a transcript draft adapter. No microphone permission starts here; save only after review.';

  @override
  String get captureVoiceDraftButton => 'Add voice draft';

  @override
  String get captureImportHint =>
      'Add context for an imported photo, link, or file...';

  @override
  String get captureImportTitle => 'Bring material in';

  @override
  String get captureImportBody =>
      'Attach a photo or shared item, keep the raw source, then let WideNote create source-linked Memory.';

  @override
  String get captureImportPhotoButton => 'Add photo';

  @override
  String get captureImportShareButton => 'Import item';

  @override
  String get captureActionPhoto => 'Photo';

  @override
  String get captureActionVoice => 'Voice';

  @override
  String get captureActionImport => 'Import';

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
      'Review built-in pack permissions and deferred high-risk capabilities.';

  @override
  String get permissionGateGrantedTitle => 'Granted built-in permissions';

  @override
  String get permissionGateDeferredTitle => 'Deferred high-risk permissions';

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
      'Local provider setup for runtime and Agent Pack model access.';

  @override
  String get providerSettingsAdd => 'Add provider';

  @override
  String get providerSettingsListTitle => 'Providers';

  @override
  String get providerSettingsEmpty => 'No providers configured.';

  @override
  String get providerSettingsDefaultTag => 'Default';

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
  String get backupExportReadyStatus => 'Backup JSON is ready.';

  @override
  String get backupSavedFileStatus => 'Backup files saved locally.';

  @override
  String get backupImportDoneStatus => 'Backup imported into local storage.';

  @override
  String backupFailedStatus(String details) {
    return 'Backup failed: $details';
  }

  @override
  String get backupExportSectionTitle => 'Export';

  @override
  String get backupExportButton => 'Export JSON';

  @override
  String get backupExportEmpty =>
      'Export creates a versioned local backup JSON with manifest counts.';

  @override
  String get backupSecretWarning =>
      'Backups include provider API keys. Keep exported JSON private.';

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
  String get backupExportJsonTitle => 'Backup JSON';

  @override
  String get backupExportMarkdownTitle => 'Readable Markdown';

  @override
  String get backupImportSectionTitle => 'Import';

  @override
  String get backupImportHint => 'Paste a WideNote local backup JSON...';

  @override
  String get backupImportButton => 'Import backup';

  @override
  String get backupImportLatestFileButton => 'Import latest saved file';
}
