import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../application/capture_input_controller.dart';
import '../media/capture_media.dart';

class CaptureConsole extends StatelessWidget {
  const CaptureConsole({
    required this.controller,
    required this.onSubmit,
    required this.onAddCamera,
    required this.onAddGallery,
    required this.onRemoveAttachment,
    required this.onAcceptAttachmentReview,
    required this.isProcessing,
    required this.inputState,
    this.onClose,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onAddCamera;
  final VoidCallback onAddGallery;
  final ValueChanged<String> onRemoveAttachment;
  final ValueChanged<String> onAcceptAttachmentReview;
  final bool isProcessing;
  final CaptureInputState inputState;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final inputBusy = inputState.isBusy || isProcessing;
    return DecoratedBox(
      key: const Key('capture-sheet'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD3DAE6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x24000000),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ConsoleHeader(onClose: onClose),
            const SizedBox(height: 14),
            TextField(
              key: const Key('quick-capture-field'),
              controller: controller,
              enabled: !inputBusy,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              autocorrect: true,
              enableSuggestions: true,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              minLines: 7,
              maxLines: 12,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(hintText: context.l10n.newRecordHint),
            ),
            if (inputState.isRecordingVoice) ...[
              const SizedBox(height: 12),
              const _RecordingInProgressLine(),
            ],
            const SizedBox(height: 12),
            _ConsoleActions(
              inputBusy: inputBusy,
              isProcessing: isProcessing,
              onAddCamera: onAddCamera,
              onAddGallery: onAddGallery,
              onSubmit: onSubmit,
            ),
            if (inputState.errorMessage != null) ...[
              const SizedBox(height: 8),
              _CaptureErrorLine(
                text: localizedCaptureError(
                  context.l10n,
                  inputState.errorMessage!,
                ),
              ),
            ],
            if (inputState.hasAttachments) ...[
              const SizedBox(height: 12),
              _AttachmentPreviewList(
                attachments: inputState.attachments,
                onRemove: onRemoveAttachment,
                onAcceptReview: onAcceptAttachmentReview,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConsoleHeader extends StatelessWidget {
  const _ConsoleHeader({this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.edit_note_outlined, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.newRecordTitle,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.newRecordSubtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (onClose != null)
          IconButton(
            key: const Key('capture-sheet-close-button'),
            tooltip: l10n.cancelButton,
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
      ],
    );
  }
}

class _ConsoleActions extends StatelessWidget {
  const _ConsoleActions({
    required this.inputBusy,
    required this.isProcessing,
    required this.onAddCamera,
    required this.onAddGallery,
    required this.onSubmit,
  });

  final bool inputBusy;
  final bool isProcessing;
  final VoidCallback onAddCamera;
  final VoidCallback onAddGallery;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          key: const Key('add-camera-attachment-button'),
          onPressed: inputBusy ? null : onAddCamera,
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(l10n.captureActionCamera),
        ),
        OutlinedButton.icon(
          key: const Key('add-gallery-attachment-button'),
          onPressed: inputBusy ? null : onAddGallery,
          icon: const Icon(Icons.photo_library_outlined),
          label: Text(l10n.captureActionGallery),
        ),
        FilledButton.icon(
          key: const Key('record-capture-button'),
          onPressed: isProcessing ? null : onSubmit,
          icon: const Icon(Icons.check),
          label: Text(
            isProcessing ? l10n.recordButtonProcessing : l10n.saveRecordButton,
          ),
        ),
      ],
    );
  }
}

class _RecordingInProgressLine extends StatelessWidget {
  const _RecordingInProgressLine();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7F4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF0C4B9)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Icon(Icons.mic_outlined, color: colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.l10n.backgroundVoiceComposerBusy,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentPreviewList extends StatelessWidget {
  const _AttachmentPreviewList({
    required this.attachments,
    required this.onRemove,
    required this.onAcceptReview,
  });

  final List<CaptureAttachment> attachments;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onAcceptReview;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < attachments.length; index++) ...[
          if (index > 0) const Divider(height: 20),
          _AttachmentPreviewRow(
            attachment: attachments[index],
            onRemove: onRemove,
            onAcceptReview: onAcceptReview,
          ),
        ],
      ],
    );
  }
}

class _AttachmentPreviewRow extends StatelessWidget {
  const _AttachmentPreviewRow({
    required this.attachment,
    required this.onRemove,
    required this.onAcceptReview,
  });

  final CaptureAttachment attachment;
  final ValueChanged<String> onRemove;
  final ValueChanged<String> onAcceptReview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final stateLine = _attachmentStateLine(l10n, attachment);
    return Semantics(
      key: Key('attachment-row-${attachment.id}'),
      container: true,
      explicitChildNodes: true,
      label: '${attachment.displayName}. $stateLine',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_attachmentIcon(attachment.kind), color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  stateLine,
                  key: Key('attachment-state-${attachment.id}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (attachment.state == CaptureAttachmentState.needsReview)
                      TextButton.icon(
                        key: Key('review-attachment-${attachment.id}'),
                        onPressed: () => onAcceptReview(attachment.id),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text(l10n.captureUseTranscriptButton),
                      ),
                    IconButton(
                      key: Key('remove-attachment-${attachment.id}'),
                      onPressed: () => onRemove(attachment.id),
                      tooltip: l10n.captureRemoveAttachmentTooltip,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureErrorLine extends StatelessWidget {
  const _CaptureErrorLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('capture-error-line'),
      container: true,
      liveRegion: true,
      label: text,
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFC94A3A), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFFC94A3A)),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _attachmentIcon(CaptureAssetKind kind) {
  return switch (kind) {
    CaptureAssetKind.photo => Icons.image_outlined,
    CaptureAssetKind.voice => Icons.graphic_eq_outlined,
    CaptureAssetKind.share => Icons.file_upload_outlined,
  };
}

String _attachmentStateLine(
  AppLocalizations l10n,
  CaptureAttachment attachment,
) {
  final reason = attachment.reviewReason;
  return switch (attachment.state) {
    CaptureAttachmentState.ready => l10n.captureAttachmentReady(
      attachment.previewText,
    ),
    CaptureAttachmentState.needsReview => l10n.captureAttachmentNeedsReview(
      attachment.previewText,
    ),
    CaptureAttachmentState.blocked => l10n.captureAttachmentBlocked(
      localizedAttachmentReason(l10n, reason),
    ),
  };
}
