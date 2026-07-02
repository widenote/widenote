// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '广记';

  @override
  String get tabHome => '首页';

  @override
  String get tabChat => '对话';

  @override
  String get tabRecord => '记录';

  @override
  String get tabTodos => '待办';

  @override
  String get tabPlugins => '插件';

  @override
  String get homeSubtitle => '新记录 -> 时间线 -> 记忆 -> 洞察';

  @override
  String homeTodaySubtitle(String date) {
    return '$date · 本地优先';
  }

  @override
  String get homeOpenTimelineTooltip => '打开时间线';

  @override
  String get homeSearchTooltip => '搜索';

  @override
  String get homeOpenMemoryTooltip => '打开记忆';

  @override
  String get homeOpenDailyRecapTooltip => '打开每日回顾';

  @override
  String get homeOpenInsightsTooltip => '打开洞察';

  @override
  String get homeOpenSettingsTooltip => '打开设置';

  @override
  String get homeNewRecordTitle => '新记录';

  @override
  String get homeNewRecordBody => '沉浸式写一段内容，然后添加图片或本地来源文件。';

  @override
  String get homeBackgroundVoiceTitle => '后台录音';

  @override
  String get homeBackgroundVoiceBody => '先在后台录音，结束后再补充上下文并保存。';

  @override
  String get homeBackgroundVoiceActiveBody => '录音已经在后台进行中。';

  @override
  String get homeBackgroundVoiceActiveAction => '录音中';

  @override
  String get homeSummaryRecords => '记录';

  @override
  String get homeSummaryMemory => '记忆';

  @override
  String get homeSummaryInsights => '洞察';

  @override
  String get homeTodayRecapTitle => '今日回顾';

  @override
  String get homeOpenRecapAction => '打开';

  @override
  String homeTodayRecapBody(int recordCount, int memoryCount, int todoCount) {
    return '$recordCount 条记录 · $memoryCount 条记忆 · $todoCount 个待办';
  }

  @override
  String get homeRecentRecordsTitle => '最近记录';

  @override
  String get homeOpenAllRecordsAction => '全部';

  @override
  String get homeInsightTeaserTitle => '洞察提示';

  @override
  String get homeOpenInsightsAction => '洞察';

  @override
  String get homeInsightTeaserEmpty => '有几条可溯源记录后，洞察会出现在这里。';

  @override
  String get homeInsightAskHint => '去对话追问';

  @override
  String get homeContinueRecordingTitle => '继续记录';

  @override
  String get homeContinueRecordingBody => '首页入口和底部记录按钮都会打开同一个本地记录面板。';

  @override
  String get homeContinueRecordingAction => '新记录';

  @override
  String get newRecordTitle => '新记录';

  @override
  String get newRecordSubtitle => '原始输入留在本地，AI 不会覆盖它。';

  @override
  String get newRecordHint => '写下一个想法、情绪、项目上下文、会议片段或生活事件...';

  @override
  String get saveRecordButton => '保存记录';

  @override
  String get backgroundVoiceActiveTitle => '后台录音中';

  @override
  String get backgroundVoiceActiveBody => '音频会作为本地原始素材保留。停止后可以复核草稿并补充上下文。';

  @override
  String get backgroundVoiceTimerPlaceholder => '录音中';

  @override
  String get backgroundVoiceComposerBusy => '后台录音仍在进行中。请先停止录音，再保存这条记录。';

  @override
  String get voicePreviewListening => '正在听写...';

  @override
  String get voicePreviewUnavailable => '实时转写预览暂不可用，音频仍会本地保存。';

  @override
  String voicePreviewDraft(String text) {
    return '转写草稿：$text';
  }

  @override
  String get recapTitle => '每日回顾';

  @override
  String recapSubtitle(String date) {
    return '来自本地对象事实的今日概览 · $date';
  }

  @override
  String get recapBackTooltip => '关闭每日回顾';

  @override
  String get recapUnavailableTitle => '每日回顾暂不可用';

  @override
  String get recapEmptyTitle => '今天还没有记录。';

  @override
  String get recapEmptyBody => '记录一个想法、语音草稿、相机照片或相册图片后，今天的回顾会在这里保留来源。';

  @override
  String get recapCapturesMetric => '记录';

  @override
  String get recapMemoryMetric => '记忆';

  @override
  String get recapTodoOpenMetric => '未完成待办';

  @override
  String get recapTodoCompletedMetric => '已完成';

  @override
  String get recapCardsMetric => '卡片';

  @override
  String get recapInsightsMetric => '洞察';

  @override
  String get recapRecordsTitle => '今天的记录';

  @override
  String get recapMemoryTitle => '今天的记忆';

  @override
  String get recapTodosTitle => '待办活动';

  @override
  String get recapCardsTitle => '卡片';

  @override
  String get recapInsightsTitle => '洞察';

  @override
  String get recapEntryRecordTitle => '记录';

  @override
  String get recapEntryMemoryTitle => '记忆';

  @override
  String get recapEntryOpenTodoTitle => '未完成待办';

  @override
  String get recapEntryCompletedTodoTitle => '已完成待办';

  @override
  String get recapUntitledCapture => '未命名记录';

  @override
  String get recapUntitledTodo => '未命名待办';

  @override
  String get recapSectionEmpty => '今天这个分区还没有可溯源内容。';

  @override
  String get recapEvidenceTitle => '本地证据';

  @override
  String recapEvidenceBody(int eventCount, int traceCount) {
    return '$eventCount 个事件 · $traceCount 条追踪';
  }

  @override
  String get quickCaptureTitle => '快速记录';

  @override
  String get quickCaptureHint => '写下一个想法、会议记录、承诺，或一段原始记忆...';

  @override
  String get captureModeText => '文字';

  @override
  String get captureModeVoice => '语音';

  @override
  String get captureModeMedia => '媒体';

  @override
  String get captureModeTextTitle => '先记录下来';

  @override
  String get captureModeTextBody => '默认保持低摩擦本地记录。原始记录保存后，智能体再进行整理。';

  @override
  String get captureVoiceHint => '为录音补充背景，录音会作为本地原始媒体附件保存...';

  @override
  String get captureVoiceTitle => '录音';

  @override
  String get captureVoiceBody => 'WideNote 会请求麦克风权限，保存本地原始音频；转写生成留给后续智能体步骤。';

  @override
  String get captureVoiceStartButton => '开始录音';

  @override
  String get captureVoiceRecordingTitle => '正在录音';

  @override
  String get captureVoiceRecordingBody => '停止后会附加录音；取消会丢弃录音且不会创建记录。';

  @override
  String get captureVoiceStopButton => '停止';

  @override
  String get captureVoiceCancelButton => '取消';

  @override
  String get captureMediaHint => '为相机照片或相册图片补充背景...';

  @override
  String get captureMediaTitle => '附加媒体';

  @override
  String get captureMediaBody => '相机和相册使用系统选择器。WideNote 只保存本地文件引用、哈希和来源元数据。';

  @override
  String get captureMediaCameraButton => '相机';

  @override
  String get captureMediaGalleryButton => '相册';

  @override
  String get captureActionCamera => '相机';

  @override
  String get captureActionGallery => '相册';

  @override
  String get captureActionVoice => '语音';

  @override
  String get captureUseTranscriptButton => '使用转写';

  @override
  String get captureRemoveAttachmentTooltip => '移除';

  @override
  String captureAttachmentReady(String preview) {
    return '已就绪 · $preview';
  }

  @override
  String captureAttachmentNeedsReview(String preview) {
    return '转写需要复核 · $preview';
  }

  @override
  String captureAttachmentBlocked(String reason) {
    return '附件已阻止 · $reason · 预览在复核前隐藏。';
  }

  @override
  String get captureAttachmentAssetSafetyReason => '素材安全';

  @override
  String get captureAttachmentBlockedBySafety => '被素材安全策略阻止';

  @override
  String captureAttachmentUnsupportedMimeType(String mimeType) {
    return '不支持的文件类型：$mimeType';
  }

  @override
  String get captureAttachmentVoiceTranscriptNeedsReview => '语音转写需要复核';

  @override
  String get captureAttachmentAllowed => '已允许';

  @override
  String get captureAttachmentKindPhoto => '照片';

  @override
  String get captureAttachmentKindVoice => '语音';

  @override
  String get captureAttachmentKindShare => '分享内容';

  @override
  String get captureAttachmentFallbackName => '附件';

  @override
  String captureAttachmentSummary(String kind, String name) {
    return '$kind：$name';
  }

  @override
  String captureBlockedAttachmentSummary(String name) {
    return '已阻止附件：$name';
  }

  @override
  String get captureEmptyMessage => '先输入文字或添加一个附件，再保存记录。';

  @override
  String get captureReviewPendingAttachments => '请先复核或移除待处理附件，再保存记录。';

  @override
  String get captureStopVoiceBeforeSaving => '请先停止或取消录音，再保存。';

  @override
  String get captureRemoveBlockedAttachments => '请先移除已阻止的附件再保存。';

  @override
  String get captureReviewAttachments => '请先复核附件再保存。';

  @override
  String captureVoiceFailed(String details) {
    return '录音失败：$details';
  }

  @override
  String get captureVoiceCancelled => '录音已取消。';

  @override
  String captureVoiceCancelFailed(String details) {
    return '取消录音失败：$details';
  }

  @override
  String captureAttachmentFailed(String details) {
    return '附件添加失败：$details';
  }

  @override
  String get captureCameraCancelled => '相机拍摄已取消。';

  @override
  String get captureGalleryCancelled => '相册选择已取消。';

  @override
  String get captureCameraPermissionDenied => '相机权限被拒绝。';

  @override
  String get capturePhotoLibraryPermissionDenied => '照片库权限被拒绝。';

  @override
  String get captureMicrophonePermissionDenied => '麦克风权限被拒绝。';

  @override
  String get captureCameraUnavailable => '这台设备上的相机不可用。';

  @override
  String get capturePhotoLibraryUnavailable => '这台设备上的照片库不可用。';

  @override
  String get captureMicrophoneUnavailable => '这台设备上的麦克风不可用。';

  @override
  String get captureCameraFailed => '相机拍摄失败。';

  @override
  String get captureGalleryFailed => '相册选择失败。';

  @override
  String get captureVoiceFailedSimple => '录音失败。';

  @override
  String get captureVoiceFailedToStart => '录音启动失败。';

  @override
  String get captureVoiceFailedToStop => '录音停止失败。';

  @override
  String get captureVoiceCancelFailedSimple => '取消录音失败。';

  @override
  String get captureVoiceFileNotCreated => '未创建录音文件。';

  @override
  String get captureVoiceEmptyFile => '录音生成了空文件。';

  @override
  String get captureVoiceFileNotReturned => '未返回录音文件。';

  @override
  String get captureRecordSavedModelRequired =>
      '记录已本地保存。配置模型提供商或等智能体恢复后重试，即可生成记忆、卡片、洞察和待办。';

  @override
  String get captureRecordSavedAgentFailed => '记录已本地保存，但智能体处理失败。请在模型或权限恢复后重试。';

  @override
  String captureMemoryReviewFailed(String details) {
    return '记忆复核失败：$details';
  }

  @override
  String get capturePhotoAttachedMessage => '照片已添加，复核后可以保存记录。';

  @override
  String get captureVoiceAttachedMessage => '语音草稿已添加，请先复核转写再保存。';

  @override
  String get captureShareAttachedMessage => '导入项目已添加，复核后可以保存记录。';

  @override
  String get captureSavedMessage => '记录已保存，本地智能体正在整理。';

  @override
  String get captureOpenTimelineAction => '时间线';

  @override
  String get recordButton => '记录';

  @override
  String get recordButtonProcessing => '处理中';

  @override
  String get stageProcessingTitle => '处理';

  @override
  String get stageProcessingRunning => '运行中';

  @override
  String get stageProcessingIdle => '空闲';

  @override
  String stageProcessingProcessed(int count) {
    return '$count 条已处理';
  }

  @override
  String get stageMemoryTitle => '记忆';

  @override
  String get stageMemoryReady => '就绪';

  @override
  String stageMemoryAccepted(int count) {
    return '$count 条已入库';
  }

  @override
  String stageMemoryAcceptedReview(int acceptedCount, int reviewCount) {
    return '$acceptedCount 条已入库 · $reviewCount 条待复核';
  }

  @override
  String get stageCardsTitle => '卡片';

  @override
  String get stageCardsWaiting => '等待中';

  @override
  String stageCardsLinked(int count) {
    return '$count 张卡片';
  }

  @override
  String get stageInsightTitle => '洞察';

  @override
  String get stageInsightDraftLane => '草稿通道';

  @override
  String get stageInsightWaiting => '等待中';

  @override
  String stageInsightSourceLinked(int count) {
    return '$count 条可溯源';
  }

  @override
  String get stageTodoTitle => '待办';

  @override
  String stageTodoLinked(int count) {
    return '$count 条已关联';
  }

  @override
  String get cardsTitle => '卡片';

  @override
  String get cardsEmpty => '还没有可溯源卡片。';

  @override
  String get insightsTitle => '洞察';

  @override
  String get insightsEmpty => '还没有可溯源洞察。';

  @override
  String get recordsTitle => '记录';

  @override
  String get recordsEmpty => '还没有本地记录。';

  @override
  String get memoryReviewTitle => '记忆复核';

  @override
  String get memoryReviewEmpty => '暂无需要复核的记忆候选。';

  @override
  String get memoryReviewAccept => '接受';

  @override
  String get memoryReviewEdit => '编辑';

  @override
  String get memoryReviewReject => '拒绝';

  @override
  String get memoryEditTitle => '编辑记忆';

  @override
  String get cancelButton => '取消';

  @override
  String get saveButton => '保存';

  @override
  String get memoryTitle => '记忆';

  @override
  String get memoryEmpty => '记忆队列正在等待第一次记录。';

  @override
  String get memoryPageTitle => '记忆';

  @override
  String get memoryPageSubtitle => '编辑、删除留痕、恢复并检查带来源的本地记忆。';

  @override
  String get memorySearchHint => '文本搜索需要召回器...';

  @override
  String get memoryTextSearchRequiresRetriever =>
      '文本搜索需要模型或向量召回器。清空输入框后可在本地浏览记忆。';

  @override
  String get memoryTextSearchClearHint => '清空输入框后可在本地浏览记忆。';

  @override
  String get memoryActiveSectionTitle => '活跃记忆';

  @override
  String get memoryActiveEmpty => '还没有活跃记忆。';

  @override
  String get memoryDeletedSectionTitle => '已删除记忆';

  @override
  String get memoryDeletedEmpty => '还没有删除留痕的记忆。';

  @override
  String get memoryActionEdit => '编辑';

  @override
  String get memoryActionDelete => '删除';

  @override
  String get memoryActionRestore => '恢复';

  @override
  String memoryRevisionLabel(int revision) {
    return '第 $revision 版';
  }

  @override
  String get memoryBodyCannotBeEmpty => '记忆正文不能为空。';

  @override
  String get memoryUpdateFailed => '记忆更新失败。';

  @override
  String get memoryTypePreference => '偏好';

  @override
  String get memoryTypeProject => '项目';

  @override
  String get memoryTypePerson => '人物';

  @override
  String get memoryTypeHealth => '健康';

  @override
  String get memoryTypeFinance => '财务';

  @override
  String get memoryTypeLocation => '地点';

  @override
  String get memoryTypeCredential => '凭据';

  @override
  String get memoryTypeInsight => '洞察';

  @override
  String get memoryTypeTaskContext => '任务上下文';

  @override
  String get memorySensitivityLow => '低敏感度';

  @override
  String get memorySensitivityMedium => '中敏感度';

  @override
  String get memorySensitivityHigh => '高敏感度';

  @override
  String get cardKindCapture => '记录卡片';

  @override
  String get cardKindMemory => '记忆卡片';

  @override
  String get insightKindSummary => '摘要洞察';

  @override
  String get insightKindCount => '计数洞察';

  @override
  String get insightKindTrend => '趋势洞察';

  @override
  String get insightKindSourceMix => '来源组合洞察';

  @override
  String get insightKindActionPattern => '行动模式洞察';

  @override
  String get insightKindAttachmentEvidence => '附件证据洞察';

  @override
  String get insightMetricSourceLinked => '可溯源';

  @override
  String get traceTitle => '追踪';

  @override
  String get traceEmpty => '记录或插件运行后，本地运行事件会显示在这里。';

  @override
  String get recordStatusSavedProcessing => '已本地保存，正在处理';

  @override
  String get recordStatusProcessed => '已本地处理';

  @override
  String get recordStatusAgentFailed => '已本地保存，智能体处理失败';

  @override
  String get memoryAutoSavedTitle => '记忆自动入库';

  @override
  String get memoryNeedsReviewTitle => '记忆待复核';

  @override
  String get memorySavedTitle => '记忆已入库';

  @override
  String get statusAutoAccepted => '自动接受';

  @override
  String get statusNeedsReview => '需要复核';

  @override
  String get statusAccepted => '已接受';

  @override
  String confidenceLabel(String confidence) {
    return '$confidence 置信度';
  }

  @override
  String get confidenceHigh => '高';

  @override
  String get confidenceMedium => '中';

  @override
  String get confidenceLow => '低';

  @override
  String todoFollowUpTitle(String body) {
    return '跟进：$body';
  }

  @override
  String get todoSeedReviewMemory => '导出前复核生成的记忆';

  @override
  String get todoSeedConfirmBackup => '确认备份权限边界';

  @override
  String get todoReviewCaptureTitle => '复核记录';

  @override
  String todoSourceLabel(String sourceId) {
    return '来源：$sourceId';
  }

  @override
  String sourceLabel(String sourceId) {
    return '来源：$sourceId';
  }

  @override
  String sourceKindIdLabel(String kind, String sourceId) {
    return '$kind：$sourceId';
  }

  @override
  String sourceKindIdExtraLabel(String kind, String sourceId, int extraCount) {
    return '$kind：$sourceId +$extraCount';
  }

  @override
  String get sourceUnknownLabel => '未知来源';

  @override
  String get sourceKindRawText => '原始文本';

  @override
  String get sourceKindAttachment => '附件';

  @override
  String get sourceKindFile => '文件';

  @override
  String get attachmentArtifactStatusPending => '待处理';

  @override
  String get attachmentArtifactStatusReady => '就绪';

  @override
  String get attachmentArtifactStatusFailed => '失败';

  @override
  String get attachmentArtifactStatusBlocked => '阻塞';

  @override
  String get attachmentArtifactStatusNeedsReview => '需要复核';

  @override
  String get attachmentArtifactKindAudioTranscript => '音频转写';

  @override
  String get attachmentArtifactKindImageDerivatives => '图片产物';

  @override
  String get attachmentArtifactKindOcrText => 'OCR 文本';

  @override
  String get attachmentArtifactKindVisionSummary => '图片摘要';

  @override
  String get attachmentArtifactKindSharedText => '分享文本';

  @override
  String get timelineAttachmentArtifactsTitle => '附件产物';

  @override
  String sourceLinkCount(int count) {
    return '$count 个来源链接';
  }

  @override
  String localTimeLabel(String time) {
    return '$time 本地';
  }

  @override
  String get todoStatusNeedsExplicitPermission => '需要显式授权';

  @override
  String get todoStatusSuggestedByAgent => '智能体建议';

  @override
  String get todoStatusNotSuggested => '未建议';

  @override
  String get todoStatusOpen => '未完成';

  @override
  String get todoStatusCompleted => '已完成';

  @override
  String get todoActionComplete => '完成';

  @override
  String get todoActionReopen => '重新打开';

  @override
  String get todoUpdateFailed => '待办更新失败。';

  @override
  String get chatTitle => '对话';

  @override
  String get chatSubtitle => '用本地记忆、记录和待办作为上下文询问 WideNote。';

  @override
  String get chatSessionsTitle => '会话';

  @override
  String get chatDailyReviewTitle => '每日回顾';

  @override
  String get chatDailyReviewSubtitle => '询问今天、关联记录和待处理事项。';

  @override
  String get chatMemoryQaTitle => '记忆问答';

  @override
  String get chatMemoryQaSubtitle => '查询可编辑、可溯源的本地记忆。';

  @override
  String get chatAgentPackSandboxTitle => 'Agent Pack 沙盒';

  @override
  String get chatAgentPackSandboxSubtitle => '在权限复核后试运行插件动作。';

  @override
  String get chatInputTitle => '输入';

  @override
  String get chatInputHint => '向 WideNote 询问记录、记忆条目或插件运行...';

  @override
  String get chatLoadErrorTitle => '对话加载失败';

  @override
  String get chatLoadErrorBody => '本地对话暂时无法打开，请稍后重试。';

  @override
  String get chatHistoryTitle => '历史会话';

  @override
  String get chatNewSessionButton => '新对话';

  @override
  String get chatNewSessionTooltip => '开始一个新对话';

  @override
  String get chatConversationListTitle => '对话列表';

  @override
  String get chatActiveSessionLabel => '当前对话';

  @override
  String get chatDefaultSessionTitle => '新对话';

  @override
  String chatSessionMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条消息',
      one: '1 条消息',
      zero: '空对话',
    );
    return '$_temp0';
  }

  @override
  String get chatSessionActionsTooltip => '对话操作';

  @override
  String get chatRenameSessionAction => '重命名';

  @override
  String get chatDeleteSessionAction => '删除';

  @override
  String get chatRenameSessionTitle => '重命名对话';

  @override
  String get chatRenameSessionHint => '对话标题';

  @override
  String get chatDeleteSessionTitle => '删除对话？';

  @override
  String get chatDeleteSessionBody => '这会从本设备移除这个本地对话和其中的消息。';

  @override
  String get chatDeleteSessionConfirm => '删除';

  @override
  String get chatSessionDeletedSnackbar => '对话已删除。';

  @override
  String get chatEmptySessions => '还没有本地会话。';

  @override
  String get chatBackToConversationsTooltip => '返回对话列表';

  @override
  String get chatBackToConversationsButton => '返回对话列表';

  @override
  String get chatSessionMissingTitle => '对话不存在';

  @override
  String get chatSessionMissingBody => '这个本地对话已不在本设备上。';

  @override
  String get chatSessionOpeningTitle => '正在打开对话';

  @override
  String get chatSessionSwitchBlockedTitle => '回答进行中';

  @override
  String get chatSessionSwitchDisabled => '当前回答完成后才能切换会话。';

  @override
  String get chatLocalConversationTitle => '本地对话';

  @override
  String get chatEmptyConversation => '先问一个关于记录、记忆或待办的问题。';

  @override
  String get chatSendFailed => '发送失败';

  @override
  String get retryButton => '重试';

  @override
  String get chatSourcesTitle => '引用来源';

  @override
  String get chatTyping => '正在基于本地上下文回答...';

  @override
  String get chatComposerTitle => '提问';

  @override
  String get chatComposerHint => '问问本地记录、记忆或待办...';

  @override
  String get chatSendButton => '发送';

  @override
  String get chatGeneratingButton => '生成中';

  @override
  String get chatContextMemoryTitle => '记忆';

  @override
  String get chatContextRecordTitle => '记录';

  @override
  String get chatContextTodoTitle => '待办';

  @override
  String get chatContextCardTitle => '卡片';

  @override
  String get chatContextInsightTitle => '洞察';

  @override
  String get chatContextRedactedTitle => '已脱敏来源';

  @override
  String get chatContextUntitledCapture => '未命名本地记录';

  @override
  String get chatContextUntitledTodo => '未命名待办建议';

  @override
  String get chatErrorModelNotConfigured => '尚未配置模型访问。请先在设置里添加提供商，然后重试。';

  @override
  String get chatErrorModelEmptyAnswer => '模型没有返回回答。请重试或切换提供商。';

  @override
  String get chatErrorModelUnavailable => '模型暂不可用。请检查提供商设置或稍后重试。';

  @override
  String get todosTitle => '待办与日程';

  @override
  String get todosSubtitle => '把可执行行动、带时间的安排候选和普通记录分开展示。';

  @override
  String get todosSurfaceTitle => '来源关联待办';

  @override
  String get todosEmpty => '还没有来源关联待办。';

  @override
  String get todoActionsSectionTitle => '行动项';

  @override
  String get todoActionsEmpty => '还没有明确行动项。';

  @override
  String get todoSchedulesSectionTitle => '日程候选';

  @override
  String get todoSchedulesEmpty => '还没有日程候选。';

  @override
  String get todoStatusSuggestedAction => '智能体建议行动';

  @override
  String get todoStatusScheduleCandidate => '日程候选';

  @override
  String get todoQuietTitle => '未进入待办';

  @override
  String todoQuietSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# 条记录没有明确行动或日程意图，仍保留在时间线。',
      one: '# 条记录没有明确行动或日程意图，仍保留在时间线。',
    );
    return '$_temp0';
  }

  @override
  String todoScheduledForLabel(String time) {
    return '时间线索：$time';
  }

  @override
  String get timelineTitle => '时间线';

  @override
  String get timelineSubtitle => '浏览记录、卡片、记忆、洞察和待办。';

  @override
  String get timelineSearchTooltip => '搜索时间线';

  @override
  String get timelineBackTooltip => '返回时间线';

  @override
  String timelineLoadFailed(String error) {
    return '时间线加载失败：$error';
  }

  @override
  String get timelineUnavailableTitle => '时间线暂不可用';

  @override
  String get timelineEmptyTitle => '还没有时间线项目';

  @override
  String get timelineEmptyBody => '先本地记录一条内容，就能生成带来源的卡片。';

  @override
  String get timelineUntitledCapture => '未命名记录';

  @override
  String get timelineUntitledTodo => '未命名待办';

  @override
  String get timelineStartCaptureButton => '开始记录';

  @override
  String get timelineSearchTitle => '搜索';

  @override
  String get timelineSearchSubtitle => '不离开设备，在本地时间线中筛选。';

  @override
  String get timelineSearchUnavailableTitle => '搜索暂不可用';

  @override
  String timelineSearchFailed(String error) {
    return '时间线搜索失败：$error';
  }

  @override
  String get timelineSearchHint => '按类型筛选；文本搜索会在召回器就绪后启用';

  @override
  String get timelineFilterAll => '全部';

  @override
  String get timelineSearchEmptyTitle => '还没有可搜索内容';

  @override
  String get timelineSearchEmptyBody => '先创建一条记录，再浏览卡片、记忆和待办。';

  @override
  String get timelineSearchNeedsRetrieverTitle => '文本搜索需要召回器';

  @override
  String get timelineSearchNeedsRetrieverBody => '清空输入框后可按类型本地浏览。语义搜索会使用模型召回器。';

  @override
  String get timelineSearchNoResultsTitle => '没有匹配的时间线项目';

  @override
  String get timelineSearchNoResultsBody => '移除类型筛选可以显示更多本地项目。';

  @override
  String timelineSearchResultCount(int count) {
    return '$count 个结果';
  }

  @override
  String get timelineKindCapture => '记录';

  @override
  String get timelineKindCaptures => '记录';

  @override
  String get timelineKindCard => '卡片';

  @override
  String get timelineKindCards => '卡片';

  @override
  String get timelineKindInsight => '洞察';

  @override
  String get timelineKindInsights => '洞察';

  @override
  String get timelineKindMemory => '记忆';

  @override
  String get timelineKindTodo => '待办';

  @override
  String get timelineKindTodos => '待办';

  @override
  String get timelineKindEvent => '事件';

  @override
  String timelineKindDetailTitle(String kind) {
    return '$kind详情';
  }

  @override
  String get timelineCardDetailTitle => '卡片详情';

  @override
  String get timelineCardDetailSubtitle => '检查卡片正文、来源和关联项目。';

  @override
  String get timelineCardUnavailableTitle => '卡片暂不可用';

  @override
  String timelineCardFailed(String error) {
    return '卡片详情加载失败：$error';
  }

  @override
  String get timelineCardNotFoundTitle => '未找到卡片';

  @override
  String get timelineCardNotFoundBody => '当前本地时间线里没有选中的卡片。';

  @override
  String get timelineSourceRefsTitle => '来源引用';

  @override
  String get timelineRelatedRecordsTitle => '关联记录';

  @override
  String get timelineRelatedMemoryTitle => '关联记忆';

  @override
  String get timelineRelatedTodosTitle => '关联待办';

  @override
  String get timelineNoLinkedItems => '没有关联项目。';

  @override
  String get timelineItemDetailTitle => '时间线详情';

  @override
  String get timelineItemDetailSubtitle => '检查本地项目、状态、元数据和来源。';

  @override
  String get timelineItemUnavailableTitle => '时间线项目暂不可用';

  @override
  String timelineItemFailed(String error) {
    return '时间线项目加载失败：$error';
  }

  @override
  String get timelineSourceNotFoundTitle => '未找到来源';

  @override
  String get timelineSourceNotFoundBody => '当前本地索引里还没有这个来源引用。';

  @override
  String get timelineStatusTitle => '状态';

  @override
  String get timelineMetadataTitle => '元数据';

  @override
  String get timelineOpenSourceTooltip => '打开来源';

  @override
  String timelineSourceRefCount(int count) {
    return '$count 个来源引用';
  }

  @override
  String get timelineStatusActive => '活跃';

  @override
  String get timelineStatusDeleted => '已删除';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSubtitle => '隐私、权限、模型、备份和追踪。';

  @override
  String get settingsBackTooltip => '从设置返回';

  @override
  String get settingsPrivacyTitle => '隐私';

  @override
  String get settingsPrivacyLocalFirstTitle => '本地优先核心';

  @override
  String get settingsPrivacyLocalFirstBody =>
      '记录、记忆、待办、卡片、对话和追踪会留在这台设备上，除非你主动选择备份、同步或模型提供商。';

  @override
  String get settingsPrivacyLocalFirstStatus => '无需账号';

  @override
  String get settingsPrivacyPermissionsTitle => '权限可撤销';

  @override
  String get settingsPrivacyPermissionsBody =>
      '内置插件只使用窄权限；高风险文件、网络和脚本能力会延期到显式授权链路就绪后。';

  @override
  String get settingsPrivacyPermissionsStatus => '可复核';

  @override
  String get settingsPrivacyBackupTitle => '备份密钥边界';

  @override
  String get settingsPrivacyBackupBody =>
      '完整 .widenote 备份会包含模型提供商和 allowlist 安全存储 Key，恢复后可直接继续使用已配置功能；请把备份文件保存在可信位置。';

  @override
  String get settingsPrivacyBackupStatus => '完整备份';

  @override
  String get settingsControlsTitle => '控制入口';

  @override
  String get settingsPermissionsTitle => '隐私与权限';

  @override
  String get settingsPermissionsSubtitle => '复核可用的插件权限和延期的高风险能力。';

  @override
  String get settingsPermissionsStatus => '显式授权';

  @override
  String settingsPermissionsStatusSummary(
    int availableCount,
    int deferredCount,
  ) {
    return '$availableCount 可用 / $deferredCount 延期';
  }

  @override
  String get settingsSystemPermissionsTitle => '系统权限';

  @override
  String get settingsSystemPermissionsSubtitle => '检查相机、麦克风、定位、媒体、文件和日历访问。';

  @override
  String get settingsSystemPermissionsStatus => '设备';

  @override
  String get settingsModelProvidersTitle => '模型提供商';

  @override
  String get settingsModelProvidersSubtitle =>
      '为运行时和 Agent Pack 配置本地或自带密钥的模型访问。';

  @override
  String get settingsTranscriptionTitle => '语音转写';

  @override
  String get settingsTranscriptionSubtitle =>
      '配置本地 SenseVoice、MiMo ASR、实时预览和转写校正。';

  @override
  String get settingsTranscriptionStatusLoading => '加载中';

  @override
  String get settingsTranscriptionStatusLocal => '本地';

  @override
  String get settingsTranscriptionStatusRemote => 'MiMo';

  @override
  String get settingsTranscriptionStatusNeedsSetup => '待配置';

  @override
  String get settingsBackupTitle => '备份与恢复';

  @override
  String get settingsBackupSubtitle => '导出或导入本地记录、记忆、卡片、模型提供商、待办和追踪。';

  @override
  String get settingsBackupStatus => '本地';

  @override
  String get settingsBackupStatusSafeOnly => '本地完整';

  @override
  String get settingsBackupStatusExportReady => '可导出';

  @override
  String get settingsBackupStatusRestored => '已恢复';

  @override
  String get settingsBackupStatusNeedsReview => '需检查';

  @override
  String get settingsTraceConsoleTitle => '日志中心';

  @override
  String get settingsTraceConsoleSubtitle => '查看本地 Agent Runtime 日志、权限检查和生成输出。';

  @override
  String get settingsTraceConsoleStatus => '只读';

  @override
  String settingsTraceConsoleStatusSummary(int eventCount, int warningCount) {
    return '$eventCount 事件 / $warningCount 警告';
  }

  @override
  String get systemPermissionsTitle => '系统权限';

  @override
  String get systemPermissionsSubtitle => '复核 App 级设备权限，需要时直接跳到对应系统设置。';

  @override
  String get systemPermissionsBackTooltip => '从系统权限返回';

  @override
  String get systemPermissionsLoading => '正在检查权限';

  @override
  String get systemPermissionsError => '暂时无法读取权限状态';

  @override
  String get systemPermissionsSummaryTitle => '设备状态';

  @override
  String systemPermissionsSummary(int grantedCount, int reviewCount) {
    return '$grantedCount 项就绪 / $reviewCount 项需关注';
  }

  @override
  String get systemPermissionsPlatformAndroid => 'Android';

  @override
  String get systemPermissionsPlatformIos => 'iOS';

  @override
  String get systemPermissionsPlatformOther => '仅移动端';

  @override
  String get systemPermissionsRefreshAction => '刷新';

  @override
  String get systemPermissionsDeviceAccessTitle => 'App 访问';

  @override
  String get systemPermissionsStatusGranted => '已允许';

  @override
  String get systemPermissionsStatusLimited => '部分允许';

  @override
  String get systemPermissionsStatusDenied => '未允许';

  @override
  String get systemPermissionsStatusPermanentlyDenied => '需设置';

  @override
  String get systemPermissionsStatusRestricted => '受限制';

  @override
  String get systemPermissionsStatusNotRequired => '选择器';

  @override
  String get systemPermissionsStatusNotConfigured => '未启用';

  @override
  String get systemPermissionsStatusNotSupported => '不支持';

  @override
  String get systemPermissionsStatusUnknown => '未知';

  @override
  String get systemPermissionsStatusServiceOff => '服务关闭';

  @override
  String get systemPermissionsActionRequest => '请求';

  @override
  String get systemPermissionsActionManage => '管理';

  @override
  String get systemPermissionsActionOpenSettings => '设置';

  @override
  String get systemPermissionsLocationServiceOffBody => '系统定位服务当前关闭。';

  @override
  String get systemPermissionsCameraTitle => '相机';

  @override
  String get systemPermissionsCameraSubtitle => '仅在拍摄本地照片附件时使用。';

  @override
  String get systemPermissionsMicrophoneTitle => '麦克风';

  @override
  String get systemPermissionsMicrophoneSubtitle => '仅在保存本地语音记录时使用。';

  @override
  String get systemPermissionsLocationTitle => '定位';

  @override
  String get systemPermissionsLocationSubtitle => '开启位置上下文后，仅用于前台 GPS 元数据。';

  @override
  String get systemPermissionsPhotosTitle => '照片与媒体';

  @override
  String get systemPermissionsPhotosSubtitle => '在 iOS 上复核本地媒体附件使用的照片库访问。';

  @override
  String get systemPermissionsPhotosAndroidSubtitle =>
      '在 Android 上，WideNote 使用系统照片选择器，不申请广泛媒体权限。';

  @override
  String get systemPermissionsFilesTitle => '文件';

  @override
  String get systemPermissionsFilesSubtitle => '备份和导入使用系统文档选择器，不申请广泛文件访问。';

  @override
  String get systemPermissionsCalendarTitle => '日历';

  @override
  String get systemPermissionsCalendarSubtitle => '系统日历读写会等后续权限决策落地后再启用。';

  @override
  String get pluginsTitle => '插件';

  @override
  String get pluginsSubtitle => '管理权限、模型、备份和追踪的插件控制入口。';

  @override
  String get pluginsControlEntriesTitle => '控制入口';

  @override
  String get pluginsPackLibraryTitle => '插件库';

  @override
  String get pluginsPackLibrarySubtitle => '安装、检查和停用 Agent Pack。';

  @override
  String get pluginsPackLibraryStatus => '可管理';

  @override
  String get pluginsPermissionGateTitle => '权限门禁';

  @override
  String get pluginsPermissionGateSubtitle => '在插件运行前复核敏感能力。';

  @override
  String get pluginsPermissionGateStatus => '显式授权';

  @override
  String get pluginsModelProviderTitle => '模型提供商';

  @override
  String get pluginsModelProviderSubtitle => '配置本地或自带密钥的模型访问。';

  @override
  String get pluginsModelProviderStatus => '未连接';

  @override
  String pluginsModelProviderConfigured(int count) {
    return '$count 个提供商';
  }

  @override
  String get pluginsBackupTitle => '备份';

  @override
  String get pluginsBackupSubtitle => '导出或导入本地 WideNote 备份。';

  @override
  String get pluginsBackupStatus => '本地优先';

  @override
  String get pluginsTraceConsoleTitle => 'Agent Console';

  @override
  String get pluginsTraceConsoleSubtitle => '检查本地运行、审批、追踪和插件输出。';

  @override
  String get pluginsTraceConsoleStatus => '本地';

  @override
  String get packLibraryTitle => '插件库';

  @override
  String get packLibrarySubtitle => '在动态安装能力就绪前，检查内置官方 Agent Pack。';

  @override
  String get packLibraryInstalledTitle => '已安装官方插件';

  @override
  String packLibraryVersion(String version) {
    return 'v$version';
  }

  @override
  String packLibraryPermissionCount(int count) {
    return '$count 个权限';
  }

  @override
  String packLibraryOutputCount(int count) {
    return '$count 个输出';
  }

  @override
  String packLibraryEnabledCount(int count) {
    return '$count 个已启用';
  }

  @override
  String packLibraryDisabledCount(int count) {
    return '$count 个已停用';
  }

  @override
  String get packLibraryDisableImpact =>
      '停用只影响后续本地任务，不会删除已存储在这台设备上的记录、追踪或派生输出。';

  @override
  String packLibraryPublisher(String publisher) {
    return '发布者：$publisher';
  }

  @override
  String packLibraryEdition(String edition) {
    return '版本类型：$edition';
  }

  @override
  String packLibraryMarketplaceSource(String source) {
    return '来源：$source';
  }

  @override
  String packLibraryTrustLevel(String trust) {
    return '信任：$trust';
  }

  @override
  String packLibraryCategories(String categories) {
    return '分类：$categories';
  }

  @override
  String packLibraryCapabilities(String capabilities) {
    return '能力：$capabilities';
  }

  @override
  String packLibraryReplacementSlots(String slots) {
    return '替换槽：$slots';
  }

  @override
  String packLibraryAdditiveSlots(String slots) {
    return '附加槽：$slots';
  }

  @override
  String packLibraryEntrypoint(String entrypoint) {
    return '运行时：$entrypoint';
  }

  @override
  String packLibrarySubscriptionCount(int count) {
    return '$count 个订阅';
  }

  @override
  String packLibraryFailureCount(int count) {
    return '$count 次失败';
  }

  @override
  String packLibraryPermissionDecisionSummary(
    int granted,
    int denied,
    int revoked,
  ) {
    return '权限：$granted 已授权 / $denied 已拒绝 / $revoked 已撤销';
  }

  @override
  String packLibraryLastFailure(String message) {
    return '最近失败：$message';
  }

  @override
  String get packLibraryStatusEnabled => '已启用';

  @override
  String get packLibraryStatusDisabled => '已停用';

  @override
  String packLibraryStatusUnknown(String status) {
    return '状态：$status';
  }

  @override
  String get packLibraryRuntimeIdle => '运行时：空闲';

  @override
  String get packLibraryRuntimeQueued => '运行时：排队中';

  @override
  String get packLibraryRuntimeRunning => '运行时：运行中';

  @override
  String get packLibraryRuntimeSucceeded => '运行时：已成功';

  @override
  String get packLibraryRuntimeFailed => '运行时：失败';

  @override
  String get packLibraryRuntimeDenied => '运行时：已拒绝';

  @override
  String get packLibraryRuntimeCanceled => '运行时：已取消';

  @override
  String get packLibraryRuntimeBlocked => '运行时：已阻塞';

  @override
  String packLibraryRuntimeUnknown(String status) {
    return '运行时：$status';
  }

  @override
  String get packDefaultName => '默认记录循环';

  @override
  String get packDefaultDescription => '保守的内置插件，用于记录卡片、记忆候选和轻量洞察。';

  @override
  String get packTodoName => '待办提取循环';

  @override
  String get packTodoDescription => '内置插件，用于生成带来源的待办建议。';

  @override
  String get permissionGateTitle => '权限门禁';

  @override
  String get permissionGateSubtitle => '复核本地插件权限状态和延期的高风险能力。';

  @override
  String get permissionGateGrantedTitle => '内置与可用权限';

  @override
  String get permissionGateDeferredTitle => '延期的高风险权限';

  @override
  String get permissionGateStatusAvailable => '内置 / 可用';

  @override
  String get permissionGateStatusGranted => '本地已授权';

  @override
  String get permissionGateStatusDenied => '本地已拒绝';

  @override
  String get permissionGateStatusRevoked => '本地已撤销';

  @override
  String get permissionGateActionGrant => '授权';

  @override
  String get permissionGateActionDeny => '拒绝';

  @override
  String get permissionGateActionRevoke => '撤销';

  @override
  String get permissionGateActionDeferred => '延期';

  @override
  String get permissionGateImpactAvailable => '授权或拒绝只会改变后续本地运行。';

  @override
  String get permissionGateImpactGranted => '后续本地运行可以使用此权限，直到你撤销它。';

  @override
  String get permissionGateImpactDenied => '需要此权限的后续本地运行会被阻止；既有记录和追踪会保留。';

  @override
  String get permissionGateImpactRevoked => '撤销会阻止后续使用；既有记录、追踪和派生输出会保留以便复核。';

  @override
  String get permissionGateImpactDeferred => '此高风险或外部能力在本地 L3 切片中保持禁用。';

  @override
  String get permissionGateRiskLow => '低风险';

  @override
  String get permissionGateRiskMedium => '中风险';

  @override
  String get permissionGateRiskHigh => '高风险';

  @override
  String get permissionGateCommunityPacks => '社区插件';

  @override
  String get permissionGateMediaPacks => '媒体插件';

  @override
  String get permissionGateContextPacks => '上下文插件';

  @override
  String get permissionGateDeferredSandbox => '沙箱审批就绪前延期。';

  @override
  String get permissionGateDeferredExternalTools => '外部工具权限设计就绪前延期。';

  @override
  String get permissionGateDeferredPlatform => '平台权限复核就绪前延期。';

  @override
  String get permissionGateDeferredPrivacy => '隐私决策覆盖前延期。';

  @override
  String get agentPlatformTitle => 'Agent Console';

  @override
  String get agentPlatformSubtitle => '来自运行、任务、审批和追踪的本地运行控制证据。';

  @override
  String get agentConsoleTitle => 'Agent Console';

  @override
  String get agentConsoleSubtitle => '本地优先地控制运行、任务、审批、插件和脱敏追踪。';

  @override
  String get traceConsoleTitle => 'Agent Console';

  @override
  String get traceConsoleSubtitle => '查看本地 Agent Runtime 运行、权限和生成输出。';

  @override
  String get agentConsoleSummaryTitle => '本地控制摘要';

  @override
  String get traceConsoleSummaryTitle => '运行摘要';

  @override
  String traceConsoleEventCount(int count) {
    return '日志事件：$count';
  }

  @override
  String traceConsoleRunCount(int count) {
    return '运行：$count';
  }

  @override
  String traceConsoleWarningCount(int count) {
    return '警告：$count';
  }

  @override
  String get traceConsoleRefreshButton => '刷新';

  @override
  String get traceConsoleOpenButton => '打开 Agent Console';

  @override
  String get traceConsoleEventsTitle => '事件';

  @override
  String get traceConsoleEventsSubtitle => '在独立页面浏览本地运行事件，并在需要时打开原始日志。';

  @override
  String get traceConsoleEventsEntryTitle => '日志事件';

  @override
  String get traceConsoleEventsEntryBody => '把较长的事件流放到单独页面；只在需要时查看本机原始证据。';

  @override
  String get traceConsoleOpenEventsButton => '打开事件';

  @override
  String get traceConsoleEmpty => '还没有运行日志。记录或插件运行后会显示在这里。';

  @override
  String get traceConsoleNoMessage => '没有记录消息。';

  @override
  String traceConsoleRun(String runId) {
    return '运行：$runId';
  }

  @override
  String traceConsolePack(String packId) {
    return '插件：$packId';
  }

  @override
  String traceConsoleAgent(String agentId) {
    return '智能体：$agentId';
  }

  @override
  String traceConsoleDuration(num duration) {
    return '耗时：$duration ms';
  }

  @override
  String agentConsoleTotalCount(int count) {
    return '总数：$count';
  }

  @override
  String agentConsoleActiveCount(int count) {
    return '活跃：$count';
  }

  @override
  String agentConsoleFailedCount(int count) {
    return '失败：$count';
  }

  @override
  String agentConsoleDeniedCount(int count) {
    return '已拒绝：$count';
  }

  @override
  String agentConsoleBlockedCount(int count) {
    return '已阻塞：$count';
  }

  @override
  String agentConsoleTaskCount(int count) {
    return '任务：$count';
  }

  @override
  String agentConsolePendingApprovalCount(int count) {
    return '审批：$count';
  }

  @override
  String get agentConsoleFilterTitle => '状态过滤';

  @override
  String get agentConsoleFilterAll => '全部';

  @override
  String get agentConsoleFilterActive => '活跃';

  @override
  String get agentConsoleFilterFailed => '失败';

  @override
  String get agentConsoleFilterDenied => '拒绝';

  @override
  String get agentConsoleFilterBlocked => '阻塞';

  @override
  String get approvalQueueTitle => '审批队列';

  @override
  String get approvalQueueEmpty => '暂无待审批本地行动。';

  @override
  String get approvalQueueScaffoldBody =>
      '持久审批存储就绪后，请求会在这里暂停等待处理。本页不会批准或拒绝假的运行结果。';

  @override
  String get agentConsoleRunsTitle => '运行';

  @override
  String get agentConsoleRunsEmpty => '没有符合当前过滤条件的本地运行。';

  @override
  String get agentConsoleTasksTitle => '任务';

  @override
  String get agentConsoleTasksEmpty => '没有符合当前过滤条件的本地任务。';

  @override
  String agentConsoleStatus(String status) {
    return '状态：$status';
  }

  @override
  String agentConsoleSeverity(String severity) {
    return '级别：$severity';
  }

  @override
  String agentConsoleTask(String taskId) {
    return '任务：$taskId';
  }

  @override
  String agentConsoleEvent(String eventId) {
    return '事件：$eventId';
  }

  @override
  String agentConsoleParentTrace(String traceId) {
    return '父追踪：$traceId';
  }

  @override
  String agentConsoleAttempt(int attempt) {
    return '第 $attempt 次尝试';
  }

  @override
  String agentConsoleTaskAttempts(int attempts, int maxAttempts) {
    return '尝试：$attempts/$maxAttempts';
  }

  @override
  String agentConsoleMissingDependencies(int count) {
    return '$count 个缺失依赖';
  }

  @override
  String agentConsoleOutputCount(int count) {
    return '$count 个输出';
  }

  @override
  String agentConsoleStarted(String time) {
    return '开始：$time';
  }

  @override
  String agentConsoleCompleted(String time) {
    return '完成：$time';
  }

  @override
  String agentConsoleCreated(String time) {
    return '创建：$time';
  }

  @override
  String get agentConsoleNotCompleted => '尚未完成';

  @override
  String agentConsoleError(String message) {
    return '错误：$message';
  }

  @override
  String get agentConsoleRetryAction => '重试';

  @override
  String get agentConsoleCancelAction => '取消';

  @override
  String get agentConsoleControlsUnavailable =>
      '移动端暴露实时 RuntimeKernel 控制 provider 前，重试和取消保持禁用。这里不会执行假的成功操作。';

  @override
  String get agentConsoleRunTracesTitle => '追踪列表';

  @override
  String get agentConsoleRunNoTraces => '这个运行还没有记录追踪。';

  @override
  String get agentConsoleRunModeReadOnly => '运行模式：只读';

  @override
  String get agentConsoleRunModeConfirm => '运行模式：需确认';

  @override
  String get agentConsoleRunModeAuto => '运行模式：自动';

  @override
  String get agentConsoleRunModeUnknown => '运行模式：未知';

  @override
  String agentConsoleChildDelegation(String delegationId) {
    return '委派：$delegationId';
  }

  @override
  String agentConsoleChildRun(String runId) {
    return '子运行：$runId';
  }

  @override
  String agentConsoleChildStatus(String status) {
    return '子状态：$status';
  }

  @override
  String agentConsoleDelegationViolations(String codes) {
    return '违规：$codes';
  }

  @override
  String get traceConsoleOpenSourceButton => '打开来源';

  @override
  String get traceConsoleNoSource => '这条追踪没有可打开的来源引用。';

  @override
  String get traceConsolePayloadTitle => '脱敏 payload';

  @override
  String get traceConsolePayloadEmpty => '没有记录 payload。';

  @override
  String traceConsolePayloadRedactedCount(int count) {
    return '$count 个敏感字段已脱敏';
  }

  @override
  String get traceConsoleRedactedValue => '[已脱敏]';

  @override
  String get traceConsoleEventsFilteredEmpty => '没有符合当前过滤条件的日志事件。';

  @override
  String get traceConsoleBackTooltip => '从日志中心返回';

  @override
  String get agentConsoleAgentsTitle => 'Agent 运行';

  @override
  String get agentConsoleAgentsSubtitle => '查看本地运行、任务、禁用控制和每次运行的追踪摘要。';

  @override
  String get agentConsoleAgentsEntryTitle => 'Agent 运行与任务';

  @override
  String get agentConsoleAgentsEntryBody => '在单独页面查看较长的运行和任务列表。';

  @override
  String get agentConsoleOpenAgentsButton => '打开运行';

  @override
  String get traceRawOpenButton => '查看原始日志';

  @override
  String get traceRawTitle => '原始日志';

  @override
  String get traceRawSubtitle => '这条追踪的本地运行证据。';

  @override
  String get traceRawWarningTitle => '本机私有日志';

  @override
  String get traceRawWarningBody =>
      '这里可能显示原始 prompt 和工具数据。本页不提供复制、分享或导出操作，也不得用于外部审查。';

  @override
  String get traceRawNotFoundTitle => '原始日志不可用';

  @override
  String get traceRawNotFoundBody => '本地存储中没有找到这条追踪。';

  @override
  String get traceRawMetadataTitle => '元数据';

  @override
  String get traceRawMessageTitle => '原始消息';

  @override
  String get traceRawPayloadTitle => '原始 payload';

  @override
  String traceRawPolicyRedactedCount(int count) {
    return '$count 个凭证、路径或媒体字段已按策略遮蔽';
  }

  @override
  String get providerSettingsTitle => '模型提供商';

  @override
  String get providerSettingsSubtitle =>
      '选择 WideNote 智能体如何访问模型、默认运行时模型是谁，以及哪些能力可以安全使用。';

  @override
  String get providerSettingsAdd => '添加提供商';

  @override
  String get providerSettingsListTitle => '提供商';

  @override
  String get providerSettingsEmpty => '还没有配置模型提供商。';

  @override
  String get providerSettingsDefaultTag => '默认';

  @override
  String get providerSettingsStatusTitle => '运行时模型访问';

  @override
  String providerSettingsStatusConfigured(String provider) {
    return '正在使用 $provider';
  }

  @override
  String get providerSettingsStatusNotConfigured => '尚未配置模型';

  @override
  String get providerSettingsStatusDescriptionConfigured =>
      '当前切片中，对话和需要模型的 Agent Pack 默认使用这个模型；捕获仍会在本地保存原始记录。';

  @override
  String get providerSettingsStatusDescriptionOffline =>
      '核心记录仍会本地保存原始输入。对话回答和语义模型任务需要先配置自带密钥的提供商。';

  @override
  String providerSettingsProviderCount(int count) {
    return '$count 个提供商';
  }

  @override
  String get providerSettingsRolesTitle => '模型角色';

  @override
  String get providerSettingsRolesDescription =>
      'WideNote 把提供商凭据和运行时角色分开，方便后续 Agent Pack 安全路由。';

  @override
  String get providerSettingsTextRoleTitle => '默认文本模型';

  @override
  String get providerSettingsTextRoleDescription =>
      '当前用于对话回答和需要模型的内置 Agent Pack。';

  @override
  String get providerSettingsAgentRoleTitle => '按智能体覆盖';

  @override
  String get providerSettingsAgentRoleDescription => '暂未启用。当前所有内置智能体继承默认模型。';

  @override
  String get providerSettingsRoleFallback => '需要配置模型';

  @override
  String get providerSettingsCapabilitiesTitle => '能力与隐私';

  @override
  String get providerSettingsCapabilitiesDescription =>
      '连接测试只在用户主动触发时运行。API Key 保留在本地，只会出现在用户自己导出的备份里。';

  @override
  String get providerSettingsCapabilityChat => '对话';

  @override
  String get providerSettingsCapabilityCompletion => '补全';

  @override
  String get providerSettingsCapabilityOfflineFallback => '本地原始记录';

  @override
  String get providerSettingsCapabilityByok => '自带密钥本地存储';

  @override
  String get providerClearKeyTitle => '清除已保存的 API Key';

  @override
  String get providerClearKeySubtitle => '不勾选且输入框留空时，会继续保留已保存的密钥。';

  @override
  String get providerConnectionUntested => '未测试';

  @override
  String get providerConnectionTesting => '测试中';

  @override
  String get providerConnectionConnected => '已连接';

  @override
  String get providerConnectionFailed => '失败';

  @override
  String get providerActionSetDefault => '设为默认';

  @override
  String get providerActionTestConnection => '测试连接';

  @override
  String get providerActionEdit => '编辑提供商';

  @override
  String get providerActionDelete => '删除提供商';

  @override
  String get providerDeleteTitle => '删除提供商？';

  @override
  String providerDeleteBody(String provider) {
    return '从本地模型设置中移除“$provider”。';
  }

  @override
  String get providerDialogAddTitle => '添加提供商';

  @override
  String get providerDialogEditTitle => '编辑提供商';

  @override
  String get providerFieldProviderType => '提供商类型';

  @override
  String get providerFieldDisplayName => '显示名称';

  @override
  String get providerFieldEndpoint => '端点';

  @override
  String get providerFieldModel => '模型';

  @override
  String get providerFieldApiKey => 'API Key';

  @override
  String get providerApiKeyKeepSessionHelper => '留空会沿用本次会话中的凭据。';

  @override
  String get providerApiKeyOptionalHelper => '这个提供商可不填；只有本地服务要求鉴权时再填写。';

  @override
  String get providerEndpointPresetHelper => '已按官方文档预填；如果账号使用其他地域或网关，可以修改。';

  @override
  String get providerModelPresetHelper => '先从提供商拉取可用模型，再从列表里选择；只有需要时再使用自定义。';

  @override
  String get providerFetchModelsTooltip => '获取可用模型';

  @override
  String get providerModelCustomOption => '自定义模型 ID';

  @override
  String get providerModelCustomHelper => '当提供商没有返回你要用的模型时使用。';

  @override
  String get providerModelFetchRequiresApiKey => '请先填写 API Key，再获取这个提供商的模型列表。';

  @override
  String get providerModelFetchEmpty => '没有返回可用模型。可以保留当前模型，或输入自定义 ID。';

  @override
  String get providerModelFetchFailed => '无法获取模型列表。请检查端点、密钥和网络。';

  @override
  String get providerModelFetchAuthenticationFailed =>
      '获取模型列表鉴权失败。请检查 API Key 和账号权限。';

  @override
  String get providerModelFetchRateLimited => '获取模型列表被限流，请稍后再试。';

  @override
  String get providerModelFetchTimedOut => '获取模型列表超时。请检查端点和网络。';

  @override
  String get providerModelFetchServerFailed => '提供商在获取模型列表时返回了服务端错误。';

  @override
  String get providerInvalidEndpoint => '端点不是有效的 URI。';

  @override
  String get providerSaveFailed => '提供商无法保存。';

  @override
  String providerConfigInvalid(String details) {
    return '提供商配置无效：$details。';
  }

  @override
  String get providerNotFound => '未找到提供商。';

  @override
  String get providerTestingConnectionMessage => '正在测试连接...';

  @override
  String get providerConnectionUnexpectedFailure => '提供商连接测试意外失败。';

  @override
  String get providerSavedKeyClearedMessage => '已清除保存的 API Key。测试前请先添加新密钥。';

  @override
  String get providerConnectionNotRunMessage => '这些已保存设置还没有运行连接测试。';

  @override
  String providerConnectionValidatedOffline(String provider) {
    return '$provider 已完成离线验证，没有发送真实请求。';
  }

  @override
  String providerConnectionSucceeded(String provider) {
    return '$provider 连接测试已成功。';
  }

  @override
  String providerConnectionIncomplete(String provider, String details) {
    return '$provider 配置不完整：$details。';
  }

  @override
  String providerConnectionUnsupportedProbe(String provider) {
    return '$provider 无法用当前能力集合运行对话连接探测。';
  }

  @override
  String providerConnectionProviderUnexpectedFailure(String provider) {
    return '$provider 连接测试意外失败。';
  }

  @override
  String get voiceSettingsTitle => '语音转写';

  @override
  String get voiceSettingsSubtitle => '原始音频本地保存，记录默认使用转写文本，校正证据继续保留来源引用。';

  @override
  String voiceSettingsLoadFailed(String details) {
    return '语音转写设置加载失败：$details';
  }

  @override
  String get voiceSettingsSaved => '语音转写设置已保存。';

  @override
  String get voiceSettingsStatusTitle => '状态';

  @override
  String get voiceSettingsEngineTitle => '转写引擎';

  @override
  String get voiceSettingsEngineDescription => '为新的转写任务选择唯一一条 ASR 路径。';

  @override
  String get voiceSettingsEngineLocal => '本地 SenseVoice';

  @override
  String get voiceSettingsEngineMimo => 'MiMo ASR';

  @override
  String get voiceSettingsEngineDisabled => '关闭';

  @override
  String get voiceSettingsLocalModelTitle => '本地模型';

  @override
  String get voiceSettingsLocalModelManageTitle => '本地 ASR 模型';

  @override
  String get voiceSettingsLocalModelManageDescription =>
      '下载 SenseVoice 用于离线转写和实时预览。下载会写入临时 .part 目录，中断后可以安全重试。';

  @override
  String voiceSettingsModelProgress(String state, int progress) {
    return '$state · $progress%';
  }

  @override
  String get voiceSettingsModelDownloadButton => '下载本地模型';

  @override
  String get voiceSettingsModelDownloading => '下载中...';

  @override
  String get voiceSettingsModelDeleteButton => '删除本地模型';

  @override
  String get voiceSettingsModelUnavailable => '当前设备无法使用本地模型存储。';

  @override
  String get voiceSettingsModelDownloadReady => '本地 ASR 模型已就绪。';

  @override
  String voiceSettingsModelDownloadFailed(String details) {
    return '本地 ASR 模型下载失败：$details';
  }

  @override
  String get voiceSettingsModelDeleted => '本地 ASR 模型已删除。';

  @override
  String get voiceSettingsRemoteFallbackTitle => '当前引擎';

  @override
  String get voiceSettingsRemoteEnabled => '已启用';

  @override
  String get voiceSettingsRemoteDisabled => '已停用';

  @override
  String get voiceSettingsPreviewTitle => '实时预览';

  @override
  String get voiceSettingsPreviewDescription =>
      '录音时用本地麦克风 PCM 生成预览。预览失败时，WAV 文件仍会保存。';

  @override
  String get voiceSettingsPreviewSwitchTitle => '录音时显示转写预览';

  @override
  String get voiceSettingsPreviewSwitchSubtitle => '保存的 WAV 仍是来源事实。';

  @override
  String get voiceSettingsRemoteTitle => 'MiMo ASR';

  @override
  String get voiceSettingsRemoteDescription =>
      '只有选择 MiMo 引擎或手动用 MiMo 重试时，才会使用配置的 MiMo 兼容端点。';

  @override
  String get voiceSettingsRemoteConsentTitle => '允许 MiMo 音频上传';

  @override
  String get voiceSettingsRemoteConsentSubtitle =>
      '音频上传只用于已选择的 MiMo 引擎和手动 MiMo 重试。';

  @override
  String get voiceSettingsEndpointLabel => '端点';

  @override
  String get voiceSettingsModelLabel => '模型';

  @override
  String get voiceSettingsApiKeyLabel => 'API Key';

  @override
  String get voiceSettingsApiKeyHelper => '保存到本地安全存储。留空会保留已保存的密钥。';

  @override
  String get voiceSettingsCorrectionTitle => '转写校正';

  @override
  String get voiceSettingsCorrectionDescription =>
      '校正 Agent Pack 可以修正名称和术语。它会记录校正证据，但不会直接写入 Memory。';

  @override
  String get voiceSettingsCorrectionModeLabel => '校正模式';

  @override
  String get voiceSettingsCorrectionDisabled => '停用';

  @override
  String get voiceSettingsCorrectionSuggest => '仅建议';

  @override
  String get voiceSettingsCorrectionAutoApply => '高置信自动应用';

  @override
  String get voiceSettingsRetryTitle => '手动重试';

  @override
  String get voiceSettingsRetryDescription => '用 MiMo ASR 路径重试失败或需要复核的转写。';

  @override
  String get voiceSettingsRetryButton => '重试失败转写';

  @override
  String get voiceSettingsRetryRunning => '重试中...';

  @override
  String voiceSettingsRetrySummary(int attempted, int succeeded, int failed) {
    return '$attempted 已尝试 / $succeeded 成功 / $failed 失败';
  }

  @override
  String get voiceSettingsModelStateNotDownloaded => '未下载';

  @override
  String get voiceSettingsModelStateChecking => '检查中';

  @override
  String get voiceSettingsModelStateDownloading => '下载中';

  @override
  String get voiceSettingsModelStateInterrupted => '已中断';

  @override
  String get voiceSettingsModelStateVerifying => '校验中';

  @override
  String get voiceSettingsModelStateReady => '就绪';

  @override
  String get voiceSettingsModelStateFailed => '失败';

  @override
  String get voiceSettingsModelStateCorrupted => '已损坏';

  @override
  String get voiceSettingsModelStateDeleting => '删除中';

  @override
  String get backupTitle => '备份';

  @override
  String get backupSubtitle => '导出和导入本地记录、记忆、卡片、对话、模型提供商、待办和追踪数据。';

  @override
  String get backupIdleStatus => '本地数据会留在这台设备上，直到你创建或导入备份。';

  @override
  String get backupExportReadyStatus => 'WideNote 备份归档已准备好。';

  @override
  String get backupSavedFileStatus => 'WideNote 备份归档已交给你选择的位置。';

  @override
  String get backupImportReadyStatus => '备份文件已载入。确认导入后会替换本地数据。';

  @override
  String get backupImportDoneStatus => '备份已替换本地存储。';

  @override
  String backupFailedStatus(String details) {
    return '备份失败：$details';
  }

  @override
  String get backupInvalidFormat => '备份格式无效。';

  @override
  String get backupUnsupportedVersion => '不支持的备份版本。';

  @override
  String get backupNoSavedFile => '没有找到已保存的备份文件。';

  @override
  String get backupLocalConflict => '备份内容与本地数据冲突。';

  @override
  String get backupUnexpectedError => '发生了意外的备份错误。';

  @override
  String get backupExportSectionTitle => '导出与恢复边界';

  @override
  String get backupExportButton => '创建 .widenote 备份';

  @override
  String get backupExportEmpty =>
      '导出会创建一个整目录压缩的 .widenote 归档，可以交给其他 App 打开，也可以保存到你选择的位置。';

  @override
  String get backupSecretWarning =>
      '完整备份会包含模型提供商和 allowlist 安全存储 Key；非正式构建还可能包含诊断日志，请只保存到可信位置。';

  @override
  String get backupRestoreBoundary =>
      '.widenote 归档会恢复 SQLite 快照、采集媒体文件、Provider Key 和 allowlist 应用设置。';

  @override
  String get backupOwnerExportBoundary =>
      '备份是压缩目录，不再把 JSON 或 Markdown 文档作为恢复源。';

  @override
  String get backupFullSecretBoundary =>
      '完整 .widenote 备份会包含 Provider、AMap 和 MiMo ASR Key；非正式构建还会附带恢复时忽略的支持诊断。';

  @override
  String backupLegacyProviderCredentialReentryCount(int count) {
    return '需要重新填写的 Provider Key 数：$count';
  }

  @override
  String get backupManifestCountsTitle => '备份计数';

  @override
  String backupCount(String section, int count) {
    return '$section：$count';
  }

  @override
  String get backupCopyMarkdownButton => '复制导出';

  @override
  String get backupOpenShareFileButton => '打开或分享 .widenote';

  @override
  String get backupSaveFilesButton => '保存到选择的位置';

  @override
  String get backupSavedArchivePath => 'WideNote 备份';

  @override
  String get backupExportDestination => '目标位置';

  @override
  String get backupCopiedStatus => '导出内容已复制。';

  @override
  String get backupExportMarkdownTitle => '可读导出';

  @override
  String get backupImportSectionTitle => '导入';

  @override
  String get backupImportHint => '选择 .widenote 文件。WideNote 会先检查备份，再替换本地数据。';

  @override
  String get backupImportButton => '用所选备份替换';

  @override
  String get backupImportFileButton => '选择 .widenote 文件';

  @override
  String get backupImportReadyInline => '备份已载入，可以确认后替换本地数据。';

  @override
  String get backupImportSourcePath => '导入来源';

  @override
  String get backupConfirmReplaceTitle => '替换本地数据？';

  @override
  String get backupConfirmReplaceBody =>
      '这次导入会用备份内容全量替换本地记录、记忆、待办、对话、模型提供商元数据、Pack、权限、运行时状态和追踪。确认这是你要恢复的文件后再继续。';

  @override
  String get backupConfirmReplaceCancel => '取消';

  @override
  String get backupConfirmReplaceAction => '替换并导入';

  @override
  String backupImportNeedsProviderKeys(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '模型提供商元数据已恢复。模型调用前需要重新填写 $count 个 Provider Key。',
      one: '模型提供商元数据已恢复。模型调用前需要重新填写 1 个 Provider Key。',
    );
    return '$_temp0';
  }

  @override
  String get backupImportSecretsRestored => '模型提供商凭据已恢复，可直接使用。';

  @override
  String get backupImportNoProviderKeysNeeded => '这个备份不需要重新填写 Provider Key。';

  @override
  String get settingsLocationTitle => '位置上下文';

  @override
  String get settingsLocationSubtitle => '为记录保存本地 GPS，并可单独启用高德地址解析。';

  @override
  String get settingsLocationStatusOff => '未启用';

  @override
  String get settingsLocationStatusGps => '仅 GPS';

  @override
  String get settingsLocationStatusAmap => 'GPS + 高德';

  @override
  String get locationSettingsTitle => '位置上下文';

  @override
  String get locationSettingsSubtitle =>
      '选择 WideNote 在本地保存什么，以及什么时候可以把坐标发送给高德。';

  @override
  String get locationPrivacyTitle => '隐私边界';

  @override
  String get locationPrivacyLocalTitle => '本地 GPS';

  @override
  String get locationPrivacyLocalBody =>
      '启用后，WideNote 只会在保存记录时请求前台定位，并把坐标保存到这条本地记录上。';

  @override
  String get locationPrivacyAmapTitle => '高德逆地理编码';

  @override
  String get locationPrivacyAmapBody =>
      '高德地址解析需要单独授权。启用后，记录坐标会发送到高德 Web 服务，用来返回地址摘要。';

  @override
  String get locationStatusGpsOn => 'GPS 采集已开';

  @override
  String get locationStatusGpsOff => 'GPS 采集已关';

  @override
  String get locationStatusAmapOn => '高德解析已开';

  @override
  String get locationStatusAmapOff => '高德解析已关';

  @override
  String get locationCaptureTitle => '记录位置';

  @override
  String get locationSaveGpsTitle => '新记录保存 GPS';

  @override
  String get locationSaveGpsBody => '只在本地记录上保存 WGS-84 纬度、经度、精度、来源和采集时间。';

  @override
  String get locationAmapTitle => '地址解析';

  @override
  String get locationAmapSwitchTitle => '使用高德逆地理编码';

  @override
  String get locationAmapSwitchBody => '把记录坐标发送给高德 Web 服务，并把返回地址作为派生上下文保存。';

  @override
  String get locationAmapKeyLabel => '高德 Web 服务 Key';

  @override
  String get locationAmapKeyHelper =>
      '保存到本地安全存储；不会进入 .widenote 备份或 Owner Export。';

  @override
  String get locationGranularityTitle => '展示粒度';

  @override
  String get locationGranularityBody => '列表和状态默认使用较粗粒度展示，降低旁人看到精确位置的风险。';

  @override
  String get locationGranularityLabel => '默认展示';

  @override
  String get locationGranularityCity => '城市';

  @override
  String get locationGranularityDistrict => '区县';

  @override
  String get locationGranularityNeighborhood => '社区';

  @override
  String get locationGranularityStreet => '街道';

  @override
  String get locationGranularityFull => '完整地址';

  @override
  String get locationTestTitle => '当前状态';

  @override
  String get locationTestBody => '按当前设置运行一次前台定位测试；预览会保持粗粒度。';

  @override
  String get locationTestAction => '测试定位';

  @override
  String get locationTestRunning => '测试中...';

  @override
  String get locationMaintenanceTitle => '已保存位置';

  @override
  String get locationMaintenanceBody => '关闭功能只会停止未来采集；可以清除已有记录里的位置元数据。';

  @override
  String get locationClearSavedAction => '清除已保存位置';

  @override
  String get locationClearConfirmTitle => '清除已保存位置？';

  @override
  String get locationClearConfirmBody => '这会移除已有本地记录中的位置元数据，记录正文和附件不会改变。';

  @override
  String get locationClearConfirmAction => '清除';

  @override
  String locationClearSavedResult(int count) {
    return '已从 $count 条记录清除位置元数据。';
  }

  @override
  String get locationStatusAvailable => '已获取位置。';

  @override
  String locationStatusSummary(String summary) {
    return '区域：$summary';
  }

  @override
  String get locationStatusCoordinatesSaved => 'GPS 坐标已保存到本地记录。';

  @override
  String get locationStatusDisabled => '位置采集未启用。';

  @override
  String get locationStatusServiceDisabled => '设备定位服务已关闭。';

  @override
  String get locationStatusPermissionDenied => '定位权限被拒绝。';

  @override
  String get locationStatusPermissionDeniedForever => '定位权限已在系统设置中被阻止。';

  @override
  String get locationStatusTimeout => '定位超时。';

  @override
  String get locationStatusAmapKeyMissing => '缺少高德 Key；仍可保存 GPS。';

  @override
  String get locationStatusAmapDisabled => '高德解析未启用。';

  @override
  String get locationStatusAmapTimeout => '高德解析超时；仍可保存 GPS。';

  @override
  String get locationStatusUnavailable => '位置不可用。';

  @override
  String locationRecordSummary(String summary) {
    return '位置：$summary';
  }

  @override
  String get locationRecordCoordinatesSaved => 'GPS 已保存';

  @override
  String get locationRecordUnavailable => '位置不可用';
}
