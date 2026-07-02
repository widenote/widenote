const captureMemoryPromptRef = 'capture.memory_candidate.v2';
const todoSuggestionPromptRef = 'todo.suggestion.v1';
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

String buildTodoSuggestionPrompt({
  required String text,
  required String sourceEventId,
}) {
  final captureText = text.trim().isEmpty ? '(empty capture)' : text.trim();
  return <String>[
    'You are the WideNote Todo Loop Agent.',
    '',
    'Task:',
    '- Decide whether one raw, local-first capture should become an action item, a schedule candidate, or no todo suggestion.',
    '- Use semantic judgment from the full capture, not keyword matching.',
    '- Treat ordinary diary, status, observation, idea, or product-note captures as quiet unless the source clearly asks for a future action or scheduled commitment.',
    '- Use action for an explicit task, follow-up, errand, message, review, fix, purchase, cleanup, or other user-actionable commitment without a concrete time cue.',
    '- Use schedule for an explicit action, event, appointment, meeting, reminder, deadline, or commitment with a concrete date, time, or time cue.',
    '- Do not invent actions, dates, people, or urgency. Preserve the source language when possible.',
    '- This output is a derived suggestion only. It does not write Calendar or Reminder data.',
    '',
    'Output:',
    '- Return exactly one JSON object and nothing else.',
    '- Do not wrap the JSON in Markdown, code fences, bullets, headings, or commentary.',
    '- Shape: {"kind":"quiet","title":"","confidence":"high","reason":"ordinary_record","scheduled_at_label":null}',
    '- kind must be one of: action, schedule, quiet.',
    '- title: for action or schedule, a concise user-facing label under 80 characters. For quiet, use an empty string.',
    '- confidence must be one of: high, medium, low.',
    '- reason: short machine-readable explanation such as explicit_action, explicit_schedule, ordinary_record, ambiguous, or insufficient_evidence.',
    '- scheduled_at_label: copy only the explicit date/time/time cue from the source for schedule; otherwise null.',
    '- If unsure whether this is actionable, choose quiet with confidence low or medium.',
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
