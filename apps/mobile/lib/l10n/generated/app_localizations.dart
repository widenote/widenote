import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'WideNote'**
  String get appTitle;

  /// No description provided for @tabHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get tabHome;

  /// No description provided for @tabChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get tabChat;

  /// No description provided for @tabTodos.
  ///
  /// In en, this message translates to:
  /// **'Todos'**
  String get tabTodos;

  /// No description provided for @tabPlugins.
  ///
  /// In en, this message translates to:
  /// **'Packs'**
  String get tabPlugins;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'quick capture -> timeline -> memory -> insight'**
  String get homeSubtitle;

  /// No description provided for @homeOpenTimelineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open Timeline'**
  String get homeOpenTimelineTooltip;

  /// No description provided for @homeSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get homeSearchTooltip;

  /// No description provided for @homeOpenMemoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open Memory'**
  String get homeOpenMemoryTooltip;

  /// No description provided for @homeOpenDailyRecapTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open Daily Recap'**
  String get homeOpenDailyRecapTooltip;

  /// No description provided for @homeOpenSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get homeOpenSettingsTooltip;

  /// No description provided for @recapTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Recap'**
  String get recapTitle;

  /// No description provided for @recapSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Today from local object truth · {date}'**
  String recapSubtitle(String date);

  /// No description provided for @recapBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close Daily Recap'**
  String get recapBackTooltip;

  /// No description provided for @recapUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily Recap unavailable'**
  String get recapUnavailableTitle;

  /// No description provided for @recapEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded today yet.'**
  String get recapEmptyTitle;

  /// No description provided for @recapEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Capture a thought, voice draft, camera photo, or gallery image. Today\'s recap will stay source-linked here.'**
  String get recapEmptyBody;

  /// No description provided for @recapCapturesMetric.
  ///
  /// In en, this message translates to:
  /// **'captures'**
  String get recapCapturesMetric;

  /// No description provided for @recapMemoryMetric.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get recapMemoryMetric;

  /// No description provided for @recapTodoOpenMetric.
  ///
  /// In en, this message translates to:
  /// **'open todos'**
  String get recapTodoOpenMetric;

  /// No description provided for @recapTodoCompletedMetric.
  ///
  /// In en, this message translates to:
  /// **'completed'**
  String get recapTodoCompletedMetric;

  /// No description provided for @recapCardsMetric.
  ///
  /// In en, this message translates to:
  /// **'cards'**
  String get recapCardsMetric;

  /// No description provided for @recapInsightsMetric.
  ///
  /// In en, this message translates to:
  /// **'insights'**
  String get recapInsightsMetric;

  /// No description provided for @recapRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Records today'**
  String get recapRecordsTitle;

  /// No description provided for @recapMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory today'**
  String get recapMemoryTitle;

  /// No description provided for @recapTodosTitle.
  ///
  /// In en, this message translates to:
  /// **'Todo activity'**
  String get recapTodosTitle;

  /// No description provided for @recapCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get recapCardsTitle;

  /// No description provided for @recapInsightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get recapInsightsTitle;

  /// No description provided for @recapSectionEmpty.
  ///
  /// In en, this message translates to:
  /// **'No source-linked items in this section today.'**
  String get recapSectionEmpty;

  /// No description provided for @recapEvidenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Local evidence'**
  String get recapEvidenceTitle;

  /// No description provided for @recapEvidenceBody.
  ///
  /// In en, this message translates to:
  /// **'{eventCount, plural, =1{1 event} other{{eventCount} events}} · {traceCount, plural, =1{1 trace} other{{traceCount} traces}}'**
  String recapEvidenceBody(int eventCount, int traceCount);

  /// No description provided for @quickCaptureTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick Capture'**
  String get quickCaptureTitle;

  /// No description provided for @quickCaptureHint.
  ///
  /// In en, this message translates to:
  /// **'Drop a thought, meeting note, promise, or raw memory...'**
  String get quickCaptureHint;

  /// No description provided for @captureModeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get captureModeText;

  /// No description provided for @captureModeVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get captureModeVoice;

  /// No description provided for @captureModeMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get captureModeMedia;

  /// No description provided for @captureModeTextTitle.
  ///
  /// In en, this message translates to:
  /// **'Write first'**
  String get captureModeTextTitle;

  /// No description provided for @captureModeTextBody.
  ///
  /// In en, this message translates to:
  /// **'Fast local capture stays the default. Agents organize it after the raw record is saved.'**
  String get captureModeTextBody;

  /// No description provided for @captureVoiceHint.
  ///
  /// In en, this message translates to:
  /// **'Add context while the voice recording is attached as local raw media...'**
  String get captureVoiceHint;

  /// No description provided for @captureVoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Record voice'**
  String get captureVoiceTitle;

  /// No description provided for @captureVoiceBody.
  ///
  /// In en, this message translates to:
  /// **'WideNote requests microphone permission, stores the raw audio locally, and keeps transcript generation as a later agent step.'**
  String get captureVoiceBody;

  /// No description provided for @captureVoiceStartButton.
  ///
  /// In en, this message translates to:
  /// **'Start recording'**
  String get captureVoiceStartButton;

  /// No description provided for @captureVoiceRecordingTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get captureVoiceRecordingTitle;

  /// No description provided for @captureVoiceRecordingBody.
  ///
  /// In en, this message translates to:
  /// **'Stop to attach the recording, or cancel to discard it without creating a record.'**
  String get captureVoiceRecordingBody;

  /// No description provided for @captureVoiceStopButton.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get captureVoiceStopButton;

  /// No description provided for @captureVoiceCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get captureVoiceCancelButton;

  /// No description provided for @captureMediaHint.
  ///
  /// In en, this message translates to:
  /// **'Add context for a camera photo or gallery image...'**
  String get captureMediaHint;

  /// No description provided for @captureMediaTitle.
  ///
  /// In en, this message translates to:
  /// **'Attach media'**
  String get captureMediaTitle;

  /// No description provided for @captureMediaBody.
  ///
  /// In en, this message translates to:
  /// **'Camera and gallery use platform pickers. WideNote stores a local file reference, hash, and source metadata.'**
  String get captureMediaBody;

  /// No description provided for @captureMediaCameraButton.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get captureMediaCameraButton;

  /// No description provided for @captureMediaGalleryButton.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get captureMediaGalleryButton;

  /// No description provided for @captureActionCamera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get captureActionCamera;

  /// No description provided for @captureActionGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get captureActionGallery;

  /// No description provided for @captureActionVoice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get captureActionVoice;

  /// No description provided for @captureUseTranscriptButton.
  ///
  /// In en, this message translates to:
  /// **'Use transcript'**
  String get captureUseTranscriptButton;

  /// No description provided for @captureRemoveAttachmentTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get captureRemoveAttachmentTooltip;

  /// No description provided for @captureAttachmentReady.
  ///
  /// In en, this message translates to:
  /// **'Ready · {preview}'**
  String captureAttachmentReady(String preview);

  /// No description provided for @captureAttachmentNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Transcript needs review · {preview}'**
  String captureAttachmentNeedsReview(String preview);

  /// No description provided for @captureAttachmentBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked attachment · {reason} · Preview hidden until review.'**
  String captureAttachmentBlocked(String reason);

  /// No description provided for @captureEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add text or an attachment before saving.'**
  String get captureEmptyMessage;

  /// No description provided for @capturePhotoAttachedMessage.
  ///
  /// In en, this message translates to:
  /// **'Photo attached. Review it, then save the record.'**
  String get capturePhotoAttachedMessage;

  /// No description provided for @captureVoiceAttachedMessage.
  ///
  /// In en, this message translates to:
  /// **'Voice draft attached. Review the transcript before saving.'**
  String get captureVoiceAttachedMessage;

  /// No description provided for @captureShareAttachedMessage.
  ///
  /// In en, this message translates to:
  /// **'Imported item attached. Review it, then save the record.'**
  String get captureShareAttachedMessage;

  /// No description provided for @captureSavedMessage.
  ///
  /// In en, this message translates to:
  /// **'Record saved. Local agents are organizing it now.'**
  String get captureSavedMessage;

  /// No description provided for @captureOpenTimelineAction.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get captureOpenTimelineAction;

  /// No description provided for @recordButton.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get recordButton;

  /// No description provided for @recordButtonProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get recordButtonProcessing;

  /// No description provided for @stageProcessingTitle.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get stageProcessingTitle;

  /// No description provided for @stageProcessingRunning.
  ///
  /// In en, this message translates to:
  /// **'running'**
  String get stageProcessingRunning;

  /// No description provided for @stageProcessingIdle.
  ///
  /// In en, this message translates to:
  /// **'idle'**
  String get stageProcessingIdle;

  /// No description provided for @stageProcessingProcessed.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 processed} other{{count} processed}}'**
  String stageProcessingProcessed(int count);

  /// No description provided for @stageMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get stageMemoryTitle;

  /// No description provided for @stageMemoryReady.
  ///
  /// In en, this message translates to:
  /// **'ready'**
  String get stageMemoryReady;

  /// No description provided for @stageMemoryAccepted.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 accepted} other{{count} accepted}}'**
  String stageMemoryAccepted(int count);

  /// No description provided for @stageMemoryAcceptedReview.
  ///
  /// In en, this message translates to:
  /// **'{acceptedCount, plural, =1{1 accepted} other{{acceptedCount} accepted}} · {reviewCount, plural, =1{1 review} other{{reviewCount} review}}'**
  String stageMemoryAcceptedReview(int acceptedCount, int reviewCount);

  /// No description provided for @stageCardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get stageCardsTitle;

  /// No description provided for @stageCardsWaiting.
  ///
  /// In en, this message translates to:
  /// **'waiting'**
  String get stageCardsWaiting;

  /// No description provided for @stageCardsLinked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 card} other{{count} cards}}'**
  String stageCardsLinked(int count);

  /// No description provided for @stageInsightTitle.
  ///
  /// In en, this message translates to:
  /// **'Insight'**
  String get stageInsightTitle;

  /// No description provided for @stageInsightDraftLane.
  ///
  /// In en, this message translates to:
  /// **'draft lane'**
  String get stageInsightDraftLane;

  /// No description provided for @stageInsightWaiting.
  ///
  /// In en, this message translates to:
  /// **'waiting'**
  String get stageInsightWaiting;

  /// No description provided for @stageInsightSourceLinked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 source-linked} other{{count} source-linked}}'**
  String stageInsightSourceLinked(int count);

  /// No description provided for @stageTodoTitle.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get stageTodoTitle;

  /// No description provided for @stageTodoLinked.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 linked} other{{count} linked}}'**
  String stageTodoLinked(int count);

  /// No description provided for @cardsTitle.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get cardsTitle;

  /// No description provided for @cardsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No source-linked cards yet.'**
  String get cardsEmpty;

  /// No description provided for @insightsTitle.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get insightsTitle;

  /// No description provided for @insightsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No source-linked insights yet.'**
  String get insightsEmpty;

  /// No description provided for @recordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get recordsTitle;

  /// No description provided for @recordsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No local records yet.'**
  String get recordsEmpty;

  /// No description provided for @memoryReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory Review'**
  String get memoryReviewTitle;

  /// No description provided for @memoryReviewEmpty.
  ///
  /// In en, this message translates to:
  /// **'No Memory candidates need review.'**
  String get memoryReviewEmpty;

  /// No description provided for @memoryReviewAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get memoryReviewAccept;

  /// No description provided for @memoryReviewEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get memoryReviewEdit;

  /// No description provided for @memoryReviewReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get memoryReviewReject;

  /// No description provided for @memoryEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Memory'**
  String get memoryEditTitle;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @memoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get memoryTitle;

  /// No description provided for @memoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'Memory queue is waiting for first capture.'**
  String get memoryEmpty;

  /// No description provided for @memoryPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get memoryPageTitle;

  /// No description provided for @memoryPageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Edit, tombstone, restore, and inspect local Memory with source links.'**
  String get memoryPageSubtitle;

  /// No description provided for @memorySearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Memory body, type, status, or source...'**
  String get memorySearchHint;

  /// No description provided for @memoryActiveSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Active Memory'**
  String get memoryActiveSectionTitle;

  /// No description provided for @memoryActiveEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active Memory yet.'**
  String get memoryActiveEmpty;

  /// No description provided for @memoryDeletedSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Deleted Memory'**
  String get memoryDeletedSectionTitle;

  /// No description provided for @memoryDeletedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tombstoned Memory.'**
  String get memoryDeletedEmpty;

  /// No description provided for @memoryActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get memoryActionEdit;

  /// No description provided for @memoryActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get memoryActionDelete;

  /// No description provided for @memoryActionRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get memoryActionRestore;

  /// No description provided for @memoryRevisionLabel.
  ///
  /// In en, this message translates to:
  /// **'rev {revision}'**
  String memoryRevisionLabel(int revision);

  /// No description provided for @traceTitle.
  ///
  /// In en, this message translates to:
  /// **'Trace'**
  String get traceTitle;

  /// No description provided for @traceEmpty.
  ///
  /// In en, this message translates to:
  /// **'Local runtime events appear here after captures or pack runs.'**
  String get traceEmpty;

  /// No description provided for @recordStatusSavedProcessing.
  ///
  /// In en, this message translates to:
  /// **'Saved locally, processing'**
  String get recordStatusSavedProcessing;

  /// No description provided for @recordStatusProcessed.
  ///
  /// In en, this message translates to:
  /// **'Processed locally'**
  String get recordStatusProcessed;

  /// No description provided for @recordStatusAgentFailed.
  ///
  /// In en, this message translates to:
  /// **'Saved locally, agent failed'**
  String get recordStatusAgentFailed;

  /// No description provided for @memoryAutoSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory saved automatically'**
  String get memoryAutoSavedTitle;

  /// No description provided for @memoryNeedsReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory needs review'**
  String get memoryNeedsReviewTitle;

  /// No description provided for @memorySavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory saved'**
  String get memorySavedTitle;

  /// No description provided for @statusAutoAccepted.
  ///
  /// In en, this message translates to:
  /// **'auto-accepted'**
  String get statusAutoAccepted;

  /// No description provided for @statusNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'needs review'**
  String get statusNeedsReview;

  /// No description provided for @statusAccepted.
  ///
  /// In en, this message translates to:
  /// **'accepted'**
  String get statusAccepted;

  /// No description provided for @confidenceLabel.
  ///
  /// In en, this message translates to:
  /// **'{confidence} confidence'**
  String confidenceLabel(String confidence);

  /// No description provided for @confidenceHigh.
  ///
  /// In en, this message translates to:
  /// **'high'**
  String get confidenceHigh;

  /// No description provided for @confidenceMedium.
  ///
  /// In en, this message translates to:
  /// **'medium'**
  String get confidenceMedium;

  /// No description provided for @confidenceLow.
  ///
  /// In en, this message translates to:
  /// **'low'**
  String get confidenceLow;

  /// No description provided for @todoFollowUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Follow up: {body}'**
  String todoFollowUpTitle(String body);

  /// No description provided for @todoSeedReviewMemory.
  ///
  /// In en, this message translates to:
  /// **'Review generated Memory before export'**
  String get todoSeedReviewMemory;

  /// No description provided for @todoSeedConfirmBackup.
  ///
  /// In en, this message translates to:
  /// **'Confirm backup permission boundary'**
  String get todoSeedConfirmBackup;

  /// No description provided for @todoSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'source: {sourceId}'**
  String todoSourceLabel(String sourceId);

  /// No description provided for @todoStatusNeedsExplicitPermission.
  ///
  /// In en, this message translates to:
  /// **'needs explicit permission'**
  String get todoStatusNeedsExplicitPermission;

  /// No description provided for @todoStatusSuggestedByAgent.
  ///
  /// In en, this message translates to:
  /// **'suggested by agent'**
  String get todoStatusSuggestedByAgent;

  /// No description provided for @todoStatusOpen.
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get todoStatusOpen;

  /// No description provided for @todoStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'completed'**
  String get todoStatusCompleted;

  /// No description provided for @todoActionComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get todoActionComplete;

  /// No description provided for @todoActionReopen.
  ///
  /// In en, this message translates to:
  /// **'Reopen'**
  String get todoActionReopen;

  /// No description provided for @chatTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chatTitle;

  /// No description provided for @chatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask WideNote with local Memory, records, and todos as context.'**
  String get chatSubtitle;

  /// No description provided for @chatSessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get chatSessionsTitle;

  /// No description provided for @chatDailyReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily review'**
  String get chatDailyReviewTitle;

  /// No description provided for @chatDailyReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask about today, linked records, and pending todos.'**
  String get chatDailyReviewSubtitle;

  /// No description provided for @chatMemoryQaTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory QA'**
  String get chatMemoryQaTitle;

  /// No description provided for @chatMemoryQaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Query editable local Memory with visible provenance.'**
  String get chatMemoryQaSubtitle;

  /// No description provided for @chatAgentPackSandboxTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent Pack sandbox'**
  String get chatAgentPackSandboxTitle;

  /// No description provided for @chatAgentPackSandboxSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try pack actions after permission review.'**
  String get chatAgentPackSandboxSubtitle;

  /// No description provided for @chatInputTitle.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get chatInputTitle;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Ask WideNote about a record, Memory item, or pack run...'**
  String get chatInputHint;

  /// No description provided for @chatLoadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat failed to load'**
  String get chatLoadErrorTitle;

  /// No description provided for @chatLoadErrorBody.
  ///
  /// In en, this message translates to:
  /// **'The local chat could not be opened. Please try again.'**
  String get chatLoadErrorBody;

  /// No description provided for @chatHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get chatHistoryTitle;

  /// No description provided for @chatEmptySessions.
  ///
  /// In en, this message translates to:
  /// **'No local sessions yet.'**
  String get chatEmptySessions;

  /// No description provided for @chatSessionSwitchDisabled.
  ///
  /// In en, this message translates to:
  /// **'Wait for the current answer before switching sessions.'**
  String get chatSessionSwitchDisabled;

  /// No description provided for @chatLocalConversationTitle.
  ///
  /// In en, this message translates to:
  /// **'Local chat'**
  String get chatLocalConversationTitle;

  /// No description provided for @chatEmptyConversation.
  ///
  /// In en, this message translates to:
  /// **'Ask a question about records, Memory, or todos.'**
  String get chatEmptyConversation;

  /// No description provided for @chatSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Send failed'**
  String get chatSendFailed;

  /// No description provided for @retryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryButton;

  /// No description provided for @chatSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get chatSourcesTitle;

  /// No description provided for @chatTyping.
  ///
  /// In en, this message translates to:
  /// **'Answering with local context...'**
  String get chatTyping;

  /// No description provided for @chatComposerTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get chatComposerTitle;

  /// No description provided for @chatComposerHint.
  ///
  /// In en, this message translates to:
  /// **'Ask about local records, Memory, or todos...'**
  String get chatComposerHint;

  /// No description provided for @chatSendButton.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get chatSendButton;

  /// No description provided for @chatGeneratingButton.
  ///
  /// In en, this message translates to:
  /// **'Generating'**
  String get chatGeneratingButton;

  /// No description provided for @chatAssistantEmptyReply.
  ///
  /// In en, this message translates to:
  /// **'I don\'t have local records to cite yet. Add captures first, then I can answer from Memory, records, and todos.'**
  String get chatAssistantEmptyReply;

  /// No description provided for @chatAssistantContextReply.
  ///
  /// In en, this message translates to:
  /// **'I found {count} local context item(s). {lead}\n\n{sources}'**
  String chatAssistantContextReply(int count, String lead, String sources);

  /// No description provided for @chatAssistantLeadTodo.
  ///
  /// In en, this message translates to:
  /// **'The closest match is a todo: {excerpt}'**
  String chatAssistantLeadTodo(String excerpt);

  /// No description provided for @chatAssistantLeadMemory.
  ///
  /// In en, this message translates to:
  /// **'The closest match is a Memory item: {excerpt}'**
  String chatAssistantLeadMemory(String excerpt);

  /// No description provided for @chatAssistantLeadCapture.
  ///
  /// In en, this message translates to:
  /// **'The closest match is a raw record: {excerpt}'**
  String chatAssistantLeadCapture(String excerpt);

  /// No description provided for @chatAssistantLeadGeneric.
  ///
  /// In en, this message translates to:
  /// **'The closest match is: {excerpt}'**
  String chatAssistantLeadGeneric(String excerpt);

  /// No description provided for @chatContextMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get chatContextMemoryTitle;

  /// No description provided for @chatContextRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get chatContextRecordTitle;

  /// No description provided for @chatContextTodoTitle.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get chatContextTodoTitle;

  /// No description provided for @chatContextUntitledCapture.
  ///
  /// In en, this message translates to:
  /// **'Untitled local capture'**
  String get chatContextUntitledCapture;

  /// No description provided for @chatContextUntitledTodo.
  ///
  /// In en, this message translates to:
  /// **'Untitled todo suggestion'**
  String get chatContextUntitledTodo;

  /// No description provided for @todosTitle.
  ///
  /// In en, this message translates to:
  /// **'Todos'**
  String get todosTitle;

  /// No description provided for @todosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Source-linked actions with visible record provenance.'**
  String get todosSubtitle;

  /// No description provided for @todosSurfaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Source-linked todos'**
  String get todosSurfaceTitle;

  /// No description provided for @todosEmpty.
  ///
  /// In en, this message translates to:
  /// **'No source-linked todos yet.'**
  String get todosEmpty;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy, permissions, models, backup, and traces.'**
  String get settingsSubtitle;

  /// No description provided for @settingsBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close Settings'**
  String get settingsBackTooltip;

  /// No description provided for @settingsPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacyTitle;

  /// No description provided for @settingsPrivacyLocalFirstTitle.
  ///
  /// In en, this message translates to:
  /// **'Local-first core'**
  String get settingsPrivacyLocalFirstTitle;

  /// No description provided for @settingsPrivacyLocalFirstBody.
  ///
  /// In en, this message translates to:
  /// **'Records, Memory, todos, cards, chat, and traces stay on this device unless you choose backup, sync, or a provider.'**
  String get settingsPrivacyLocalFirstBody;

  /// No description provided for @settingsPrivacyLocalFirstStatus.
  ///
  /// In en, this message translates to:
  /// **'no account'**
  String get settingsPrivacyLocalFirstStatus;

  /// No description provided for @settingsPrivacyPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Revocable permissions'**
  String get settingsPrivacyPermissionsTitle;

  /// No description provided for @settingsPrivacyPermissionsBody.
  ///
  /// In en, this message translates to:
  /// **'Built-in packs use narrow permissions; high-risk file, network, and script capabilities stay deferred until explicit approval exists.'**
  String get settingsPrivacyPermissionsBody;

  /// No description provided for @settingsPrivacyPermissionsStatus.
  ///
  /// In en, this message translates to:
  /// **'reviewable'**
  String get settingsPrivacyPermissionsStatus;

  /// No description provided for @settingsPrivacyBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup secrets boundary'**
  String get settingsPrivacyBackupTitle;

  /// No description provided for @settingsPrivacyBackupBody.
  ///
  /// In en, this message translates to:
  /// **'Safe export omits provider API keys. Encrypted full backup is the future secret-bearing restore path and has no action in this build.'**
  String get settingsPrivacyBackupBody;

  /// No description provided for @settingsPrivacyBackupStatus.
  ///
  /// In en, this message translates to:
  /// **'safe export'**
  String get settingsPrivacyBackupStatus;

  /// No description provided for @settingsControlsTitle.
  ///
  /// In en, this message translates to:
  /// **'Controls'**
  String get settingsControlsTitle;

  /// No description provided for @settingsPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & Permissions'**
  String get settingsPermissionsTitle;

  /// No description provided for @settingsPermissionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review available pack permissions and deferred high-risk capabilities.'**
  String get settingsPermissionsSubtitle;

  /// No description provided for @settingsPermissionsStatus.
  ///
  /// In en, this message translates to:
  /// **'explicit'**
  String get settingsPermissionsStatus;

  /// No description provided for @settingsPermissionsStatusSummary.
  ///
  /// In en, this message translates to:
  /// **'{availableCount} available / {deferredCount} deferred'**
  String settingsPermissionsStatusSummary(
    int availableCount,
    int deferredCount,
  );

  /// No description provided for @settingsModelProvidersTitle.
  ///
  /// In en, this message translates to:
  /// **'Model Providers'**
  String get settingsModelProvidersTitle;

  /// No description provided for @settingsModelProvidersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure local or BYOK model access for runtime and Agent Packs.'**
  String get settingsModelProvidersSubtitle;

  /// No description provided for @settingsBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackupTitle;

  /// No description provided for @settingsBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export or import local records, Memory, cards, providers, todos, and traces.'**
  String get settingsBackupSubtitle;

  /// No description provided for @settingsBackupStatus.
  ///
  /// In en, this message translates to:
  /// **'local'**
  String get settingsBackupStatus;

  /// No description provided for @settingsBackupStatusSafeOnly.
  ///
  /// In en, this message translates to:
  /// **'safe only'**
  String get settingsBackupStatusSafeOnly;

  /// No description provided for @settingsBackupStatusExportReady.
  ///
  /// In en, this message translates to:
  /// **'export ready'**
  String get settingsBackupStatusExportReady;

  /// No description provided for @settingsBackupStatusRestored.
  ///
  /// In en, this message translates to:
  /// **'restored'**
  String get settingsBackupStatusRestored;

  /// No description provided for @settingsBackupStatusNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'review needed'**
  String get settingsBackupStatusNeedsReview;

  /// No description provided for @settingsTraceConsoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Trace Console'**
  String get settingsTraceConsoleTitle;

  /// No description provided for @settingsTraceConsoleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect local Agent Runtime runs, permission checks, and generated outputs.'**
  String get settingsTraceConsoleSubtitle;

  /// No description provided for @settingsTraceConsoleStatus.
  ///
  /// In en, this message translates to:
  /// **'read-only'**
  String get settingsTraceConsoleStatus;

  /// No description provided for @settingsTraceConsoleStatusSummary.
  ///
  /// In en, this message translates to:
  /// **'{eventCount} events / {warningCount} warnings'**
  String settingsTraceConsoleStatusSummary(int eventCount, int warningCount);

  /// No description provided for @pluginsTitle.
  ///
  /// In en, this message translates to:
  /// **'Packs'**
  String get pluginsTitle;

  /// No description provided for @pluginsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pack controls for permissions, models, backup, and traces.'**
  String get pluginsSubtitle;

  /// No description provided for @pluginsControlEntriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Control entries'**
  String get pluginsControlEntriesTitle;

  /// No description provided for @pluginsPackLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Pack Library'**
  String get pluginsPackLibraryTitle;

  /// No description provided for @pluginsPackLibrarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Install, inspect, and disable Agent Packs.'**
  String get pluginsPackLibrarySubtitle;

  /// No description provided for @pluginsPackLibraryStatus.
  ///
  /// In en, this message translates to:
  /// **'available'**
  String get pluginsPackLibraryStatus;

  /// No description provided for @pluginsPermissionGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission Gate'**
  String get pluginsPermissionGateTitle;

  /// No description provided for @pluginsPermissionGateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review sensitive capabilities before a pack can run.'**
  String get pluginsPermissionGateSubtitle;

  /// No description provided for @pluginsPermissionGateStatus.
  ///
  /// In en, this message translates to:
  /// **'explicit'**
  String get pluginsPermissionGateStatus;

  /// No description provided for @pluginsModelProviderTitle.
  ///
  /// In en, this message translates to:
  /// **'Model Provider'**
  String get pluginsModelProviderTitle;

  /// No description provided for @pluginsModelProviderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure local or BYOK model access.'**
  String get pluginsModelProviderSubtitle;

  /// No description provided for @pluginsModelProviderStatus.
  ///
  /// In en, this message translates to:
  /// **'not connected'**
  String get pluginsModelProviderStatus;

  /// No description provided for @pluginsModelProviderConfigured.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 provider} other{{count} providers}}'**
  String pluginsModelProviderConfigured(int count);

  /// No description provided for @pluginsBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get pluginsBackupTitle;

  /// No description provided for @pluginsBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export or import the local WideNote backup.'**
  String get pluginsBackupSubtitle;

  /// No description provided for @pluginsBackupStatus.
  ///
  /// In en, this message translates to:
  /// **'local-first'**
  String get pluginsBackupStatus;

  /// No description provided for @pluginsTraceConsoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Trace Console'**
  String get pluginsTraceConsoleTitle;

  /// No description provided for @pluginsTraceConsoleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect pack runs, permissions, and generated outputs.'**
  String get pluginsTraceConsoleSubtitle;

  /// No description provided for @pluginsTraceConsoleStatus.
  ///
  /// In en, this message translates to:
  /// **'trace-ready'**
  String get pluginsTraceConsoleStatus;

  /// No description provided for @packLibraryTitle.
  ///
  /// In en, this message translates to:
  /// **'Pack Library'**
  String get packLibraryTitle;

  /// No description provided for @packLibrarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect built-in official Agent Packs before dynamic installs exist.'**
  String get packLibrarySubtitle;

  /// No description provided for @packLibraryInstalledTitle.
  ///
  /// In en, this message translates to:
  /// **'Installed official packs'**
  String get packLibraryInstalledTitle;

  /// No description provided for @packLibraryVersion.
  ///
  /// In en, this message translates to:
  /// **'v{version}'**
  String packLibraryVersion(String version);

  /// No description provided for @packLibraryPermissionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 permission} other{{count} permissions}}'**
  String packLibraryPermissionCount(int count);

  /// No description provided for @packLibraryOutputCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 output} other{{count} outputs}}'**
  String packLibraryOutputCount(int count);

  /// No description provided for @permissionGateTitle.
  ///
  /// In en, this message translates to:
  /// **'Permission Gate'**
  String get permissionGateTitle;

  /// No description provided for @permissionGateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review local pack permission state and deferred high-risk capabilities.'**
  String get permissionGateSubtitle;

  /// No description provided for @permissionGateGrantedTitle.
  ///
  /// In en, this message translates to:
  /// **'Built-in and available permissions'**
  String get permissionGateGrantedTitle;

  /// No description provided for @permissionGateDeferredTitle.
  ///
  /// In en, this message translates to:
  /// **'Deferred high-risk permissions'**
  String get permissionGateDeferredTitle;

  /// No description provided for @permissionGateStatusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Built-in / available'**
  String get permissionGateStatusAvailable;

  /// No description provided for @permissionGateStatusGranted.
  ///
  /// In en, this message translates to:
  /// **'Granted locally'**
  String get permissionGateStatusGranted;

  /// No description provided for @permissionGateStatusDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied locally'**
  String get permissionGateStatusDenied;

  /// No description provided for @permissionGateStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked locally'**
  String get permissionGateStatusRevoked;

  /// No description provided for @permissionGateActionGrant.
  ///
  /// In en, this message translates to:
  /// **'Grant'**
  String get permissionGateActionGrant;

  /// No description provided for @permissionGateActionDeny.
  ///
  /// In en, this message translates to:
  /// **'Deny'**
  String get permissionGateActionDeny;

  /// No description provided for @permissionGateActionRevoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get permissionGateActionRevoke;

  /// No description provided for @permissionGateActionDeferred.
  ///
  /// In en, this message translates to:
  /// **'Deferred'**
  String get permissionGateActionDeferred;

  /// No description provided for @agentPlatformTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent Observability'**
  String get agentPlatformTitle;

  /// No description provided for @agentPlatformSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Read-only local runtime evidence from real trace events.'**
  String get agentPlatformSubtitle;

  /// No description provided for @traceConsoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Trace Console'**
  String get traceConsoleTitle;

  /// No description provided for @traceConsoleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect local Agent Runtime runs, permissions, and generated outputs.'**
  String get traceConsoleSubtitle;

  /// No description provided for @traceConsoleSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Runtime summary'**
  String get traceConsoleSummaryTitle;

  /// No description provided for @traceConsoleEventCount.
  ///
  /// In en, this message translates to:
  /// **'Trace events: {count}'**
  String traceConsoleEventCount(int count);

  /// No description provided for @traceConsoleRunCount.
  ///
  /// In en, this message translates to:
  /// **'Runs: {count}'**
  String traceConsoleRunCount(int count);

  /// No description provided for @traceConsoleWarningCount.
  ///
  /// In en, this message translates to:
  /// **'Warnings: {count}'**
  String traceConsoleWarningCount(int count);

  /// No description provided for @traceConsoleRefreshButton.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get traceConsoleRefreshButton;

  /// No description provided for @traceConsoleOpenButton.
  ///
  /// In en, this message translates to:
  /// **'Open trace console'**
  String get traceConsoleOpenButton;

  /// No description provided for @traceConsoleEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get traceConsoleEventsTitle;

  /// No description provided for @traceConsoleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No runtime traces yet. Capture or pack runs will appear here.'**
  String get traceConsoleEmpty;

  /// No description provided for @traceConsoleNoMessage.
  ///
  /// In en, this message translates to:
  /// **'No message recorded.'**
  String get traceConsoleNoMessage;

  /// No description provided for @traceConsoleRun.
  ///
  /// In en, this message translates to:
  /// **'run: {runId}'**
  String traceConsoleRun(String runId);

  /// No description provided for @traceConsolePack.
  ///
  /// In en, this message translates to:
  /// **'pack: {packId}'**
  String traceConsolePack(String packId);

  /// No description provided for @traceConsoleAgent.
  ///
  /// In en, this message translates to:
  /// **'agent: {agentId}'**
  String traceConsoleAgent(String agentId);

  /// No description provided for @traceConsoleDuration.
  ///
  /// In en, this message translates to:
  /// **'duration: {duration} ms'**
  String traceConsoleDuration(num duration);

  /// No description provided for @providerSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Model Providers'**
  String get providerSettingsTitle;

  /// No description provided for @providerSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose how WideNote agents reach models, what the default runtime model is, and which capabilities are safe to use.'**
  String get providerSettingsSubtitle;

  /// No description provided for @providerSettingsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add provider'**
  String get providerSettingsAdd;

  /// No description provided for @providerSettingsListTitle.
  ///
  /// In en, this message translates to:
  /// **'Providers'**
  String get providerSettingsListTitle;

  /// No description provided for @providerSettingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No providers configured.'**
  String get providerSettingsEmpty;

  /// No description provided for @providerSettingsDefaultTag.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get providerSettingsDefaultTag;

  /// No description provided for @providerSettingsStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Runtime model access'**
  String get providerSettingsStatusTitle;

  /// No description provided for @providerSettingsStatusConfigured.
  ///
  /// In en, this message translates to:
  /// **'Using {provider}'**
  String providerSettingsStatusConfigured(String provider);

  /// No description provided for @providerSettingsStatusNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Offline fallback active'**
  String get providerSettingsStatusNotConfigured;

  /// No description provided for @providerSettingsStatusDescriptionConfigured.
  ///
  /// In en, this message translates to:
  /// **'Capture, chat, and Agent Packs use this default unless a later role override says otherwise.'**
  String get providerSettingsStatusDescriptionConfigured;

  /// No description provided for @providerSettingsStatusDescriptionOffline.
  ///
  /// In en, this message translates to:
  /// **'Core capture still works locally with deterministic summaries. Add a BYOK provider when you want live model calls.'**
  String get providerSettingsStatusDescriptionOffline;

  /// No description provided for @providerSettingsProviderCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 provider} other{{count} providers}}'**
  String providerSettingsProviderCount(int count);

  /// No description provided for @providerSettingsRolesTitle.
  ///
  /// In en, this message translates to:
  /// **'Model roles'**
  String get providerSettingsRolesTitle;

  /// No description provided for @providerSettingsRolesDescription.
  ///
  /// In en, this message translates to:
  /// **'WideNote keeps provider credentials separate from runtime roles so future Agent Packs can route safely.'**
  String get providerSettingsRolesDescription;

  /// No description provided for @providerSettingsTextRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Default text model'**
  String get providerSettingsTextRoleTitle;

  /// No description provided for @providerSettingsTextRoleDescription.
  ///
  /// In en, this message translates to:
  /// **'Used by capture summaries, chat answers, Memory extraction, and built-in Agent Packs in this slice.'**
  String get providerSettingsTextRoleDescription;

  /// No description provided for @providerSettingsAgentRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Per-Agent overrides'**
  String get providerSettingsAgentRoleTitle;

  /// No description provided for @providerSettingsAgentRoleDescription.
  ///
  /// In en, this message translates to:
  /// **'Not enabled yet. For now, all built-in agents inherit the default model.'**
  String get providerSettingsAgentRoleDescription;

  /// No description provided for @providerSettingsRoleFallback.
  ///
  /// In en, this message translates to:
  /// **'Local deterministic fallback'**
  String get providerSettingsRoleFallback;

  /// No description provided for @providerSettingsCapabilitiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Capabilities and privacy'**
  String get providerSettingsCapabilitiesTitle;

  /// No description provided for @providerSettingsCapabilitiesDescription.
  ///
  /// In en, this message translates to:
  /// **'Connection tests are user-initiated. API keys stay local and are included only in user-managed backups.'**
  String get providerSettingsCapabilitiesDescription;

  /// No description provided for @providerSettingsCapabilityChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get providerSettingsCapabilityChat;

  /// No description provided for @providerSettingsCapabilityCompletion.
  ///
  /// In en, this message translates to:
  /// **'Completion'**
  String get providerSettingsCapabilityCompletion;

  /// No description provided for @providerSettingsCapabilityOfflineFallback.
  ///
  /// In en, this message translates to:
  /// **'Offline fallback'**
  String get providerSettingsCapabilityOfflineFallback;

  /// No description provided for @providerSettingsCapabilityByok.
  ///
  /// In en, this message translates to:
  /// **'BYOK local storage'**
  String get providerSettingsCapabilityByok;

  /// No description provided for @providerClearKeyTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear saved API key'**
  String get providerClearKeyTitle;

  /// No description provided for @providerClearKeySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Leave unchecked and keep this field blank to keep the saved key.'**
  String get providerClearKeySubtitle;

  /// No description provided for @providerConnectionUntested.
  ///
  /// In en, this message translates to:
  /// **'Untested'**
  String get providerConnectionUntested;

  /// No description provided for @providerConnectionTesting.
  ///
  /// In en, this message translates to:
  /// **'Testing'**
  String get providerConnectionTesting;

  /// No description provided for @providerConnectionConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get providerConnectionConnected;

  /// No description provided for @providerConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get providerConnectionFailed;

  /// No description provided for @providerActionSetDefault.
  ///
  /// In en, this message translates to:
  /// **'Set default'**
  String get providerActionSetDefault;

  /// No description provided for @providerActionTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test connection'**
  String get providerActionTestConnection;

  /// No description provided for @providerActionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit provider'**
  String get providerActionEdit;

  /// No description provided for @providerDialogAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add provider'**
  String get providerDialogAddTitle;

  /// No description provided for @providerDialogEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit provider'**
  String get providerDialogEditTitle;

  /// No description provided for @providerFieldProviderType.
  ///
  /// In en, this message translates to:
  /// **'Provider type'**
  String get providerFieldProviderType;

  /// No description provided for @providerFieldDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get providerFieldDisplayName;

  /// No description provided for @providerFieldEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get providerFieldEndpoint;

  /// No description provided for @providerFieldModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get providerFieldModel;

  /// No description provided for @providerFieldApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get providerFieldApiKey;

  /// No description provided for @providerApiKeyKeepSessionHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep the session credential.'**
  String get providerApiKeyKeepSessionHelper;

  /// No description provided for @providerInvalidEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint is not a valid URI.'**
  String get providerInvalidEndpoint;

  /// No description provided for @providerSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Provider could not be saved.'**
  String get providerSaveFailed;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupTitle;

  /// No description provided for @backupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export and import local records, Memory, cards, chat, providers, todos, and trace data.'**
  String get backupSubtitle;

  /// No description provided for @backupIdleStatus.
  ///
  /// In en, this message translates to:
  /// **'Local data stays on this device until you export or paste a backup.'**
  String get backupIdleStatus;

  /// No description provided for @backupExportReadyStatus.
  ///
  /// In en, this message translates to:
  /// **'Safe backup JSON is ready.'**
  String get backupExportReadyStatus;

  /// No description provided for @backupSavedFileStatus.
  ///
  /// In en, this message translates to:
  /// **'Backup files saved locally.'**
  String get backupSavedFileStatus;

  /// No description provided for @backupImportDoneStatus.
  ///
  /// In en, this message translates to:
  /// **'Backup imported into local storage.'**
  String get backupImportDoneStatus;

  /// No description provided for @backupFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {details}'**
  String backupFailedStatus(String details);

  /// No description provided for @backupExportSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Export and restore boundary'**
  String get backupExportSectionTitle;

  /// No description provided for @backupExportButton.
  ///
  /// In en, this message translates to:
  /// **'Export safe restore JSON'**
  String get backupExportButton;

  /// No description provided for @backupExportEmpty.
  ///
  /// In en, this message translates to:
  /// **'Export creates a safe, versioned restore JSON and a readable Owner Export Markdown projection.'**
  String get backupExportEmpty;

  /// No description provided for @backupSecretWarning.
  ///
  /// In en, this message translates to:
  /// **'Safe export omits provider API keys. Re-enter provider keys after restore.'**
  String get backupSecretWarning;

  /// No description provided for @backupSafeRestoreBoundary.
  ///
  /// In en, this message translates to:
  /// **'Safe restore JSON brings back records, Memory, todos, provider metadata, pack installs, permissions, runtime state, and traces. Provider keys are omitted.'**
  String get backupSafeRestoreBoundary;

  /// No description provided for @backupOwnerExportBoundary.
  ///
  /// In en, this message translates to:
  /// **'Owner Export Markdown is for reading and moving your data. It excludes secrets and is not a restore source.'**
  String get backupOwnerExportBoundary;

  /// No description provided for @backupFullSecretBoundary.
  ///
  /// In en, this message translates to:
  /// **'Encrypted full backup will be the secret-bearing path for restoring API keys. It has no action in this build.'**
  String get backupFullSecretBoundary;

  /// No description provided for @backupSafeOmittedProviderKeys.
  ///
  /// In en, this message translates to:
  /// **'Provider keys omitted from safe export: {count}'**
  String backupSafeOmittedProviderKeys(int count);

  /// No description provided for @backupManifestCountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manifest counts'**
  String get backupManifestCountsTitle;

  /// No description provided for @backupCount.
  ///
  /// In en, this message translates to:
  /// **'{section}: {count}'**
  String backupCount(String section, int count);

  /// No description provided for @backupCopyJsonButton.
  ///
  /// In en, this message translates to:
  /// **'Copy JSON'**
  String get backupCopyJsonButton;

  /// No description provided for @backupCopyMarkdownButton.
  ///
  /// In en, this message translates to:
  /// **'Copy Markdown'**
  String get backupCopyMarkdownButton;

  /// No description provided for @backupSaveFilesButton.
  ///
  /// In en, this message translates to:
  /// **'Save files'**
  String get backupSaveFilesButton;

  /// No description provided for @backupSavedJsonPath.
  ///
  /// In en, this message translates to:
  /// **'JSON file'**
  String get backupSavedJsonPath;

  /// No description provided for @backupSavedMarkdownPath.
  ///
  /// In en, this message translates to:
  /// **'Markdown file'**
  String get backupSavedMarkdownPath;

  /// No description provided for @backupCopiedStatus.
  ///
  /// In en, this message translates to:
  /// **'Export copied.'**
  String get backupCopiedStatus;

  /// No description provided for @backupExportJsonTitle.
  ///
  /// In en, this message translates to:
  /// **'Safe backup JSON'**
  String get backupExportJsonTitle;

  /// No description provided for @backupExportMarkdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Owner Export Markdown'**
  String get backupExportMarkdownTitle;

  /// No description provided for @backupImportSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get backupImportSectionTitle;

  /// No description provided for @backupImportHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a WideNote local backup JSON...'**
  String get backupImportHint;

  /// No description provided for @backupImportButton.
  ///
  /// In en, this message translates to:
  /// **'Import backup'**
  String get backupImportButton;

  /// No description provided for @backupImportLatestFileButton.
  ///
  /// In en, this message translates to:
  /// **'Import latest saved file'**
  String get backupImportLatestFileButton;

  /// No description provided for @backupImportNeedsProviderKeys.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Provider metadata restored. Re-enter 1 provider key before model calls can use it.} other{Provider metadata restored. Re-enter {count} provider keys before model calls can use them.}}'**
  String backupImportNeedsProviderKeys(int count);

  /// No description provided for @backupImportSecretsRestored.
  ///
  /// In en, this message translates to:
  /// **'Secret-bearing backup restored provider credentials.'**
  String get backupImportSecretsRestored;

  /// No description provided for @backupImportNoProviderKeysNeeded.
  ///
  /// In en, this message translates to:
  /// **'No provider keys need re-entry for this backup.'**
  String get backupImportNoProviderKeysNeeded;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
