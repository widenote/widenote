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
  String get tabRecord => 'Record';

  @override
  String get tabTodos => 'Todos';

  @override
  String get tabPlugins => 'Packs';

  @override
  String get homeSubtitle => 'new records -> timeline -> memory -> insight';

  @override
  String homeTodaySubtitle(String date) {
    return '$date · local-first';
  }

  @override
  String get homeOpenTimelineTooltip => 'Open Timeline';

  @override
  String get homeSearchTooltip => 'Search';

  @override
  String get homeOpenMemoryTooltip => 'Open Memory';

  @override
  String get homeOpenDailyRecapTooltip => 'Open Daily Recap';

  @override
  String get homeOpenInsightsTooltip => 'Open Insights';

  @override
  String get homeOpenSettingsTooltip => 'Open Settings';

  @override
  String get homeNewRecordTitle => 'New record';

  @override
  String get homeNewRecordBody =>
      'Write a focused note, then attach photos or local source files.';

  @override
  String get homeBackgroundVoiceTitle => 'Background voice';

  @override
  String get homeBackgroundVoiceBody =>
      'Record audio in the background, then add context before saving.';

  @override
  String get homeBackgroundVoiceActiveBody => 'Recording is already running.';

  @override
  String get homeBackgroundVoiceActiveAction => 'Recording';

  @override
  String get homeSummaryRecords => 'Records';

  @override
  String get homeSummaryMemory => 'Memory';

  @override
  String get homeSummaryInsights => 'Insights';

  @override
  String get homeTodayRecapTitle => 'Today recap';

  @override
  String get homeOpenRecapAction => 'Open';

  @override
  String homeTodayRecapBody(int recordCount, int memoryCount, int todoCount) {
    String _temp0 = intl.Intl.pluralLogic(
      recordCount,
      locale: localeName,
      other: '$recordCount records',
      one: '1 record',
      zero: 'No records yet',
    );
    String _temp1 = intl.Intl.pluralLogic(
      memoryCount,
      locale: localeName,
      other: '$memoryCount Memory items',
      one: '1 Memory item',
      zero: 'Memory ready',
    );
    String _temp2 = intl.Intl.pluralLogic(
      todoCount,
      locale: localeName,
      other: '$todoCount todos',
      one: '1 todo',
      zero: 'no open todos',
    );
    return '$_temp0 · $_temp1 · $_temp2';
  }

  @override
  String get homeRecentRecordsTitle => 'Recent records';

  @override
  String get homeOpenAllRecordsAction => 'All';

  @override
  String get homeInsightTeaserTitle => 'Insight teaser';

  @override
  String get homeOpenInsightsAction => 'Insights';

  @override
  String get homeInsightTeaserEmpty =>
      'Insights will appear after a few source-linked records.';

  @override
  String get homeInsightAskHint => 'Ask in Chat';

  @override
  String get homeContinueRecordingTitle => 'Continue recording';

  @override
  String get homeContinueRecordingBody =>
      'Use the same local compose sheet from Home or the center Record action.';

  @override
  String get homeContinueRecordingAction => 'New record';

  @override
  String get newRecordTitle => 'New record';

  @override
  String get newRecordSubtitle =>
      'Original input stays local and is never overwritten by AI.';

  @override
  String get newRecordHint =>
      'Write a thought, feeling, project context, meeting fragment, or life event...';

  @override
  String get saveRecordButton => 'Save record';

  @override
  String get backgroundVoiceActiveTitle => 'Recording in background';

  @override
  String get backgroundVoiceActiveBody =>
      'Audio is being preserved as local source material. Stop to review the draft and add context.';

  @override
  String get backgroundVoiceTimerPlaceholder => 'REC';

  @override
  String get backgroundVoiceComposerBusy =>
      'A background recording is still running. Stop it before saving this record.';

  @override
  String get voicePreviewListening => 'Listening...';

  @override
  String get voicePreviewUnavailable =>
      'Live transcript preview is unavailable. Audio is still being saved locally.';

  @override
  String voicePreviewDraft(String text) {
    return 'Draft transcript: $text';
  }

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
  String get recapEntryRecordTitle => 'Record';

  @override
  String get recapEntryMemoryTitle => 'Memory';

  @override
  String get recapEntryOpenTodoTitle => 'Open todo';

  @override
  String get recapEntryCompletedTodoTitle => 'Completed todo';

  @override
  String get recapUntitledCapture => 'Untitled capture';

  @override
  String get recapUntitledTodo => 'Untitled todo';

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
  String get captureAttachmentAssetSafetyReason => 'asset safety';

  @override
  String get captureAttachmentBlockedBySafety => 'blocked by asset safety';

  @override
  String captureAttachmentUnsupportedMimeType(String mimeType) {
    return 'unsupported file type: $mimeType';
  }

  @override
  String get captureAttachmentVoiceTranscriptNeedsReview =>
      'voice transcript needs review';

  @override
  String get captureAttachmentAllowed => 'allowed';

  @override
  String get captureAttachmentKindPhoto => 'photo';

  @override
  String get captureAttachmentKindVoice => 'voice';

  @override
  String get captureAttachmentKindShare => 'shared item';

  @override
  String get captureAttachmentFallbackName => 'attachment';

  @override
  String captureAttachmentSummary(String kind, String name) {
    return '$kind: $name';
  }

  @override
  String captureBlockedAttachmentSummary(String name) {
    return 'Blocked attachment: $name';
  }

  @override
  String get captureEmptyMessage => 'Add text or an attachment before saving.';

  @override
  String get captureReviewPendingAttachments =>
      'Review or remove pending attachments before saving.';

  @override
  String get captureStopVoiceBeforeSaving =>
      'Stop or cancel the voice recording before saving.';

  @override
  String get captureRemoveBlockedAttachments =>
      'Remove blocked attachments before saving.';

  @override
  String get captureReviewAttachments => 'Review attachments before saving.';

  @override
  String captureVoiceFailed(String details) {
    return 'Voice recording failed: $details';
  }

  @override
  String get captureVoiceCancelled => 'Voice recording cancelled.';

  @override
  String captureVoiceCancelFailed(String details) {
    return 'Voice recording cancel failed: $details';
  }

  @override
  String captureAttachmentFailed(String details) {
    return 'Attachment failed: $details';
  }

  @override
  String get captureCameraCancelled => 'Camera capture cancelled.';

  @override
  String get captureGalleryCancelled => 'Gallery selection cancelled.';

  @override
  String get captureCameraPermissionDenied => 'Camera permission denied.';

  @override
  String get capturePhotoLibraryPermissionDenied =>
      'Photo library permission denied.';

  @override
  String get captureMicrophonePermissionDenied =>
      'Microphone permission denied.';

  @override
  String get captureCameraUnavailable =>
      'Camera is unavailable on this device.';

  @override
  String get capturePhotoLibraryUnavailable =>
      'Photo library is unavailable on this device.';

  @override
  String get captureMicrophoneUnavailable =>
      'Microphone is unavailable on this device.';

  @override
  String get captureCameraFailed => 'Camera capture failed.';

  @override
  String get captureGalleryFailed => 'Gallery selection failed.';

  @override
  String get captureVoiceFailedSimple => 'Voice recording failed.';

  @override
  String get captureVoiceFailedToStart => 'Voice recording failed to start.';

  @override
  String get captureVoiceFailedToStop => 'Voice recording failed to stop.';

  @override
  String get captureVoiceCancelFailedSimple => 'Voice recording cancel failed.';

  @override
  String get captureVoiceFileNotCreated =>
      'Voice recording file was not created.';

  @override
  String get captureVoiceEmptyFile => 'Voice recording produced an empty file.';

  @override
  String get captureVoiceFileNotReturned =>
      'Voice recording file was not returned.';

  @override
  String get captureRecordSavedModelRequired =>
      'Record saved locally. Configure a model provider or retry after agent recovery to generate Memory, cards, insights, and todos.';

  @override
  String get captureRecordSavedAgentFailed =>
      'Record saved locally, but agent processing failed. Retry after model or permission recovery.';

  @override
  String captureMemoryReviewFailed(String details) {
    return 'Memory review failed: $details';
  }

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
  String get memorySearchHint => 'Text search needs a retriever...';

  @override
  String get memoryTextSearchRequiresRetriever =>
      'Text search needs a model-backed retriever. Clear the field to browse Memory locally.';

  @override
  String get memoryTextSearchClearHint =>
      'Clear the text field to browse Memory locally.';

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
  String get memoryBodyCannotBeEmpty => 'Memory body cannot be empty.';

  @override
  String get memoryUpdateFailed => 'Memory update failed.';

  @override
  String get memoryTypePreference => 'preference';

  @override
  String get memoryTypeProject => 'project';

  @override
  String get memoryTypePerson => 'person';

  @override
  String get memoryTypeHealth => 'health';

  @override
  String get memoryTypeFinance => 'finance';

  @override
  String get memoryTypeLocation => 'location';

  @override
  String get memoryTypeCredential => 'credential';

  @override
  String get memoryTypeInsight => 'insight';

  @override
  String get memoryTypeTaskContext => 'task context';

  @override
  String get memorySensitivityLow => 'low sensitivity';

  @override
  String get memorySensitivityMedium => 'medium sensitivity';

  @override
  String get memorySensitivityHigh => 'high sensitivity';

  @override
  String get cardKindCapture => 'capture card';

  @override
  String get cardKindMemory => 'Memory card';

  @override
  String get insightKindSummary => 'summary insight';

  @override
  String get insightKindCount => 'count insight';

  @override
  String get insightKindTrend => 'trend insight';

  @override
  String get insightKindSourceMix => 'source mix insight';

  @override
  String get insightKindActionPattern => 'action pattern insight';

  @override
  String get insightKindAttachmentEvidence => 'attachment evidence insight';

  @override
  String get insightMetricSourceLinked => 'source-linked';

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
  String get todoReviewCaptureTitle => 'Review capture';

  @override
  String todoSourceLabel(String sourceId) {
    return 'source: $sourceId';
  }

  @override
  String sourceLabel(String sourceId) {
    return 'source: $sourceId';
  }

  @override
  String sourceKindIdLabel(String kind, String sourceId) {
    return '$kind: $sourceId';
  }

  @override
  String sourceKindIdExtraLabel(String kind, String sourceId, int extraCount) {
    return '$kind: $sourceId +$extraCount';
  }

  @override
  String get sourceUnknownLabel => 'unknown source';

  @override
  String get sourceKindRawText => 'raw text';

  @override
  String get sourceKindAttachment => 'attachment';

  @override
  String get sourceKindFile => 'file';

  @override
  String get attachmentArtifactStatusPending => 'pending';

  @override
  String get attachmentArtifactStatusReady => 'ready';

  @override
  String get attachmentArtifactStatusFailed => 'failed';

  @override
  String get attachmentArtifactStatusBlocked => 'blocked';

  @override
  String get attachmentArtifactStatusNeedsReview => 'needs review';

  @override
  String get attachmentArtifactKindAudioTranscript => 'audio transcript';

  @override
  String get attachmentArtifactKindImageDerivatives => 'image artifact';

  @override
  String get attachmentArtifactKindOcrText => 'OCR text';

  @override
  String get attachmentArtifactKindVisionSummary => 'image summary';

  @override
  String get attachmentArtifactKindSharedText => 'shared text';

  @override
  String get timelineAttachmentArtifactsTitle => 'Attachment artifacts';

  @override
  String sourceLinkCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count source links',
      one: '1 source link',
    );
    return '$_temp0';
  }

  @override
  String localTimeLabel(String time) {
    return '$time local';
  }

  @override
  String get todoStatusNeedsExplicitPermission => 'needs explicit permission';

  @override
  String get todoStatusSuggestedByAgent => 'suggested by agent';

  @override
  String get todoStatusNotSuggested => 'not suggested';

  @override
  String get todoStatusOpen => 'open';

  @override
  String get todoStatusCompleted => 'completed';

  @override
  String get todoActionComplete => 'Complete';

  @override
  String get todoActionReopen => 'Reopen';

  @override
  String get todoUpdateFailed => 'Todo update failed.';

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
  String get chatNewSessionButton => 'New chat';

  @override
  String get chatNewSessionTooltip => 'Start a new chat';

  @override
  String get chatConversationListTitle => 'Conversations';

  @override
  String get chatActiveSessionLabel => 'Current chat';

  @override
  String get chatDefaultSessionTitle => 'New chat';

  @override
  String chatSessionMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
      zero: 'Empty',
    );
    return '$_temp0';
  }

  @override
  String get chatSessionActionsTooltip => 'Chat actions';

  @override
  String get chatRenameSessionAction => 'Rename';

  @override
  String get chatDeleteSessionAction => 'Delete';

  @override
  String get chatRenameSessionTitle => 'Rename chat';

  @override
  String get chatRenameSessionHint => 'Chat title';

  @override
  String get chatDeleteSessionTitle => 'Delete chat?';

  @override
  String get chatDeleteSessionBody =>
      'This removes the local chat and its messages from this device.';

  @override
  String get chatDeleteSessionConfirm => 'Delete';

  @override
  String get chatSessionDeletedSnackbar => 'Chat deleted.';

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
  String get chatContextMemoryTitle => 'Memory';

  @override
  String get chatContextRecordTitle => 'Record';

  @override
  String get chatContextTodoTitle => 'Todo';

  @override
  String get chatContextCardTitle => 'Card';

  @override
  String get chatContextInsightTitle => 'Insight';

  @override
  String get chatContextRedactedTitle => 'Redacted source';

  @override
  String get chatContextUntitledCapture => 'Untitled local capture';

  @override
  String get chatContextUntitledTodo => 'Untitled todo suggestion';

  @override
  String get chatErrorModelNotConfigured =>
      'Model access is not configured. Add a provider in Settings, then retry.';

  @override
  String get chatErrorModelEmptyAnswer =>
      'The model returned no answer. Retry or choose another provider.';

  @override
  String get chatErrorModelUnavailable =>
      'The model is unavailable. Check provider settings or retry.';

  @override
  String get todosTitle => 'Actions';

  @override
  String get todosSubtitle =>
      'Source-linked action items and schedule candidates, separated from ordinary records.';

  @override
  String get todosSurfaceTitle => 'Source-linked todos';

  @override
  String get todosEmpty => 'No source-linked todos yet.';

  @override
  String get todoActionsSectionTitle => 'Action items';

  @override
  String get todoActionsEmpty => 'No clear action items yet.';

  @override
  String get todoSchedulesSectionTitle => 'Schedule candidates';

  @override
  String get todoSchedulesEmpty => 'No schedule candidates yet.';

  @override
  String get todoStatusSuggestedAction => 'Suggested action';

  @override
  String get todoStatusScheduleCandidate => 'Schedule candidate';

  @override
  String get todoQuietTitle => 'Kept out of actions';

  @override
  String todoQuietSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '# records did not have clear action or schedule intent. They stay on the timeline.',
      one:
          '# record did not have a clear action or schedule intent. It stays on the timeline.',
    );
    return '$_temp0';
  }

  @override
  String todoScheduledForLabel(String time) {
    return 'Time cue: $time';
  }

  @override
  String get timelineTitle => 'Timeline';

  @override
  String get timelineSubtitle =>
      'Browse captures, cards, Memory, insights, and todos.';

  @override
  String get timelineSearchTooltip => 'Search timeline';

  @override
  String get timelineBackTooltip => 'Back to timeline';

  @override
  String timelineLoadFailed(String error) {
    return 'Timeline failed to load: $error';
  }

  @override
  String get timelineUnavailableTitle => 'Timeline unavailable';

  @override
  String get timelineEmptyTitle => 'No timeline items yet';

  @override
  String get timelineEmptyBody =>
      'Capture something locally to create source-linked cards.';

  @override
  String get timelineUntitledCapture => 'Untitled capture';

  @override
  String get timelineUntitledTodo => 'Untitled todo';

  @override
  String get timelineStartCaptureButton => 'Start capture';

  @override
  String get timelineSearchTitle => 'Search';

  @override
  String get timelineSearchSubtitle =>
      'Filter the local timeline without leaving the device.';

  @override
  String get timelineSearchUnavailableTitle => 'Search unavailable';

  @override
  String timelineSearchFailed(String error) {
    return 'Timeline search failed: $error';
  }

  @override
  String get timelineSearchHint =>
      'Filter by type, or use text after retriever setup';

  @override
  String get timelineFilterAll => 'All';

  @override
  String get timelineSearchEmptyTitle => 'Nothing to search yet';

  @override
  String get timelineSearchEmptyBody =>
      'Create a capture first, then browse cards, Memory, and todos.';

  @override
  String get timelineSearchNeedsRetrieverTitle =>
      'Text search needs a retriever';

  @override
  String get timelineSearchNeedsRetrieverBody =>
      'Clear the text field to browse locally by type. Semantic search will use a model-backed retriever.';

  @override
  String get timelineSearchNoResultsTitle => 'No matching timeline items';

  @override
  String get timelineSearchNoResultsBody =>
      'Remove the type filter to show more local items.';

  @override
  String timelineSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String get timelineKindCapture => 'Capture';

  @override
  String get timelineKindCaptures => 'Captures';

  @override
  String get timelineKindCard => 'Card';

  @override
  String get timelineKindCards => 'Cards';

  @override
  String get timelineKindInsight => 'Insight';

  @override
  String get timelineKindInsights => 'Insights';

  @override
  String get timelineKindMemory => 'Memory';

  @override
  String get timelineKindTodo => 'Todo';

  @override
  String get timelineKindTodos => 'Todos';

  @override
  String get timelineKindEvent => 'Event';

  @override
  String timelineKindDetailTitle(String kind) {
    return '$kind Detail';
  }

  @override
  String get timelineCardDetailTitle => 'Card Detail';

  @override
  String get timelineCardDetailSubtitle =>
      'Inspect the card body, provenance, and related items.';

  @override
  String get timelineCardUnavailableTitle => 'Card unavailable';

  @override
  String timelineCardFailed(String error) {
    return 'Card detail failed: $error';
  }

  @override
  String get timelineCardNotFoundTitle => 'Card not found';

  @override
  String get timelineCardNotFoundBody =>
      'The selected card is not in the current local timeline.';

  @override
  String get timelineSourceRefsTitle => 'Source refs';

  @override
  String get timelineRelatedRecordsTitle => 'Related records';

  @override
  String get timelineRelatedMemoryTitle => 'Related Memory';

  @override
  String get timelineRelatedTodosTitle => 'Related todos';

  @override
  String get timelineNoLinkedItems => 'No linked items.';

  @override
  String get timelineItemDetailTitle => 'Timeline Detail';

  @override
  String get timelineItemDetailSubtitle =>
      'Inspect the local item, status, metadata, and sources.';

  @override
  String get timelineItemUnavailableTitle => 'Timeline item unavailable';

  @override
  String timelineItemFailed(String error) {
    return 'Timeline item failed: $error';
  }

  @override
  String get timelineSourceNotFoundTitle => 'Source not found';

  @override
  String get timelineSourceNotFoundBody =>
      'This source reference is not available in the current local index yet.';

  @override
  String get timelineStatusTitle => 'Status';

  @override
  String get timelineMetadataTitle => 'Metadata';

  @override
  String get timelineOpenSourceTooltip => 'Open source';

  @override
  String timelineSourceRefCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count source refs',
      one: '1 source ref',
    );
    return '$_temp0';
  }

  @override
  String get timelineStatusActive => 'active';

  @override
  String get timelineStatusDeleted => 'deleted';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSubtitle =>
      'Privacy, permissions, models, backup, and logs.';

  @override
  String get settingsBackTooltip => 'Back from Settings';

  @override
  String get settingsPrivacyTitle => 'Privacy';

  @override
  String get settingsPrivacyLocalFirstTitle => 'Local-first core';

  @override
  String get settingsPrivacyLocalFirstBody =>
      'Records, Memory, todos, cards, chat, and logs stay on this device unless you choose backup, sync, or a provider.';

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
      'Full .widenote backups include provider and allowlisted secure-storage keys so restore can use configured features immediately. Keep backup files in a trusted location.';

  @override
  String get settingsPrivacyBackupStatus => 'full backup';

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
  String get settingsSystemPermissionsTitle => 'System Permissions';

  @override
  String get settingsSystemPermissionsSubtitle =>
      'Check camera, microphone, location, photos, files, and calendar access.';

  @override
  String get settingsSystemPermissionsStatus => 'device';

  @override
  String get settingsModelProvidersTitle => 'Model Providers';

  @override
  String get settingsModelProvidersSubtitle =>
      'Configure local or BYOK model access for runtime and Agent Packs.';

  @override
  String get settingsTranscriptionTitle => 'Voice Transcription';

  @override
  String get settingsTranscriptionSubtitle =>
      'Configure local SenseVoice, MiMo ASR, live preview, and transcript correction.';

  @override
  String get settingsTranscriptionStatusLoading => 'loading';

  @override
  String get settingsTranscriptionStatusLocal => 'local';

  @override
  String get settingsTranscriptionStatusRemote => 'MiMo';

  @override
  String get settingsTranscriptionStatusNeedsSetup => 'setup';

  @override
  String get settingsBackupTitle => 'Backup & Restore';

  @override
  String get settingsBackupSubtitle =>
      'Export or import local records, Memory, cards, providers, todos, and logs.';

  @override
  String get settingsBackupStatus => 'local';

  @override
  String get settingsBackupStatusSafeOnly => 'full local';

  @override
  String get settingsBackupStatusExportReady => 'export ready';

  @override
  String get settingsBackupStatusRestored => 'restored';

  @override
  String get settingsBackupStatusNeedsReview => 'review needed';

  @override
  String get settingsTraceConsoleTitle => 'Log Center';

  @override
  String get settingsTraceConsoleSubtitle =>
      'Review local Agent Runtime logs, permission checks, and generated outputs.';

  @override
  String get settingsTraceConsoleStatus => 'read-only';

  @override
  String settingsTraceConsoleStatusSummary(int eventCount, int warningCount) {
    return '$eventCount events / $warningCount warnings';
  }

  @override
  String get systemPermissionsTitle => 'System Permissions';

  @override
  String get systemPermissionsSubtitle =>
      'Review app-level device permissions and jump to the right system setting when needed.';

  @override
  String get systemPermissionsBackTooltip => 'Back from System Permissions';

  @override
  String get systemPermissionsLoading => 'Checking permissions';

  @override
  String get systemPermissionsError => 'Permission status unavailable';

  @override
  String get systemPermissionsSummaryTitle => 'Device status';

  @override
  String systemPermissionsSummary(int grantedCount, int reviewCount) {
    return '$grantedCount ready / $reviewCount need attention';
  }

  @override
  String get systemPermissionsPlatformAndroid => 'Android';

  @override
  String get systemPermissionsPlatformIos => 'iOS';

  @override
  String get systemPermissionsPlatformOther => 'mobile only';

  @override
  String get systemPermissionsRefreshAction => 'Refresh';

  @override
  String get systemPermissionsDeviceAccessTitle => 'App access';

  @override
  String get systemPermissionsStatusGranted => 'allowed';

  @override
  String get systemPermissionsStatusLimited => 'limited';

  @override
  String get systemPermissionsStatusDenied => 'not allowed';

  @override
  String get systemPermissionsStatusPermanentlyDenied => 'settings';

  @override
  String get systemPermissionsStatusRestricted => 'restricted';

  @override
  String get systemPermissionsStatusNotRequired => 'picker';

  @override
  String get systemPermissionsStatusNotConfigured => 'not enabled';

  @override
  String get systemPermissionsStatusNotSupported => 'unsupported';

  @override
  String get systemPermissionsStatusUnknown => 'unknown';

  @override
  String get systemPermissionsStatusServiceOff => 'service off';

  @override
  String get systemPermissionsActionRequest => 'Request';

  @override
  String get systemPermissionsActionManage => 'Manage';

  @override
  String get systemPermissionsActionOpenSettings => 'Settings';

  @override
  String get systemPermissionsLocationServiceOffBody =>
      'Location services are off at the system level.';

  @override
  String get systemPermissionsCameraTitle => 'Camera';

  @override
  String get systemPermissionsCameraSubtitle =>
      'Used only when you capture a local photo attachment.';

  @override
  String get systemPermissionsMicrophoneTitle => 'Microphone';

  @override
  String get systemPermissionsMicrophoneSubtitle =>
      'Used only when you save local voice recordings.';

  @override
  String get systemPermissionsLocationTitle => 'Location';

  @override
  String get systemPermissionsLocationSubtitle =>
      'Used only for foreground GPS metadata after Location Context is enabled.';

  @override
  String get systemPermissionsPhotosTitle => 'Photos & Media';

  @override
  String get systemPermissionsPhotosSubtitle =>
      'On iOS, review selected photo library access for local media attachments.';

  @override
  String get systemPermissionsPhotosAndroidSubtitle =>
      'On Android, WideNote uses the system photo picker without broad media permission.';

  @override
  String get systemPermissionsFilesTitle => 'Files';

  @override
  String get systemPermissionsFilesSubtitle =>
      'Backups and imports use system document pickers without broad file access.';

  @override
  String get systemPermissionsCalendarTitle => 'Calendar';

  @override
  String get systemPermissionsCalendarSubtitle =>
      'System calendar read/write is not enabled until a follow-up permission decision lands.';

  @override
  String get pluginsTitle => 'Packs';

  @override
  String get pluginsSubtitle =>
      'Pack controls for permissions, models, backup, and logs.';

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
  String get pluginsTraceConsoleTitle => 'Agent Console';

  @override
  String get pluginsTraceConsoleSubtitle =>
      'Inspect local runs, approvals, traces, and pack output.';

  @override
  String get pluginsTraceConsoleStatus => 'local';

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
  String packLibraryEnabledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count enabled',
      one: '1 enabled',
    );
    return '$_temp0';
  }

  @override
  String packLibraryDisabledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count disabled',
      one: '1 disabled',
    );
    return '$_temp0';
  }

  @override
  String get packLibraryDisableImpact =>
      'Disabling affects future local tasks only. It does not delete records, traces, or derived outputs already stored on this device.';

  @override
  String packLibraryPublisher(String publisher) {
    return 'publisher: $publisher';
  }

  @override
  String packLibraryEdition(String edition) {
    return 'edition: $edition';
  }

  @override
  String packLibraryMarketplaceSource(String source) {
    return 'source: $source';
  }

  @override
  String packLibraryTrustLevel(String trust) {
    return 'trust: $trust';
  }

  @override
  String packLibraryCategories(String categories) {
    return 'categories: $categories';
  }

  @override
  String packLibraryCapabilities(String capabilities) {
    return 'capabilities: $capabilities';
  }

  @override
  String packLibraryReplacementSlots(String slots) {
    return 'replacement slots: $slots';
  }

  @override
  String packLibraryAdditiveSlots(String slots) {
    return 'additive slots: $slots';
  }

  @override
  String packLibraryEntrypoint(String entrypoint) {
    return 'runtime: $entrypoint';
  }

  @override
  String packLibrarySubscriptionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count subscriptions',
      one: '1 subscription',
    );
    return '$_temp0';
  }

  @override
  String packLibraryFailureCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count failures',
      one: '1 failure',
    );
    return '$_temp0';
  }

  @override
  String packLibraryPermissionDecisionSummary(
    int granted,
    int denied,
    int revoked,
  ) {
    return 'permissions: $granted granted / $denied denied / $revoked revoked';
  }

  @override
  String packLibraryLastFailure(String message) {
    return 'Last failure: $message';
  }

  @override
  String get packLibraryStatusEnabled => 'enabled';

  @override
  String get packLibraryStatusDisabled => 'disabled';

  @override
  String packLibraryStatusUnknown(String status) {
    return 'status: $status';
  }

  @override
  String get packLibraryRuntimeIdle => 'runtime: idle';

  @override
  String get packLibraryRuntimeQueued => 'runtime: queued';

  @override
  String get packLibraryRuntimeRunning => 'runtime: running';

  @override
  String get packLibraryRuntimeSucceeded => 'runtime: succeeded';

  @override
  String get packLibraryRuntimeFailed => 'runtime: failed';

  @override
  String get packLibraryRuntimeDenied => 'runtime: denied';

  @override
  String get packLibraryRuntimeCanceled => 'runtime: canceled';

  @override
  String get packLibraryRuntimeBlocked => 'runtime: blocked';

  @override
  String packLibraryRuntimeUnknown(String status) {
    return 'runtime: $status';
  }

  @override
  String get packDefaultName => 'Default Capture Loop';

  @override
  String get packDefaultDescription =>
      'Conservative built-in pack for capture cards, Memory candidates, and lightweight insight.';

  @override
  String get packTodoName => 'Todo Extraction Loop';

  @override
  String get packTodoDescription =>
      'Built-in pack for source-linked todo suggestions.';

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
  String get permissionGateImpactAvailable =>
      'Grant or deny changes future local runs only.';

  @override
  String get permissionGateImpactGranted =>
      'Future local runs may use this permission until you revoke it.';

  @override
  String get permissionGateImpactDenied =>
      'Future local runs needing this permission are blocked; existing records and traces remain.';

  @override
  String get permissionGateImpactRevoked =>
      'Revocation blocks future use; existing records, traces, and derived outputs remain for review.';

  @override
  String get permissionGateImpactDeferred =>
      'This high-risk or external capability is disabled in the local L3 slice.';

  @override
  String get permissionGateRiskLow => 'low risk';

  @override
  String get permissionGateRiskMedium => 'medium risk';

  @override
  String get permissionGateRiskHigh => 'high risk';

  @override
  String get permissionGateCommunityPacks => 'community packs';

  @override
  String get permissionGateMediaPacks => 'media packs';

  @override
  String get permissionGateContextPacks => 'context packs';

  @override
  String get permissionGateDeferredSandbox =>
      'Deferred until sandbox approval exists.';

  @override
  String get permissionGateDeferredExternalTools =>
      'Deferred until external-tool permission design exists.';

  @override
  String get permissionGateDeferredPlatform =>
      'Deferred until platform permission review exists.';

  @override
  String get permissionGateDeferredPrivacy =>
      'Deferred until privacy decision coverage exists.';

  @override
  String get agentPlatformTitle => 'Agent Console';

  @override
  String get agentPlatformSubtitle =>
      'Local runtime control evidence from runs, tasks, approvals, and traces.';

  @override
  String get agentConsoleTitle => 'Agent Console';

  @override
  String get agentConsoleSubtitle =>
      'Local-first control for runs, tasks, approvals, packs, and redacted traces.';

  @override
  String get traceConsoleTitle => 'Agent Console';

  @override
  String get traceConsoleSubtitle =>
      'Review local Agent Runtime runs, permissions, and generated outputs.';

  @override
  String get agentConsoleSummaryTitle => 'Local control summary';

  @override
  String get traceConsoleSummaryTitle => 'Runtime summary';

  @override
  String traceConsoleEventCount(int count) {
    return 'Log events: $count';
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
  String get traceConsoleOpenButton => 'Open Agent Console';

  @override
  String get traceConsoleEventsTitle => 'Events';

  @override
  String get traceConsoleEmpty =>
      'No runtime logs yet. Capture or pack runs will appear here.';

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
  String agentConsoleTotalCount(int count) {
    return 'Total: $count';
  }

  @override
  String agentConsoleActiveCount(int count) {
    return 'Active: $count';
  }

  @override
  String agentConsoleFailedCount(int count) {
    return 'Failed: $count';
  }

  @override
  String agentConsoleDeniedCount(int count) {
    return 'Denied: $count';
  }

  @override
  String agentConsoleBlockedCount(int count) {
    return 'Blocked: $count';
  }

  @override
  String agentConsoleTaskCount(int count) {
    return 'Tasks: $count';
  }

  @override
  String agentConsolePendingApprovalCount(int count) {
    return 'Approvals: $count';
  }

  @override
  String get agentConsoleFilterTitle => 'Status filter';

  @override
  String get agentConsoleFilterAll => 'All';

  @override
  String get agentConsoleFilterActive => 'Active';

  @override
  String get agentConsoleFilterFailed => 'Failed';

  @override
  String get agentConsoleFilterDenied => 'Denied';

  @override
  String get agentConsoleFilterBlocked => 'Blocked';

  @override
  String get approvalQueueTitle => 'Approval Queue';

  @override
  String get approvalQueueEmpty => 'No pending local action approvals.';

  @override
  String get approvalQueueScaffoldBody =>
      'Approval requests will stay paused here once a persisted approval store is available. This page does not approve or deny fake runtime work.';

  @override
  String get agentConsoleRunsTitle => 'Runs';

  @override
  String get agentConsoleRunsEmpty => 'No local runs match this filter.';

  @override
  String get agentConsoleTasksTitle => 'Tasks';

  @override
  String get agentConsoleTasksEmpty => 'No local tasks match this filter.';

  @override
  String agentConsoleStatus(String status) {
    return 'status: $status';
  }

  @override
  String agentConsoleSeverity(String severity) {
    return 'severity: $severity';
  }

  @override
  String agentConsoleTask(String taskId) {
    return 'task: $taskId';
  }

  @override
  String agentConsoleEvent(String eventId) {
    return 'event: $eventId';
  }

  @override
  String agentConsoleParentTrace(String traceId) {
    return 'parent trace: $traceId';
  }

  @override
  String agentConsoleAttempt(int attempt) {
    return 'attempt: $attempt';
  }

  @override
  String agentConsoleTaskAttempts(int attempts, int maxAttempts) {
    return 'attempts: $attempts/$maxAttempts';
  }

  @override
  String agentConsoleMissingDependencies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count missing dependencies',
      one: '1 missing dependency',
    );
    return '$_temp0';
  }

  @override
  String agentConsoleOutputCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count outputs',
      one: '1 output',
    );
    return '$_temp0';
  }

  @override
  String agentConsoleStarted(String time) {
    return 'started: $time';
  }

  @override
  String agentConsoleCompleted(String time) {
    return 'completed: $time';
  }

  @override
  String agentConsoleCreated(String time) {
    return 'created: $time';
  }

  @override
  String get agentConsoleNotCompleted => 'not completed';

  @override
  String agentConsoleError(String message) {
    return 'Error: $message';
  }

  @override
  String get agentConsoleRetryAction => 'Retry';

  @override
  String get agentConsoleCancelAction => 'Cancel';

  @override
  String get agentConsoleControlsUnavailable =>
      'Retry and cancel are disabled until the mobile app exposes a live RuntimeKernel control provider. No fake success is performed here.';

  @override
  String get agentConsoleRunTracesTitle => 'Trace list';

  @override
  String get agentConsoleRunNoTraces => 'No traces recorded for this run yet.';

  @override
  String get agentConsoleRunModeReadOnly => 'run mode: read-only';

  @override
  String get agentConsoleRunModeConfirm => 'run mode: confirm';

  @override
  String get agentConsoleRunModeAuto => 'run mode: auto';

  @override
  String get agentConsoleRunModeUnknown => 'run mode: unknown';

  @override
  String agentConsoleChildDelegation(String delegationId) {
    return 'delegation: $delegationId';
  }

  @override
  String agentConsoleChildRun(String runId) {
    return 'child run: $runId';
  }

  @override
  String agentConsoleChildStatus(String status) {
    return 'child status: $status';
  }

  @override
  String agentConsoleDelegationViolations(String codes) {
    return 'violations: $codes';
  }

  @override
  String get traceConsoleOpenSourceButton => 'Open source';

  @override
  String get traceConsoleNoSource =>
      'No source reference is available for this trace.';

  @override
  String get traceConsolePayloadTitle => 'Redacted payload';

  @override
  String get traceConsolePayloadEmpty => 'No payload recorded.';

  @override
  String traceConsolePayloadRedactedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sensitive fields redacted',
      one: '1 sensitive field redacted',
    );
    return '$_temp0';
  }

  @override
  String get traceConsoleRedactedValue => '[redacted]';

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
  String get providerSettingsStatusNotConfigured => 'Model not configured';

  @override
  String get providerSettingsStatusDescriptionConfigured =>
      'Chat and model-backed Agent Pack work use this default unless a later role override says otherwise. Capture still saves raw records locally.';

  @override
  String get providerSettingsStatusDescriptionOffline =>
      'Core capture still saves raw records locally. Chat answers and semantic model work require a configured BYOK provider.';

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
      'Used by chat answers and model-backed Agent Pack work in this slice.';

  @override
  String get providerSettingsAgentRoleTitle => 'Per-Agent overrides';

  @override
  String get providerSettingsAgentRoleDescription =>
      'Not enabled yet. For now, all built-in agents inherit the default model.';

  @override
  String get providerSettingsRoleFallback => 'Requires configured model';

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
  String get providerSettingsCapabilityOfflineFallback => 'Local raw capture';

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
  String get providerActionDelete => 'Delete provider';

  @override
  String get providerDeleteTitle => 'Delete provider?';

  @override
  String providerDeleteBody(String provider) {
    return 'Remove \"$provider\" from local model settings.';
  }

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
  String get providerApiKeyOptionalHelper =>
      'Optional for this provider; fill it only if your local server requires one.';

  @override
  String get providerEndpointPresetHelper =>
      'Preset from the provider docs; edit it if your account uses another region or gateway.';

  @override
  String get providerModelPresetHelper =>
      'Fetch models from the provider, then choose one from the list; use custom only when needed.';

  @override
  String get providerFetchModelsTooltip => 'Fetch available models';

  @override
  String get providerModelCustomOption => 'Custom model ID';

  @override
  String get providerModelCustomHelper =>
      'Use this when the provider does not return the model you need.';

  @override
  String get providerModelFetchRequiresApiKey =>
      'Add an API key before fetching this provider\'s models.';

  @override
  String get providerModelFetchEmpty =>
      'No models were returned. Keep the current model or enter a custom ID.';

  @override
  String get providerModelFetchFailed =>
      'Could not fetch models. Check the endpoint, key, and network.';

  @override
  String get providerModelFetchAuthenticationFailed =>
      'Model fetch authentication failed. Check the API key and account access.';

  @override
  String get providerModelFetchRateLimited =>
      'Model fetch was rate limited. Try again later.';

  @override
  String get providerModelFetchTimedOut =>
      'Model fetch timed out. Check the endpoint and network.';

  @override
  String get providerModelFetchServerFailed =>
      'The provider returned a server error while fetching models.';

  @override
  String get providerInvalidEndpoint => 'Endpoint is not a valid URI.';

  @override
  String get providerSaveFailed => 'Provider could not be saved.';

  @override
  String providerConfigInvalid(String details) {
    return 'Provider config invalid: $details.';
  }

  @override
  String get providerNotFound => 'Provider not found.';

  @override
  String get providerTestingConnectionMessage => 'Testing connection...';

  @override
  String get providerConnectionUnexpectedFailure =>
      'Provider connection test failed unexpectedly.';

  @override
  String get providerSavedKeyClearedMessage =>
      'Saved API key cleared. Add a key before testing.';

  @override
  String get providerConnectionNotRunMessage =>
      'Connection test has not run for these saved settings.';

  @override
  String providerConnectionValidatedOffline(String provider) {
    return '$provider validated offline. No live request sent.';
  }

  @override
  String providerConnectionSucceeded(String provider) {
    return '$provider connection test succeeded.';
  }

  @override
  String providerConnectionIncomplete(String provider, String details) {
    return '$provider configuration is incomplete: $details.';
  }

  @override
  String providerConnectionUnsupportedProbe(String provider) {
    return '$provider cannot run the chat connection probe with this capability set.';
  }

  @override
  String providerConnectionProviderUnexpectedFailure(String provider) {
    return '$provider connection test failed unexpectedly.';
  }

  @override
  String get voiceSettingsTitle => 'Voice Transcription';

  @override
  String get voiceSettingsSubtitle =>
      'Save original audio locally, use transcript text for records, and keep correction evidence source-linked.';

  @override
  String voiceSettingsLoadFailed(String details) {
    return 'Voice transcription settings could not load: $details';
  }

  @override
  String get voiceSettingsSaved => 'Voice transcription settings saved.';

  @override
  String get voiceSettingsStatusTitle => 'Status';

  @override
  String get voiceSettingsEngineTitle => 'Transcription engine';

  @override
  String get voiceSettingsEngineDescription =>
      'Choose exactly one ASR path for new transcripts.';

  @override
  String get voiceSettingsEngineLocal => 'Local SenseVoice';

  @override
  String get voiceSettingsEngineMimo => 'MiMo ASR';

  @override
  String get voiceSettingsEngineDisabled => 'Off';

  @override
  String get voiceSettingsLocalModelTitle => 'Local model';

  @override
  String get voiceSettingsLocalModelManageTitle => 'Local ASR model';

  @override
  String get voiceSettingsLocalModelManageDescription =>
      'Download SenseVoice for offline transcription and live preview. Downloads use a temporary .part directory and can be retried safely.';

  @override
  String voiceSettingsModelProgress(String state, int progress) {
    return '$state · $progress%';
  }

  @override
  String get voiceSettingsModelDownloadButton => 'Download local model';

  @override
  String get voiceSettingsModelDownloading => 'Downloading...';

  @override
  String get voiceSettingsModelDeleteButton => 'Delete local model';

  @override
  String get voiceSettingsModelUnavailable =>
      'Local model storage is unavailable on this device.';

  @override
  String get voiceSettingsModelDownloadReady => 'Local ASR model is ready.';

  @override
  String voiceSettingsModelDownloadFailed(String details) {
    return 'Local ASR model download failed: $details';
  }

  @override
  String get voiceSettingsModelDeleted => 'Local ASR model deleted.';

  @override
  String get voiceSettingsRemoteFallbackTitle => 'Selected engine';

  @override
  String get voiceSettingsRemoteEnabled => 'enabled';

  @override
  String get voiceSettingsRemoteDisabled => 'disabled';

  @override
  String get voiceSettingsPreviewTitle => 'Live preview';

  @override
  String get voiceSettingsPreviewDescription =>
      'Preview uses local microphone PCM while recording. If preview fails, the WAV file is still saved.';

  @override
  String get voiceSettingsPreviewSwitchTitle =>
      'Show transcript preview while recording';

  @override
  String get voiceSettingsPreviewSwitchSubtitle =>
      'The saved WAV remains the source of truth.';

  @override
  String get voiceSettingsRemoteTitle => 'MiMo ASR';

  @override
  String get voiceSettingsRemoteDescription =>
      'Use the configured MiMo-compatible endpoint only when MiMo is the selected engine or you manually retry with MiMo.';

  @override
  String get voiceSettingsRemoteConsentTitle => 'Allow MiMo audio upload';

  @override
  String get voiceSettingsRemoteConsentSubtitle =>
      'Audio upload is used only for the selected MiMo engine and manual MiMo retry.';

  @override
  String get voiceSettingsEndpointLabel => 'Endpoint';

  @override
  String get voiceSettingsModelLabel => 'Model';

  @override
  String get voiceSettingsApiKeyLabel => 'API key';

  @override
  String get voiceSettingsApiKeyHelper =>
      'Stored in secure local storage. Leave blank to keep the saved key.';

  @override
  String get voiceSettingsCorrectionTitle => 'Transcript correction';

  @override
  String get voiceSettingsCorrectionDescription =>
      'The correction Agent Pack can revise names and terms. It records correction evidence but does not write Memory directly.';

  @override
  String get voiceSettingsCorrectionModeLabel => 'Correction mode';

  @override
  String get voiceSettingsCorrectionDisabled => 'Disabled';

  @override
  String get voiceSettingsCorrectionSuggest => 'Suggest only';

  @override
  String get voiceSettingsCorrectionAutoApply => 'Auto-apply high confidence';

  @override
  String get voiceSettingsRetryTitle => 'Manual retry';

  @override
  String get voiceSettingsRetryDescription =>
      'Retry failed or review-needed transcripts with the MiMo ASR path.';

  @override
  String get voiceSettingsRetryButton => 'Retry failed transcripts';

  @override
  String get voiceSettingsRetryRunning => 'Retrying...';

  @override
  String voiceSettingsRetrySummary(int attempted, int succeeded, int failed) {
    return '$attempted attempted / $succeeded succeeded / $failed failed';
  }

  @override
  String get voiceSettingsModelStateNotDownloaded => 'not downloaded';

  @override
  String get voiceSettingsModelStateChecking => 'checking';

  @override
  String get voiceSettingsModelStateDownloading => 'downloading';

  @override
  String get voiceSettingsModelStateInterrupted => 'interrupted';

  @override
  String get voiceSettingsModelStateVerifying => 'verifying';

  @override
  String get voiceSettingsModelStateReady => 'ready';

  @override
  String get voiceSettingsModelStateFailed => 'failed';

  @override
  String get voiceSettingsModelStateCorrupted => 'corrupted';

  @override
  String get voiceSettingsModelStateDeleting => 'deleting';

  @override
  String get backupTitle => 'Backup';

  @override
  String get backupSubtitle =>
      'Export and import local records, Memory, cards, chat, providers, todos, and trace data.';

  @override
  String get backupIdleStatus =>
      'Local data stays on this device until you create or import a backup.';

  @override
  String get backupExportReadyStatus => 'WideNote backup archive is ready.';

  @override
  String get backupSavedFileStatus =>
      'WideNote backup archive is ready in the selected destination.';

  @override
  String get backupImportReadyStatus =>
      'Backup file loaded. Confirm import to replace local data.';

  @override
  String get backupImportDoneStatus => 'Backup replaced local storage.';

  @override
  String backupFailedStatus(String details) {
    return 'Backup failed: $details';
  }

  @override
  String get backupInvalidFormat => 'Invalid backup format.';

  @override
  String get backupUnsupportedVersion => 'Unsupported backup version.';

  @override
  String get backupNoSavedFile => 'No saved backup file found.';

  @override
  String get backupLocalConflict => 'Backup conflicts with local data.';

  @override
  String get backupUnexpectedError => 'Unexpected backup error.';

  @override
  String get backupExportSectionTitle => 'Export and restore boundary';

  @override
  String get backupExportButton => 'Create .widenote backup';

  @override
  String get backupExportEmpty =>
      'Export creates one compressed directory .widenote archive. You can open it with another app or save it to a location you choose.';

  @override
  String get backupSecretWarning =>
      'Full backups include provider and allowlisted secure-storage keys. Keep .widenote files somewhere you trust.';

  @override
  String get backupRestoreBoundary =>
      'The .widenote archive restores a SQLite snapshot, capture media files, provider API keys, and allowlisted app settings.';

  @override
  String get backupOwnerExportBoundary =>
      'Backups are compressed directories, not JSON or Markdown restore documents.';

  @override
  String get backupFullSecretBoundary =>
      'Full .widenote backups include provider, AMap, and MiMo ASR keys so restore can use configured features immediately.';

  @override
  String backupLegacyProviderCredentialReentryCount(int count) {
    return 'Provider keys requiring re-entry: $count';
  }

  @override
  String get backupManifestCountsTitle => 'Backup counts';

  @override
  String backupCount(String section, int count) {
    return '$section: $count';
  }

  @override
  String get backupCopyMarkdownButton => 'Copy export';

  @override
  String get backupOpenShareFileButton => 'Open or share .widenote';

  @override
  String get backupSaveFilesButton => 'Save to selected location';

  @override
  String get backupSavedArchivePath => 'WideNote backup';

  @override
  String get backupExportDestination => 'Destination';

  @override
  String get backupCopiedStatus => 'Export copied.';

  @override
  String get backupExportMarkdownTitle => 'Readable export';

  @override
  String get backupImportSectionTitle => 'Import';

  @override
  String get backupImportHint =>
      'Choose a .widenote file. WideNote will inspect it before replacing local data.';

  @override
  String get backupImportButton => 'Replace with selected backup';

  @override
  String get backupImportFileButton => 'Choose .widenote file';

  @override
  String get backupImportReadyInline =>
      'Backup is loaded and ready to replace local data.';

  @override
  String get backupImportSourcePath => 'Import source';

  @override
  String get backupConfirmReplaceTitle => 'Replace local data?';

  @override
  String get backupConfirmReplaceBody =>
      'This import fully replaces local records, Memory, todos, chats, provider metadata, packs, permissions, runtime state, and traces with the backup contents. Continue only if this is the file you want.';

  @override
  String get backupConfirmReplaceCancel => 'Cancel';

  @override
  String get backupConfirmReplaceAction => 'Replace and import';

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
      'Provider credentials restored and ready to use.';

  @override
  String get backupImportNoProviderKeysNeeded =>
      'No provider keys need re-entry for this backup.';

  @override
  String get settingsLocationTitle => 'Location Context';

  @override
  String get settingsLocationSubtitle =>
      'Save local GPS with records and optionally use AMap for address summaries.';

  @override
  String get settingsLocationStatusOff => 'off';

  @override
  String get settingsLocationStatusGps => 'GPS only';

  @override
  String get settingsLocationStatusAmap => 'GPS + AMap';

  @override
  String get locationSettingsTitle => 'Location Context';

  @override
  String get locationSettingsSubtitle =>
      'Choose what WideNote saves locally and when coordinates may be sent to AMap.';

  @override
  String get locationPrivacyTitle => 'Privacy boundary';

  @override
  String get locationPrivacyLocalTitle => 'Local GPS';

  @override
  String get locationPrivacyLocalBody =>
      'When enabled, WideNote requests foreground location only while saving a record and stores the coordinate on that local record.';

  @override
  String get locationPrivacyAmapTitle => 'AMap reverse geocoding';

  @override
  String get locationPrivacyAmapBody =>
      'AMap address lookup is separate consent. When enabled, the record coordinate is sent to AMap Web Service to return an address summary.';

  @override
  String get locationStatusGpsOn => 'GPS capture on';

  @override
  String get locationStatusGpsOff => 'GPS capture off';

  @override
  String get locationStatusAmapOn => 'AMap lookup on';

  @override
  String get locationStatusAmapOff => 'AMap lookup off';

  @override
  String get locationCaptureTitle => 'Record location';

  @override
  String get locationSaveGpsTitle => 'Save GPS with new records';

  @override
  String get locationSaveGpsBody =>
      'Stores WGS-84 latitude, longitude, accuracy, source, and capture time only on the local record.';

  @override
  String get locationAmapTitle => 'Address lookup';

  @override
  String get locationAmapSwitchTitle => 'Use AMap reverse geocoding';

  @override
  String get locationAmapSwitchBody =>
      'Sends the record coordinate to AMap Web Service and stores the returned address as derived context.';

  @override
  String get locationAmapKeyLabel => 'AMap Web Service Key';

  @override
  String get locationAmapKeyHelper =>
      'Stored in secure local storage. It is not included in .widenote backups or Owner Export.';

  @override
  String get locationGranularityTitle => 'Display granularity';

  @override
  String get locationGranularityBody =>
      'Lists and status surfaces use coarse display by default to reduce shoulder-surfing risk.';

  @override
  String get locationGranularityLabel => 'Default display';

  @override
  String get locationGranularityCity => 'City';

  @override
  String get locationGranularityDistrict => 'District';

  @override
  String get locationGranularityNeighborhood => 'Neighborhood';

  @override
  String get locationGranularityStreet => 'Street';

  @override
  String get locationGranularityFull => 'Full address';

  @override
  String get locationTestTitle => 'Current status';

  @override
  String get locationTestBody =>
      'Run one foreground lookup with the current settings. The preview stays coarse.';

  @override
  String get locationTestAction => 'Test location';

  @override
  String get locationTestRunning => 'Testing...';

  @override
  String get locationMaintenanceTitle => 'Saved locations';

  @override
  String get locationMaintenanceBody =>
      'Turning the feature off stops future capture. Use clear to remove saved location metadata from existing records.';

  @override
  String get locationClearSavedAction => 'Clear saved locations';

  @override
  String get locationClearConfirmTitle => 'Clear saved locations?';

  @override
  String get locationClearConfirmBody =>
      'This removes location metadata from existing local capture records. Record text and attachments stay unchanged.';

  @override
  String get locationClearConfirmAction => 'Clear';

  @override
  String locationClearSavedResult(int count) {
    return 'Cleared location metadata from $count records.';
  }

  @override
  String get locationStatusAvailable => 'Location captured.';

  @override
  String locationStatusSummary(String summary) {
    return 'Area: $summary';
  }

  @override
  String get locationStatusCoordinatesSaved =>
      'GPS coordinates saved on the local record.';

  @override
  String get locationStatusDisabled => 'Location capture is off.';

  @override
  String get locationStatusServiceDisabled =>
      'Device location service is disabled.';

  @override
  String get locationStatusPermissionDenied =>
      'Location permission was denied.';

  @override
  String get locationStatusPermissionDeniedForever =>
      'Location permission is blocked in system settings.';

  @override
  String get locationStatusTimeout => 'Location lookup timed out.';

  @override
  String get locationStatusAmapKeyMissing =>
      'AMap key is missing. GPS can still be saved.';

  @override
  String get locationStatusAmapDisabled => 'AMap lookup is off.';

  @override
  String get locationStatusAmapTimeout =>
      'AMap lookup timed out. GPS can still be saved.';

  @override
  String get locationStatusUnavailable => 'Location is unavailable.';

  @override
  String locationRecordSummary(String summary) {
    return 'Location: $summary';
  }

  @override
  String get locationRecordCoordinatesSaved => 'GPS saved';

  @override
  String get locationRecordUnavailable => 'Location unavailable';
}
