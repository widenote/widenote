#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const TODO_PERMISSION = "todo.suggest";
const TODO_OUTPUT_EVENT = "wn.todo.suggested";

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
    const errors = validateManifestPath(manifestPath);

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
  validateAgentPermissions(agents, packPermissionSet, errors);
  validateModelProfileRefs(agents, modelProfiles, errors);
  validateOutputEvents(agents, errors);
  validateExecutableSafety(agents, tools, errors);
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

  if (
    "schema_version" in manifest &&
    (!Number.isInteger(manifest.schema_version) || manifest.schema_version < 1)
  ) {
    errors.push("schema_version must be an integer greater than or equal to 1");
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

      if ("permissions" in agent) {
        validateStringArrayValue(
          agent.permissions,
          `${path}.permissions`,
          errors,
          { allowEmpty: true },
        );
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

      validateStringValue(profile.id, `model_profiles[${index}].id`, errors);
    });
  }

  if (Array.isArray(manifest.tools)) {
    manifest.tools.forEach((tool, index) => {
      if (!isPlainObject(tool)) {
        return;
      }

      const path = `tools[${index}]`;
      validateStringValue(tool.id, `${path}.id`, errors);
      if ("permissions" in tool) {
        validateStringArrayValue(tool.permissions, `${path}.permissions`, errors);
      }
      if ("side_effect" in tool) {
        validateStringValue(tool.side_effect, `${path}.side_effect`, errors);
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
    if (typeof dependency === "string" && byId.has(dependency)) {
      visitSubscription(dependency, byId, visiting, visited, errors);
    }
  }
  visiting.delete(id);
  visited.add(id);
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
      (permission) => permission !== TODO_PERMISSION,
    );

    if (packPermissions.length === 0) {
      errors.push(`pack.todo must request ${TODO_PERMISSION}`);
    }

    for (const permission of invalidPackPermissions) {
      errors.push(
        `pack.todo must only request ${TODO_PERMISSION}; found ${permission}`,
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
        if (permission !== TODO_PERMISSION) {
          errors.push(
            `pack.todo agents[${index}] must only request ${TODO_PERMISSION}; found ${permission}`,
          );
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
