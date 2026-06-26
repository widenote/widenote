#!/usr/bin/env node

import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";

import { validateManifest, validateManifestPath } from "./validate.mjs";

const baseManifest = Object.freeze({
  id: "pack.test",
  name: "Test Pack",
  version: "0.1.0",
  schema_version: 1,
  publisher: "widenote",
  edition: "local_dev",
  permissions: ["model.complete", "insight.write"],
  subscriptions: [
    {
      id: "sub.capture",
      event_types: ["wn.capture.created"],
      agent_id: "agent.capture",
    },
  ],
  agents: [
    {
      id: "agent.capture",
      runtime: "native",
      permissions: ["model.complete", "insight.write"],
      output_events: ["wn.insight.created"],
      retry_policy: {
        max_attempts: 2,
      },
    },
  ],
  model_profiles: [
    {
      id: "chat_profile",
      purpose: "Synthetic chat profile.",
      required: false,
      routing_policy: "fixed_provider",
      provider_ref: "provider.fake.synthetic",
      model_ref: "fake-chat",
      required_capabilities: ["chat", "completion"],
      allow_fallback: true,
    },
  ],
  tools: [],
});

assert.deepEqual(validateManifest(clone(baseManifest)), []);

expectError(
  {
    ...clone(baseManifest),
    schema_version: 2,
  },
  "schema_version must be 1",
);

expectError(
  {
    ...clone(baseManifest),
    subscriptions: [
      {
        id: "sub.capture",
        event_types: ["wn.capture.created"],
        agent_id: "agent.capture",
        depends_on: ["sub.missing"],
      },
    ],
  },
  "depends_on references missing subscription: sub.missing",
);

expectError(
  {
    ...clone(baseManifest),
    subscriptions: [
      {
        id: "sub.first",
        event_types: ["wn.capture.created"],
        agent_id: "agent.capture",
        depends_on: ["sub.second"],
      },
      {
        id: "sub.second",
        event_types: ["wn.capture.created"],
        agent_id: "agent.capture",
        depends_on: ["sub.first"],
      },
    ],
  },
  "subscriptions.depends_on contains a cycle",
);

expectError(
  {
    ...clone(baseManifest),
    agents: [
      {
        ...clone(baseManifest).agents[0],
        retry_policy: {
          max_attempts: 0,
        },
      },
    ],
  },
  "retry_policy.max_attempts must be between 1 and 5",
);

expectError(
  {
    ...clone(baseManifest),
    agents: [
      {
        ...clone(baseManifest).agents[0],
        runtime: "script",
      },
    ],
  },
  "runtime script is deferred",
);

expectError(
  {
    ...clone(baseManifest),
    tools: [
      {
        id: "tool.unsafe",
        permissions: ["tool.run_script"],
        side_effect: "script_execution",
      },
    ],
  },
  "side_effect script_execution is deferred",
);

expectError(
  {
    ...clone(baseManifest),
    agents: [
      {
        ...clone(baseManifest).agents[0],
        model_profile_ref: "missing_profile",
      },
    ],
  },
  "model_profile_ref references missing model profile: missing_profile",
);

expectError(
  {
    ...clone(baseManifest),
    model_profiles: [
      {
        id: "chat_profile",
        purpose: "Synthetic chat profile.",
        routing_policy: "unsafe_remote_choice",
      },
    ],
  },
  "routing_policy must be one of",
);

expectError(
  {
    ...clone(baseManifest),
    tools: [
      {
        id: "tool.memory",
        permissions: ["memory.read"],
      },
    ],
  },
  "tools[0].permissions contains permission not declared by pack: memory.read",
);

const officialManifestPaths = [
  "../../packs/official/default/manifest.json",
  "../../packs/official/todo/manifest.json",
].map((path) => fileURLToPath(new URL(path, import.meta.url)));

for (const manifestPath of officialManifestPaths) {
  assert.deepEqual(validateManifestPath(manifestPath), []);
}

console.log("tools/pack_validator/validate_test.mjs: ok");

function expectError(manifest, expected) {
  const errors = validateManifest(manifest);
  assert(
    errors.some((error) => error.includes(expected)),
    `Expected error containing "${expected}", got: ${errors.join("; ")}`,
  );
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}
