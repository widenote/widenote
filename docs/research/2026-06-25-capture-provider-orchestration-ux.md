# Capture, Provider, and Orchestration UX Notes

Date: 2026-06-25

## Context

This note summarizes a product/UX pass over the mobile home capture flow, model
provider settings, and post-capture Agent Runtime orchestration.

Inputs:

- User feedback that the home title should show only the active language.
- User feedback that photo, voice, import, and record interactions felt silent.
- Clean-room review of public `memex-lab/memex` at
  `b1a3d590d589ecba13d92dfd6a5de7445cb891b0`.
- Existing WideNote ADRs and RFCs, especially ADR-0003, ADR-0005, ADR-0006,
  the Memory model RFC, and the Model Provider Settings RFC.

## Clean-Room Memex Reference

The Memex reference was used only for interaction hierarchy, not for code,
schemas, prompts, private APIs, or UI assets.

Useful high-level patterns:

- The AI/model entry starts with a status overview before configuration forms.
- Provider credentials are separated from model-role assignment.
- A default text model is visible as a role, with room for per-agent overrides.
- Capabilities such as speech/location/agent assignment are grouped under the
  model setup surface instead of being hidden inside provider rows.
- Provider rows support add/edit/delete/default/test workflows, but users first
  see what the settings affect.

WideNote keeps its own implementation and terms:

- Local-first BYOK provider config stays in
  `apps/mobile/lib/features/model_providers`.
- Shared provider contracts stay in `packages/dart/model_providers`.
- Per-Agent routing remains deferred; the current role surface explains that
  built-in agents inherit the default provider.

## Current WideNote Post-Capture Chain

WideNote already has the core chain discussed previously:

```text
record button
  -> CaptureController.submitCapture
  -> CaptureOrchestrator.processCapture
  -> RuntimeKernel.publish(wn.capture.created)
  -> pack.default / agent.capture_loop
  -> wn.memory.proposed + wn.card.created + wn.insight.created
  -> MemoryService auto-accept or review
  -> pack.todo / agent.todo_loop
  -> wn.todo.suggested when allowed
  -> LocalDbEventStore + LocalDbTraceSink + LocalDbMemoryRepository
  -> local cards, insights, todos, timeline, trace console
```

The chain is deterministic and local by default. Model failures fall back to a
local summary and route low-confidence Memory to review. Sensitive captures can
skip todo suggestion and route Memory to review.

Current limitation:

- The runtime dispatch is local and immediate in the mobile slice. ADR-0003
  still expects a more explicit durable task queue surface as the runtime grows.

## UX Changes Landed In This Slice

- Home app title uses only the current locale: `WideNote` in English and `广记`
  in Chinese.
- Empty record submission now gives immediate feedback instead of silently
  returning.
- Photo, voice draft, and import actions show immediate confirmation after the
  fake adapter adds an attachment.
- Successful record submission confirms that local agents are organizing the
  record and offers a Timeline action.
- Home cards, insights, records, Memory, and traces are clickable:
  - cards open card detail;
  - records, insights, and Memory open timeline item detail;
  - traces open the trace console.
- Provider settings now show:
  - runtime model access status;
  - model roles and default fallback;
  - capabilities and privacy notes;
  - provider list and existing add/edit/default/test actions.

## Follow-Ups

- Add real camera/gallery, microphone, ASR, share intent, and file import behind
  explicit platform permission and privacy decisions.
- Add durable per-Agent model-role routing once Agent Pack role policy is
  accepted.
- Promote the current immediate runtime dispatch into a visible durable task
  queue when background/scheduled Agent Pack execution starts.
