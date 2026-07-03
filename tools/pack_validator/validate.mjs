#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { pathToFileURL } from "node:url";

import {
  validateUiBlocks,
  validateUiContributions,
} from "./ui_contributions.mjs";

const TODO_PERMISSION = "todo.suggest";
const TODO_PERMISSIONS = new Set(["model.complete", TODO_PERMISSION]);
const TODO_OUTPUT_EVENT = "wn.todo.suggested";
const MODEL_ROUTING_POLICIES = new Set([
  "app_default",
  "user_selected",
  "pack_preferred",
  "fixed_provider",
]);
const MODEL_CAPABILITIES = new Set([
  "chat",
  "completion",
  "embedding",
  "vision",
  "audio",
  "streaming",
  "tool_use",
  "toolUse",
]);
const RUN_MODES = new Set(["read_only", "confirm", "auto"]);
const TOOL_ACCESS = new Set(["read", "write", "read_write"]);
const TOOL_RISK = new Set(["low", "medium", "high"]);
const TOOL_LOCALITY = new Set(["local", "external"]);
const TOOL_APPROVAL_REQUIREMENTS = new Set(["none", "per_call", "deferred"]);
const TOOL_EXECUTIONS = new Set(["local", "fake", "deferred", "disabled"]);
const EDITIONS = new Set(["official", "store", "community", "local_dev"]);
const MARKETPLACE_SOURCES = new Set(["bundled", "github", "local_dev"]);
const MARKETPLACE_TRUST_LEVELS = new Set([
  "official",
  "reviewed",
  "community",
  "local_dev",
]);
const MARKETPLACE_INSTALL_MODES = new Set([
  "bundled",
  "manifest_url",
  "local_file",
  "deferred",
]);
const MARKETPLACE_STATUSES = new Set([
  "available",
  "preview",
  "deferred",
  "disabled",
]);
const MARKETPLACE_INDEX_SOURCES = new Set(["github"]);
const SLOT_MODES = new Set(["reserved", "exclusive", "additive"]);
const REPLACEMENT_SLOT_ALLOWED_EDITIONS = new Set(["official", "local_dev"]);
const TAG_PATTERN = /^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$/;
const PACK_ID_PATTERN = /^pack\.[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)*$/;
const SLOT_ID_PATTERN = /^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/;
const TOOL_CAPABILITY_KINDS = new Set([
  "local_core",
  "context_packet",
  "memory",
  "todo",
  "trace",
  "settings",
  "model",
  "http",
  "mcp",
  "web",
  "file",
  "network",
  "shell",
  "script",
  "runner",
  "webhook",
]);
const TOOL_SIDE_EFFECTS = new Set([
  "none",
  "local_write",
  "external_write",
  "network",
  "model_call",
  "file_access",
  "script_execution",
]);
const DEFERRED_ONLY_CAPABILITY_KINDS = new Set([
  "http",
  "mcp",
  "web",
  "file",
  "network",
  "shell",
  "script",
  "runner",
  "webhook",
]);
const DEFERRED_ONLY_SIDE_EFFECTS = new Set([
  "external_write",
  "network",
  "file_access",
  "script_execution",
]);
const NON_LIVE_EXECUTIONS = new Set(["fake", "deferred", "disabled"]);
const requiredManifestFields = [
  "id",
  "name",
  "version",
  "schema_version",
  "publisher",
  "edition",
  "permissions",
  "subscriptions",
  "agents",
];

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  runCli(process.argv.slice(2));
}

function runCli(manifestPaths) {
  if (manifestPaths.length === 0) {
    console.error(
      "Usage: node tools/pack_validator/validate.mjs <manifest.json> [...]",
    );
    process.exit(2);
  }

  let failureCount = 0;

  for (const manifestPath of manifestPaths) {
    const errors = validateDocumentPath(manifestPath);

    if (errors.length > 0) {
      failureCount += errors.length;
      console.error(`${manifestPath}: invalid`);
      for (const error of errors) {
        console.error(`  - ${error}`);
      }
      continue;
    }

    console.log(`${manifestPath}: ok`);
  }

  if (failureCount > 0) {
    console.error(
      `${failureCount} validation ${
        failureCount === 1 ? "error" : "errors"
      } found.`,
    );
    process.exit(1);
  }
}

export function validateManifestPath(manifestPath) {
  let manifest;

  try {
    manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  } catch (error) {
    return [`JSON parse failed: ${error.message}`];
  }

  return validateManifest(manifest);
}

export function validateDocumentPath(documentPath) {
  let document;

  try {
    document = JSON.parse(readFileSync(documentPath, "utf8"));
  } catch (error) {
    return [`JSON parse failed: ${error.message}`];
  }

  if (isPlainObject(document) && Array.isArray(document.packs)) {
    return validateMarketplaceIndex(document, { indexPath: documentPath });
  }

  return validateManifest(document);
}

export function validateMarketplaceIndexPath(indexPath) {
  let index;

  try {
    index = JSON.parse(readFileSync(indexPath, "utf8"));
  } catch (error) {
    return [`JSON parse failed: ${error.message}`];
  }

  return validateMarketplaceIndex(index, { indexPath });
}

export function validateManifest(manifest) {
  const errors = [];

  if (!isPlainObject(manifest)) {
    return ["manifest must be a JSON object"];
  }

  validateRequiredFields(manifest, errors);
  validateBasicShape(manifest, errors);

  const packPermissionSet = new Set(
    Array.isArray(manifest.permissions) ? manifest.permissions : [],
  );
  const agents = Array.isArray(manifest.agents) ? manifest.agents : [];
  const subscriptions = Array.isArray(manifest.subscriptions)
    ? manifest.subscriptions
    : [];
  const modelProfiles = Array.isArray(manifest.model_profiles)
    ? manifest.model_profiles
    : [];
  const tools = Array.isArray(manifest.tools) ? manifest.tools : [];

  validateAgentIds(agents, errors);
  validateSubscriptions(subscriptions, agents, errors);
  validateSubscriptionDependencies(subscriptions, errors);
  validateMarketplace(manifest, errors);
  validateSlotDeclarations(manifest, errors);
  validateAgentPermissions(agents, packPermissionSet, errors);
  validateToolPermissions(tools, packPermissionSet, errors);
  validateAgentToolRefs(agents, tools, errors);
  validateModelProfileRefs(agents, modelProfiles, errors);
  validateOutputEvents(agents, errors);
  validateRunModeToolBoundaries(manifest, agents, tools, errors);
  validateExecutableSafety(agents, tools, errors);
  const declaredUiBlocks = validateUiBlocks(manifest, errors);
  validateUiContributions(manifest, packPermissionSet, declaredUiBlocks, errors);
  validatePhaseOneGuardrails(manifest, agents, errors);

  return errors;
}

function validateRequiredFields(manifest, errors) {
  for (const field of requiredManifestFields) {
    if (!(field in manifest)) {
      errors.push(`missing required field: ${field}`);
    }
  }
}

function validateBasicShape(manifest, errors) {
  validateStringField(manifest, "id", errors);
  validateStringField(manifest, "name", errors);
  validateStringField(manifest, "version", errors);
  validateStringField(manifest, "publisher", errors);
  validateStringField(manifest, "edition", errors);
  if ("edition" in manifest) {
    validateStringEnumValue(manifest.edition, "edition", EDITIONS, errors);
  }
  if ("default_run_mode" in manifest) {
    validateStringEnumValue(
      manifest.default_run_mode,
      "default_run_mode",
      RUN_MODES,
      errors,
    );
  }

  if (
    "schema_version" in manifest &&
    (!Number.isInteger(manifest.schema_version) || manifest.schema_version !== 1)
  ) {
    errors.push("schema_version must be 1");
  }

  validateStringArrayField(manifest, "permissions", errors, { allowEmpty: true });
  validateObjectArrayField(manifest, "subscriptions", errors);
  validateObjectArrayField(manifest, "agents", errors);

  if ("model_profiles" in manifest) {
    validateObjectArrayField(manifest, "model_profiles", errors, {
      allowEmpty: true,
    });
  }

  if ("tools" in manifest) {
    validateObjectArrayField(manifest, "tools", errors, { allowEmpty: true });
  }

  if ("marketplace" in manifest && !isPlainObject(manifest.marketplace)) {
    errors.push("marketplace must be an object");
  }

  if ("replacement_slots" in manifest) {
    validateObjectArrayField(manifest, "replacement_slots", errors, {
      allowEmpty: true,
    });
  }

  if ("additive_slots" in manifest) {
    validateObjectArrayField(manifest, "additive_slots", errors, {
      allowEmpty: true,
    });
  }

  if (Array.isArray(manifest.subscriptions)) {
    manifest.subscriptions.forEach((subscription, index) => {
      if (!isPlainObject(subscription)) {
        return;
      }

      const path = `subscriptions[${index}]`;
      validateStringValue(subscription.id, `${path}.id`, errors);
      validateStringArrayValue(
        subscription.event_types,
        `${path}.event_types`,
        errors,
      );
      validateStringValue(subscription.agent_id, `${path}.agent_id`, errors);

      if ("depends_on" in subscription) {
        validateStringArrayValue(
          subscription.depends_on,
          `${path}.depends_on`,
          errors,
          { allowEmpty: true },
        );
      }
    });
  }

  if (Array.isArray(manifest.agents)) {
    manifest.agents.forEach((agent, index) => {
      if (!isPlainObject(agent)) {
        return;
      }

      const path = `agents[${index}]`;
      validateStringValue(agent.id, `${path}.id`, errors);
      validateStringValue(agent.runtime, `${path}.runtime`, errors);
      if ("run_mode" in agent) {
        validateStringEnumValue(agent.run_mode, `${path}.run_mode`, RUN_MODES, errors);
      }

      if ("permissions" in agent) {
        validateStringArrayValue(
          agent.permissions,
          `${path}.permissions`,
          errors,
          { allowEmpty: true },
        );
      }

      if ("tools" in agent) {
        validateStringArrayValue(agent.tools, `${path}.tools`, errors, {
          allowEmpty: true,
        });
      }

      if ("model_profile_ref" in agent && agent.model_profile_ref !== null) {
        validateStringValue(
          agent.model_profile_ref,
          `${path}.model_profile_ref`,
          errors,
        );
      }

      if ("retry_policy" in agent) {
        validateRetryPolicy(agent.retry_policy, `${path}.retry_policy`, errors);
      }
    });
  }

  if (Array.isArray(manifest.model_profiles)) {
    manifest.model_profiles.forEach((profile, index) => {
      if (!isPlainObject(profile)) {
        return;
      }

      const path = `model_profiles[${index}]`;
      validateStringValue(profile.id, `${path}.id`, errors);
      validateStringValue(profile.purpose, `${path}.purpose`, errors);

      if ("required" in profile && typeof profile.required !== "boolean") {
        errors.push(`${path}.required must be a boolean`);
      }

      if ("routing_policy" in profile) {
        validateStringEnumValue(
          profile.routing_policy,
          `${path}.routing_policy`,
          MODEL_ROUTING_POLICIES,
          errors,
        );
      }

      if ("provider_ref" in profile && profile.provider_ref !== null) {
        validateStringValue(profile.provider_ref, `${path}.provider_ref`, errors);
      }

      if ("model_ref" in profile && profile.model_ref !== null) {
        validateStringValue(profile.model_ref, `${path}.model_ref`, errors);
      }

      if ("required_capabilities" in profile) {
        validateStringArrayEnumValue(
          profile.required_capabilities,
          `${path}.required_capabilities`,
          MODEL_CAPABILITIES,
          errors,
          { allowEmpty: true },
        );
      }

      if ("allow_fallback" in profile && typeof profile.allow_fallback !== "boolean") {
        errors.push(`${path}.allow_fallback must be a boolean`);
      }
    });
  }

  if (Array.isArray(manifest.tools)) {
    manifest.tools.forEach((tool, index) => {
      if (!isPlainObject(tool)) {
        return;
      }

      const path = `tools[${index}]`;
      validateStringValue(tool.id, `${path}.id`, errors);
      validateRequiredToolFields(tool, path, errors);
      if ("capability_kind" in tool) {
        validateStringEnumValue(
          tool.capability_kind,
          `${path}.capability_kind`,
          TOOL_CAPABILITY_KINDS,
          errors,
        );
      }
      if ("permissions" in tool) {
        validateStringArrayValue(tool.permissions, `${path}.permissions`, errors);
      }
      if ("required_permissions" in tool) {
        validateStringArrayValue(
          tool.required_permissions,
          `${path}.required_permissions`,
          errors,
        );
      }
      if ("access" in tool) {
        validateStringEnumValue(tool.access, `${path}.access`, TOOL_ACCESS, errors);
      }
      if ("risk" in tool) {
        validateStringEnumValue(tool.risk, `${path}.risk`, TOOL_RISK, errors);
      }
      if ("locality" in tool) {
        validateStringEnumValue(
          tool.locality,
          `${path}.locality`,
          TOOL_LOCALITY,
          errors,
        );
      }
      if ("approval_requirement" in tool) {
        validateStringEnumValue(
          tool.approval_requirement,
          `${path}.approval_requirement`,
          TOOL_APPROVAL_REQUIREMENTS,
          errors,
        );
      }
      if ("execution" in tool) {
        validateStringEnumValue(
          tool.execution,
          `${path}.execution`,
          TOOL_EXECUTIONS,
          errors,
        );
      }
      if ("side_effect" in tool) {
        validateStringEnumValue(
          tool.side_effect,
          `${path}.side_effect`,
          TOOL_SIDE_EFFECTS,
          errors,
        );
      }
      if ("compatible_run_modes" in tool) {
        validateStringArrayEnumValue(
          tool.compatible_run_modes,
          `${path}.compatible_run_modes`,
          RUN_MODES,
          errors,
        );
      }
    });
  }

}

function validateAgentIds(agents, errors) {
  const seen = new Set();

  agents.forEach((agent, index) => {
    if (!isPlainObject(agent)) {
      return;
    }

    if (typeof agent.id !== "string") {
      return;
    }

    if (seen.has(agent.id)) {
      errors.push(`agents[${index}].id duplicates agent id: ${agent.id}`);
      return;
    }

    seen.add(agent.id);
  });
}

function validateSubscriptions(subscriptions, agents, errors) {
  const agentIds = new Set(
    agents
      .filter((agent) => isPlainObject(agent))
      .map((agent) => agent.id)
      .filter((agentId) => typeof agentId === "string"),
  );

  subscriptions.forEach((subscription, index) => {
    if (!isPlainObject(subscription)) {
      return;
    }

    if (
      typeof subscription.agent_id === "string" &&
      !agentIds.has(subscription.agent_id)
    ) {
      errors.push(
        `subscriptions[${index}].agent_id references missing agent: ${subscription.agent_id}`,
      );
    }
  });
}

function validateSubscriptionDependencies(subscriptions, errors) {
  const seen = new Set();
  const byId = new Map();

  subscriptions.forEach((subscription, index) => {
    if (!isPlainObject(subscription) || typeof subscription.id !== "string") {
      return;
    }

    if (seen.has(subscription.id)) {
      errors.push(
        `subscriptions[${index}].id duplicates subscription id: ${subscription.id}`,
      );
      return;
    }

    seen.add(subscription.id);
    byId.set(subscription.id, subscription);
  });

  subscriptions.forEach((subscription, index) => {
    if (!isPlainObject(subscription) || !Array.isArray(subscription.depends_on)) {
      return;
    }

    for (const dependency of subscription.depends_on) {
      if (isExternalSubscriptionDependency(dependency)) {
        continue;
      }
      if (dependency === subscription.id) {
        errors.push(`subscriptions[${index}].depends_on references itself`);
      }
      if (typeof dependency === "string" && !byId.has(dependency)) {
        errors.push(
          `subscriptions[${index}].depends_on references missing subscription: ${dependency}`,
        );
      }
    }
  });

  const visiting = new Set();
  const visited = new Set();

  for (const id of byId.keys()) {
    visitSubscription(id, byId, visiting, visited, errors);
  }
}

function visitSubscription(id, byId, visiting, visited, errors) {
  if (visited.has(id)) {
    return;
  }
  if (visiting.has(id)) {
    errors.push(`subscriptions.depends_on contains a cycle at ${id}`);
    return;
  }

  const subscription = byId.get(id);
  if (!subscription || !Array.isArray(subscription.depends_on)) {
    visited.add(id);
    return;
  }

  visiting.add(id);
  for (const dependency of subscription.depends_on) {
    if (
      typeof dependency === "string" &&
      !isExternalSubscriptionDependency(dependency) &&
      byId.has(dependency)
    ) {
      visitSubscription(dependency, byId, visiting, visited, errors);
    }
  }
  visiting.delete(id);
  visited.add(id);
}

function isExternalSubscriptionDependency(dependency) {
  return typeof dependency === "string" && dependency.includes("::");
}

function validateMarketplace(manifest, errors) {
  if (!isPlainObject(manifest.marketplace)) {
    return;
  }

  const marketplace = manifest.marketplace;
  validateStringEnumValue(
    marketplace.source,
    "marketplace.source",
    MARKETPLACE_SOURCES,
    errors,
  );
  validateStringEnumValue(
    marketplace.trust_level,
    "marketplace.trust_level",
    MARKETPLACE_TRUST_LEVELS,
    errors,
  );
  if ("install_mode" in marketplace) {
    validateStringEnumValue(
      marketplace.install_mode,
      "marketplace.install_mode",
      MARKETPLACE_INSTALL_MODES,
      errors,
    );
  }
  if ("repository_url" in marketplace && marketplace.repository_url !== null) {
    validateStringValue(
      marketplace.repository_url,
      "marketplace.repository_url",
      errors,
    );
  }
  if ("docs_path" in marketplace && marketplace.docs_path !== null) {
    validateStringValue(marketplace.docs_path, "marketplace.docs_path", errors);
  }
  if ("icon_path" in marketplace && marketplace.icon_path !== null) {
    validateStringValue(marketplace.icon_path, "marketplace.icon_path", errors);
  }
  validateStringArrayPatternValue(
    marketplace.categories,
    "marketplace.categories",
    TAG_PATTERN,
    errors,
  );
  validateStringArrayPatternValue(
    marketplace.capabilities,
    "marketplace.capabilities",
    TAG_PATTERN,
    errors,
  );
  if ("status" in marketplace) {
    validateStringEnumValue(
      marketplace.status,
      "marketplace.status",
      MARKETPLACE_STATUSES,
      errors,
    );
  }
}

function validateSlotDeclarations(manifest, errors) {
  validateSlotList(manifest.replacement_slots, "replacement_slots", errors, {
    replacement: true,
    edition: manifest.edition,
  });
  validateSlotList(manifest.additive_slots, "additive_slots", errors, {
    replacement: false,
    edition: manifest.edition,
  });
}

function validateSlotList(value, path, errors, options) {
  if (!Array.isArray(value)) {
    return;
  }
  const seenIds = new Set();
  value.forEach((slot, index) => {
    if (!isPlainObject(slot)) {
      return;
    }
    validateStringPatternValue(slot.id, `${path}[${index}].id`, SLOT_ID_PATTERN, errors);
    validateStringEnumValue(slot.mode, `${path}[${index}].mode`, SLOT_MODES, errors);
    if ("description" in slot) {
      validateStringValue(slot.description, `${path}[${index}].description`, errors);
    }
    if (typeof slot.id === "string") {
      if (seenIds.has(slot.id)) {
        errors.push(`${path}[${index}].id duplicates slot id: ${slot.id}`);
      }
      seenIds.add(slot.id);
    }
    if (!options.replacement && slot.mode !== "additive") {
      errors.push(`${path}[${index}].mode must be additive for additive_slots`);
    }
  });

  if (
    options.replacement &&
    value.length > 0 &&
    !REPLACEMENT_SLOT_ALLOWED_EDITIONS.has(options.edition)
  ) {
    errors.push(
      "replacement_slots are reserved for official or local_dev packs in this slice",
    );
  }
}

function validateAgentPermissions(agents, packPermissionSet, errors) {
  agents.forEach((agent, index) => {
    if (!isPlainObject(agent)) {
      return;
    }

    if (!Array.isArray(agent.permissions)) {
      return;
    }

    for (const permission of agent.permissions) {
      if (typeof permission === "string" && !packPermissionSet.has(permission)) {
        errors.push(
          `agents[${index}].permissions contains permission not declared by pack: ${permission}`,
        );
      }
    }
  });
}

function validateToolPermissions(tools, packPermissionSet, errors) {
  tools.forEach((tool, index) => {
    if (!isPlainObject(tool)) {
      return;
    }

    for (const field of ["permissions", "required_permissions"]) {
      if (!Array.isArray(tool[field])) {
        continue;
      }

      for (const permission of tool[field]) {
        if (typeof permission === "string" && !packPermissionSet.has(permission)) {
          errors.push(
            `tools[${index}].${field} contains permission not declared by pack: ${permission}`,
          );
        }
      }
    }

    if (
      Array.isArray(tool.permissions) &&
      Array.isArray(tool.required_permissions) &&
      !sameStringSet(tool.permissions, tool.required_permissions)
    ) {
      errors.push(
        `tools[${index}].required_permissions must match tools[${index}].permissions`,
      );
    }
  });
}

function validateAgentToolRefs(agents, tools, errors) {
  const toolIds = new Set(
    tools
      .filter((tool) => isPlainObject(tool))
      .map((tool) => tool.id)
      .filter((toolId) => typeof toolId === "string"),
  );

  agents.forEach((agent, index) => {
    if (!isPlainObject(agent) || !Array.isArray(agent.tools)) {
      return;
    }

    for (const toolId of agent.tools) {
      if (typeof toolId === "string" && !toolIds.has(toolId)) {
        errors.push(
          `agents[${index}].tools references missing tool: ${toolId}`,
        );
      }
    }
  });
}

function validateModelProfileRefs(agents, modelProfiles, errors) {
  const modelProfileIds = new Set(
    modelProfiles
      .filter((profile) => isPlainObject(profile))
      .map((profile) => profile.id)
      .filter((profileId) => typeof profileId === "string"),
  );

  agents.forEach((agent, index) => {
    if (!isPlainObject(agent)) {
      return;
    }

    if (
      agent.model_profile_ref !== undefined &&
      agent.model_profile_ref !== null &&
      typeof agent.model_profile_ref === "string" &&
      !modelProfileIds.has(agent.model_profile_ref)
    ) {
      errors.push(
        `agents[${index}].model_profile_ref references missing model profile: ${agent.model_profile_ref}`,
      );
    }
  });
}

function validateOutputEvents(agents, errors) {
  agents.forEach((agent, index) => {
    if (!isPlainObject(agent)) {
      return;
    }

    validateStringArrayValue(
      agent.output_events,
      `agents[${index}].output_events`,
      errors,
    );
  });
}

function validateRunModeToolBoundaries(manifest, agents, tools, errors) {
  const toolsById = new Map(
    tools
      .filter((tool) => isPlainObject(tool) && typeof tool.id === "string")
      .map((tool) => [tool.id, tool]),
  );
  const defaultRunMode =
    typeof manifest.default_run_mode === "string"
      ? manifest.default_run_mode
      : "confirm";

  tools.forEach((tool, index) => {
    if (!isPlainObject(tool)) {
      return;
    }

    if (isDeferredOnlyTool(tool) && !NON_LIVE_EXECUTIONS.has(tool.execution)) {
      errors.push(
        `tools[${index}].execution must be fake, deferred, or disabled for deferred-only capability ${tool.capability_kind ?? tool.side_effect}`,
      );
    }

    if (tool.locality === "external" && tool.execution === "local") {
      errors.push(
        `tools[${index}].execution local is not allowed for external tools in L1-L3`,
      );
    }

    if (requiresExplicitApproval(tool) && tool.approval_requirement === "none") {
      errors.push(
        `tools[${index}].approval_requirement must not be none for external, high-risk, or deferred-only tools`,
      );
    }
  });

  agents.forEach((agent, agentIndex) => {
    if (!isPlainObject(agent) || !Array.isArray(agent.tools)) {
      return;
    }

    const runMode =
      typeof agent.run_mode === "string" ? agent.run_mode : defaultRunMode;

    agent.tools.forEach((toolId) => {
      const tool = toolsById.get(toolId);
      if (!tool) {
        return;
      }

      if (
        Array.isArray(tool.compatible_run_modes) &&
        !tool.compatible_run_modes.includes(runMode)
      ) {
        errors.push(
          `agents[${agentIndex}].run_mode ${runMode} is not compatible with tool: ${tool.id}`,
        );
      }

      if (runMode === "read_only") {
        validateReadOnlyTool(agentIndex, tool, errors);
        return;
      }

      if (runMode === "confirm") {
        validateConfirmTool(agentIndex, tool, errors);
        return;
      }

      if (runMode === "auto") {
        validateAutoTool(agentIndex, tool, errors);
      }
    });
  });
}

function validateReadOnlyTool(agentIndex, tool, errors) {
  if (tool.access === "write" || tool.access === "read_write") {
    errors.push(
      `agents[${agentIndex}].run_mode read_only cannot use write-capable tool: ${tool.id}`,
    );
  }

  if (tool.locality === "external") {
    errors.push(
      `agents[${agentIndex}].run_mode read_only cannot use external tool: ${tool.id}`,
    );
  }

  if (tool.risk === "high") {
    errors.push(
      `agents[${agentIndex}].run_mode read_only cannot use high-risk tool: ${tool.id}`,
    );
  }
}

function validateConfirmTool(agentIndex, tool, errors) {
  if (!requiresExplicitApproval(tool)) {
    return;
  }

  if (tool.execution === "deferred" || tool.execution === "disabled") {
    if (tool.approval_requirement !== "deferred") {
      errors.push(
        `agents[${agentIndex}].run_mode confirm requires deferred approval metadata for deferred tool: ${tool.id}`,
      );
    }
    return;
  }

  if (tool.approval_requirement !== "per_call") {
    errors.push(
      `agents[${agentIndex}].run_mode confirm requires per_call approval for external, high-risk, or explicit approval-gated tool: ${tool.id}`,
    );
  }
}

function validateAutoTool(agentIndex, tool, errors) {
  if (tool.risk !== "low") {
    errors.push(
      `agents[${agentIndex}].run_mode auto can only use low-risk tools: ${tool.id}`,
    );
  }

  if (tool.locality === "external") {
    errors.push(
      `agents[${agentIndex}].run_mode auto cannot use external tool: ${tool.id}`,
    );
  }

  if (isDeferredOnlyTool(tool)) {
    errors.push(
      `agents[${agentIndex}].run_mode auto cannot use deferred-only live capability: ${tool.id}`,
    );
  }

  if (tool.execution === "deferred" || tool.execution === "disabled") {
    errors.push(
      `agents[${agentIndex}].run_mode auto cannot automatically execute deferred or disabled tool: ${tool.id}`,
    );
  }

  if (tool.approval_requirement !== "none") {
    errors.push(
      `agents[${agentIndex}].run_mode auto cannot use approval-gated tool: ${tool.id}`,
    );
  }
}

function validateExecutableSafety(agents, tools, errors) {
  agents.forEach((agent, index) => {
    if (!isPlainObject(agent)) {
      return;
    }

    if (agent.runtime === "script") {
      errors.push(
        `agents[${index}].runtime script is deferred until a sandbox RFC is accepted`,
      );
    }
  });

  tools.forEach((tool, index) => {
    if (!isPlainObject(tool)) {
      return;
    }

    if (tool.side_effect === "script_execution") {
      errors.push(
        `tools[${index}].side_effect script_execution is deferred until a sandbox RFC is accepted`,
      );
    }
  });
}

function validatePhaseOneGuardrails(manifest, agents, errors) {
  if (manifest.edition === "official") {
    agents.forEach((agent, index) => {
      if (!isPlainObject(agent)) {
        return;
      }
      if (agent.runtime !== "native") {
        errors.push(
          `official agents[${index}].runtime must be native in L1-L3`,
        );
      }
    });

    const tools = Array.isArray(manifest.tools) ? manifest.tools : [];
    tools.forEach((tool, index) => {
      if (!isPlainObject(tool)) {
        return;
      }
      if (isDeferredOnlyTool(tool)) {
        errors.push(
          `official tools[${index}] cannot declare deferred-only capability in L1-L3: ${tool.id}`,
        );
      }
    });
  }

  if (manifest.id === "pack.default") {
    if (arrayIncludes(manifest.permissions, TODO_PERMISSION)) {
      errors.push(`pack.default must not request ${TODO_PERMISSION}`);
    }

    agents.forEach((agent, index) => {
      if (!isPlainObject(agent)) {
        return;
      }

      if (arrayIncludes(agent.permissions, TODO_PERMISSION)) {
        errors.push(
          `pack.default agents[${index}] must not request ${TODO_PERMISSION}`,
        );
      }

      if (arrayIncludes(agent.output_events, TODO_OUTPUT_EVENT)) {
        errors.push(
          `pack.default agents[${index}] must not output ${TODO_OUTPUT_EVENT}`,
        );
      }
    });
  }

  if (manifest.id === "pack.todo") {
    const packPermissions = Array.isArray(manifest.permissions)
      ? manifest.permissions
      : [];
    const invalidPackPermissions = packPermissions.filter(
      (permission) => !TODO_PERMISSIONS.has(permission),
    );

    for (const permission of TODO_PERMISSIONS) {
      if (!arrayIncludes(packPermissions, permission)) {
        errors.push(`pack.todo must request ${permission}`);
      }
    }

    for (const permission of invalidPackPermissions) {
      errors.push(
        `pack.todo must only request model.complete and ${TODO_PERMISSION}; found ${permission}`,
      );
    }

    agents.forEach((agent, index) => {
      if (!isPlainObject(agent)) {
        return;
      }

      if (!Array.isArray(agent.permissions)) {
        return;
      }

      for (const permission of agent.permissions) {
        if (!TODO_PERMISSIONS.has(permission)) {
          errors.push(
            `pack.todo agents[${index}] must only request model.complete and ${TODO_PERMISSION}; found ${permission}`,
          );
        }
      }

      for (const permission of TODO_PERMISSIONS) {
        if (!arrayIncludes(agent.permissions, permission)) {
          errors.push(`pack.todo agents[${index}] must request ${permission}`);
        }
      }
    });

    const outputsTodoEvent = agents.some(
      (agent) =>
        isPlainObject(agent) &&
        arrayIncludes(agent.output_events, TODO_OUTPUT_EVENT),
    );

    if (!outputsTodoEvent) {
      errors.push(`pack.todo must output ${TODO_OUTPUT_EVENT}`);
    }
  }
}

export function validateMarketplaceIndex(index, options = {}) {
  const errors = [];

  if (!isPlainObject(index)) {
    return ["marketplace index must be a JSON object"];
  }

  if (
    "schema_version" in index &&
    (!Number.isInteger(index.schema_version) || index.schema_version !== 1)
  ) {
    errors.push("schema_version must be 1");
  }
  if (!("schema_version" in index)) {
    errors.push("missing required field: schema_version");
  }
  validateStringEnumValue(index.source, "source", MARKETPLACE_INDEX_SOURCES, errors);
  validateStringValue(index.updated_at, "updated_at", errors);
  validateObjectArrayField(index, "packs", errors, { allowEmpty: true });

  const seenPackIds = new Set();
  const indexDir = options.indexPath ? dirname(options.indexPath) : null;
  const entries = Array.isArray(index.packs) ? index.packs : [];

  entries.forEach((entry, indexInList) => {
    if (!isPlainObject(entry)) {
      return;
    }
    const path = `packs[${indexInList}]`;
    validateStringPatternValue(entry.id, `${path}.id`, PACK_ID_PATTERN, errors);
    validateStringValue(entry.manifest_path, `${path}.manifest_path`, errors);
    validateStringValue(entry.publisher, `${path}.publisher`, errors);
    validateStringEnumValue(entry.edition, `${path}.edition`, EDITIONS, errors);
    validateStringEnumValue(
      entry.trust_level,
      `${path}.trust_level`,
      MARKETPLACE_TRUST_LEVELS,
      errors,
    );
    validateStringEnumValue(
      entry.status,
      `${path}.status`,
      MARKETPLACE_STATUSES,
      errors,
    );
    validateStringArrayPatternValue(
      entry.categories,
      `${path}.categories`,
      TAG_PATTERN,
      errors,
    );
    validateStringArrayPatternValue(
      entry.capabilities,
      `${path}.capabilities`,
      TAG_PATTERN,
      errors,
    );
    if ("repository_url" in entry && entry.repository_url !== null) {
      validateStringValue(entry.repository_url, `${path}.repository_url`, errors);
    }
    if ("docs_path" in entry && entry.docs_path !== null) {
      validateStringValue(entry.docs_path, `${path}.docs_path`, errors);
    }
    if (typeof entry.id === "string") {
      if (seenPackIds.has(entry.id)) {
        errors.push(`${path}.id duplicates pack id: ${entry.id}`);
      }
      seenPackIds.add(entry.id);
    }
    if (indexDir && typeof entry.manifest_path === "string") {
      validateIndexedManifest(entry, indexDir, path, errors);
    }
  });

  return errors;
}

function validateIndexedManifest(entry, indexDir, path, errors) {
  const manifestPath = resolve(indexDir, entry.manifest_path);
  if (!existsSync(manifestPath)) {
    errors.push(`${path}.manifest_path does not exist: ${entry.manifest_path}`);
    return;
  }
  const manifestErrors = validateManifestPath(manifestPath);
  if (manifestErrors.length > 0) {
    errors.push(
      `${path}.manifest_path points to invalid manifest: ${manifestErrors.join("; ")}`,
    );
    return;
  }
  const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
  if (manifest.id !== entry.id) {
    errors.push(`${path}.id does not match manifest id: ${manifest.id}`);
  }
  if (manifest.publisher !== entry.publisher) {
    errors.push(`${path}.publisher does not match manifest publisher`);
  }
  if (manifest.edition !== entry.edition) {
    errors.push(`${path}.edition does not match manifest edition`);
  }
  const marketplace = isPlainObject(manifest.marketplace)
    ? manifest.marketplace
    : null;
  if (marketplace) {
    if (marketplace.trust_level !== entry.trust_level) {
      errors.push(`${path}.trust_level does not match manifest marketplace trust`);
    }
    compareStringArrays(
      entry.categories,
      marketplace.categories,
      `${path}.categories`,
      errors,
    );
    compareStringArrays(
      entry.capabilities,
      marketplace.capabilities,
      `${path}.capabilities`,
      errors,
    );
  }
}

function validateStringField(object, field, errors) {
  if (field in object) {
    validateStringValue(object[field], field, errors);
  }
}

function validateRetryPolicy(value, path, errors) {
  if (!isPlainObject(value)) {
    errors.push(`${path} must be an object`);
    return;
  }

  if (!Number.isInteger(value.max_attempts)) {
    errors.push(`${path}.max_attempts must be an integer`);
    return;
  }

  if (value.max_attempts < 1 || value.max_attempts > 5) {
    errors.push(`${path}.max_attempts must be between 1 and 5`);
  }
}

function validateRequiredToolFields(tool, path, errors) {
  for (const field of [
    "permissions",
    "required_permissions",
    "access",
    "risk",
    "locality",
    "approval_requirement",
    "execution",
    "side_effect",
    "compatible_run_modes",
  ]) {
    if (!(field in tool)) {
      errors.push(`${path}.${field} is required for tool capability metadata`);
    }
  }
}

function isDeferredOnlyTool(tool) {
  return (
    DEFERRED_ONLY_CAPABILITY_KINDS.has(tool.capability_kind) ||
    DEFERRED_ONLY_SIDE_EFFECTS.has(tool.side_effect)
  );
}

function requiresExplicitApproval(tool) {
  return (
    tool.risk === "high" ||
    tool.locality === "external" ||
    isDeferredOnlyTool(tool)
  );
}

function validateStringValue(value, path, errors) {
  if (typeof value !== "string" || value.length === 0) {
    errors.push(`${path} must be a non-empty string`);
  }
}

function validateStringArrayField(object, field, errors, options = {}) {
  if (field in object) {
    validateStringArrayValue(object[field], field, errors, options);
  }
}

function validateStringArrayValue(value, path, errors, options = {}) {
  if (!Array.isArray(value)) {
    errors.push(`${path} must be an array`);
    return;
  }

  if (!options.allowEmpty && value.length === 0) {
    errors.push(`${path} must be a non-empty array`);
    return;
  }

  value.forEach((item, index) => {
    if (typeof item !== "string" || item.length === 0) {
      errors.push(`${path}[${index}] must be a non-empty string`);
    }
  });
}

function validateStringEnumValue(value, path, allowedValues, errors) {
  validateStringValue(value, path, errors);
  if (typeof value === "string" && !allowedValues.has(value)) {
    errors.push(
      `${path} must be one of: ${Array.from(allowedValues).join(", ")}`,
    );
  }
}

function validateStringPatternValue(value, path, pattern, errors) {
  validateStringValue(value, path, errors);
  if (typeof value === "string" && !pattern.test(value)) {
    errors.push(`${path} has invalid value: ${value}`);
  }
}

function validateStringArrayEnumValue(
  value,
  path,
  allowedValues,
  errors,
  options = {},
) {
  validateStringArrayValue(value, path, errors, options);
  if (!Array.isArray(value)) {
    return;
  }
  value.forEach((item, index) => {
    if (typeof item === "string" && !allowedValues.has(item)) {
      errors.push(
        `${path}[${index}] must be one of: ${Array.from(allowedValues).join(", ")}`,
      );
    }
  });
}

function validateStringArrayPatternValue(value, path, pattern, errors) {
  validateStringArrayValue(value, path, errors);
  if (!Array.isArray(value)) {
    return;
  }
  value.forEach((item, index) => {
    if (typeof item === "string" && !pattern.test(item)) {
      errors.push(`${path}[${index}] has invalid value: ${item}`);
    }
  });
}

function validateObjectArrayField(object, field, errors, options = {}) {
  if (!(field in object)) {
    return;
  }

  if (!Array.isArray(object[field])) {
    errors.push(`${field} must be an array`);
    return;
  }

  if (!options.allowEmpty && object[field].length === 0) {
    errors.push(`${field} must be a non-empty array`);
    return;
  }

  object[field].forEach((item, index) => {
    if (!isPlainObject(item)) {
      errors.push(`${field}[${index}] must be an object`);
    }
  });
}

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function arrayIncludes(value, expected) {
  return Array.isArray(value) && value.includes(expected);
}

function sameStringSet(left, right) {
  const leftStrings = left.filter((item) => typeof item === "string");
  const rightStrings = right.filter((item) => typeof item === "string");
  if (leftStrings.length !== rightStrings.length) {
    return false;
  }

  const rightSet = new Set(rightStrings);
  return leftStrings.every((item) => rightSet.has(item));
}

function compareStringArrays(left, right, path, errors) {
  if (!Array.isArray(left) || !Array.isArray(right)) {
    return;
  }
  if (!sameStringSet(left, right)) {
    errors.push(`${path} does not match manifest marketplace metadata`);
  }
}
