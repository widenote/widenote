#!/usr/bin/env node

import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";

import {
  validateDocumentPath,
  validateManifest,
  validateManifestPath,
  validateMarketplaceIndex,
} from "./validate.mjs";

const baseManifest = Object.freeze({
  id: "pack.test",
  name: "Test Pack",
  version: "0.1.0",
  schema_version: 1,
  publisher: "widenote",
  edition: "local_dev",
  default_run_mode: "confirm",
  permissions: ["model.complete", "insight.write", "memory.read"],
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
      run_mode: "confirm",
      permissions: ["model.complete", "insight.write", "memory.read"],
      tools: ["tool.memory.read"],
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
  tools: [
    {
      id: "tool.memory.read",
      capability_kind: "memory",
      permissions: ["memory.read"],
      required_permissions: ["memory.read"],
      access: "read",
      risk: "low",
      locality: "local",
      approval_requirement: "none",
      execution: "local",
      side_effect: "none",
      compatible_run_modes: ["read_only", "confirm", "auto"],
    },
  ],
  marketplace: {
    source: "local_dev",
    trust_level: "local_dev",
    install_mode: "local_file",
    categories: ["test"],
    capabilities: ["memory.read"],
    status: "preview",
  },
  additive_slots: [
    {
      id: "knowledge.organization",
      mode: "additive",
    },
  ],
});

assert.deepEqual(validateManifest(clone(baseManifest)), []);

assert.deepEqual(
  validateManifest({
    ...clone(baseManifest),
    ui_blocks: [
      { type: "claim_list", events: ["wn.insight.created"] },
      { type: "metric_row", events: ["wn.insight.created"] },
      { type: "source_refs", events: ["wn.insight.created"] },
      { type: "note", events: ["wn.insight.created"] },
    ],
  }),
  [],
);

expectError(
  {
    ...clone(baseManifest),
    ui_blocks: [{ type: "webview", events: ["wn.insight.created"] }],
  },
  "ui_blocks[0].type must be one of",
);

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
    agents: [
      {
        ...clone(baseManifest).agents[0],
        tools: ["tool.unsafe"],
      },
    ],
    tools: [
      {
        id: "tool.unsafe",
        permissions: ["tool.run_script"],
        required_permissions: ["tool.run_script"],
        capability_kind: "script",
        access: "write",
        risk: "high",
        locality: "local",
        approval_requirement: "deferred",
        execution: "disabled",
        side_effect: "script_execution",
        compatible_run_modes: ["confirm"],
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
    agents: [
      {
        ...clone(baseManifest).agents[0],
        tools: ["tool.trace"],
      },
    ],
    tools: [
      {
        id: "tool.trace",
        permissions: ["trace.read"],
        required_permissions: ["trace.read"],
        capability_kind: "trace",
        access: "read",
        risk: "low",
        locality: "local",
        approval_requirement: "none",
        execution: "local",
        side_effect: "none",
        compatible_run_modes: ["read_only", "confirm", "auto"],
      },
    ],
  },
  "tools[0].permissions contains permission not declared by pack: trace.read",
);

expectError(
  (() => {
    const manifest = clone(baseManifest);
    delete manifest.tools[0].compatible_run_modes;
    return manifest;
  })(),
  "tools[0].compatible_run_modes is required",
);

expectError(
  {
    ...clone(baseManifest),
    default_run_mode: "auto",
    permissions: ["model.complete", "insight.write", "web.fetch.public"],
    agents: [
      {
        ...clone(baseManifest).agents[0],
        run_mode: "auto",
        permissions: ["model.complete", "insight.write", "web.fetch.public"],
        tools: ["tool.web.fetch"],
      },
    ],
    tools: [
      {
        id: "tool.web.fetch",
        capability_kind: "web",
        permissions: ["web.fetch.public"],
        required_permissions: ["web.fetch.public"],
        access: "read",
        risk: "medium",
        locality: "external",
        approval_requirement: "deferred",
        execution: "deferred",
        side_effect: "network",
        compatible_run_modes: ["confirm"],
      },
    ],
  },
  "run_mode auto cannot use external tool: tool.web.fetch",
);

expectError(
  {
    ...clone(baseManifest),
    permissions: ["model.complete", "insight.write", "web.fetch.public"],
    agents: [
      {
        ...clone(baseManifest).agents[0],
        permissions: ["model.complete", "insight.write", "web.fetch.public"],
        tools: ["tool.http.live"],
      },
    ],
    tools: [
      {
        id: "tool.http.live",
        capability_kind: "http",
        permissions: ["web.fetch.public"],
        required_permissions: ["web.fetch.public"],
        access: "read_write",
        risk: "high",
        locality: "external",
        approval_requirement: "per_call",
        execution: "local",
        side_effect: "network",
        compatible_run_modes: ["confirm"],
      },
    ],
  },
  "execution must be fake, deferred, or disabled",
);

expectError(
  {
    ...clone(baseManifest),
    agents: [
      {
        ...clone(baseManifest).agents[0],
        run_mode: "read_only",
        tools: ["tool.memory.write"],
      },
    ],
    tools: [
      {
        id: "tool.memory.write",
        capability_kind: "memory",
        permissions: ["memory.read"],
        required_permissions: ["memory.read"],
        access: "write",
        risk: "low",
        locality: "local",
        approval_requirement: "per_call",
        execution: "local",
        side_effect: "local_write",
        compatible_run_modes: ["confirm", "auto"],
      },
    ],
  },
  "run_mode read_only cannot use write-capable tool: tool.memory.write",
);

assert.deepEqual(
  validateManifest({
    ...clone(baseManifest),
    default_run_mode: "auto",
    permissions: [
      "model.complete",
      "insight.write",
      "memory.read",
      "memory.propose",
    ],
    agents: [
      {
        ...clone(baseManifest).agents[0],
        run_mode: "auto",
        permissions: [
          "model.complete",
          "insight.write",
          "memory.read",
          "memory.propose",
        ],
        tools: ["tool.memory.propose"],
      },
    ],
    tools: [
      {
        id: "tool.memory.propose",
        capability_kind: "memory",
        permissions: ["memory.propose"],
        required_permissions: ["memory.propose"],
        access: "write",
        risk: "low",
        locality: "local",
        approval_requirement: "none",
        execution: "local",
        side_effect: "local_write",
        compatible_run_modes: ["confirm", "auto"],
      },
    ],
  }),
  [],
);

expectError(
  {
    ...clone(baseManifest),
    agents: [
      {
        ...clone(baseManifest).agents[0],
        tools: ["tool.memory.bulk_delete"],
      },
    ],
    tools: [
      {
        id: "tool.memory.bulk_delete",
        capability_kind: "memory",
        permissions: ["memory.read"],
        required_permissions: ["memory.read"],
        access: "write",
        risk: "high",
        locality: "local",
        approval_requirement: "none",
        execution: "local",
        side_effect: "local_write",
        compatible_run_modes: ["confirm", "auto"],
      },
    ],
  },
  "approval_requirement must not be none",
);

expectError(
  {
    ...clone(baseManifest),
    marketplace: {
      ...clone(baseManifest).marketplace,
      trust_level: "unsafe",
    },
  },
  "marketplace.trust_level must be one of",
);

expectError(
  {
    ...clone(baseManifest),
    additive_slots: [
      {
        id: "knowledge.organization",
        mode: "exclusive",
      },
    ],
  },
  "mode must be additive for additive_slots",
);

expectError(
  {
    ...clone(baseManifest),
    edition: "community",
    replacement_slots: [
      {
        id: "memory.write_policy",
        mode: "reserved",
      },
    ],
  },
  "replacement_slots are reserved",
);

expectError(
  {
    ...clone(baseManifest),
    edition: "official",
    permissions: ["model.complete", "insight.write", "mcp.call"],
    agents: [
      {
        ...clone(baseManifest).agents[0],
        permissions: ["model.complete", "insight.write", "mcp.call"],
        tools: ["tool.mcp.call"],
      },
    ],
    tools: [
      {
        id: "tool.mcp.call",
        capability_kind: "mcp",
        permissions: ["mcp.call"],
        required_permissions: ["mcp.call"],
        access: "read",
        risk: "high",
        locality: "external",
        approval_requirement: "deferred",
        execution: "deferred",
        side_effect: "network",
        compatible_run_modes: ["confirm"],
      },
    ],
  },
  "official tools[0] cannot declare deferred-only capability",
);

const officialManifestPaths = [
  "../../packs/official/default/manifest.json",
  "../../packs/official/todo/manifest.json",
  "../../packs/official/pkm_library/manifest.json",
].map((path) => fileURLToPath(new URL(path, import.meta.url)));

for (const manifestPath of officialManifestPaths) {
  assert.deepEqual(validateManifestPath(manifestPath), []);
}

const marketplaceIndexPath = fileURLToPath(
  new URL("../../packs/marketplace/index.json", import.meta.url),
);
assert.deepEqual(validateDocumentPath(marketplaceIndexPath), []);

const validMarketplaceIndex = {
  schema_version: 1,
  source: "github",
  updated_at: "2026-06-28",
  packs: [
    {
      id: "pack.test",
      manifest_path: "../official/test/manifest.json",
      publisher: "widenote",
      edition: "local_dev",
      trust_level: "local_dev",
      status: "preview",
      categories: ["test"],
      capabilities: ["memory.read"],
    },
  ],
};
assert.deepEqual(validateMarketplaceIndex(clone(validMarketplaceIndex)), []);

expectMarketplaceError(
  {
    ...clone(validMarketplaceIndex),
    packs: [
      ...clone(validMarketplaceIndex).packs,
      clone(validMarketplaceIndex).packs[0],
    ],
  },
  "duplicates pack id",
);

expectMarketplaceError(
  {
    ...clone(validMarketplaceIndex),
    packs: [
      {
        ...clone(validMarketplaceIndex).packs[0],
        trust_level: "trusted_by_vibes",
      },
    ],
  },
  "trust_level must be one of",
);

console.log("tools/pack_validator/validate_test.mjs: ok");

function expectError(manifest, expected) {
  const errors = validateManifest(manifest);
  assert(
    errors.some((error) => error.includes(expected)),
    `Expected error containing "${expected}", got: ${errors.join("; ")}`,
  );
}

function expectMarketplaceError(index, expected) {
  const errors = validateMarketplaceIndex(index);
  assert(
    errors.some((error) => error.includes(expected)),
    `Expected error containing "${expected}", got: ${errors.join("; ")}`,
  );
}

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}
