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

  /// No description provided for @tabRecord.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get tabRecord;

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
  /// **'new records -> timeline -> memory -> insight'**
  String get homeSubtitle;

  /// No description provided for @homeTodaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'{date} · local-first'**
  String homeTodaySubtitle(String date);

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

  /// No description provided for @homeOpenInsightsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open Insights'**
  String get homeOpenInsightsTooltip;

  /// No description provided for @homeOpenSettingsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get homeOpenSettingsTooltip;

  /// No description provided for @homeNewRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'New record'**
  String get homeNewRecordTitle;

  /// No description provided for @homeNewRecordBody.
  ///
  /// In en, this message translates to:
  /// **'Write a focused note, then attach photos or local source files.'**
  String get homeNewRecordBody;

  /// No description provided for @homeBackgroundVoiceTitle.
  ///
  /// In en, this message translates to:
  /// **'Background voice'**
  String get homeBackgroundVoiceTitle;

  /// No description provided for @homeBackgroundVoiceBody.
  ///
  /// In en, this message translates to:
  /// **'Record audio in the background, then add context before saving.'**
  String get homeBackgroundVoiceBody;

  /// No description provided for @homeBackgroundVoiceActiveBody.
  ///
  /// In en, this message translates to:
  /// **'Recording is already running.'**
  String get homeBackgroundVoiceActiveBody;

  /// No description provided for @homeBackgroundVoiceActiveAction.
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get homeBackgroundVoiceActiveAction;

  /// No description provided for @homeSummaryRecords.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get homeSummaryRecords;

  /// No description provided for @homeSummaryMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get homeSummaryMemory;

  /// No description provided for @homeSummaryInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get homeSummaryInsights;

  /// No description provided for @homeTodayRecapTitle.
  ///
  /// In en, this message translates to:
  /// **'Today recap'**
  String get homeTodayRecapTitle;

  /// No description provided for @homeOpenRecapAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get homeOpenRecapAction;

  /// No description provided for @homeTodayRecapBody.
  ///
  /// In en, this message translates to:
  /// **'{recordCount, plural, =0{No records yet} =1{1 record} other{{recordCount} records}} · {memoryCount, plural, =0{Memory ready} =1{1 Memory item} other{{memoryCount} Memory items}} · {todoCount, plural, =0{no open todos} =1{1 todo} other{{todoCount} todos}}'**
  String homeTodayRecapBody(int recordCount, int memoryCount, int todoCount);

  /// No description provided for @homeTodayRecapSummary.
  ///
  /// In en, this message translates to:
  /// **'{recordCount, plural, =0{No records} =1{1 record} other{{recordCount} records}} · {memoryCount, plural, =0{0 Memory} =1{1 Memory} other{{memoryCount} Memory}} · {todoOpenCount, plural, =0{0 open todos} =1{1 open todo} other{{todoOpenCount} open todos}} · {todoCompletedCount, plural, =0{0 completed} =1{1 completed} other{{todoCompletedCount} completed}} · {cardCount, plural, =0{0 cards} =1{1 card} other{{cardCount} cards}} · {insightCount, plural, =0{0 insights} =1{1 insight} other{{insightCount} insights}}'**
  String homeTodayRecapSummary(
    int recordCount,
    int memoryCount,
    int todoOpenCount,
    int todoCompletedCount,
    int cardCount,
    int insightCount,
  );

  /// No description provided for @homeRecapMetricChip.
  ///
  /// In en, this message translates to:
  /// **'{label}: {count}'**
  String homeRecapMetricChip(int count, String label);

  /// No description provided for @homeTodayRecapLoading.
  ///
  /// In en, this message translates to:
  /// **'Refreshing local recap...'**
  String get homeTodayRecapLoading;

  /// No description provided for @homeTodayRecapUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Local recap unavailable.'**
  String get homeTodayRecapUnavailable;

  /// No description provided for @homeRecentRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent records'**
  String get homeRecentRecordsTitle;

  /// No description provided for @homeOpenAllRecordsAction.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get homeOpenAllRecordsAction;

  /// No description provided for @homeInsightTeaserTitle.
  ///
  /// In en, this message translates to:
  /// **'Insight teaser'**
  String get homeInsightTeaserTitle;

  /// No description provided for @homeOpenInsightsAction.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get homeOpenInsightsAction;

  /// No description provided for @homeInsightTeaserEmpty.
  ///
  /// In en, this message translates to:
  /// **'Insights will appear after a few source-linked records.'**
  String get homeInsightTeaserEmpty;

  /// No description provided for @homeInsightAskHint.
  ///
  /// In en, this message translates to:
  /// **'Ask in Chat'**
  String get homeInsightAskHint;

  /// No description provided for @homeContinueRecordingTitle.
  ///
  /// In en, this message translates to:
  /// **'Continue recording'**
  String get homeContinueRecordingTitle;

  /// No description provided for @homeContinueRecordingBody.
  ///
  /// In en, this message translates to:
  /// **'Use the same local compose sheet from Home or the center Record action.'**
  String get homeContinueRecordingBody;

  /// No description provided for @homeContinueRecordingAction.
  ///
  /// In en, this message translates to:
  /// **'New record'**
  String get homeContinueRecordingAction;

  /// No description provided for @newRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'New record'**
  String get newRecordTitle;

  /// No description provided for @newRecordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Original input stays local and is never overwritten by AI.'**
  String get newRecordSubtitle;

  /// No description provided for @newRecordHint.
  ///
  /// In en, this message translates to:
  /// **'Write a thought, feeling, project context, meeting fragment, or life event...'**
  String get newRecordHint;

  /// No description provided for @saveRecordButton.
  ///
  /// In en, this message translates to:
  /// **'Save record'**
  String get saveRecordButton;

  /// No description provided for @backgroundVoiceActiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording in background'**
  String get backgroundVoiceActiveTitle;

  /// No description provided for @backgroundVoiceActiveBody.
  ///
  /// In en, this message translates to:
  /// **'Audio is being preserved as local source material. Stop to review the draft and add context.'**
  String get backgroundVoiceActiveBody;

  /// No description provided for @backgroundVoiceTimerPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'REC'**
  String get backgroundVoiceTimerPlaceholder;

  /// No description provided for @backgroundVoiceComposerBusy.
  ///
  /// In en, this message translates to:
  /// **'A background recording is still running. Stop it before saving this record.'**
  String get backgroundVoiceComposerBusy;

  /// No description provided for @voicePreviewListening.
  ///
  /// In en, this message translates to:
  /// **'Listening...'**
  String get voicePreviewListening;

  /// No description provided for @voicePreviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live transcript preview is unavailable. Audio is still being saved locally.'**
  String get voicePreviewUnavailable;

  /// No description provided for @voicePreviewDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft transcript: {text}'**
  String voicePreviewDraft(String text);

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

  /// No description provided for @recapEntryRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get recapEntryRecordTitle;

  /// No description provided for @recapEntryMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get recapEntryMemoryTitle;

  /// No description provided for @recapEntryOpenTodoTitle.
  ///
  /// In en, this message translates to:
  /// **'Open todo'**
  String get recapEntryOpenTodoTitle;

  /// No description provided for @recapEntryCompletedTodoTitle.
  ///
  /// In en, this message translates to:
  /// **'Completed todo'**
  String get recapEntryCompletedTodoTitle;

  /// No description provided for @recapUntitledCapture.
  ///
  /// In en, this message translates to:
  /// **'Untitled capture'**
  String get recapUntitledCapture;

  /// No description provided for @recapUntitledTodo.
  ///
  /// In en, this message translates to:
  /// **'Untitled todo'**
  String get recapUntitledTodo;

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

  /// No description provided for @captureAttachmentAssetSafetyReason.
  ///
  /// In en, this message translates to:
  /// **'asset safety'**
  String get captureAttachmentAssetSafetyReason;

  /// No description provided for @captureAttachmentBlockedBySafety.
  ///
  /// In en, this message translates to:
  /// **'blocked by asset safety'**
  String get captureAttachmentBlockedBySafety;

  /// No description provided for @captureAttachmentUnsupportedMimeType.
  ///
  /// In en, this message translates to:
  /// **'unsupported file type: {mimeType}'**
  String captureAttachmentUnsupportedMimeType(String mimeType);

  /// No description provided for @captureAttachmentVoiceTranscriptNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'voice transcript needs review'**
  String get captureAttachmentVoiceTranscriptNeedsReview;

  /// No description provided for @captureAttachmentAllowed.
  ///
  /// In en, this message translates to:
  /// **'allowed'**
  String get captureAttachmentAllowed;

  /// No description provided for @captureAttachmentKindPhoto.
  ///
  /// In en, this message translates to:
  /// **'photo'**
  String get captureAttachmentKindPhoto;

  /// No description provided for @captureAttachmentKindVoice.
  ///
  /// In en, this message translates to:
  /// **'voice'**
  String get captureAttachmentKindVoice;

  /// No description provided for @captureAttachmentKindShare.
  ///
  /// In en, this message translates to:
  /// **'shared item'**
  String get captureAttachmentKindShare;

  /// No description provided for @captureAttachmentFallbackName.
  ///
  /// In en, this message translates to:
  /// **'attachment'**
  String get captureAttachmentFallbackName;

  /// No description provided for @captureAttachmentSummary.
  ///
  /// In en, this message translates to:
  /// **'{kind}: {name}'**
  String captureAttachmentSummary(String kind, String name);

  /// No description provided for @captureBlockedAttachmentSummary.
  ///
  /// In en, this message translates to:
  /// **'Blocked attachment: {name}'**
  String captureBlockedAttachmentSummary(String name);

  /// No description provided for @captureEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Add text or an attachment before saving.'**
  String get captureEmptyMessage;

  /// No description provided for @captureReviewPendingAttachments.
  ///
  /// In en, this message translates to:
  /// **'Review or remove pending attachments before saving.'**
  String get captureReviewPendingAttachments;

  /// No description provided for @captureStopVoiceBeforeSaving.
  ///
  /// In en, this message translates to:
  /// **'Stop or cancel the voice recording before saving.'**
  String get captureStopVoiceBeforeSaving;

  /// No description provided for @captureRemoveBlockedAttachments.
  ///
  /// In en, this message translates to:
  /// **'Remove blocked attachments before saving.'**
  String get captureRemoveBlockedAttachments;

  /// No description provided for @captureReviewAttachments.
  ///
  /// In en, this message translates to:
  /// **'Review attachments before saving.'**
  String get captureReviewAttachments;

  /// No description provided for @captureVoiceFailed.
  ///
  /// In en, this message translates to:
  /// **'Voice recording failed: {details}'**
  String captureVoiceFailed(String details);

  /// No description provided for @captureVoiceCancelled.
  ///
  /// In en, this message translates to:
  /// **'Voice recording cancelled.'**
  String get captureVoiceCancelled;

  /// No description provided for @captureVoiceCancelFailed.
  ///
  /// In en, this message translates to:
  /// **'Voice recording cancel failed: {details}'**
  String captureVoiceCancelFailed(String details);

  /// No description provided for @captureAttachmentFailed.
  ///
  /// In en, this message translates to:
  /// **'Attachment failed: {details}'**
  String captureAttachmentFailed(String details);

  /// No description provided for @captureCameraCancelled.
  ///
  /// In en, this message translates to:
  /// **'Camera capture cancelled.'**
  String get captureCameraCancelled;

  /// No description provided for @captureGalleryCancelled.
  ///
  /// In en, this message translates to:
  /// **'Gallery selection cancelled.'**
  String get captureGalleryCancelled;

  /// No description provided for @captureCameraPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Camera permission denied.'**
  String get captureCameraPermissionDenied;

  /// No description provided for @capturePhotoLibraryPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Photo library permission denied.'**
  String get capturePhotoLibraryPermissionDenied;

  /// No description provided for @captureMicrophonePermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission denied.'**
  String get captureMicrophonePermissionDenied;

  /// No description provided for @captureCameraUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Camera is unavailable on this device.'**
  String get captureCameraUnavailable;

  /// No description provided for @capturePhotoLibraryUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photo library is unavailable on this device.'**
  String get capturePhotoLibraryUnavailable;

  /// No description provided for @captureMicrophoneUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Microphone is unavailable on this device.'**
  String get captureMicrophoneUnavailable;

  /// No description provided for @captureCameraFailed.
  ///
  /// In en, this message translates to:
  /// **'Camera capture failed.'**
  String get captureCameraFailed;

  /// No description provided for @captureGalleryFailed.
  ///
  /// In en, this message translates to:
  /// **'Gallery selection failed.'**
  String get captureGalleryFailed;

  /// No description provided for @captureVoiceFailedSimple.
  ///
  /// In en, this message translates to:
  /// **'Voice recording failed.'**
  String get captureVoiceFailedSimple;

  /// No description provided for @captureVoiceFailedToStart.
  ///
  /// In en, this message translates to:
  /// **'Voice recording failed to start.'**
  String get captureVoiceFailedToStart;

  /// No description provided for @captureVoiceFailedToStop.
  ///
  /// In en, this message translates to:
  /// **'Voice recording failed to stop.'**
  String get captureVoiceFailedToStop;

  /// No description provided for @captureVoiceCancelFailedSimple.
  ///
  /// In en, this message translates to:
  /// **'Voice recording cancel failed.'**
  String get captureVoiceCancelFailedSimple;

  /// No description provided for @captureVoiceFileNotCreated.
  ///
  /// In en, this message translates to:
  /// **'Voice recording file was not created.'**
  String get captureVoiceFileNotCreated;

  /// No description provided for @captureVoiceEmptyFile.
  ///
  /// In en, this message translates to:
  /// **'Voice recording produced an empty file.'**
  String get captureVoiceEmptyFile;

  /// No description provided for @captureVoiceFileNotReturned.
  ///
  /// In en, this message translates to:
  /// **'Voice recording file was not returned.'**
  String get captureVoiceFileNotReturned;

  /// No description provided for @captureRecordSavedModelRequired.
  ///
  /// In en, this message translates to:
  /// **'Record saved locally. Configure a model provider or retry after agent recovery to generate Memory, cards, insights, and todos.'**
  String get captureRecordSavedModelRequired;

  /// No description provided for @captureRecordSavedAgentFailed.
  ///
  /// In en, this message translates to:
  /// **'Record saved locally, but agent processing failed. Retry after model or permission recovery.'**
  String get captureRecordSavedAgentFailed;

  /// No description provided for @captureMemoryReviewFailed.
  ///
  /// In en, this message translates to:
  /// **'Memory review failed: {details}'**
  String captureMemoryReviewFailed(String details);

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
  /// **'Text search needs a retriever...'**
  String get memorySearchHint;

  /// No description provided for @memoryTextSearchRequiresRetriever.
  ///
  /// In en, this message translates to:
  /// **'Text search needs a model-backed retriever. Clear the field to browse Memory locally.'**
  String get memoryTextSearchRequiresRetriever;

  /// No description provided for @memoryTextSearchClearHint.
  ///
  /// In en, this message translates to:
  /// **'Clear the text field to browse Memory locally.'**
  String get memoryTextSearchClearHint;

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

  /// No description provided for @memoryBodyCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Memory body cannot be empty.'**
  String get memoryBodyCannotBeEmpty;

  /// No description provided for @memoryUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Memory update failed.'**
  String get memoryUpdateFailed;

  /// No description provided for @memoryTypePreference.
  ///
  /// In en, this message translates to:
  /// **'preference'**
  String get memoryTypePreference;

  /// No description provided for @memoryTypeProject.
  ///
  /// In en, this message translates to:
  /// **'project'**
  String get memoryTypeProject;

  /// No description provided for @memoryTypePerson.
  ///
  /// In en, this message translates to:
  /// **'person'**
  String get memoryTypePerson;

  /// No description provided for @memoryTypeHealth.
  ///
  /// In en, this message translates to:
  /// **'health'**
  String get memoryTypeHealth;

  /// No description provided for @memoryTypeFinance.
  ///
  /// In en, this message translates to:
  /// **'finance'**
  String get memoryTypeFinance;

  /// No description provided for @memoryTypeLocation.
  ///
  /// In en, this message translates to:
  /// **'location'**
  String get memoryTypeLocation;

  /// No description provided for @memoryTypeCredential.
  ///
  /// In en, this message translates to:
  /// **'credential'**
  String get memoryTypeCredential;

  /// No description provided for @memoryTypeInsight.
  ///
  /// In en, this message translates to:
  /// **'insight'**
  String get memoryTypeInsight;

  /// No description provided for @memoryTypeTaskContext.
  ///
  /// In en, this message translates to:
  /// **'task context'**
  String get memoryTypeTaskContext;

  /// No description provided for @memorySensitivityLow.
  ///
  /// In en, this message translates to:
  /// **'low sensitivity'**
  String get memorySensitivityLow;

  /// No description provided for @memorySensitivityMedium.
  ///
  /// In en, this message translates to:
  /// **'medium sensitivity'**
  String get memorySensitivityMedium;

  /// No description provided for @memorySensitivityHigh.
  ///
  /// In en, this message translates to:
  /// **'high sensitivity'**
  String get memorySensitivityHigh;

  /// No description provided for @cardKindCapture.
  ///
  /// In en, this message translates to:
  /// **'capture card'**
  String get cardKindCapture;

  /// No description provided for @cardKindMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory card'**
  String get cardKindMemory;

  /// No description provided for @insightKindSummary.
  ///
  /// In en, this message translates to:
  /// **'summary insight'**
  String get insightKindSummary;

  /// No description provided for @insightKindCount.
  ///
  /// In en, this message translates to:
  /// **'count insight'**
  String get insightKindCount;

  /// No description provided for @insightKindTrend.
  ///
  /// In en, this message translates to:
  /// **'trend insight'**
  String get insightKindTrend;

  /// No description provided for @insightKindSourceMix.
  ///
  /// In en, this message translates to:
  /// **'source mix insight'**
  String get insightKindSourceMix;

  /// No description provided for @insightKindActionPattern.
  ///
  /// In en, this message translates to:
  /// **'action pattern insight'**
  String get insightKindActionPattern;

  /// No description provided for @insightKindAttachmentEvidence.
  ///
  /// In en, this message translates to:
  /// **'attachment evidence insight'**
  String get insightKindAttachmentEvidence;

  /// No description provided for @insightMetricSourceLinked.
  ///
  /// In en, this message translates to:
  /// **'source-linked'**
  String get insightMetricSourceLinked;

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

  /// No description provided for @recordStatusProcessingShort.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get recordStatusProcessingShort;

  /// No description provided for @recordStatusProcessedShort.
  ///
  /// In en, this message translates to:
  /// **'Processed'**
  String get recordStatusProcessedShort;

  /// No description provided for @recordStatusFailedShort.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get recordStatusFailedShort;

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

  /// No description provided for @todoReviewCaptureTitle.
  ///
  /// In en, this message translates to:
  /// **'Review capture'**
  String get todoReviewCaptureTitle;

  /// No description provided for @todoSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'source: {sourceId}'**
  String todoSourceLabel(String sourceId);

  /// No description provided for @sourceLabel.
  ///
  /// In en, this message translates to:
  /// **'source: {sourceId}'**
  String sourceLabel(String sourceId);

  /// No description provided for @sourceKindIdLabel.
  ///
  /// In en, this message translates to:
  /// **'{kind}: {sourceId}'**
  String sourceKindIdLabel(String kind, String sourceId);

  /// No description provided for @sourceKindIdExtraLabel.
  ///
  /// In en, this message translates to:
  /// **'{kind}: {sourceId} +{extraCount}'**
  String sourceKindIdExtraLabel(String kind, String sourceId, int extraCount);

  /// No description provided for @sourceUnknownLabel.
  ///
  /// In en, this message translates to:
  /// **'unknown source'**
  String get sourceUnknownLabel;

  /// No description provided for @sourceLocalRecordLabel.
  ///
  /// In en, this message translates to:
  /// **'Local record · {time}'**
  String sourceLocalRecordLabel(String time);

  /// No description provided for @sourceKindRawText.
  ///
  /// In en, this message translates to:
  /// **'raw text'**
  String get sourceKindRawText;

  /// No description provided for @sourceKindAttachment.
  ///
  /// In en, this message translates to:
  /// **'attachment'**
  String get sourceKindAttachment;

  /// No description provided for @sourceKindFile.
  ///
  /// In en, this message translates to:
  /// **'file'**
  String get sourceKindFile;

  /// No description provided for @attachmentArtifactStatusPending.
  ///
  /// In en, this message translates to:
  /// **'pending'**
  String get attachmentArtifactStatusPending;

  /// No description provided for @attachmentArtifactStatusReady.
  ///
  /// In en, this message translates to:
  /// **'ready'**
  String get attachmentArtifactStatusReady;

  /// No description provided for @attachmentArtifactStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get attachmentArtifactStatusFailed;

  /// No description provided for @attachmentArtifactStatusBlocked.
  ///
  /// In en, this message translates to:
  /// **'blocked'**
  String get attachmentArtifactStatusBlocked;

  /// No description provided for @attachmentArtifactStatusNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'needs review'**
  String get attachmentArtifactStatusNeedsReview;

  /// No description provided for @attachmentArtifactKindAudioTranscript.
  ///
  /// In en, this message translates to:
  /// **'audio transcript'**
  String get attachmentArtifactKindAudioTranscript;

  /// No description provided for @attachmentArtifactKindImageDerivatives.
  ///
  /// In en, this message translates to:
  /// **'image artifact'**
  String get attachmentArtifactKindImageDerivatives;

  /// No description provided for @attachmentArtifactKindOcrText.
  ///
  /// In en, this message translates to:
  /// **'OCR text'**
  String get attachmentArtifactKindOcrText;

  /// No description provided for @attachmentArtifactKindVisionSummary.
  ///
  /// In en, this message translates to:
  /// **'image summary'**
  String get attachmentArtifactKindVisionSummary;

  /// No description provided for @attachmentArtifactKindSharedText.
  ///
  /// In en, this message translates to:
  /// **'shared text'**
  String get attachmentArtifactKindSharedText;

  /// No description provided for @timelineAttachmentArtifactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Attachment artifacts'**
  String get timelineAttachmentArtifactsTitle;

  /// No description provided for @sourceLinkCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 source link} other{{count} source links}}'**
  String sourceLinkCount(int count);

  /// No description provided for @localTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'{time} local'**
  String localTimeLabel(String time);

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

  /// No description provided for @todoStatusNotSuggested.
  ///
  /// In en, this message translates to:
  /// **'not suggested'**
  String get todoStatusNotSuggested;

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

  /// No description provided for @todoUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Todo update failed.'**
  String get todoUpdateFailed;

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

  /// No description provided for @chatNewSessionButton.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get chatNewSessionButton;

  /// No description provided for @chatNewSessionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Start a new chat'**
  String get chatNewSessionTooltip;

  /// No description provided for @chatConversationListTitle.
  ///
  /// In en, this message translates to:
  /// **'Conversations'**
  String get chatConversationListTitle;

  /// No description provided for @chatActiveSessionLabel.
  ///
  /// In en, this message translates to:
  /// **'Current chat'**
  String get chatActiveSessionLabel;

  /// No description provided for @chatDefaultSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get chatDefaultSessionTitle;

  /// No description provided for @chatSessionMessageCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Empty} =1{1 message} other{{count} messages}}'**
  String chatSessionMessageCount(int count);

  /// No description provided for @chatSessionActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Chat actions'**
  String get chatSessionActionsTooltip;

  /// No description provided for @chatRenameSessionAction.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get chatRenameSessionAction;

  /// No description provided for @chatDeleteSessionAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDeleteSessionAction;

  /// No description provided for @chatRenameSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename chat'**
  String get chatRenameSessionTitle;

  /// No description provided for @chatRenameSessionHint.
  ///
  /// In en, this message translates to:
  /// **'Chat title'**
  String get chatRenameSessionHint;

  /// No description provided for @chatDeleteSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete chat?'**
  String get chatDeleteSessionTitle;

  /// No description provided for @chatDeleteSessionBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the local chat and its messages from this device.'**
  String get chatDeleteSessionBody;

  /// No description provided for @chatDeleteSessionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get chatDeleteSessionConfirm;

  /// No description provided for @chatSessionDeletedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Chat deleted.'**
  String get chatSessionDeletedSnackbar;

  /// No description provided for @chatEmptySessions.
  ///
  /// In en, this message translates to:
  /// **'No local sessions yet.'**
  String get chatEmptySessions;

  /// No description provided for @chatBackToConversationsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back to conversations'**
  String get chatBackToConversationsTooltip;

  /// No description provided for @chatBackToConversationsButton.
  ///
  /// In en, this message translates to:
  /// **'Back to conversations'**
  String get chatBackToConversationsButton;

  /// No description provided for @chatSessionMissingTitle.
  ///
  /// In en, this message translates to:
  /// **'Chat not found'**
  String get chatSessionMissingTitle;

  /// No description provided for @chatSessionMissingBody.
  ///
  /// In en, this message translates to:
  /// **'This local chat is no longer available on this device.'**
  String get chatSessionMissingBody;

  /// No description provided for @chatSessionOpeningTitle.
  ///
  /// In en, this message translates to:
  /// **'Opening chat'**
  String get chatSessionOpeningTitle;

  /// No description provided for @chatSessionSwitchBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Answer in progress'**
  String get chatSessionSwitchBlockedTitle;

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

  /// No description provided for @chatContextCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get chatContextCardTitle;

  /// No description provided for @chatContextInsightTitle.
  ///
  /// In en, this message translates to:
  /// **'Insight'**
  String get chatContextInsightTitle;

  /// No description provided for @chatContextRedactedTitle.
  ///
  /// In en, this message translates to:
  /// **'Redacted source'**
  String get chatContextRedactedTitle;

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

  /// No description provided for @chatErrorModelNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Model access is not configured. Add a provider in Settings, then retry.'**
  String get chatErrorModelNotConfigured;

  /// No description provided for @chatErrorModelEmptyAnswer.
  ///
  /// In en, this message translates to:
  /// **'The model returned no answer. Retry or choose another provider.'**
  String get chatErrorModelEmptyAnswer;

  /// No description provided for @chatErrorModelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The model is unavailable. Check provider settings or retry.'**
  String get chatErrorModelUnavailable;

  /// No description provided for @todosTitle.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get todosTitle;

  /// No description provided for @todosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Source-linked action items and schedule candidates, separated from ordinary records.'**
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

  /// No description provided for @todoActionsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Action items'**
  String get todoActionsSectionTitle;

  /// No description provided for @todoActionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No clear action items yet.'**
  String get todoActionsEmpty;

  /// No description provided for @todoSchedulesSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule candidates'**
  String get todoSchedulesSectionTitle;

  /// No description provided for @todoSchedulesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No schedule candidates yet.'**
  String get todoSchedulesEmpty;

  /// No description provided for @todoStatusSuggestedAction.
  ///
  /// In en, this message translates to:
  /// **'Suggested action'**
  String get todoStatusSuggestedAction;

  /// No description provided for @todoStatusScheduleCandidate.
  ///
  /// In en, this message translates to:
  /// **'Schedule candidate'**
  String get todoStatusScheduleCandidate;

  /// No description provided for @todoQuietTitle.
  ///
  /// In en, this message translates to:
  /// **'Kept out of actions'**
  String get todoQuietTitle;

  /// No description provided for @todoQuietSummary.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {# record did not have a clear action or schedule intent. It stays on the timeline.} other {# records did not have clear action or schedule intent. They stay on the timeline.}}'**
  String todoQuietSummary(num count);

  /// No description provided for @todoScheduledForLabel.
  ///
  /// In en, this message translates to:
  /// **'Time cue: {time}'**
  String todoScheduledForLabel(String time);

  /// No description provided for @todoSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tasks'**
  String get todoSearchHint;

  /// No description provided for @todoSummaryOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get todoSummaryOpen;

  /// No description provided for @todoSummarySchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get todoSummarySchedule;

  /// No description provided for @todoSummaryCompleted.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get todoSummaryCompleted;

  /// No description provided for @todoNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching tasks.'**
  String get todoNoMatches;

  /// No description provided for @todoBucketOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get todoBucketOverdue;

  /// No description provided for @todoBucketToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todoBucketToday;

  /// No description provided for @todoBucketTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get todoBucketTomorrow;

  /// No description provided for @todoBucketLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get todoBucketLater;

  /// No description provided for @todoBucketNoDeadline.
  ///
  /// In en, this message translates to:
  /// **'No deadline'**
  String get todoBucketNoDeadline;

  /// No description provided for @todoBucketScheduleCandidates.
  ///
  /// In en, this message translates to:
  /// **'Schedule candidates'**
  String get todoBucketScheduleCandidates;

  /// No description provided for @todoBucketCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get todoBucketCompleted;

  /// No description provided for @todoCompletedEmpty.
  ///
  /// In en, this message translates to:
  /// **'No completed tasks yet.'**
  String get todoCompletedEmpty;

  /// No description provided for @todoPriorityNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get todoPriorityNone;

  /// No description provided for @todoPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get todoPriorityLow;

  /// No description provided for @todoPriorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get todoPriorityMedium;

  /// No description provided for @todoPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get todoPriorityHigh;

  /// No description provided for @todoDueNone.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get todoDueNone;

  /// No description provided for @todoDueToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get todoDueToday;

  /// No description provided for @todoDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get todoDueTomorrow;

  /// No description provided for @todoDueLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get todoDueLater;

  /// No description provided for @todoDueLabel.
  ///
  /// In en, this message translates to:
  /// **'Due: {date}'**
  String todoDueLabel(String date);

  /// No description provided for @todoSubtaskProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} subtasks'**
  String todoSubtaskProgress(int completed, int total);

  /// No description provided for @todoDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Task detail'**
  String get todoDetailTitle;

  /// No description provided for @todoDetailMissing.
  ///
  /// In en, this message translates to:
  /// **'This task is no longer available.'**
  String get todoDetailMissing;

  /// No description provided for @todoDetailContent.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get todoDetailContent;

  /// No description provided for @todoDetailTitleField.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get todoDetailTitleField;

  /// No description provided for @todoDetailSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save title'**
  String get todoDetailSaveTitle;

  /// No description provided for @todoDetailStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get todoDetailStatus;

  /// No description provided for @todoCompletedAtLabel.
  ///
  /// In en, this message translates to:
  /// **'Completed: {date}'**
  String todoCompletedAtLabel(String date);

  /// No description provided for @todoDetailScheduleNotice.
  ///
  /// In en, this message translates to:
  /// **'Schedule candidates are local suggestions and are not completed like action items.'**
  String get todoDetailScheduleNotice;

  /// No description provided for @todoDetailCompletedNotice.
  ///
  /// In en, this message translates to:
  /// **'Completed tasks stay at the bottom. Reopen to move this task back to active buckets.'**
  String get todoDetailCompletedNotice;

  /// No description provided for @todoDetailMetadata.
  ///
  /// In en, this message translates to:
  /// **'Task metadata'**
  String get todoDetailMetadata;

  /// No description provided for @todoDetailPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get todoDetailPriority;

  /// No description provided for @todoDetailDue.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get todoDetailDue;

  /// No description provided for @todoDetailIndent.
  ///
  /// In en, this message translates to:
  /// **'Indent level {level}'**
  String todoDetailIndent(int level);

  /// No description provided for @todoDetailSort.
  ///
  /// In en, this message translates to:
  /// **'Sort order {order}'**
  String todoDetailSort(int order);

  /// No description provided for @todoDetailSubtasks.
  ///
  /// In en, this message translates to:
  /// **'Subtasks'**
  String get todoDetailSubtasks;

  /// No description provided for @todoDetailNoSubtasks.
  ///
  /// In en, this message translates to:
  /// **'No structured subtasks.'**
  String get todoDetailNoSubtasks;

  /// No description provided for @todoDetailSource.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get todoDetailSource;

  /// No description provided for @todoDetailOpenSource.
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get todoDetailOpenSource;

  /// No description provided for @timelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get timelineTitle;

  /// No description provided for @timelineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse captures, cards, Memory, insights, and todos.'**
  String get timelineSubtitle;

  /// No description provided for @timelineSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search timeline'**
  String get timelineSearchTooltip;

  /// No description provided for @timelineBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back to timeline'**
  String get timelineBackTooltip;

  /// No description provided for @timelineLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Timeline failed to load: {error}'**
  String timelineLoadFailed(String error);

  /// No description provided for @timelineUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeline unavailable'**
  String get timelineUnavailableTitle;

  /// No description provided for @timelineEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No timeline items yet'**
  String get timelineEmptyTitle;

  /// No description provided for @timelineEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Capture something locally to create source-linked cards.'**
  String get timelineEmptyBody;

  /// No description provided for @timelineUntitledCapture.
  ///
  /// In en, this message translates to:
  /// **'Untitled capture'**
  String get timelineUntitledCapture;

  /// No description provided for @timelineUntitledTodo.
  ///
  /// In en, this message translates to:
  /// **'Untitled todo'**
  String get timelineUntitledTodo;

  /// No description provided for @timelineStartCaptureButton.
  ///
  /// In en, this message translates to:
  /// **'Start capture'**
  String get timelineStartCaptureButton;

  /// No description provided for @timelineSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get timelineSearchTitle;

  /// No description provided for @timelineSearchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Filter the local timeline without leaving the device.'**
  String get timelineSearchSubtitle;

  /// No description provided for @timelineSearchUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Search unavailable'**
  String get timelineSearchUnavailableTitle;

  /// No description provided for @timelineSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Timeline search failed: {error}'**
  String timelineSearchFailed(String error);

  /// No description provided for @timelineSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Filter by type, or use text after retriever setup'**
  String get timelineSearchHint;

  /// No description provided for @timelineFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get timelineFilterAll;

  /// No description provided for @timelineSearchEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing to search yet'**
  String get timelineSearchEmptyTitle;

  /// No description provided for @timelineSearchEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Create a capture first, then browse cards, Memory, and todos.'**
  String get timelineSearchEmptyBody;

  /// No description provided for @timelineSearchNeedsRetrieverTitle.
  ///
  /// In en, this message translates to:
  /// **'Text search needs a retriever'**
  String get timelineSearchNeedsRetrieverTitle;

  /// No description provided for @timelineSearchNeedsRetrieverBody.
  ///
  /// In en, this message translates to:
  /// **'Clear the text field to browse locally by type. Semantic search will use a model-backed retriever.'**
  String get timelineSearchNeedsRetrieverBody;

  /// No description provided for @timelineSearchNoResultsTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching timeline items'**
  String get timelineSearchNoResultsTitle;

  /// No description provided for @timelineSearchNoResultsBody.
  ///
  /// In en, this message translates to:
  /// **'Remove the type filter to show more local items.'**
  String get timelineSearchNoResultsBody;

  /// No description provided for @timelineSearchResultCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 result} other{{count} results}}'**
  String timelineSearchResultCount(int count);

  /// No description provided for @timelineKindCapture.
  ///
  /// In en, this message translates to:
  /// **'Capture'**
  String get timelineKindCapture;

  /// No description provided for @timelineKindCaptures.
  ///
  /// In en, this message translates to:
  /// **'Captures'**
  String get timelineKindCaptures;

  /// No description provided for @timelineKindCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get timelineKindCard;

  /// No description provided for @timelineKindCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get timelineKindCards;

  /// No description provided for @timelineKindInsight.
  ///
  /// In en, this message translates to:
  /// **'Insight'**
  String get timelineKindInsight;

  /// No description provided for @timelineKindInsights.
  ///
  /// In en, this message translates to:
  /// **'Insights'**
  String get timelineKindInsights;

  /// No description provided for @timelineKindMemory.
  ///
  /// In en, this message translates to:
  /// **'Memory'**
  String get timelineKindMemory;

  /// No description provided for @timelineKindTodo.
  ///
  /// In en, this message translates to:
  /// **'Todo'**
  String get timelineKindTodo;

  /// No description provided for @timelineKindTodos.
  ///
  /// In en, this message translates to:
  /// **'Todos'**
  String get timelineKindTodos;

  /// No description provided for @timelineKindEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get timelineKindEvent;

  /// No description provided for @timelineKindDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'{kind} Detail'**
  String timelineKindDetailTitle(String kind);

  /// No description provided for @timelineCardDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Card Detail'**
  String get timelineCardDetailTitle;

  /// No description provided for @timelineCardDetailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect the card body, provenance, and related items.'**
  String get timelineCardDetailSubtitle;

  /// No description provided for @timelineCardUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Card unavailable'**
  String get timelineCardUnavailableTitle;

  /// No description provided for @timelineCardFailed.
  ///
  /// In en, this message translates to:
  /// **'Card detail failed: {error}'**
  String timelineCardFailed(String error);

  /// No description provided for @timelineCardNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Card not found'**
  String get timelineCardNotFoundTitle;

  /// No description provided for @timelineCardNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'The selected card is not in the current local timeline.'**
  String get timelineCardNotFoundBody;

  /// No description provided for @timelineSourceRefsTitle.
  ///
  /// In en, this message translates to:
  /// **'Source refs'**
  String get timelineSourceRefsTitle;

  /// No description provided for @timelineRelatedRecordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Related records'**
  String get timelineRelatedRecordsTitle;

  /// No description provided for @timelineRelatedMemoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Related Memory'**
  String get timelineRelatedMemoryTitle;

  /// No description provided for @timelineRelatedTodosTitle.
  ///
  /// In en, this message translates to:
  /// **'Related todos'**
  String get timelineRelatedTodosTitle;

  /// No description provided for @timelineNoLinkedItems.
  ///
  /// In en, this message translates to:
  /// **'No linked items.'**
  String get timelineNoLinkedItems;

  /// No description provided for @timelineItemDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeline Detail'**
  String get timelineItemDetailTitle;

  /// No description provided for @timelineItemDetailSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect the local item, status, metadata, and sources.'**
  String get timelineItemDetailSubtitle;

  /// No description provided for @timelineItemUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeline item unavailable'**
  String get timelineItemUnavailableTitle;

  /// No description provided for @timelineItemFailed.
  ///
  /// In en, this message translates to:
  /// **'Timeline item failed: {error}'**
  String timelineItemFailed(String error);

  /// No description provided for @timelineSourceNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Source not found'**
  String get timelineSourceNotFoundTitle;

  /// No description provided for @timelineSourceNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This source reference is not available in the current local index yet.'**
  String get timelineSourceNotFoundBody;

  /// No description provided for @timelineStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get timelineStatusTitle;

  /// No description provided for @timelineMetadataTitle.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get timelineMetadataTitle;

  /// No description provided for @timelineOpenSourceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get timelineOpenSourceTooltip;

  /// No description provided for @timelineSourceRefCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 source ref} other{{count} source refs}}'**
  String timelineSourceRefCount(int count);

  /// No description provided for @timelineStatusActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get timelineStatusActive;

  /// No description provided for @timelineStatusDeleted.
  ///
  /// In en, this message translates to:
  /// **'deleted'**
  String get timelineStatusDeleted;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy, permissions, models, backup, and logs.'**
  String get settingsSubtitle;

  /// No description provided for @settingsBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back from Settings'**
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
  /// **'Records, Memory, todos, cards, chat, and logs stay on this device unless you choose backup, sync, or a provider.'**
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
  /// **'Full .widenote backups include provider and allowlisted secure-storage keys so restore can use configured features immediately. Keep backup files in a trusted location.'**
  String get settingsPrivacyBackupBody;

  /// No description provided for @settingsPrivacyBackupStatus.
  ///
  /// In en, this message translates to:
  /// **'full backup'**
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

  /// No description provided for @settingsSystemPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'System Permissions'**
  String get settingsSystemPermissionsTitle;

  /// No description provided for @settingsSystemPermissionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check camera, microphone, location, photos, files, and calendar access.'**
  String get settingsSystemPermissionsSubtitle;

  /// No description provided for @settingsSystemPermissionsStatus.
  ///
  /// In en, this message translates to:
  /// **'device'**
  String get settingsSystemPermissionsStatus;

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

  /// No description provided for @settingsTranscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice Transcription'**
  String get settingsTranscriptionTitle;

  /// No description provided for @settingsTranscriptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure local SenseVoice, MiMo ASR, live preview, and transcript correction.'**
  String get settingsTranscriptionSubtitle;

  /// No description provided for @settingsTranscriptionStatusLoading.
  ///
  /// In en, this message translates to:
  /// **'loading'**
  String get settingsTranscriptionStatusLoading;

  /// No description provided for @settingsTranscriptionStatusLocal.
  ///
  /// In en, this message translates to:
  /// **'local'**
  String get settingsTranscriptionStatusLocal;

  /// No description provided for @settingsTranscriptionStatusRemote.
  ///
  /// In en, this message translates to:
  /// **'MiMo'**
  String get settingsTranscriptionStatusRemote;

  /// No description provided for @settingsTranscriptionStatusNeedsSetup.
  ///
  /// In en, this message translates to:
  /// **'setup'**
  String get settingsTranscriptionStatusNeedsSetup;

  /// No description provided for @settingsBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get settingsBackupTitle;

  /// No description provided for @settingsBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Export or import local records, Memory, cards, providers, todos, and logs.'**
  String get settingsBackupSubtitle;

  /// No description provided for @settingsBackupStatus.
  ///
  /// In en, this message translates to:
  /// **'local'**
  String get settingsBackupStatus;

  /// No description provided for @settingsBackupStatusSafeOnly.
  ///
  /// In en, this message translates to:
  /// **'full local'**
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
  /// **'Log Center'**
  String get settingsTraceConsoleTitle;

  /// No description provided for @settingsTraceConsoleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review local Agent Runtime logs, permission checks, and generated outputs.'**
  String get settingsTraceConsoleSubtitle;

  /// No description provided for @settingsTraceConsoleStatus.
  ///
  /// In en, this message translates to:
  /// **'read-only'**
  String get settingsTraceConsoleStatus;

  /// No description provided for @settingsTraceConsoleStatusSummary.
  ///
  /// In en, this message translates to:
  /// **'{eventCount} logs / {warningCount} warnings'**
  String settingsTraceConsoleStatusSummary(int eventCount, int warningCount);

  /// No description provided for @systemPermissionsTitle.
  ///
  /// In en, this message translates to:
  /// **'System Permissions'**
  String get systemPermissionsTitle;

  /// No description provided for @systemPermissionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review app-level device permissions and jump to the right system setting when needed.'**
  String get systemPermissionsSubtitle;

  /// No description provided for @systemPermissionsBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back from System Permissions'**
  String get systemPermissionsBackTooltip;

  /// No description provided for @systemPermissionsLoading.
  ///
  /// In en, this message translates to:
  /// **'Checking permissions'**
  String get systemPermissionsLoading;

  /// No description provided for @systemPermissionsError.
  ///
  /// In en, this message translates to:
  /// **'Permission status unavailable'**
  String get systemPermissionsError;

  /// No description provided for @systemPermissionsSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Device status'**
  String get systemPermissionsSummaryTitle;

  /// No description provided for @systemPermissionsSummary.
  ///
  /// In en, this message translates to:
  /// **'{grantedCount} ready / {reviewCount} need attention'**
  String systemPermissionsSummary(int grantedCount, int reviewCount);

  /// No description provided for @systemPermissionsPlatformAndroid.
  ///
  /// In en, this message translates to:
  /// **'Android'**
  String get systemPermissionsPlatformAndroid;

  /// No description provided for @systemPermissionsPlatformIos.
  ///
  /// In en, this message translates to:
  /// **'iOS'**
  String get systemPermissionsPlatformIos;

  /// No description provided for @systemPermissionsPlatformOther.
  ///
  /// In en, this message translates to:
  /// **'mobile only'**
  String get systemPermissionsPlatformOther;

  /// No description provided for @systemPermissionsRefreshAction.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get systemPermissionsRefreshAction;

  /// No description provided for @systemPermissionsDeviceAccessTitle.
  ///
  /// In en, this message translates to:
  /// **'App access'**
  String get systemPermissionsDeviceAccessTitle;

  /// No description provided for @systemPermissionsStatusGranted.
  ///
  /// In en, this message translates to:
  /// **'allowed'**
  String get systemPermissionsStatusGranted;

  /// No description provided for @systemPermissionsStatusLimited.
  ///
  /// In en, this message translates to:
  /// **'limited'**
  String get systemPermissionsStatusLimited;

  /// No description provided for @systemPermissionsStatusDenied.
  ///
  /// In en, this message translates to:
  /// **'not allowed'**
  String get systemPermissionsStatusDenied;

  /// No description provided for @systemPermissionsStatusPermanentlyDenied.
  ///
  /// In en, this message translates to:
  /// **'settings'**
  String get systemPermissionsStatusPermanentlyDenied;

  /// No description provided for @systemPermissionsStatusRestricted.
  ///
  /// In en, this message translates to:
  /// **'restricted'**
  String get systemPermissionsStatusRestricted;

  /// No description provided for @systemPermissionsStatusNotRequired.
  ///
  /// In en, this message translates to:
  /// **'picker'**
  String get systemPermissionsStatusNotRequired;

  /// No description provided for @systemPermissionsStatusNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'not enabled'**
  String get systemPermissionsStatusNotConfigured;

  /// No description provided for @systemPermissionsStatusNotSupported.
  ///
  /// In en, this message translates to:
  /// **'unsupported'**
  String get systemPermissionsStatusNotSupported;

  /// No description provided for @systemPermissionsStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'unknown'**
  String get systemPermissionsStatusUnknown;

  /// No description provided for @systemPermissionsStatusServiceOff.
  ///
  /// In en, this message translates to:
  /// **'service off'**
  String get systemPermissionsStatusServiceOff;

  /// No description provided for @systemPermissionsActionRequest.
  ///
  /// In en, this message translates to:
  /// **'Request'**
  String get systemPermissionsActionRequest;

  /// No description provided for @systemPermissionsActionManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get systemPermissionsActionManage;

  /// No description provided for @systemPermissionsActionOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get systemPermissionsActionOpenSettings;

  /// No description provided for @systemPermissionsLocationServiceOffBody.
  ///
  /// In en, this message translates to:
  /// **'Location services are off at the system level.'**
  String get systemPermissionsLocationServiceOffBody;

  /// No description provided for @systemPermissionsCameraTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get systemPermissionsCameraTitle;

  /// No description provided for @systemPermissionsCameraSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used only when you capture a local photo attachment.'**
  String get systemPermissionsCameraSubtitle;

  /// No description provided for @systemPermissionsMicrophoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get systemPermissionsMicrophoneTitle;

  /// No description provided for @systemPermissionsMicrophoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used only when you save local voice recordings.'**
  String get systemPermissionsMicrophoneSubtitle;

  /// No description provided for @systemPermissionsLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get systemPermissionsLocationTitle;

  /// No description provided for @systemPermissionsLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Used only for foreground GPS metadata after Location Context is enabled.'**
  String get systemPermissionsLocationSubtitle;

  /// No description provided for @systemPermissionsPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'Photos & Media'**
  String get systemPermissionsPhotosTitle;

  /// No description provided for @systemPermissionsPhotosSubtitle.
  ///
  /// In en, this message translates to:
  /// **'On iOS, review selected photo library access for local media attachments.'**
  String get systemPermissionsPhotosSubtitle;

  /// No description provided for @systemPermissionsPhotosAndroidSubtitle.
  ///
  /// In en, this message translates to:
  /// **'On Android, WideNote uses the system photo picker without broad media permission.'**
  String get systemPermissionsPhotosAndroidSubtitle;

  /// No description provided for @systemPermissionsFilesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get systemPermissionsFilesTitle;

  /// No description provided for @systemPermissionsFilesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Backups and imports use system document pickers without broad file access.'**
  String get systemPermissionsFilesSubtitle;

  /// No description provided for @systemPermissionsCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get systemPermissionsCalendarTitle;

  /// No description provided for @systemPermissionsCalendarSubtitle.
  ///
  /// In en, this message translates to:
  /// **'System calendar read/write is not enabled until a follow-up permission decision lands.'**
  String get systemPermissionsCalendarSubtitle;

  /// No description provided for @pluginsTitle.
  ///
  /// In en, this message translates to:
  /// **'Packs'**
  String get pluginsTitle;

  /// No description provided for @pluginsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pack controls for permissions, models, backup, and logs.'**
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
  /// **'Log Center'**
  String get pluginsTraceConsoleTitle;

  /// No description provided for @pluginsTraceConsoleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect local runtime logs, approvals, traces, and pack output.'**
  String get pluginsTraceConsoleSubtitle;

  /// No description provided for @pluginsTraceConsoleStatus.
  ///
  /// In en, this message translates to:
  /// **'local'**
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

  /// No description provided for @packLibraryEnabledCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 enabled} other{{count} enabled}}'**
  String packLibraryEnabledCount(int count);

  /// No description provided for @packLibraryDisabledCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 disabled} other{{count} disabled}}'**
  String packLibraryDisabledCount(int count);

  /// No description provided for @packLibraryDisableImpact.
  ///
  /// In en, this message translates to:
  /// **'Disabling affects future local tasks only. It does not delete records, traces, or derived outputs already stored on this device.'**
  String get packLibraryDisableImpact;

  /// No description provided for @packLibraryPublisher.
  ///
  /// In en, this message translates to:
  /// **'publisher: {publisher}'**
  String packLibraryPublisher(String publisher);

  /// No description provided for @packLibraryEdition.
  ///
  /// In en, this message translates to:
  /// **'edition: {edition}'**
  String packLibraryEdition(String edition);

  /// No description provided for @packLibraryMarketplaceSource.
  ///
  /// In en, this message translates to:
  /// **'source: {source}'**
  String packLibraryMarketplaceSource(String source);

  /// No description provided for @packLibraryTrustLevel.
  ///
  /// In en, this message translates to:
  /// **'trust: {trust}'**
  String packLibraryTrustLevel(String trust);

  /// No description provided for @packLibraryCategories.
  ///
  /// In en, this message translates to:
  /// **'categories: {categories}'**
  String packLibraryCategories(String categories);

  /// No description provided for @packLibraryCapabilities.
  ///
  /// In en, this message translates to:
  /// **'capabilities: {capabilities}'**
  String packLibraryCapabilities(String capabilities);

  /// No description provided for @packLibraryReplacementSlots.
  ///
  /// In en, this message translates to:
  /// **'replacement slots: {slots}'**
  String packLibraryReplacementSlots(String slots);

  /// No description provided for @packLibraryAdditiveSlots.
  ///
  /// In en, this message translates to:
  /// **'additive slots: {slots}'**
  String packLibraryAdditiveSlots(String slots);

  /// No description provided for @packLibraryEntrypoint.
  ///
  /// In en, this message translates to:
  /// **'runtime: {entrypoint}'**
  String packLibraryEntrypoint(String entrypoint);

  /// No description provided for @packLibrarySubscriptionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 subscription} other{{count} subscriptions}}'**
  String packLibrarySubscriptionCount(int count);

  /// No description provided for @packLibraryFailureCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 failure} other{{count} failures}}'**
  String packLibraryFailureCount(int count);

  /// No description provided for @packLibraryPermissionDecisionSummary.
  ///
  /// In en, this message translates to:
  /// **'permissions: {granted} granted / {denied} denied / {revoked} revoked'**
  String packLibraryPermissionDecisionSummary(
    int granted,
    int denied,
    int revoked,
  );

  /// No description provided for @packLibraryLastFailure.
  ///
  /// In en, this message translates to:
  /// **'Last failure: {message}'**
  String packLibraryLastFailure(String message);

  /// No description provided for @packLibraryStatusEnabled.
  ///
  /// In en, this message translates to:
  /// **'enabled'**
  String get packLibraryStatusEnabled;

  /// No description provided for @packLibraryStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'disabled'**
  String get packLibraryStatusDisabled;

  /// No description provided for @packLibraryStatusUnknown.
  ///
  /// In en, this message translates to:
  /// **'status: {status}'**
  String packLibraryStatusUnknown(String status);

  /// No description provided for @packLibraryRuntimeIdle.
  ///
  /// In en, this message translates to:
  /// **'runtime: idle'**
  String get packLibraryRuntimeIdle;

  /// No description provided for @packLibraryRuntimeQueued.
  ///
  /// In en, this message translates to:
  /// **'runtime: queued'**
  String get packLibraryRuntimeQueued;

  /// No description provided for @packLibraryRuntimeRunning.
  ///
  /// In en, this message translates to:
  /// **'runtime: running'**
  String get packLibraryRuntimeRunning;

  /// No description provided for @packLibraryRuntimeSucceeded.
  ///
  /// In en, this message translates to:
  /// **'runtime: succeeded'**
  String get packLibraryRuntimeSucceeded;

  /// No description provided for @packLibraryRuntimeFailed.
  ///
  /// In en, this message translates to:
  /// **'runtime: failed'**
  String get packLibraryRuntimeFailed;

  /// No description provided for @packLibraryRuntimeDenied.
  ///
  /// In en, this message translates to:
  /// **'runtime: denied'**
  String get packLibraryRuntimeDenied;

  /// No description provided for @packLibraryRuntimeCanceled.
  ///
  /// In en, this message translates to:
  /// **'runtime: canceled'**
  String get packLibraryRuntimeCanceled;

  /// No description provided for @packLibraryRuntimeBlocked.
  ///
  /// In en, this message translates to:
  /// **'runtime: blocked'**
  String get packLibraryRuntimeBlocked;

  /// No description provided for @packLibraryRuntimeUnknown.
  ///
  /// In en, this message translates to:
  /// **'runtime: {status}'**
  String packLibraryRuntimeUnknown(String status);

  /// No description provided for @packDefaultName.
  ///
  /// In en, this message translates to:
  /// **'Default Capture Loop'**
  String get packDefaultName;

  /// No description provided for @packDefaultDescription.
  ///
  /// In en, this message translates to:
  /// **'Conservative built-in pack for capture cards, Memory candidates, and lightweight insight.'**
  String get packDefaultDescription;

  /// No description provided for @packTodoName.
  ///
  /// In en, this message translates to:
  /// **'Todo Extraction Loop'**
  String get packTodoName;

  /// No description provided for @packTodoDescription.
  ///
  /// In en, this message translates to:
  /// **'Built-in pack for source-linked todo suggestions.'**
  String get packTodoDescription;

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

  /// No description provided for @permissionGateImpactAvailable.
  ///
  /// In en, this message translates to:
  /// **'Grant or deny changes future local runs only.'**
  String get permissionGateImpactAvailable;

  /// No description provided for @permissionGateImpactGranted.
  ///
  /// In en, this message translates to:
  /// **'Future local runs may use this permission until you revoke it.'**
  String get permissionGateImpactGranted;

  /// No description provided for @permissionGateImpactDenied.
  ///
  /// In en, this message translates to:
  /// **'Future local runs needing this permission are blocked; existing records and traces remain.'**
  String get permissionGateImpactDenied;

  /// No description provided for @permissionGateImpactRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revocation blocks future use; existing records, traces, and derived outputs remain for review.'**
  String get permissionGateImpactRevoked;

  /// No description provided for @permissionGateImpactDeferred.
  ///
  /// In en, this message translates to:
  /// **'This high-risk or external capability is disabled in the local L3 slice.'**
  String get permissionGateImpactDeferred;

  /// No description provided for @permissionGateRiskLow.
  ///
  /// In en, this message translates to:
  /// **'low risk'**
  String get permissionGateRiskLow;

  /// No description provided for @permissionGateRiskMedium.
  ///
  /// In en, this message translates to:
  /// **'medium risk'**
  String get permissionGateRiskMedium;

  /// No description provided for @permissionGateRiskHigh.
  ///
  /// In en, this message translates to:
  /// **'high risk'**
  String get permissionGateRiskHigh;

  /// No description provided for @permissionGateCommunityPacks.
  ///
  /// In en, this message translates to:
  /// **'community packs'**
  String get permissionGateCommunityPacks;

  /// No description provided for @permissionGateMediaPacks.
  ///
  /// In en, this message translates to:
  /// **'media packs'**
  String get permissionGateMediaPacks;

  /// No description provided for @permissionGateContextPacks.
  ///
  /// In en, this message translates to:
  /// **'context packs'**
  String get permissionGateContextPacks;

  /// No description provided for @permissionGateDeferredSandbox.
  ///
  /// In en, this message translates to:
  /// **'Deferred until sandbox approval exists.'**
  String get permissionGateDeferredSandbox;

  /// No description provided for @permissionGateDeferredExternalTools.
  ///
  /// In en, this message translates to:
  /// **'Deferred until external-tool permission design exists.'**
  String get permissionGateDeferredExternalTools;

  /// No description provided for @permissionGateDeferredPlatform.
  ///
  /// In en, this message translates to:
  /// **'Deferred until platform permission review exists.'**
  String get permissionGateDeferredPlatform;

  /// No description provided for @permissionGateDeferredPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Deferred until privacy decision coverage exists.'**
  String get permissionGateDeferredPrivacy;

  /// No description provided for @agentPlatformTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Center'**
  String get agentPlatformTitle;

  /// No description provided for @agentPlatformSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local runtime evidence from raw logs, runs, tasks, approvals, and traces.'**
  String get agentPlatformSubtitle;

  /// No description provided for @agentConsoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Center'**
  String get agentConsoleTitle;

  /// No description provided for @agentConsoleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local-first logs for runs, tasks, approvals, packs, and redacted traces.'**
  String get agentConsoleSubtitle;

  /// No description provided for @traceConsoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Log Center'**
  String get traceConsoleTitle;

  /// No description provided for @traceConsoleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review local Agent Runtime logs, permissions, and generated outputs.'**
  String get traceConsoleSubtitle;

  /// No description provided for @agentConsoleSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Local log summary'**
  String get agentConsoleSummaryTitle;

  /// No description provided for @traceConsoleSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Runtime summary'**
  String get traceConsoleSummaryTitle;

  /// No description provided for @traceConsoleEventCount.
  ///
  /// In en, this message translates to:
  /// **'Raw logs: {count}'**
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
  /// **'Open Log Center'**
  String get traceConsoleOpenButton;

  /// No description provided for @traceConsoleEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Raw logs'**
  String get traceConsoleEventsTitle;

  /// No description provided for @traceConsoleEventsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review local runtime trace rows as raw log evidence.'**
  String get traceConsoleEventsSubtitle;

  /// No description provided for @traceConsoleEventsEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Raw logs'**
  String get traceConsoleEventsEntryTitle;

  /// No description provided for @traceConsoleEventsEntryBody.
  ///
  /// In en, this message translates to:
  /// **'Show the local raw log stream directly. Credential, path, and media fields stay masked.'**
  String get traceConsoleEventsEntryBody;

  /// No description provided for @traceConsoleOpenEventsButton.
  ///
  /// In en, this message translates to:
  /// **'Open raw logs'**
  String get traceConsoleOpenEventsButton;

  /// No description provided for @traceConsoleEmpty.
  ///
  /// In en, this message translates to:
  /// **'No runtime logs yet. Capture or pack runs will appear here.'**
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

  /// No description provided for @agentConsoleTotalCount.
  ///
  /// In en, this message translates to:
  /// **'Total: {count}'**
  String agentConsoleTotalCount(int count);

  /// No description provided for @agentConsoleActiveCount.
  ///
  /// In en, this message translates to:
  /// **'Active: {count}'**
  String agentConsoleActiveCount(int count);

  /// No description provided for @agentConsoleFailedCount.
  ///
  /// In en, this message translates to:
  /// **'Failed: {count}'**
  String agentConsoleFailedCount(int count);

  /// No description provided for @agentConsoleDeniedCount.
  ///
  /// In en, this message translates to:
  /// **'Denied: {count}'**
  String agentConsoleDeniedCount(int count);

  /// No description provided for @agentConsoleBlockedCount.
  ///
  /// In en, this message translates to:
  /// **'Blocked: {count}'**
  String agentConsoleBlockedCount(int count);

  /// No description provided for @agentConsoleTaskCount.
  ///
  /// In en, this message translates to:
  /// **'Tasks: {count}'**
  String agentConsoleTaskCount(int count);

  /// No description provided for @agentConsolePendingApprovalCount.
  ///
  /// In en, this message translates to:
  /// **'Approvals: {count}'**
  String agentConsolePendingApprovalCount(int count);

  /// No description provided for @agentConsoleFilterTitle.
  ///
  /// In en, this message translates to:
  /// **'Status filter'**
  String get agentConsoleFilterTitle;

  /// No description provided for @agentConsoleFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get agentConsoleFilterAll;

  /// No description provided for @agentConsoleFilterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get agentConsoleFilterActive;

  /// No description provided for @agentConsoleFilterFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get agentConsoleFilterFailed;

  /// No description provided for @agentConsoleFilterDenied.
  ///
  /// In en, this message translates to:
  /// **'Denied'**
  String get agentConsoleFilterDenied;

  /// No description provided for @agentConsoleFilterBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get agentConsoleFilterBlocked;

  /// No description provided for @approvalQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Approval Queue'**
  String get approvalQueueTitle;

  /// No description provided for @approvalQueueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No pending local action approvals.'**
  String get approvalQueueEmpty;

  /// No description provided for @approvalQueueScaffoldBody.
  ///
  /// In en, this message translates to:
  /// **'Approval requests will stay paused here once a persisted approval store is available. This page does not approve or deny fake runtime work.'**
  String get approvalQueueScaffoldBody;

  /// No description provided for @agentConsoleRunsTitle.
  ///
  /// In en, this message translates to:
  /// **'Runs'**
  String get agentConsoleRunsTitle;

  /// No description provided for @agentConsoleRunsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No local runs match this filter.'**
  String get agentConsoleRunsEmpty;

  /// No description provided for @agentConsoleTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get agentConsoleTasksTitle;

  /// No description provided for @agentConsoleTasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No local tasks match this filter.'**
  String get agentConsoleTasksEmpty;

  /// No description provided for @agentConsoleStatus.
  ///
  /// In en, this message translates to:
  /// **'status: {status}'**
  String agentConsoleStatus(String status);

  /// No description provided for @agentConsoleSeverity.
  ///
  /// In en, this message translates to:
  /// **'severity: {severity}'**
  String agentConsoleSeverity(String severity);

  /// No description provided for @agentConsoleTask.
  ///
  /// In en, this message translates to:
  /// **'task: {taskId}'**
  String agentConsoleTask(String taskId);

  /// No description provided for @agentConsoleEvent.
  ///
  /// In en, this message translates to:
  /// **'event: {eventId}'**
  String agentConsoleEvent(String eventId);

  /// No description provided for @agentConsoleParentTrace.
  ///
  /// In en, this message translates to:
  /// **'parent trace: {traceId}'**
  String agentConsoleParentTrace(String traceId);

  /// No description provided for @agentConsoleAttempt.
  ///
  /// In en, this message translates to:
  /// **'attempt: {attempt}'**
  String agentConsoleAttempt(int attempt);

  /// No description provided for @agentConsoleTaskAttempts.
  ///
  /// In en, this message translates to:
  /// **'attempts: {attempts}/{maxAttempts}'**
  String agentConsoleTaskAttempts(int attempts, int maxAttempts);

  /// No description provided for @agentConsoleMissingDependencies.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 missing dependency} other{{count} missing dependencies}}'**
  String agentConsoleMissingDependencies(int count);

  /// No description provided for @agentConsoleOutputCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 output} other{{count} outputs}}'**
  String agentConsoleOutputCount(int count);

  /// No description provided for @agentConsoleStarted.
  ///
  /// In en, this message translates to:
  /// **'started: {time}'**
  String agentConsoleStarted(String time);

  /// No description provided for @agentConsoleCompleted.
  ///
  /// In en, this message translates to:
  /// **'completed: {time}'**
  String agentConsoleCompleted(String time);

  /// No description provided for @agentConsoleCreated.
  ///
  /// In en, this message translates to:
  /// **'created: {time}'**
  String agentConsoleCreated(String time);

  /// No description provided for @agentConsoleNotCompleted.
  ///
  /// In en, this message translates to:
  /// **'not completed'**
  String get agentConsoleNotCompleted;

  /// No description provided for @agentConsoleError.
  ///
  /// In en, this message translates to:
  /// **'Error: {message}'**
  String agentConsoleError(String message);

  /// No description provided for @agentConsoleRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get agentConsoleRetryAction;

  /// No description provided for @agentConsoleCancelAction.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get agentConsoleCancelAction;

  /// No description provided for @agentConsoleControlsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Retry and cancel are disabled until the mobile app exposes a live RuntimeKernel control provider. No fake success is performed here.'**
  String get agentConsoleControlsUnavailable;

  /// No description provided for @agentConsoleRunTracesTitle.
  ///
  /// In en, this message translates to:
  /// **'Trace list'**
  String get agentConsoleRunTracesTitle;

  /// No description provided for @agentConsoleRunNoTraces.
  ///
  /// In en, this message translates to:
  /// **'No traces recorded for this run yet.'**
  String get agentConsoleRunNoTraces;

  /// No description provided for @agentConsoleRunModeReadOnly.
  ///
  /// In en, this message translates to:
  /// **'run mode: read-only'**
  String get agentConsoleRunModeReadOnly;

  /// No description provided for @agentConsoleRunModeConfirm.
  ///
  /// In en, this message translates to:
  /// **'run mode: confirm'**
  String get agentConsoleRunModeConfirm;

  /// No description provided for @agentConsoleRunModeAuto.
  ///
  /// In en, this message translates to:
  /// **'run mode: auto'**
  String get agentConsoleRunModeAuto;

  /// No description provided for @agentConsoleRunModeUnknown.
  ///
  /// In en, this message translates to:
  /// **'run mode: unknown'**
  String get agentConsoleRunModeUnknown;

  /// No description provided for @agentConsoleChildDelegation.
  ///
  /// In en, this message translates to:
  /// **'delegation: {delegationId}'**
  String agentConsoleChildDelegation(String delegationId);

  /// No description provided for @agentConsoleChildRun.
  ///
  /// In en, this message translates to:
  /// **'child run: {runId}'**
  String agentConsoleChildRun(String runId);

  /// No description provided for @agentConsoleChildStatus.
  ///
  /// In en, this message translates to:
  /// **'child status: {status}'**
  String agentConsoleChildStatus(String status);

  /// No description provided for @agentConsoleDelegationViolations.
  ///
  /// In en, this message translates to:
  /// **'violations: {codes}'**
  String agentConsoleDelegationViolations(String codes);

  /// No description provided for @traceConsoleOpenSourceButton.
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get traceConsoleOpenSourceButton;

  /// No description provided for @traceConsoleNoSource.
  ///
  /// In en, this message translates to:
  /// **'No source reference is available for this trace.'**
  String get traceConsoleNoSource;

  /// No description provided for @traceConsolePayloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Redacted payload'**
  String get traceConsolePayloadTitle;

  /// No description provided for @traceConsolePayloadEmpty.
  ///
  /// In en, this message translates to:
  /// **'No payload recorded.'**
  String get traceConsolePayloadEmpty;

  /// No description provided for @traceConsolePayloadRedactedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 sensitive field redacted} other{{count} sensitive fields redacted}}'**
  String traceConsolePayloadRedactedCount(int count);

  /// No description provided for @traceConsoleRedactedValue.
  ///
  /// In en, this message translates to:
  /// **'[redacted]'**
  String get traceConsoleRedactedValue;

  /// No description provided for @traceConsoleEventsFilteredEmpty.
  ///
  /// In en, this message translates to:
  /// **'No raw logs match this filter.'**
  String get traceConsoleEventsFilteredEmpty;

  /// No description provided for @traceConsoleBackTooltip.
  ///
  /// In en, this message translates to:
  /// **'Back from Log Center'**
  String get traceConsoleBackTooltip;

  /// No description provided for @agentConsoleAgentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent runs'**
  String get agentConsoleAgentsTitle;

  /// No description provided for @agentConsoleAgentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect local runs, tasks, disabled controls, and per-run trace summaries.'**
  String get agentConsoleAgentsSubtitle;

  /// No description provided for @agentConsoleAgentsEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent runs and tasks'**
  String get agentConsoleAgentsEntryTitle;

  /// No description provided for @agentConsoleAgentsEntryBody.
  ///
  /// In en, this message translates to:
  /// **'Open the longer run and task lists on their own page.'**
  String get agentConsoleAgentsEntryBody;

  /// No description provided for @agentConsoleOpenAgentsButton.
  ///
  /// In en, this message translates to:
  /// **'Open runs'**
  String get agentConsoleOpenAgentsButton;

  /// No description provided for @traceRawOpenButton.
  ///
  /// In en, this message translates to:
  /// **'View raw log'**
  String get traceRawOpenButton;

  /// No description provided for @traceRawTitle.
  ///
  /// In en, this message translates to:
  /// **'Raw log detail'**
  String get traceRawTitle;

  /// No description provided for @traceRawSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Local-only runtime evidence for this trace.'**
  String get traceRawSubtitle;

  /// No description provided for @traceRawWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Local private log'**
  String get traceRawWarningTitle;

  /// No description provided for @traceRawWarningBody.
  ///
  /// In en, this message translates to:
  /// **'Raw prompt and tool data may appear here. Copied text stays policy-masked, but private logs should not be used for external review.'**
  String get traceRawWarningBody;

  /// No description provided for @traceRawSearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Find raw logs'**
  String get traceRawSearchTitle;

  /// No description provided for @traceRawSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get traceRawSearchLabel;

  /// No description provided for @traceRawSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Trace id, status, prompt, or payload'**
  String get traceRawSearchHint;

  /// No description provided for @traceRawClearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get traceRawClearSearchTooltip;

  /// No description provided for @traceRawStreamTitle.
  ///
  /// In en, this message translates to:
  /// **'Raw log stream'**
  String get traceRawStreamTitle;

  /// No description provided for @traceRawCopyPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy current page'**
  String get traceRawCopyPageTooltip;

  /// No description provided for @traceRawCopiedSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Current raw log page copied.'**
  String get traceRawCopiedSnackbar;

  /// No description provided for @traceRawNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No raw logs match the current search and filter.'**
  String get traceRawNoMatches;

  /// No description provided for @traceRawNoLogsStatus.
  ///
  /// In en, this message translates to:
  /// **'No raw logs to display.'**
  String get traceRawNoLogsStatus;

  /// No description provided for @traceRawPageStatus.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {pageCount} - {start}-{end} of {total}'**
  String traceRawPageStatus(
    int page,
    int pageCount,
    int start,
    int end,
    int total,
  );

  /// No description provided for @traceRawFirstPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'First page'**
  String get traceRawFirstPageTooltip;

  /// No description provided for @traceRawPreviousPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get traceRawPreviousPageTooltip;

  /// No description provided for @traceRawNextPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get traceRawNextPageTooltip;

  /// No description provided for @traceRawLastPageTooltip.
  ///
  /// In en, this message translates to:
  /// **'Last page'**
  String get traceRawLastPageTooltip;

  /// No description provided for @traceRawNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Raw log unavailable'**
  String get traceRawNotFoundTitle;

  /// No description provided for @traceRawNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This trace was not found in local storage.'**
  String get traceRawNotFoundBody;

  /// No description provided for @traceRawMetadataTitle.
  ///
  /// In en, this message translates to:
  /// **'Metadata'**
  String get traceRawMetadataTitle;

  /// No description provided for @traceRawMessageTitle.
  ///
  /// In en, this message translates to:
  /// **'Raw message'**
  String get traceRawMessageTitle;

  /// No description provided for @traceRawPayloadTitle.
  ///
  /// In en, this message translates to:
  /// **'Raw payload'**
  String get traceRawPayloadTitle;

  /// No description provided for @traceRawPolicyRedactedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 credential, path, or media field masked by policy} other{{count} credential, path, or media fields masked by policy}}'**
  String traceRawPolicyRedactedCount(int count);

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
  /// **'Model not configured'**
  String get providerSettingsStatusNotConfigured;

  /// No description provided for @providerSettingsStatusDescriptionConfigured.
  ///
  /// In en, this message translates to:
  /// **'Chat and model-backed Agent Pack work use this default unless a later role override says otherwise. Capture still saves raw records locally.'**
  String get providerSettingsStatusDescriptionConfigured;

  /// No description provided for @providerSettingsStatusDescriptionOffline.
  ///
  /// In en, this message translates to:
  /// **'Core capture still saves raw records locally. Chat answers and semantic model work require a configured BYOK provider.'**
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
  /// **'Used by chat answers and model-backed Agent Pack work in this slice.'**
  String get providerSettingsTextRoleDescription;

  /// No description provided for @providerSettingsVisionRoleTitle.
  ///
  /// In en, this message translates to:
  /// **'Vision semantic agent'**
  String get providerSettingsVisionRoleTitle;

  /// No description provided for @providerSettingsVisionRoleDescription.
  ///
  /// In en, this message translates to:
  /// **'Used by capture image preprocessing. It requires a provider tagged with Vision.'**
  String get providerSettingsVisionRoleDescription;

  /// No description provided for @providerSettingsVisionRoleUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No Vision provider configured'**
  String get providerSettingsVisionRoleUnavailable;

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
  /// **'Requires configured model'**
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

  /// No description provided for @providerSettingsCapabilityVision.
  ///
  /// In en, this message translates to:
  /// **'Vision'**
  String get providerSettingsCapabilityVision;

  /// No description provided for @providerSettingsCapabilityAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get providerSettingsCapabilityAudio;

  /// No description provided for @providerSettingsCapabilityVideo.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get providerSettingsCapabilityVideo;

  /// No description provided for @providerSettingsCapabilityTextOnly.
  ///
  /// In en, this message translates to:
  /// **'Text only'**
  String get providerSettingsCapabilityTextOnly;

  /// No description provided for @providerSettingsCapabilityOfflineFallback.
  ///
  /// In en, this message translates to:
  /// **'Local raw capture'**
  String get providerSettingsCapabilityOfflineFallback;

  /// No description provided for @providerSettingsCapabilityByok.
  ///
  /// In en, this message translates to:
  /// **'BYOK local storage'**
  String get providerSettingsCapabilityByok;

  /// No description provided for @providerCapabilityPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Model capability tags'**
  String get providerCapabilityPreviewTitle;

  /// No description provided for @providerCapabilityVisionOverrideTitle.
  ///
  /// In en, this message translates to:
  /// **'Supports image input'**
  String get providerCapabilityVisionOverrideTitle;

  /// No description provided for @providerCapabilityVisionOverrideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable only when this model can accept image content for capture understanding.'**
  String get providerCapabilityVisionOverrideSubtitle;

  /// No description provided for @providerCapabilityAudioOverrideTitle.
  ///
  /// In en, this message translates to:
  /// **'Supports speech or audio input'**
  String get providerCapabilityAudioOverrideTitle;

  /// No description provided for @providerCapabilityAudioOverrideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable only when this model can accept audio content or speech transcription requests.'**
  String get providerCapabilityAudioOverrideSubtitle;

  /// No description provided for @providerCapabilityVideoOverrideTitle.
  ///
  /// In en, this message translates to:
  /// **'Supports video input or generation'**
  String get providerCapabilityVideoOverrideTitle;

  /// No description provided for @providerCapabilityVideoOverrideSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enable only when this model can accept video content or run video generation tasks.'**
  String get providerCapabilityVideoOverrideSubtitle;

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

  /// No description provided for @providerActionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete provider'**
  String get providerActionDelete;

  /// No description provided for @providerDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete provider?'**
  String get providerDeleteTitle;

  /// No description provided for @providerDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{provider}\" from local model settings.'**
  String providerDeleteBody(String provider);

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

  /// No description provided for @providerPresetSelectionHelper.
  ///
  /// In en, this message translates to:
  /// **'Choose the entry that matches the protocol and plan. Token Plan keys cannot be mixed with normal API keys.'**
  String get providerPresetSelectionHelper;

  /// No description provided for @providerAccessModeApiKey.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get providerAccessModeApiKey;

  /// No description provided for @providerAccessModeTokenPlan.
  ///
  /// In en, this message translates to:
  /// **'Token Plan'**
  String get providerAccessModeTokenPlan;

  /// No description provided for @providerAccessModeCodingPlan.
  ///
  /// In en, this message translates to:
  /// **'Coding Plan'**
  String get providerAccessModeCodingPlan;

  /// No description provided for @providerAccessModeLocal.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get providerAccessModeLocal;

  /// No description provided for @providerPresetOpenAiChat.
  ///
  /// In en, this message translates to:
  /// **'OpenAI Chat Completions'**
  String get providerPresetOpenAiChat;

  /// No description provided for @providerPresetOpenAiResponses.
  ///
  /// In en, this message translates to:
  /// **'OpenAI Responses API'**
  String get providerPresetOpenAiResponses;

  /// No description provided for @providerPresetAnthropicApi.
  ///
  /// In en, this message translates to:
  /// **'Anthropic Claude API'**
  String get providerPresetAnthropicApi;

  /// No description provided for @providerPresetGeminiApi.
  ///
  /// In en, this message translates to:
  /// **'Google Gemini API'**
  String get providerPresetGeminiApi;

  /// No description provided for @providerPresetOpenRouterApi.
  ///
  /// In en, this message translates to:
  /// **'OpenRouter'**
  String get providerPresetOpenRouterApi;

  /// No description provided for @providerPresetDeepSeekOpenAi.
  ///
  /// In en, this message translates to:
  /// **'DeepSeek (OpenAI API)'**
  String get providerPresetDeepSeekOpenAi;

  /// No description provided for @providerPresetDeepSeekAnthropic.
  ///
  /// In en, this message translates to:
  /// **'DeepSeek (Anthropic API)'**
  String get providerPresetDeepSeekAnthropic;

  /// No description provided for @providerPresetKimiGlobal.
  ///
  /// In en, this message translates to:
  /// **'Kimi (global API)'**
  String get providerPresetKimiGlobal;

  /// No description provided for @providerPresetKimiChina.
  ///
  /// In en, this message translates to:
  /// **'Kimi (China API)'**
  String get providerPresetKimiChina;

  /// No description provided for @providerPresetKimiCode.
  ///
  /// In en, this message translates to:
  /// **'Kimi Code API'**
  String get providerPresetKimiCode;

  /// No description provided for @providerPresetQwenChina.
  ///
  /// In en, this message translates to:
  /// **'Alibaba Qwen (China)'**
  String get providerPresetQwenChina;

  /// No description provided for @providerPresetQwenInternational.
  ///
  /// In en, this message translates to:
  /// **'Alibaba Qwen (International)'**
  String get providerPresetQwenInternational;

  /// No description provided for @providerPresetDoubaoApi.
  ///
  /// In en, this message translates to:
  /// **'Volcengine Doubao API'**
  String get providerPresetDoubaoApi;

  /// No description provided for @providerPresetDoubaoCoding.
  ///
  /// In en, this message translates to:
  /// **'Volcengine Coding Plan'**
  String get providerPresetDoubaoCoding;

  /// No description provided for @providerPresetZhipuApi.
  ///
  /// In en, this message translates to:
  /// **'Zhipu GLM API'**
  String get providerPresetZhipuApi;

  /// No description provided for @providerPresetZhipuCoding.
  ///
  /// In en, this message translates to:
  /// **'Zhipu GLM Coding Plan'**
  String get providerPresetZhipuCoding;

  /// No description provided for @providerPresetMiniMaxOpenAiToken.
  ///
  /// In en, this message translates to:
  /// **'MiniMax Token Plan (OpenAI)'**
  String get providerPresetMiniMaxOpenAiToken;

  /// No description provided for @providerPresetMiniMaxAnthropicToken.
  ///
  /// In en, this message translates to:
  /// **'MiniMax Token Plan (Anthropic)'**
  String get providerPresetMiniMaxAnthropicToken;

  /// No description provided for @providerPresetMimoOpenAiApi.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi MIMO API (OpenAI)'**
  String get providerPresetMimoOpenAiApi;

  /// No description provided for @providerPresetMimoAnthropicApi.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi MIMO API (Anthropic)'**
  String get providerPresetMimoAnthropicApi;

  /// No description provided for @providerPresetMimoOpenAiTokenCn.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi MIMO Token Plan CN (OpenAI)'**
  String get providerPresetMimoOpenAiTokenCn;

  /// No description provided for @providerPresetMimoAnthropicTokenCn.
  ///
  /// In en, this message translates to:
  /// **'Xiaomi MIMO Token Plan CN (Anthropic)'**
  String get providerPresetMimoAnthropicTokenCn;

  /// No description provided for @providerPresetOllamaLocal.
  ///
  /// In en, this message translates to:
  /// **'Ollama local'**
  String get providerPresetOllamaLocal;

  /// No description provided for @providerPresetCustomOpenAi.
  ///
  /// In en, this message translates to:
  /// **'Custom OpenAI-compatible'**
  String get providerPresetCustomOpenAi;

  /// No description provided for @providerPresetCustomAnthropic.
  ///
  /// In en, this message translates to:
  /// **'Custom Anthropic-compatible'**
  String get providerPresetCustomAnthropic;

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

  /// No description provided for @providerApiKeyOptionalHelper.
  ///
  /// In en, this message translates to:
  /// **'Optional for this provider; fill it only if your local server requires one.'**
  String get providerApiKeyOptionalHelper;

  /// No description provided for @providerEndpointPresetHelper.
  ///
  /// In en, this message translates to:
  /// **'Preset from the provider docs; edit it if your account uses another region or gateway.'**
  String get providerEndpointPresetHelper;

  /// No description provided for @providerModelPresetHelper.
  ///
  /// In en, this message translates to:
  /// **'Fetch models from the provider, then choose one from the list; use custom only when needed.'**
  String get providerModelPresetHelper;

  /// No description provided for @providerFetchModelsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Fetch available models'**
  String get providerFetchModelsTooltip;

  /// No description provided for @providerModelCustomOption.
  ///
  /// In en, this message translates to:
  /// **'Custom model ID'**
  String get providerModelCustomOption;

  /// No description provided for @providerModelCustomHelper.
  ///
  /// In en, this message translates to:
  /// **'Use this when the provider does not return the model you need.'**
  String get providerModelCustomHelper;

  /// No description provided for @providerModelFetchRequiresApiKey.
  ///
  /// In en, this message translates to:
  /// **'Add an API key before fetching this provider\'s models.'**
  String get providerModelFetchRequiresApiKey;

  /// No description provided for @providerModelFetchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No models were returned. Keep the current model or enter a custom ID.'**
  String get providerModelFetchEmpty;

  /// No description provided for @providerModelFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not fetch models. Check the endpoint, key, and network.'**
  String get providerModelFetchFailed;

  /// No description provided for @providerModelFetchAuthenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Model fetch authentication failed. Check the API key and account access.'**
  String get providerModelFetchAuthenticationFailed;

  /// No description provided for @providerModelFetchRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Model fetch was rate limited. Try again later.'**
  String get providerModelFetchRateLimited;

  /// No description provided for @providerModelFetchTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Model fetch timed out. Check the endpoint and network.'**
  String get providerModelFetchTimedOut;

  /// No description provided for @providerModelFetchServerFailed.
  ///
  /// In en, this message translates to:
  /// **'The provider returned a server error while fetching models.'**
  String get providerModelFetchServerFailed;

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

  /// No description provided for @providerConfigInvalid.
  ///
  /// In en, this message translates to:
  /// **'Provider config invalid: {details}.'**
  String providerConfigInvalid(String details);

  /// No description provided for @providerNotFound.
  ///
  /// In en, this message translates to:
  /// **'Provider not found.'**
  String get providerNotFound;

  /// No description provided for @providerTestingConnectionMessage.
  ///
  /// In en, this message translates to:
  /// **'Testing connection...'**
  String get providerTestingConnectionMessage;

  /// No description provided for @providerConnectionUnexpectedFailure.
  ///
  /// In en, this message translates to:
  /// **'Provider connection test failed unexpectedly.'**
  String get providerConnectionUnexpectedFailure;

  /// No description provided for @providerSavedKeyClearedMessage.
  ///
  /// In en, this message translates to:
  /// **'Saved API key cleared. Add a key before testing.'**
  String get providerSavedKeyClearedMessage;

  /// No description provided for @providerConnectionNotRunMessage.
  ///
  /// In en, this message translates to:
  /// **'Connection test has not run for these saved settings.'**
  String get providerConnectionNotRunMessage;

  /// No description provided for @providerConnectionValidatedOffline.
  ///
  /// In en, this message translates to:
  /// **'{provider} validated offline. No live request sent.'**
  String providerConnectionValidatedOffline(String provider);

  /// No description provided for @providerConnectionSucceeded.
  ///
  /// In en, this message translates to:
  /// **'{provider} connection test succeeded.'**
  String providerConnectionSucceeded(String provider);

  /// No description provided for @providerConnectionIncomplete.
  ///
  /// In en, this message translates to:
  /// **'{provider} configuration is incomplete: {details}.'**
  String providerConnectionIncomplete(String provider, String details);

  /// No description provided for @providerConnectionUnsupportedProbe.
  ///
  /// In en, this message translates to:
  /// **'{provider} cannot run the chat connection probe with this capability set.'**
  String providerConnectionUnsupportedProbe(String provider);

  /// No description provided for @providerConnectionProviderUnexpectedFailure.
  ///
  /// In en, this message translates to:
  /// **'{provider} connection test failed unexpectedly.'**
  String providerConnectionProviderUnexpectedFailure(String provider);

  /// No description provided for @voiceSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice Transcription'**
  String get voiceSettingsTitle;

  /// No description provided for @voiceSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save original audio locally, use transcript text for records, and keep correction evidence source-linked.'**
  String get voiceSettingsSubtitle;

  /// No description provided for @voiceSettingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Voice transcription settings could not load: {details}'**
  String voiceSettingsLoadFailed(String details);

  /// No description provided for @voiceSettingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Voice transcription settings saved.'**
  String get voiceSettingsSaved;

  /// No description provided for @voiceSettingsStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get voiceSettingsStatusTitle;

  /// No description provided for @voiceSettingsEngineTitle.
  ///
  /// In en, this message translates to:
  /// **'Transcription engine'**
  String get voiceSettingsEngineTitle;

  /// No description provided for @voiceSettingsEngineDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose exactly one ASR path for new transcripts.'**
  String get voiceSettingsEngineDescription;

  /// No description provided for @voiceSettingsEngineLocal.
  ///
  /// In en, this message translates to:
  /// **'Local SenseVoice'**
  String get voiceSettingsEngineLocal;

  /// No description provided for @voiceSettingsEngineMimo.
  ///
  /// In en, this message translates to:
  /// **'MiMo ASR'**
  String get voiceSettingsEngineMimo;

  /// No description provided for @voiceSettingsEngineDisabled.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get voiceSettingsEngineDisabled;

  /// No description provided for @voiceSettingsLocalModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Local model'**
  String get voiceSettingsLocalModelTitle;

  /// No description provided for @voiceSettingsLocalModelManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Local ASR model'**
  String get voiceSettingsLocalModelManageTitle;

  /// No description provided for @voiceSettingsLocalModelManageDescription.
  ///
  /// In en, this message translates to:
  /// **'Download SenseVoice for offline transcription and live preview. Downloads use a temporary .part directory and can be retried safely.'**
  String get voiceSettingsLocalModelManageDescription;

  /// No description provided for @voiceSettingsModelProgress.
  ///
  /// In en, this message translates to:
  /// **'{state} · {progress}%'**
  String voiceSettingsModelProgress(String state, int progress);

  /// No description provided for @voiceSettingsModelDownloadButton.
  ///
  /// In en, this message translates to:
  /// **'Download local model'**
  String get voiceSettingsModelDownloadButton;

  /// No description provided for @voiceSettingsModelDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading...'**
  String get voiceSettingsModelDownloading;

  /// No description provided for @voiceSettingsModelDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete local model'**
  String get voiceSettingsModelDeleteButton;

  /// No description provided for @voiceSettingsModelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Local model storage is unavailable on this device.'**
  String get voiceSettingsModelUnavailable;

  /// No description provided for @voiceSettingsModelDownloadReady.
  ///
  /// In en, this message translates to:
  /// **'Local ASR model is ready.'**
  String get voiceSettingsModelDownloadReady;

  /// No description provided for @voiceSettingsModelDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Local ASR model download failed: {details}'**
  String voiceSettingsModelDownloadFailed(String details);

  /// No description provided for @voiceSettingsModelDeleted.
  ///
  /// In en, this message translates to:
  /// **'Local ASR model deleted.'**
  String get voiceSettingsModelDeleted;

  /// No description provided for @voiceSettingsRemoteFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Selected engine'**
  String get voiceSettingsRemoteFallbackTitle;

  /// No description provided for @voiceSettingsRemoteEnabled.
  ///
  /// In en, this message translates to:
  /// **'enabled'**
  String get voiceSettingsRemoteEnabled;

  /// No description provided for @voiceSettingsRemoteDisabled.
  ///
  /// In en, this message translates to:
  /// **'disabled'**
  String get voiceSettingsRemoteDisabled;

  /// No description provided for @voiceSettingsPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Live preview'**
  String get voiceSettingsPreviewTitle;

  /// No description provided for @voiceSettingsPreviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Preview uses local microphone PCM while recording. If preview fails, the WAV file is still saved.'**
  String get voiceSettingsPreviewDescription;

  /// No description provided for @voiceSettingsPreviewSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Show transcript preview while recording'**
  String get voiceSettingsPreviewSwitchTitle;

  /// No description provided for @voiceSettingsPreviewSwitchSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The saved WAV remains the source of truth.'**
  String get voiceSettingsPreviewSwitchSubtitle;

  /// No description provided for @voiceSettingsRemoteTitle.
  ///
  /// In en, this message translates to:
  /// **'MiMo ASR'**
  String get voiceSettingsRemoteTitle;

  /// No description provided for @voiceSettingsRemoteDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the configured MiMo-compatible endpoint only when MiMo is the selected engine or you manually retry with MiMo.'**
  String get voiceSettingsRemoteDescription;

  /// No description provided for @voiceSettingsRemoteConsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Allow MiMo audio upload'**
  String get voiceSettingsRemoteConsentTitle;

  /// No description provided for @voiceSettingsRemoteConsentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Audio upload is used only for the selected MiMo engine and manual MiMo retry.'**
  String get voiceSettingsRemoteConsentSubtitle;

  /// No description provided for @voiceSettingsEndpointLabel.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get voiceSettingsEndpointLabel;

  /// No description provided for @voiceSettingsModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get voiceSettingsModelLabel;

  /// No description provided for @voiceSettingsApiKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'API key'**
  String get voiceSettingsApiKeyLabel;

  /// No description provided for @voiceSettingsApiKeyHelper.
  ///
  /// In en, this message translates to:
  /// **'Stored in secure local storage. Leave blank to keep the saved key.'**
  String get voiceSettingsApiKeyHelper;

  /// No description provided for @voiceSettingsCorrectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Transcript correction'**
  String get voiceSettingsCorrectionTitle;

  /// No description provided for @voiceSettingsCorrectionDescription.
  ///
  /// In en, this message translates to:
  /// **'The correction Agent Pack can revise names and terms. It records correction evidence but does not write Memory directly.'**
  String get voiceSettingsCorrectionDescription;

  /// No description provided for @voiceSettingsCorrectionModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Correction mode'**
  String get voiceSettingsCorrectionModeLabel;

  /// No description provided for @voiceSettingsCorrectionDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get voiceSettingsCorrectionDisabled;

  /// No description provided for @voiceSettingsCorrectionSuggest.
  ///
  /// In en, this message translates to:
  /// **'Suggest only'**
  String get voiceSettingsCorrectionSuggest;

  /// No description provided for @voiceSettingsCorrectionAutoApply.
  ///
  /// In en, this message translates to:
  /// **'Auto-apply high confidence'**
  String get voiceSettingsCorrectionAutoApply;

  /// No description provided for @voiceSettingsRetryTitle.
  ///
  /// In en, this message translates to:
  /// **'Manual retry'**
  String get voiceSettingsRetryTitle;

  /// No description provided for @voiceSettingsRetryDescription.
  ///
  /// In en, this message translates to:
  /// **'Retry failed or review-needed transcripts with the MiMo ASR path.'**
  String get voiceSettingsRetryDescription;

  /// No description provided for @voiceSettingsRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry failed transcripts'**
  String get voiceSettingsRetryButton;

  /// No description provided for @voiceSettingsRetryRunning.
  ///
  /// In en, this message translates to:
  /// **'Retrying...'**
  String get voiceSettingsRetryRunning;

  /// No description provided for @voiceSettingsRetrySummary.
  ///
  /// In en, this message translates to:
  /// **'{attempted} attempted / {succeeded} succeeded / {failed} failed'**
  String voiceSettingsRetrySummary(int attempted, int succeeded, int failed);

  /// No description provided for @voiceSettingsModelStateNotDownloaded.
  ///
  /// In en, this message translates to:
  /// **'not downloaded'**
  String get voiceSettingsModelStateNotDownloaded;

  /// No description provided for @voiceSettingsModelStateChecking.
  ///
  /// In en, this message translates to:
  /// **'checking'**
  String get voiceSettingsModelStateChecking;

  /// No description provided for @voiceSettingsModelStateDownloading.
  ///
  /// In en, this message translates to:
  /// **'downloading'**
  String get voiceSettingsModelStateDownloading;

  /// No description provided for @voiceSettingsModelStateInterrupted.
  ///
  /// In en, this message translates to:
  /// **'interrupted'**
  String get voiceSettingsModelStateInterrupted;

  /// No description provided for @voiceSettingsModelStateVerifying.
  ///
  /// In en, this message translates to:
  /// **'verifying'**
  String get voiceSettingsModelStateVerifying;

  /// No description provided for @voiceSettingsModelStateReady.
  ///
  /// In en, this message translates to:
  /// **'ready'**
  String get voiceSettingsModelStateReady;

  /// No description provided for @voiceSettingsModelStateFailed.
  ///
  /// In en, this message translates to:
  /// **'failed'**
  String get voiceSettingsModelStateFailed;

  /// No description provided for @voiceSettingsModelStateCorrupted.
  ///
  /// In en, this message translates to:
  /// **'corrupted'**
  String get voiceSettingsModelStateCorrupted;

  /// No description provided for @voiceSettingsModelStateDeleting.
  ///
  /// In en, this message translates to:
  /// **'deleting'**
  String get voiceSettingsModelStateDeleting;

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
  /// **'Local data stays on this device until you create or import a backup.'**
  String get backupIdleStatus;

  /// No description provided for @backupExportReadyStatus.
  ///
  /// In en, this message translates to:
  /// **'WideNote backup archive is ready.'**
  String get backupExportReadyStatus;

  /// No description provided for @backupSavedFileStatus.
  ///
  /// In en, this message translates to:
  /// **'WideNote backup archive is ready in the selected destination.'**
  String get backupSavedFileStatus;

  /// No description provided for @backupImportReadyStatus.
  ///
  /// In en, this message translates to:
  /// **'Backup file loaded. Confirm import to replace local data.'**
  String get backupImportReadyStatus;

  /// No description provided for @backupImportDoneStatus.
  ///
  /// In en, this message translates to:
  /// **'Backup replaced local storage.'**
  String get backupImportDoneStatus;

  /// No description provided for @backupFailedStatus.
  ///
  /// In en, this message translates to:
  /// **'Backup failed: {details}'**
  String backupFailedStatus(String details);

  /// No description provided for @backupInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup format.'**
  String get backupInvalidFormat;

  /// No description provided for @backupUnsupportedVersion.
  ///
  /// In en, this message translates to:
  /// **'Unsupported backup version.'**
  String get backupUnsupportedVersion;

  /// No description provided for @backupNoSavedFile.
  ///
  /// In en, this message translates to:
  /// **'No saved backup file found.'**
  String get backupNoSavedFile;

  /// No description provided for @backupLocalConflict.
  ///
  /// In en, this message translates to:
  /// **'Backup conflicts with local data.'**
  String get backupLocalConflict;

  /// No description provided for @backupUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'Unexpected backup error.'**
  String get backupUnexpectedError;

  /// No description provided for @backupExportSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Export and restore boundary'**
  String get backupExportSectionTitle;

  /// No description provided for @backupExportButton.
  ///
  /// In en, this message translates to:
  /// **'Create .widenote backup'**
  String get backupExportButton;

  /// No description provided for @backupExportEmpty.
  ///
  /// In en, this message translates to:
  /// **'Export creates one compressed directory .widenote archive. You can open it with another app or save it to a location you choose.'**
  String get backupExportEmpty;

  /// No description provided for @backupSecretWarning.
  ///
  /// In en, this message translates to:
  /// **'Full backups include provider and allowlisted secure-storage keys; non-formal builds can also include diagnostic logs. Keep .widenote files somewhere you trust.'**
  String get backupSecretWarning;

  /// No description provided for @backupRestoreBoundary.
  ///
  /// In en, this message translates to:
  /// **'The .widenote archive restores a SQLite snapshot, capture media files, provider API keys, and allowlisted app settings.'**
  String get backupRestoreBoundary;

  /// No description provided for @backupOwnerExportBoundary.
  ///
  /// In en, this message translates to:
  /// **'Backups are compressed directories, not JSON or Markdown restore documents.'**
  String get backupOwnerExportBoundary;

  /// No description provided for @backupFullSecretBoundary.
  ///
  /// In en, this message translates to:
  /// **'Full .widenote backups include provider, AMap, and MiMo ASR keys; non-formal builds also attach support diagnostics that restore ignores.'**
  String get backupFullSecretBoundary;

  /// No description provided for @backupLegacyProviderCredentialReentryCount.
  ///
  /// In en, this message translates to:
  /// **'Provider keys requiring re-entry: {count}'**
  String backupLegacyProviderCredentialReentryCount(int count);

  /// No description provided for @backupManifestCountsTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup counts'**
  String get backupManifestCountsTitle;

  /// No description provided for @backupCount.
  ///
  /// In en, this message translates to:
  /// **'{section}: {count}'**
  String backupCount(String section, int count);

  /// No description provided for @backupCopyMarkdownButton.
  ///
  /// In en, this message translates to:
  /// **'Copy export'**
  String get backupCopyMarkdownButton;

  /// No description provided for @backupOpenShareFileButton.
  ///
  /// In en, this message translates to:
  /// **'Open or share .widenote'**
  String get backupOpenShareFileButton;

  /// No description provided for @backupSaveFilesButton.
  ///
  /// In en, this message translates to:
  /// **'Save to selected location'**
  String get backupSaveFilesButton;

  /// No description provided for @backupSavedArchivePath.
  ///
  /// In en, this message translates to:
  /// **'WideNote backup'**
  String get backupSavedArchivePath;

  /// No description provided for @backupExportDestination.
  ///
  /// In en, this message translates to:
  /// **'Destination'**
  String get backupExportDestination;

  /// No description provided for @backupCopiedStatus.
  ///
  /// In en, this message translates to:
  /// **'Export copied.'**
  String get backupCopiedStatus;

  /// No description provided for @backupExportMarkdownTitle.
  ///
  /// In en, this message translates to:
  /// **'Readable export'**
  String get backupExportMarkdownTitle;

  /// No description provided for @backupImportSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get backupImportSectionTitle;

  /// No description provided for @backupImportHint.
  ///
  /// In en, this message translates to:
  /// **'Choose a .widenote file. WideNote will inspect it before replacing local data.'**
  String get backupImportHint;

  /// No description provided for @backupImportButton.
  ///
  /// In en, this message translates to:
  /// **'Replace with selected backup'**
  String get backupImportButton;

  /// No description provided for @backupImportFileButton.
  ///
  /// In en, this message translates to:
  /// **'Choose .widenote file'**
  String get backupImportFileButton;

  /// No description provided for @backupImportReadyInline.
  ///
  /// In en, this message translates to:
  /// **'Backup is loaded and ready to replace local data.'**
  String get backupImportReadyInline;

  /// No description provided for @backupImportSourcePath.
  ///
  /// In en, this message translates to:
  /// **'Import source'**
  String get backupImportSourcePath;

  /// No description provided for @backupConfirmReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace local data?'**
  String get backupConfirmReplaceTitle;

  /// No description provided for @backupConfirmReplaceBody.
  ///
  /// In en, this message translates to:
  /// **'This import fully replaces local records, Memory, todos, chats, provider metadata, packs, permissions, runtime state, and traces with the backup contents. Continue only if this is the file you want.'**
  String get backupConfirmReplaceBody;

  /// No description provided for @backupConfirmReplaceCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get backupConfirmReplaceCancel;

  /// No description provided for @backupConfirmReplaceAction.
  ///
  /// In en, this message translates to:
  /// **'Replace and import'**
  String get backupConfirmReplaceAction;

  /// No description provided for @backupImportNeedsProviderKeys.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Provider metadata restored. Re-enter 1 provider key before model calls can use it.} other{Provider metadata restored. Re-enter {count} provider keys before model calls can use them.}}'**
  String backupImportNeedsProviderKeys(int count);

  /// No description provided for @backupImportSecretsRestored.
  ///
  /// In en, this message translates to:
  /// **'Provider credentials restored and ready to use.'**
  String get backupImportSecretsRestored;

  /// No description provided for @backupImportNoProviderKeysNeeded.
  ///
  /// In en, this message translates to:
  /// **'No provider keys need re-entry for this backup.'**
  String get backupImportNoProviderKeysNeeded;

  /// No description provided for @settingsLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Location Context'**
  String get settingsLocationTitle;

  /// No description provided for @settingsLocationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save local GPS with records and optionally use AMap for address summaries.'**
  String get settingsLocationSubtitle;

  /// No description provided for @settingsLocationStatusOff.
  ///
  /// In en, this message translates to:
  /// **'off'**
  String get settingsLocationStatusOff;

  /// No description provided for @settingsLocationStatusGps.
  ///
  /// In en, this message translates to:
  /// **'GPS only'**
  String get settingsLocationStatusGps;

  /// No description provided for @settingsLocationStatusAmap.
  ///
  /// In en, this message translates to:
  /// **'GPS + AMap'**
  String get settingsLocationStatusAmap;

  /// No description provided for @locationSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Location Context'**
  String get locationSettingsTitle;

  /// No description provided for @locationSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose what WideNote saves locally and when coordinates may be sent to AMap.'**
  String get locationSettingsSubtitle;

  /// No description provided for @locationPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy boundary'**
  String get locationPrivacyTitle;

  /// No description provided for @locationPrivacyLocalTitle.
  ///
  /// In en, this message translates to:
  /// **'Local GPS'**
  String get locationPrivacyLocalTitle;

  /// No description provided for @locationPrivacyLocalBody.
  ///
  /// In en, this message translates to:
  /// **'When enabled, WideNote requests foreground location only while saving a record and stores the coordinate on that local record.'**
  String get locationPrivacyLocalBody;

  /// No description provided for @locationPrivacyAmapTitle.
  ///
  /// In en, this message translates to:
  /// **'AMap reverse geocoding'**
  String get locationPrivacyAmapTitle;

  /// No description provided for @locationPrivacyAmapBody.
  ///
  /// In en, this message translates to:
  /// **'AMap address lookup is separate consent. When enabled, the record coordinate is sent to AMap Web Service to return an address summary.'**
  String get locationPrivacyAmapBody;

  /// No description provided for @locationStatusGpsOn.
  ///
  /// In en, this message translates to:
  /// **'GPS capture on'**
  String get locationStatusGpsOn;

  /// No description provided for @locationStatusGpsOff.
  ///
  /// In en, this message translates to:
  /// **'GPS capture off'**
  String get locationStatusGpsOff;

  /// No description provided for @locationStatusAmapOn.
  ///
  /// In en, this message translates to:
  /// **'AMap lookup on'**
  String get locationStatusAmapOn;

  /// No description provided for @locationStatusAmapOff.
  ///
  /// In en, this message translates to:
  /// **'AMap lookup off'**
  String get locationStatusAmapOff;

  /// No description provided for @locationCaptureTitle.
  ///
  /// In en, this message translates to:
  /// **'Record location'**
  String get locationCaptureTitle;

  /// No description provided for @locationSaveGpsTitle.
  ///
  /// In en, this message translates to:
  /// **'Save GPS with new records'**
  String get locationSaveGpsTitle;

  /// No description provided for @locationSaveGpsBody.
  ///
  /// In en, this message translates to:
  /// **'Stores WGS-84 latitude, longitude, accuracy, source, and capture time only on the local record.'**
  String get locationSaveGpsBody;

  /// No description provided for @locationAmapTitle.
  ///
  /// In en, this message translates to:
  /// **'Address lookup'**
  String get locationAmapTitle;

  /// No description provided for @locationAmapSwitchTitle.
  ///
  /// In en, this message translates to:
  /// **'Use AMap reverse geocoding'**
  String get locationAmapSwitchTitle;

  /// No description provided for @locationAmapSwitchBody.
  ///
  /// In en, this message translates to:
  /// **'Sends the record coordinate to AMap Web Service and stores the returned address as derived context.'**
  String get locationAmapSwitchBody;

  /// No description provided for @locationAmapKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'AMap Web Service Key'**
  String get locationAmapKeyLabel;

  /// No description provided for @locationAmapKeyHelper.
  ///
  /// In en, this message translates to:
  /// **'Stored in secure local storage. It is not included in .widenote backups or Owner Export.'**
  String get locationAmapKeyHelper;

  /// No description provided for @locationGranularityTitle.
  ///
  /// In en, this message translates to:
  /// **'Display granularity'**
  String get locationGranularityTitle;

  /// No description provided for @locationGranularityBody.
  ///
  /// In en, this message translates to:
  /// **'Lists and status surfaces use coarse display by default to reduce shoulder-surfing risk.'**
  String get locationGranularityBody;

  /// No description provided for @locationGranularityLabel.
  ///
  /// In en, this message translates to:
  /// **'Default display'**
  String get locationGranularityLabel;

  /// No description provided for @locationGranularityCity.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get locationGranularityCity;

  /// No description provided for @locationGranularityDistrict.
  ///
  /// In en, this message translates to:
  /// **'District'**
  String get locationGranularityDistrict;

  /// No description provided for @locationGranularityNeighborhood.
  ///
  /// In en, this message translates to:
  /// **'Neighborhood'**
  String get locationGranularityNeighborhood;

  /// No description provided for @locationGranularityStreet.
  ///
  /// In en, this message translates to:
  /// **'Street'**
  String get locationGranularityStreet;

  /// No description provided for @locationGranularityFull.
  ///
  /// In en, this message translates to:
  /// **'Full address'**
  String get locationGranularityFull;

  /// No description provided for @locationTestTitle.
  ///
  /// In en, this message translates to:
  /// **'Current status'**
  String get locationTestTitle;

  /// No description provided for @locationTestBody.
  ///
  /// In en, this message translates to:
  /// **'Run one foreground lookup with the current settings. The preview stays coarse.'**
  String get locationTestBody;

  /// No description provided for @locationTestAction.
  ///
  /// In en, this message translates to:
  /// **'Test location'**
  String get locationTestAction;

  /// No description provided for @locationTestRunning.
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get locationTestRunning;

  /// No description provided for @locationMaintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved locations'**
  String get locationMaintenanceTitle;

  /// No description provided for @locationMaintenanceBody.
  ///
  /// In en, this message translates to:
  /// **'Turning the feature off stops future capture. Use clear to remove saved location metadata from existing records.'**
  String get locationMaintenanceBody;

  /// No description provided for @locationClearSavedAction.
  ///
  /// In en, this message translates to:
  /// **'Clear saved locations'**
  String get locationClearSavedAction;

  /// No description provided for @locationClearConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear saved locations?'**
  String get locationClearConfirmTitle;

  /// No description provided for @locationClearConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'This removes location metadata from existing local capture records. Record text and attachments stay unchanged.'**
  String get locationClearConfirmBody;

  /// No description provided for @locationClearConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get locationClearConfirmAction;

  /// No description provided for @locationClearSavedResult.
  ///
  /// In en, this message translates to:
  /// **'Cleared location metadata from {count} records.'**
  String locationClearSavedResult(int count);

  /// No description provided for @locationStatusAvailable.
  ///
  /// In en, this message translates to:
  /// **'Location captured.'**
  String get locationStatusAvailable;

  /// No description provided for @locationStatusSummary.
  ///
  /// In en, this message translates to:
  /// **'Area: {summary}'**
  String locationStatusSummary(String summary);

  /// No description provided for @locationStatusCoordinatesSaved.
  ///
  /// In en, this message translates to:
  /// **'GPS coordinates saved on the local record.'**
  String get locationStatusCoordinatesSaved;

  /// No description provided for @locationStatusDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location capture is off.'**
  String get locationStatusDisabled;

  /// No description provided for @locationStatusServiceDisabled.
  ///
  /// In en, this message translates to:
  /// **'Device location service is disabled.'**
  String get locationStatusServiceDisabled;

  /// No description provided for @locationStatusPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied.'**
  String get locationStatusPermissionDenied;

  /// No description provided for @locationStatusPermissionDeniedForever.
  ///
  /// In en, this message translates to:
  /// **'Location permission is blocked in system settings.'**
  String get locationStatusPermissionDeniedForever;

  /// No description provided for @locationStatusTimeout.
  ///
  /// In en, this message translates to:
  /// **'Location lookup timed out.'**
  String get locationStatusTimeout;

  /// No description provided for @locationStatusAmapKeyMissing.
  ///
  /// In en, this message translates to:
  /// **'AMap key is missing. GPS can still be saved.'**
  String get locationStatusAmapKeyMissing;

  /// No description provided for @locationStatusAmapDisabled.
  ///
  /// In en, this message translates to:
  /// **'AMap lookup is off.'**
  String get locationStatusAmapDisabled;

  /// No description provided for @locationStatusAmapTimeout.
  ///
  /// In en, this message translates to:
  /// **'AMap lookup timed out. GPS can still be saved.'**
  String get locationStatusAmapTimeout;

  /// No description provided for @locationStatusUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location is unavailable.'**
  String get locationStatusUnavailable;

  /// No description provided for @locationRecordSummary.
  ///
  /// In en, this message translates to:
  /// **'Location: {summary}'**
  String locationRecordSummary(String summary);

  /// No description provided for @locationRecordCoordinatesSaved.
  ///
  /// In en, this message translates to:
  /// **'GPS saved'**
  String get locationRecordCoordinatesSaved;

  /// No description provided for @locationRecordUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable'**
  String get locationRecordUnavailable;
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
