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
  String get tabHome => '首页/记录';

  @override
  String get tabChat => '对话';

  @override
  String get tabTodos => '待办';

  @override
  String get tabPlugins => '插件';

  @override
  String get homeSubtitle => '快速记录 -> 时间线 -> 记忆 -> 洞察';

  @override
  String get homeOpenTimelineTooltip => '打开时间线';

  @override
  String get homeSearchTooltip => '搜索';

  @override
  String get homeOpenMemoryTooltip => '打开记忆';

  @override
  String get homeOpenDailyRecapTooltip => '打开每日回顾';

  @override
  String get homeOpenSettingsTooltip => '打开设置';

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
  String get captureEmptyMessage => '先输入文字或添加一个附件，再保存记录。';

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
  String get memorySearchHint => '搜索记忆正文、类型、状态或来源...';

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
  String get memoryAutoSavedTitle => 'Memory 自动入库';

  @override
  String get memoryNeedsReviewTitle => 'Memory 待复核';

  @override
  String get memorySavedTitle => 'Memory 已入库';

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
  String todoSourceLabel(String sourceId) {
    return '来源：$sourceId';
  }

  @override
  String get todoStatusNeedsExplicitPermission => '需要显式授权';

  @override
  String get todoStatusSuggestedByAgent => '智能体建议';

  @override
  String get todoStatusOpen => '未完成';

  @override
  String get todoStatusCompleted => '已完成';

  @override
  String get todoActionComplete => '完成';

  @override
  String get todoActionReopen => '重新打开';

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
  String get chatEmptySessions => '还没有本地会话。';

  @override
  String get chatSessionSwitchDisabled => '当前回答完成后才能切换会话。';

  @override
  String get chatLocalConversationTitle => '本地对话';

  @override
  String get chatEmptyConversation => '先问一个关于记录、Memory 或待办的问题。';

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
  String get chatComposerHint => '问问本地记录、Memory 或待办...';

  @override
  String get chatSendButton => '发送';

  @override
  String get chatGeneratingButton => '生成中';

  @override
  String get chatAssistantEmptyReply =>
      '我还没有可引用的本地记录。先记录一些内容后，我会基于 Memory、记录和待办回答。';

  @override
  String chatAssistantContextReply(int count, String lead, String sources) {
    return '我基于 $count 条本地上下文回答。$lead\n\n$sources';
  }

  @override
  String chatAssistantLeadTodo(String excerpt) {
    return '最相关的是一个待办：$excerpt';
  }

  @override
  String chatAssistantLeadMemory(String excerpt) {
    return '最相关的是一条 Memory：$excerpt';
  }

  @override
  String chatAssistantLeadCapture(String excerpt) {
    return '最相关的是一条原始记录：$excerpt';
  }

  @override
  String chatAssistantLeadGeneric(String excerpt) {
    return '最相关的是：$excerpt';
  }

  @override
  String get chatContextMemoryTitle => 'Memory';

  @override
  String get chatContextRecordTitle => '记录';

  @override
  String get chatContextTodoTitle => '待办';

  @override
  String get chatContextUntitledCapture => '未命名本地记录';

  @override
  String get chatContextUntitledTodo => '未命名待办建议';

  @override
  String get todosTitle => '待办';

  @override
  String get todosSubtitle => '带有记录来源的可溯源行动项。';

  @override
  String get todosSurfaceTitle => '来源关联待办';

  @override
  String get todosEmpty => '还没有来源关联待办。';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSubtitle => '隐私、权限、模型、备份和追踪。';

  @override
  String get settingsBackTooltip => '关闭设置';

  @override
  String get settingsPrivacyTitle => '隐私';

  @override
  String get settingsPrivacyLocalFirstTitle => '本地优先核心';

  @override
  String get settingsPrivacyLocalFirstBody =>
      '记录、Memory、待办、卡片、对话和追踪会留在这台设备上，除非你主动选择备份、同步或模型提供商。';

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
      '安全导出不会包含模型提供商 API Key。加密完整备份是未来含密钥恢复路径，本版本不提供操作入口。';

  @override
  String get settingsPrivacyBackupStatus => '安全导出';

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
  String get settingsModelProvidersTitle => '模型提供商';

  @override
  String get settingsModelProvidersSubtitle =>
      '为运行时和 Agent Pack 配置本地或自带密钥的模型访问。';

  @override
  String get settingsBackupTitle => '备份与恢复';

  @override
  String get settingsBackupSubtitle => '导出或导入本地记录、Memory、卡片、模型提供商、待办和追踪。';

  @override
  String get settingsBackupStatus => '本地';

  @override
  String get settingsBackupStatusSafeOnly => '仅安全备份';

  @override
  String get settingsBackupStatusExportReady => '可导出';

  @override
  String get settingsBackupStatusRestored => '已恢复';

  @override
  String get settingsBackupStatusNeedsReview => '需检查';

  @override
  String get settingsTraceConsoleTitle => '追踪控制台';

  @override
  String get settingsTraceConsoleSubtitle => '检查本地 Agent Runtime 运行、权限检查和生成输出。';

  @override
  String get settingsTraceConsoleStatus => '只读';

  @override
  String settingsTraceConsoleStatusSummary(int eventCount, int warningCount) {
    return '$eventCount 事件 / $warningCount 警告';
  }

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
  String get pluginsTraceConsoleTitle => '追踪控制台';

  @override
  String get pluginsTraceConsoleSubtitle => '检查插件运行、权限和生成结果。';

  @override
  String get pluginsTraceConsoleStatus => '追踪就绪';

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
  String get agentPlatformTitle => '智能体观测';

  @override
  String get agentPlatformSubtitle => '基于真实本地追踪事件的只读运行证据。';

  @override
  String get traceConsoleTitle => '追踪控制台';

  @override
  String get traceConsoleSubtitle => '检查本地 Agent Runtime 运行、权限和生成输出。';

  @override
  String get traceConsoleSummaryTitle => '运行摘要';

  @override
  String traceConsoleEventCount(int count) {
    return '追踪事件：$count';
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
  String get traceConsoleOpenButton => '打开追踪控制台';

  @override
  String get traceConsoleEventsTitle => '事件';

  @override
  String get traceConsoleEmpty => '还没有运行追踪。记录或插件运行后会显示在这里。';

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
  String get providerSettingsStatusNotConfigured => '离线兜底已启用';

  @override
  String get providerSettingsStatusDescriptionConfigured =>
      '当前切片中，捕获、对话和内置 Agent Pack 默认使用这个模型；后续角色覆盖会在这里接入。';

  @override
  String get providerSettingsStatusDescriptionOffline =>
      '核心记录仍可用本地确定性摘要离线运行。需要真实模型调用时，再添加自带密钥的提供商。';

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
      '当前用于捕获摘要、对话回答、Memory 提取和内置 Agent Pack。';

  @override
  String get providerSettingsAgentRoleTitle => '按智能体覆盖';

  @override
  String get providerSettingsAgentRoleDescription => '暂未启用。当前所有内置智能体继承默认模型。';

  @override
  String get providerSettingsRoleFallback => '本地确定性兜底';

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
  String get providerSettingsCapabilityOfflineFallback => '离线兜底';

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
  String get providerInvalidEndpoint => '端点不是有效的 URI。';

  @override
  String get providerSaveFailed => '提供商无法保存。';

  @override
  String get backupTitle => '备份';

  @override
  String get backupSubtitle => '导出和导入本地记录、Memory、卡片、对话、模型提供商、待办和追踪数据。';

  @override
  String get backupIdleStatus => '本地数据会留在这台设备上，直到你导出或粘贴备份。';

  @override
  String get backupExportReadyStatus => '安全备份 JSON 已准备好。';

  @override
  String get backupSavedFileStatus => '备份文件已保存到本地。';

  @override
  String get backupImportDoneStatus => '备份已导入本地存储。';

  @override
  String backupFailedStatus(String details) {
    return '备份失败：$details';
  }

  @override
  String get backupExportSectionTitle => '导出与恢复边界';

  @override
  String get backupExportButton => '导出安全恢复 JSON';

  @override
  String get backupExportEmpty =>
      '导出会创建带 manifest 计数的安全恢复 JSON，以及可读的 Owner Export Markdown 投影。';

  @override
  String get backupSecretWarning => '安全导出不会包含模型提供商 API Key，恢复后需要重新填写。';

  @override
  String get backupSafeRestoreBoundary =>
      '安全恢复 JSON 会恢复记录、Memory、待办、模型提供商元数据、Pack 安装、权限、运行时状态和追踪，但不包含 Provider Key。';

  @override
  String get backupOwnerExportBoundary =>
      'Owner Export Markdown 用来阅读和搬走你的数据；它不含密钥，也不是恢复源。';

  @override
  String get backupFullSecretBoundary =>
      '加密完整备份会是恢复 API Key 的含密钥路径；当前版本不提供操作入口。';

  @override
  String backupSafeOmittedProviderKeys(int count) {
    return '安全导出省略的 Provider Key 数：$count';
  }

  @override
  String get backupManifestCountsTitle => 'Manifest 计数';

  @override
  String backupCount(String section, int count) {
    return '$section：$count';
  }

  @override
  String get backupCopyJsonButton => '复制 JSON';

  @override
  String get backupCopyMarkdownButton => '复制 Markdown';

  @override
  String get backupSaveFilesButton => '保存文件';

  @override
  String get backupSavedJsonPath => 'JSON 文件';

  @override
  String get backupSavedMarkdownPath => 'Markdown 文件';

  @override
  String get backupCopiedStatus => '导出内容已复制。';

  @override
  String get backupExportJsonTitle => '安全备份 JSON';

  @override
  String get backupExportMarkdownTitle => 'Owner Export Markdown';

  @override
  String get backupImportSectionTitle => '导入';

  @override
  String get backupImportHint => '粘贴 WideNote 本地备份 JSON...';

  @override
  String get backupImportButton => '导入备份';

  @override
  String get backupImportLatestFileButton => '导入最近保存的文件';

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
  String get backupImportSecretsRestored => '含密钥备份已恢复模型提供商凭据。';

  @override
  String get backupImportNoProviderKeysNeeded => '这个备份不需要重新填写 Provider Key。';
}
