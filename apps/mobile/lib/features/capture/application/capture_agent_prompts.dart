const captureMemoryPromptRef = 'capture.memory_summary.v1';

const captureMemoryPromptCaptureTextMarker = 'Capture text:';

String buildCaptureMemoryPrompt({
  required String text,
  required String sourceEventId,
}) {
  final captureText = text.trim().isEmpty ? '(empty capture)' : text.trim();
  return <String>[
    'You are the WideNote Capture Loop Agent.',
    '',
    'Task:',
    '- Convert one raw, local-first capture into a concise Memory candidate.',
    '- Preserve explicit names, projects, dates, times, actions, preferences, and source details that matter for recall.',
    '- Treat the raw capture as source truth. Do not invent facts, infer hidden intent, or claim that anything has been saved.',
    '- Do not copy API keys, credentials, private tokens, or passwords verbatim. If the capture contains secret-like material, summarize that sensitive content needs review.',
    '- Keep the output useful as a derived Memory item that can later point back to the source event.',
    '',
    'Output:',
    '- Return only the Memory candidate text.',
    '- Use the capture language when it is clear.',
    '- Keep it to one sentence and under 180 characters when possible.',
    '- Do not output JSON, bullets, citations, headings, or commentary.',
    '',
    'Source event id: $sourceEventId',
    captureMemoryPromptCaptureTextMarker,
    captureText,
  ].join('\n');
}
