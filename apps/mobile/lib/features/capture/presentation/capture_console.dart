import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../application/capture_input_controller.dart';
import '../media/capture_media.dart';

class CaptureConsole extends StatelessWidget {
  const CaptureConsole({
    required this.controller,
    required this.onSubmit,
    required this.onModeChanged,
    required this.onAddPhoto,
    required this.onAddVoice,
    required this.onAddShare,
    required this.onRemoveAttachment,
    required this.onAcceptAttachmentReview,
    required this.isProcessing,
    required this.inputState,
    super.key,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final ValueChanged<CaptureMode> onModeChanged;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddVoice;
  final VoidCallback onAddShare;
  final ValueChanged<String> onRemoveAttachment;
  final ValueChanged<String> onAcceptAttachmentReview;
  final bool isProcessing;
  final CaptureInputState inputState;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final inputBusy = inputState.isBusy || isProcessing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD3DAE6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ConsoleHeader(title: l10n.quickCaptureTitle),
            const SizedBox(height: 14),
            _ModeSelector(
              selected: inputState.mode,
              enabled: !inputBusy,
              onChanged: onModeChanged,
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('quick-capture-field'),
              controller: controller,
              enabled: !inputBusy,
              minLines: 3,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: _hintForMode(l10n, inputState.mode),
              ),
            ),
            const SizedBox(height: 12),
            _ModePanel(
              mode: inputState.mode,
              inputBusy: inputBusy,
              onAddVoice: onAddVoice,
              onAddPhoto: onAddPhoto,
              onAddShare: onAddShare,
            ),
            const SizedBox(height: 12),
            _ConsoleActions(
              inputBusy: inputBusy,
              isProcessing: isProcessing,
              onAddPhoto: onAddPhoto,
              onAddVoice: onAddVoice,
              onAddShare: onAddShare,
              onSubmit: onSubmit,
            ),
            if (inputState.errorMessage != null) ...[
              const SizedBox(height: 8),
              _CaptureErrorLine(text: inputState.errorMessage!),
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
  const _ConsoleHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
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
          child: Icon(Icons.bolt_outlined, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ModeSelector extends StatelessWidget {
  const _ModeSelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final CaptureMode selected;
  final bool enabled;
  final ValueChanged<CaptureMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<CaptureMode>(
      key: const Key('capture-mode-selector'),
      showSelectedIcon: false,
      segments: [
        ButtonSegment<CaptureMode>(
          value: CaptureMode.text,
          icon: const Icon(Icons.notes_outlined),
          label: Text(l10n.captureModeText),
        ),
        ButtonSegment<CaptureMode>(
          value: CaptureMode.voice,
          icon: const Icon(Icons.graphic_eq_outlined),
          label: Text(l10n.captureModeVoice),
        ),
        ButtonSegment<CaptureMode>(
          value: CaptureMode.import,
          icon: const Icon(Icons.file_upload_outlined),
          label: Text(l10n.captureModeImport),
        ),
      ],
      selected: {selected},
      onSelectionChanged: enabled
          ? (selection) => onChanged(selection.single)
          : null,
    );
  }
}

class _ModePanel extends StatelessWidget {
  const _ModePanel({
    required this.mode,
    required this.inputBusy,
    required this.onAddVoice,
    required this.onAddPhoto,
    required this.onAddShare,
  });

  final CaptureMode mode;
  final bool inputBusy;
  final VoidCallback onAddVoice;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddShare;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: switch (mode) {
        CaptureMode.text => _ModeHint(
          key: const Key('capture-mode-text-panel'),
          icon: Icons.edit_note_outlined,
          title: l10n.captureModeTextTitle,
          body: l10n.captureModeTextBody,
        ),
        CaptureMode.voice => _VoiceDraftPanel(
          inputBusy: inputBusy,
          onAddVoice: onAddVoice,
        ),
        CaptureMode.import => _ImportPanel(
          inputBusy: inputBusy,
          onAddPhoto: onAddPhoto,
          onAddShare: onAddShare,
        ),
      },
    );
  }
}

class _ModeHint extends StatelessWidget {
  const _ModeHint({
    required this.icon,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoiceDraftPanel extends StatelessWidget {
  const _VoiceDraftPanel({required this.inputBusy, required this.onAddVoice});

  final bool inputBusy;
  final VoidCallback onAddVoice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ModeHintWithAction(
      key: const Key('capture-mode-voice-panel'),
      icon: Icons.graphic_eq_outlined,
      title: l10n.captureVoiceDraftTitle,
      body: l10n.captureVoiceDraftBody,
      buttonKey: const Key('capture-voice-draft-button'),
      buttonIcon: Icons.playlist_add_check_outlined,
      buttonLabel: l10n.captureVoiceDraftButton,
      onPressed: inputBusy ? null : onAddVoice,
    );
  }
}

class _ImportPanel extends StatelessWidget {
  const _ImportPanel({
    required this.inputBusy,
    required this.onAddPhoto,
    required this.onAddShare,
  });

  final bool inputBusy;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddShare;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _ModeHintWithAction(
      key: const Key('capture-mode-import-panel'),
      icon: Icons.file_upload_outlined,
      title: l10n.captureImportTitle,
      body: l10n.captureImportBody,
      buttonKey: const Key('capture-import-share-button'),
      buttonIcon: Icons.file_upload_outlined,
      buttonLabel: l10n.captureImportShareButton,
      onPressed: inputBusy ? null : onAddShare,
      secondaryButtonKey: const Key('capture-import-photo-button'),
      secondaryButtonIcon: Icons.add_photo_alternate_outlined,
      secondaryButtonLabel: l10n.captureImportPhotoButton,
      onSecondaryPressed: inputBusy ? null : onAddPhoto,
    );
  }
}

class _ModeHintWithAction extends StatelessWidget {
  const _ModeHintWithAction({
    required this.icon,
    required this.title,
    required this.body,
    required this.buttonKey,
    required this.buttonIcon,
    required this.buttonLabel,
    required this.onPressed,
    this.secondaryButtonKey,
    this.secondaryButtonIcon,
    this.secondaryButtonLabel,
    this.onSecondaryPressed,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Key buttonKey;
  final IconData buttonIcon;
  final String buttonLabel;
  final VoidCallback? onPressed;
  final Key? secondaryButtonKey;
  final IconData? secondaryButtonIcon;
  final String? secondaryButtonLabel;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E7F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: buttonKey,
                  onPressed: onPressed,
                  icon: Icon(buttonIcon),
                  label: Text(buttonLabel),
                ),
                if (secondaryButtonKey != null &&
                    secondaryButtonIcon != null &&
                    secondaryButtonLabel != null)
                  OutlinedButton.icon(
                    key: secondaryButtonKey,
                    onPressed: onSecondaryPressed,
                    icon: Icon(secondaryButtonIcon),
                    label: Text(secondaryButtonLabel!),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsoleActions extends StatelessWidget {
  const _ConsoleActions({
    required this.inputBusy,
    required this.isProcessing,
    required this.onAddPhoto,
    required this.onAddVoice,
    required this.onAddShare,
    required this.onSubmit,
  });

  final bool inputBusy;
  final bool isProcessing;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddVoice;
  final VoidCallback onAddShare;
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
          key: const Key('add-photo-attachment-button'),
          onPressed: inputBusy ? null : onAddPhoto,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(l10n.captureActionPhoto),
        ),
        OutlinedButton.icon(
          key: const Key('add-voice-attachment-button'),
          onPressed: inputBusy ? null : onAddVoice,
          icon: const Icon(Icons.graphic_eq_outlined),
          label: Text(l10n.captureActionVoice),
        ),
        OutlinedButton.icon(
          key: const Key('add-share-import-button'),
          onPressed: inputBusy ? null : onAddShare,
          icon: const Icon(Icons.file_upload_outlined),
          label: Text(l10n.captureActionImport),
        ),
        FilledButton.icon(
          key: const Key('record-capture-button'),
          onPressed: isProcessing ? null : onSubmit,
          icon: const Icon(Icons.fiber_manual_record),
          label: Text(
            isProcessing ? l10n.recordButtonProcessing : l10n.recordButton,
          ),
        ),
      ],
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

String _hintForMode(AppLocalizations l10n, CaptureMode mode) {
  return switch (mode) {
    CaptureMode.text => l10n.quickCaptureHint,
    CaptureMode.voice => l10n.captureVoiceHint,
    CaptureMode.import => l10n.captureImportHint,
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
      reason ?? 'asset safety',
    ),
  };
}
