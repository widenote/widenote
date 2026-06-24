#!/usr/bin/env node

import assert from "node:assert/strict";

import { validateManifest } from "./validate.mjs";

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
  tools: [],
});

assert.deepEqual(validateManifest(clone(baseManifest)), []);

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
