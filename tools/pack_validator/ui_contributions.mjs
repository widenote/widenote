const SLOT_ID_PATTERN = /^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$/;

const UI_BLOCK_KINDS = new Set([
  "claim_list",
  "metric_row",
  "source_refs",
  "note",
  "evidence_list",
  "counter_evidence",
  "confidence_band",
  "contrast",
  "trend_chart",
  "timeline",
]);
const UI_CONTRIBUTION_SURFACES = new Set([
  "home.summary",
  "capture.sheet.accessory",
  "timeline.card.accessory",
  "timeline.item.detail",
  "memory.item.detail",
  "insight.detail",
  "artifact.detail",
  "chat.tool_result",
  "todo.detail",
  "plugins.pack_home",
  "settings.pack_detail",
  "bottom_tab",
]);
const UI_CONTRIBUTION_KINDS = new Set([
  "settings_form",
  "panel",
  "event_blocks",
  "action",
  "inline_status",
  "bottom_tab",
]);
const UI_CONTRIBUTION_PLACEMENTS = new Set([
  "section",
  "inline",
  "primary_action",
  "secondary_action",
  "tab",
]);
const UI_CONTRIBUTION_ALLOWED_KEYS = new Set([
  "id",
  "surface",
  "kind",
  "title",
  "description",
  "slot",
  "placement",
  "events",
  "blocks",
  "settings_schema_ref",
  "required_permissions",
]);
const NAVIGATION_UI_ALLOWED_EDITIONS = new Set(["official", "local_dev"]);

export function validateUiBlocks(manifest, errors) {
  if (!("ui_blocks" in manifest)) {
    return new Set();
  }

  if (!Array.isArray(manifest.ui_blocks)) {
    errors.push("ui_blocks must be an array");
    return new Set();
  }

  const declaredBlocks = new Set();
  manifest.ui_blocks.forEach((block, index) => {
    const path = `ui_blocks[${index}]`;
    if (!isPlainObject(block)) {
      errors.push(`${path} must be an object`);
      return;
    }

    validateAllowedKeys(block, path, new Set(["type", "events"]), errors);
    validateStringEnumValue(
      block.type,
      `${path}.type`,
      UI_BLOCK_KINDS,
      errors,
    );
    if (typeof block.type === "string" && UI_BLOCK_KINDS.has(block.type)) {
      declaredBlocks.add(block.type);
    }
    if ("events" in block) {
      validateStringArrayValue(block.events, `${path}.events`, errors, {
        allowEmpty: true,
      });
    }
  });
  return declaredBlocks;
}

export function validateUiContributions(
  manifest,
  packPermissionSet,
  declaredUiBlocks,
  errors,
) {
  if (!("ui_contributions" in manifest)) {
    return;
  }

  if (!Array.isArray(manifest.ui_contributions)) {
    errors.push("ui_contributions must be an array");
    return;
  }

  const seenIds = new Set();
  manifest.ui_contributions.forEach((contribution, index) => {
    const path = `ui_contributions[${index}]`;
    if (!isPlainObject(contribution)) {
      errors.push(`${path} must be an object`);
      return;
    }

    validateAllowedKeys(contribution, path, UI_CONTRIBUTION_ALLOWED_KEYS, errors);
    validateStringPatternValue(contribution.id, `${path}.id`, SLOT_ID_PATTERN, errors);
    if (typeof contribution.id === "string") {
      if (seenIds.has(contribution.id)) {
        errors.push(`ui_contributions contains duplicate id: ${contribution.id}`);
      }
      seenIds.add(contribution.id);
    }
    validateStringEnumValue(
      contribution.surface,
      `${path}.surface`,
      UI_CONTRIBUTION_SURFACES,
      errors,
    );
    validateStringEnumValue(
      contribution.kind,
      `${path}.kind`,
      UI_CONTRIBUTION_KINDS,
      errors,
    );
    validateStringValue(contribution.title, `${path}.title`, errors);
    if ("description" in contribution) {
      validateStringValue(contribution.description, `${path}.description`, errors);
    }
    if ("slot" in contribution) {
      validateStringPatternValue(
        contribution.slot,
        `${path}.slot`,
        SLOT_ID_PATTERN,
        errors,
      );
    }
    if ("placement" in contribution) {
      validateStringEnumValue(
        contribution.placement,
        `${path}.placement`,
        UI_CONTRIBUTION_PLACEMENTS,
        errors,
      );
    }
    if ("events" in contribution) {
      validateStringArrayValue(contribution.events, `${path}.events`, errors, {
        allowEmpty: true,
      });
    }
    if ("blocks" in contribution) {
      validateStringArrayEnumValue(
        contribution.blocks,
        `${path}.blocks`,
        UI_BLOCK_KINDS,
        errors,
        { allowEmpty: true },
      );
      if (Array.isArray(contribution.blocks)) {
        for (const block of contribution.blocks) {
          if (
            typeof block === "string" &&
            UI_BLOCK_KINDS.has(block) &&
            !declaredUiBlocks.has(block)
          ) {
            errors.push(
              `${path}.blocks contains UI block not declared by pack: ${block}`,
            );
          }
        }
      }
    }
    if ("settings_schema_ref" in contribution) {
      validateStringValue(
        contribution.settings_schema_ref,
        `${path}.settings_schema_ref`,
        errors,
      );
    }
    if ("required_permissions" in contribution) {
      validateStringArrayValue(
        contribution.required_permissions,
        `${path}.required_permissions`,
        errors,
        { allowEmpty: true },
      );
      if (Array.isArray(contribution.required_permissions)) {
        for (const permission of contribution.required_permissions) {
          if (!packPermissionSet.has(permission)) {
            errors.push(
              `${path}.required_permissions contains permission not declared by pack: ${permission}`,
            );
          }
        }
      }
    }

    if (
      contribution.kind === "event_blocks" &&
      (!Array.isArray(contribution.events) ||
        contribution.events.length === 0 ||
        !Array.isArray(contribution.blocks) ||
        contribution.blocks.length === 0)
    ) {
      errors.push(`${path} must declare events and blocks for event_blocks`);
    }
    if (
      contribution.kind === "settings_form" &&
      typeof contribution.settings_schema_ref !== "string"
    ) {
      errors.push(`${path}.settings_schema_ref is required for settings_form`);
    }
    if (
      contribution.kind === "settings_form" &&
      contribution.settings_schema_ref === "#/settings_schema" &&
      !("settings_schema" in manifest)
    ) {
      errors.push(`${path}.settings_schema_ref references missing settings_schema`);
    }
    if (
      (contribution.kind === "bottom_tab" ||
        contribution.surface === "bottom_tab") &&
      !(
        contribution.kind === "bottom_tab" &&
        contribution.surface === "bottom_tab"
      )
    ) {
      errors.push(`${path} must pair bottom_tab surface with bottom_tab kind`);
    }
    if (
      contribution.surface === "bottom_tab" &&
      !NAVIGATION_UI_ALLOWED_EDITIONS.has(manifest.edition)
    ) {
      errors.push(
        `${path} bottom_tab is reserved for official or local_dev packs`,
      );
    }
  });
}

function validateAllowedKeys(object, path, allowedKeys, errors) {
  const unknownKeys = Object.keys(object).filter((key) => !allowedKeys.has(key));
  if (unknownKeys.length === 0) {
    return;
  }
  unknownKeys.sort();
  errors.push(`${path} contains unsupported keys: ${unknownKeys.join(", ")}`);
}

function validateStringValue(value, path, errors) {
  if (typeof value !== "string" || value.length === 0) {
    errors.push(`${path} must be a non-empty string`);
  }
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

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
