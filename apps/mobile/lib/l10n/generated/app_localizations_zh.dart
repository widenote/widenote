// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'WideNote / 广记';

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
  String get quickCaptureTitle => '快速记录';

  @override
  String get quickCaptureHint => '写下一个想法、会议记录、承诺，或一段原始记忆...';

  @override
  String get captureModeText => '文字';

  @override
  String get captureModeVoice => '语音草稿';

  @override
  String get captureModeImport => '导入';

  @override
  String get captureModeTextTitle => '先记录下来';

  @override
  String get captureModeTextBody => '默认保持低摩擦本地记录。原始记录保存后，智能体再进行整理。';

  @override
  String get captureVoiceHint => '给语音草稿补充背景，转写内容需要复核后再保存...';

  @override
  String get captureVoiceDraftTitle => '语音草稿';

  @override
  String get captureVoiceDraftBody => '当前切片只使用转写草稿适配器，不会请求麦克风权限；复核后再保存。';

  @override
  String get captureVoiceDraftButton => '添加语音草稿';

  @override
  String get captureImportHint => '为导入的照片、链接或文件补充背景...';

  @override
  String get captureImportTitle => '导入材料';

  @override
  String get captureImportBody => '附加照片或分享内容，保留原始来源，再交给 WideNote 生成可溯源 Memory。';

  @override
  String get captureImportPhotoButton => '添加照片';

  @override
  String get captureImportShareButton => '导入项目';

  @override
  String get captureActionPhoto => '照片';

  @override
  String get captureActionVoice => '语音';

  @override
  String get captureActionImport => '导入';

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
  String get permissionGateSubtitle => '复核内置插件权限和延期的高风险能力。';

  @override
  String get permissionGateGrantedTitle => '已授予的内置权限';

  @override
  String get permissionGateDeferredTitle => '延期的高风险权限';

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
  String get providerSettingsSubtitle => '为运行时和 Agent Pack 配置本地模型访问。';

  @override
  String get providerSettingsAdd => '添加提供商';

  @override
  String get providerSettingsListTitle => '提供商';

  @override
  String get providerSettingsEmpty => '还没有配置模型提供商。';

  @override
  String get providerSettingsDefaultTag => '默认';

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
  String get backupExportReadyStatus => '备份 JSON 已准备好。';

  @override
  String get backupSavedFileStatus => '备份文件已保存到本地。';

  @override
  String get backupImportDoneStatus => '备份已导入本地存储。';

  @override
  String backupFailedStatus(String details) {
    return '备份失败：$details';
  }

  @override
  String get backupExportSectionTitle => '导出';

  @override
  String get backupExportButton => '导出 JSON';

  @override
  String get backupExportEmpty => '导出会创建带 manifest 计数的版本化本地备份 JSON。';

  @override
  String get backupSecretWarning => '备份会包含模型提供商 API Key。请妥善保管导出的 JSON。';

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
  String get backupExportJsonTitle => '备份 JSON';

  @override
  String get backupExportMarkdownTitle => '可读 Markdown';

  @override
  String get backupImportSectionTitle => '导入';

  @override
  String get backupImportHint => '粘贴 WideNote 本地备份 JSON...';

  @override
  String get backupImportButton => '导入备份';

  @override
  String get backupImportLatestFileButton => '导入最近保存的文件';
}
