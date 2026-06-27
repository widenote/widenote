const captureMemoryPromptRef = 'capture.memory_candidate.v2';
const pkmProfilePromptRef = 'pkm.profile_entry.v1';

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
    '- Return exactly one JSON object and nothing else.',
    '- Do not wrap the JSON in Markdown, code fences, bullets, headings, or commentary.',
    '- Shape: {"text":"...","memory_type":"task_context","confidence":"high","sensitivity":"low","durability":"durable"}',
    '- The JSON object must be complete and closed. Prefer a shorter text value over risking truncated JSON.',
    '- text: use the capture language when it is clear; keep it to one sentence and under 120 characters when possible.',
    '- memory_type must be one of: preference, project, task_context, person, health, finance, location, credential, insight.',
    '- confidence must be one of: high, medium, low.',
    '- sensitivity must be one of: low, medium, high.',
    '- durability must be one of: durable, transient.',
    '- For ordinary explicit work, project, preference, or task context, use low sensitivity and high or medium confidence.',
    '- For health, finance, location, credential-like, sensitive, ambiguous, or weakly evidenced content, choose the matching type, sensitivity, and confidence so WideNote can route it to review.',
    '',
    'Source event id: $sourceEventId',
    captureMemoryPromptCaptureTextMarker,
    captureText,
  ].join('\n');
}

String buildPkmProfilePrompt({
  required String text,
  required String sourceEventId,
}) {
  final captureText = text.trim().isEmpty ? '(empty capture)' : text.trim();
  return <String>[
    'You are the WideNote PKM Personal Library Agent.',
    '',
    'Task:',
    '- Project one raw, local-first capture into a compact personal knowledge base entry.',
    '- Treat the raw capture as source truth. Do not invent facts, infer hidden intent, or update any canonical profile.',
    '- Preserve useful people, projects, preferences, routines, resources, and decisions when explicit.',
    '- Do not copy API keys, credentials, private tokens, or passwords verbatim. If secret-like material appears, mark sensitivity high and summarize safely.',
    '- This output is a derived artifact, not accepted Memory and not a replacement for the raw capture.',
    '',
    'Output:',
    '- Return exactly one JSON object and nothing else.',
    '- Do not wrap the JSON in Markdown, code fences, bullets, headings, or commentary.',
    '- Shape: {"title":"...","summary":"...","topics":["..."],"people":["..."],"projects":["..."],"source_excerpt":"...","confidence":"medium","sensitivity":"low"}',
    '- The JSON object must be complete and closed.',
    '- title: short label under 48 characters.',
    '- summary: one or two sentences, under 220 characters.',
    '- topics, people, projects: arrays of explicit source-backed labels; use [] when absent.',
    '- source_excerpt: short quote or paraphrase from the capture, without secrets.',
    '- confidence must be one of: high, medium, low.',
    '- sensitivity must be one of: low, medium, high.',
    '',
    'Source event id: $sourceEventId',
    captureMemoryPromptCaptureTextMarker,
    captureText,
  ].join('\n');
}
