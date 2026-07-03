import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../media/capture_media.dart';

class AttachmentDerivedArtifactList extends StatelessWidget {
  const AttachmentDerivedArtifactList({
    required this.artifacts,
    required this.keyPrefix,
    this.compact = false,
    super.key,
  });

  final List<AttachmentDerivedArtifact> artifacts;
  final String keyPrefix;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (artifacts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < artifacts.length; index++) ...[
          if (index > 0) SizedBox(height: compact ? 4 : 8),
          _ArtifactRow(
            artifact: artifacts[index],
            keyPrefix: keyPrefix,
            compact: compact,
          ),
        ],
      ],
    );
  }
}

class AttachmentDerivedArtifactChips extends StatelessWidget {
  const AttachmentDerivedArtifactChips({
    required this.artifacts,
    required this.keyPrefix,
    super.key,
  });

  final List<AttachmentDerivedArtifact> artifacts;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    if (artifacts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final artifact in artifacts)
          _ArtifactChip(
            key: Key('$keyPrefix-artifact-chip-${_artifactKey(artifact)}'),
            artifact: artifact,
          ),
      ],
    );
  }
}

class _ArtifactRow extends StatelessWidget {
  const _ArtifactRow({
    required this.artifact,
    required this.keyPrefix,
    required this.compact,
  });

  final AttachmentDerivedArtifact artifact;
  final String keyPrefix;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      key: Key('$keyPrefix-artifact-${_artifactKey(artifact)}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _artifactIcon(artifact.status),
          size: compact ? 16 : 18,
          color: _artifactColor(colorScheme, artifact.status),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    localizedAttachmentArtifactKind(
                      l10n,
                      artifact.artifactKind,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  _StatusPill(status: artifact.status),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                localizedSourceLabel(l10n, artifact.sourceLabel),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (artifact.excerpt.trim().isNotEmpty && !compact) ...[
                const SizedBox(height: 2),
                Text(
                  localizedAttachmentArtifactExcerpt(l10n, artifact),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ArtifactChip extends StatelessWidget {
  const _ArtifactChip({required this.artifact, super.key});

  final AttachmentDerivedArtifact artifact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label =
        '${localizedAttachmentArtifactKind(l10n, artifact.artifactKind)} · '
        '${localizedAttachmentArtifactStatus(l10n, artifact.status)}';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_artifactIcon(artifact.status), size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final AttachmentDerivedArtifactStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = _artifactColor(
      colorScheme,
      status,
    ).withValues(alpha: 0.12);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          localizedAttachmentArtifactStatus(context.l10n, status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: _artifactColor(colorScheme, status),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String localizedAttachmentArtifactStatus(
  AppLocalizations l10n,
  AttachmentDerivedArtifactStatus status,
) {
  return switch (status) {
    AttachmentDerivedArtifactStatus.pending =>
      l10n.attachmentArtifactStatusPending,
    AttachmentDerivedArtifactStatus.ready => l10n.attachmentArtifactStatusReady,
    AttachmentDerivedArtifactStatus.failed =>
      l10n.attachmentArtifactStatusFailed,
    AttachmentDerivedArtifactStatus.blocked =>
      l10n.attachmentArtifactStatusBlocked,
    AttachmentDerivedArtifactStatus.needsReview =>
      l10n.attachmentArtifactStatusNeedsReview,
  };
}

String localizedAttachmentArtifactKind(
  AppLocalizations l10n,
  String artifactKind,
) {
  return switch (artifactKind) {
    'audio_transcript' => l10n.attachmentArtifactKindAudioTranscript,
    'image_derivatives' => l10n.attachmentArtifactKindImageDerivatives,
    'ocr_text' => l10n.attachmentArtifactKindOcrText,
    'vision_summary' => l10n.attachmentArtifactKindVisionSummary,
    'shared_text' => l10n.attachmentArtifactKindSharedText,
    _ => artifactKind,
  };
}

String localizedAttachmentArtifactExcerpt(
  AppLocalizations l10n,
  AttachmentDerivedArtifact artifact,
) {
  if (artifact.artifactKind != 'audio_transcript') {
    return artifact.excerpt;
  }
  if (artifact.status == AttachmentDerivedArtifactStatus.pending) {
    return l10n.attachmentArtifactAudioTranscriptPending;
  }
  if (artifact.status == AttachmentDerivedArtifactStatus.failed) {
    final normalized = artifact.excerpt.trim().toLowerCase();
    if (normalized.contains('no speech')) {
      return l10n.attachmentArtifactAudioTranscriptNoSpeech;
    }
    return l10n.attachmentArtifactAudioTranscriptFailed;
  }
  return artifact.excerpt;
}

IconData _artifactIcon(AttachmentDerivedArtifactStatus status) {
  return switch (status) {
    AttachmentDerivedArtifactStatus.pending => Icons.hourglass_empty,
    AttachmentDerivedArtifactStatus.ready => Icons.check_circle_outline,
    AttachmentDerivedArtifactStatus.failed => Icons.error_outline,
    AttachmentDerivedArtifactStatus.blocked => Icons.block,
    AttachmentDerivedArtifactStatus.needsReview => Icons.rate_review_outlined,
  };
}

Color _artifactColor(
  ColorScheme colorScheme,
  AttachmentDerivedArtifactStatus status,
) {
  return switch (status) {
    AttachmentDerivedArtifactStatus.pending => colorScheme.tertiary,
    AttachmentDerivedArtifactStatus.ready => colorScheme.primary,
    AttachmentDerivedArtifactStatus.failed => colorScheme.error,
    AttachmentDerivedArtifactStatus.blocked => colorScheme.error,
    AttachmentDerivedArtifactStatus.needsReview => colorScheme.secondary,
  };
}

String _artifactKey(AttachmentDerivedArtifact artifact) {
  return (artifact.id ?? artifact.artifactKind).replaceAll(
    RegExp(r'[^a-zA-Z0-9._-]+'),
    '_',
  );
}
