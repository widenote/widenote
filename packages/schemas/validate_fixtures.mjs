#!/usr/bin/env node

import { readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const packageDir = dirname(fileURLToPath(import.meta.url));
const defaultManifestPath = join(packageDir, "fixtures", "manifest.json");

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  runCli(process.argv.slice(2));
}

function runCli(args) {
  const manifestPath = args[0] ? resolve(args[0]) : defaultManifestPath;
  const results = validateFixtureManifest(manifestPath);
  let errorCount = 0;

  for (const result of results) {
    if (result.errors.length === 0) {
      console.log(`${result.fixturePath}: ok`);
      continue;
    }

    errorCount += result.errors.length;
    console.error(`${result.fixturePath}: invalid`);
    for (const error of result.errors) {
      console.error(`  - ${error}`);
    }
  }

  if (errorCount > 0) {
    console.error(
      `${errorCount} schema fixture ${errorCount === 1 ? "error" : "errors"} found.`,
    );
    process.exit(1);
  }
}

export function validateFixtureManifest(manifestPath = defaultManifestPath) {
  const manifest = readJson(manifestPath);
  if (!Array.isArray(manifest.fixtures)) {
    throw new Error(`${manifestPath}: fixtures must be an array`);
  }

  const baseDir = dirname(manifestPath);
  return manifest.fixtures.map((entry, index) => {
    if (!entry || typeof entry !== "object") {
      return {
        fixturePath: `${manifestPath}#fixtures[${index}]`,
        errors: ["fixture entry must be an object"],
      };
    }

    const schemaPath = resolve(baseDir, entry.schema);
    const fixturePath = resolve(baseDir, entry.fixture);
    const schema = readJson(schemaPath);
    const fixture = readJson(fixturePath);
    const errors = validateAgainstSchema(fixture, schema);
    return { fixturePath, schemaPath, errors };
  });
}

export function validateAgainstSchema(value, schema) {
  return validateValue(value, schema, { root: schema }, "$");
}

function validateValue(value, schema, context, path) {
  if (!schema || typeof schema !== "object") {
    return [`${path}: schema must be an object`];
  }

  const errors = [];

  if (schema.$ref) {
    errors.push(
      ...validateValue(value, resolveLocalRef(schema.$ref, context.root), context, path),
    );
    return errors;
  }

  if (schema.oneOf) {
    return validateOneOf(value, schema.oneOf, context, path);
  }

  if (schema.anyOf) {
    return validateAnyOf(value, schema.anyOf, context, path);
  }

  if ("const" in schema && !deepEqual(value, schema.const)) {
    errors.push(`${path}: expected const ${JSON.stringify(schema.const)}`);
  }

  if (schema.enum && !schema.enum.some((item) => deepEqual(item, value))) {
    errors.push(`${path}: expected one of ${schema.enum.map(formatValue).join(", ")}`);
  }

  if (schema.type) {
    const allowedTypes = Array.isArray(schema.type) ? schema.type : [schema.type];
    if (!allowedTypes.some((type) => matchesType(value, type))) {
      errors.push(`${path}: expected type ${allowedTypes.join(" or ")}`);
      return errors;
    }

    if (value === null && allowedTypes.includes("null")) {
      return errors;
    }
  }

  if (isPlainObject(value)) {
    errors.push(...validateObject(value, schema, context, path));
  }

  if (Array.isArray(value)) {
    errors.push(...validateArray(value, schema, context, path));
  }

  if (typeof value === "string") {
    errors.push(...validateString(value, schema, path));
  }

  if (typeof value === "number") {
    errors.push(...validateNumber(value, schema, path));
  }

  return errors;
}

function validateOneOf(value, schemas, context, path) {
  if (!Array.isArray(schemas)) {
    return [`${path}: oneOf must be an array`];
  }

  const results = schemas.map((child) => validateValue(value, child, context, path));
  const matchCount = results.filter((result) => result.length === 0).length;
  if (matchCount === 1) {
    return [];
  }

  if (matchCount === 0) {
    return [
      `${path}: did not match any oneOf branch`,
      ...results.flat().slice(0, 6),
    ];
  }

  return [`${path}: matched ${matchCount} oneOf branches`];
}

function validateAnyOf(value, schemas, context, path) {
  if (!Array.isArray(schemas)) {
    return [`${path}: anyOf must be an array`];
  }

  const results = schemas.map((child) => validateValue(value, child, context, path));
  if (results.some((result) => result.length === 0)) {
    return [];
  }

  return [
    `${path}: did not match any anyOf branch`,
    ...results.flat().slice(0, 6),
  ];
}

function validateObject(value, schema, context, path) {
  const errors = [];
  const properties = schema.properties ?? {};

  if (Array.isArray(schema.required)) {
    for (const field of schema.required) {
      if (!(field in value)) {
        errors.push(`${path}: missing required field ${field}`);
      }
    }
  }

  for (const [field, fieldSchema] of Object.entries(properties)) {
    if (field in value) {
      errors.push(
        ...validateValue(value[field], fieldSchema, context, `${path}.${field}`),
      );
    }
  }

  if (schema.additionalProperties === false) {
    for (const field of Object.keys(value)) {
      if (!(field in properties)) {
        errors.push(`${path}: unexpected field ${field}`);
      }
    }
  } else if (
    schema.additionalProperties &&
    typeof schema.additionalProperties === "object"
  ) {
    for (const [field, fieldValue] of Object.entries(value)) {
      if (!(field in properties)) {
        errors.push(
          ...validateValue(
            fieldValue,
            schema.additionalProperties,
            context,
            `${path}.${field}`,
          ),
        );
      }
    }
  }

  return errors;
}

function validateArray(value, schema, context, path) {
  const errors = [];

  if (Number.isInteger(schema.minItems) && value.length < schema.minItems) {
    errors.push(`${path}: expected at least ${schema.minItems} item(s)`);
  }

  if (schema.uniqueItems) {
    const seen = new Set();
    value.forEach((item, index) => {
      const key = JSON.stringify(item);
      if (seen.has(key)) {
        errors.push(`${path}[${index}]: duplicate array item`);
      }
      seen.add(key);
    });
  }

  if (schema.items) {
    value.forEach((item, index) => {
      errors.push(...validateValue(item, schema.items, context, `${path}[${index}]`));
    });
  }

  return errors;
}

function validateString(value, schema, path) {
  const errors = [];

  if (Number.isInteger(schema.minLength) && value.length < schema.minLength) {
    errors.push(`${path}: expected length >= ${schema.minLength}`);
  }

  if (schema.pattern && !new RegExp(schema.pattern).test(value)) {
    errors.push(`${path}: did not match pattern ${schema.pattern}`);
  }

  if (schema.format === "date-time" && Number.isNaN(Date.parse(value))) {
    errors.push(`${path}: expected date-time`);
  }

  if (schema.format === "uri" && !isUri(value)) {
    errors.push(`${path}: expected uri`);
  }

  return errors;
}

function validateNumber(value, schema, path) {
  const errors = [];

  if (typeof schema.minimum === "number" && value < schema.minimum) {
    errors.push(`${path}: expected >= ${schema.minimum}`);
  }

  if (typeof schema.maximum === "number" && value > schema.maximum) {
    errors.push(`${path}: expected <= ${schema.maximum}`);
  }

  return errors;
}

function resolveLocalRef(ref, root) {
  if (!ref.startsWith("#/")) {
    throw new Error(`Only local JSON Schema refs are supported: ${ref}`);
  }

  return ref
    .slice(2)
    .split("/")
    .map((part) => part.replace(/~1/g, "/").replace(/~0/g, "~"))
    .reduce((node, part) => {
      if (!node || typeof node !== "object" || !(part in node)) {
        throw new Error(`Unresolved JSON Schema ref: ${ref}`);
      }
      return node[part];
    }, root);
}

function matchesType(value, type) {
  return switchType(type, {
    string: () => typeof value === "string",
    integer: () => Number.isInteger(value),
    number: () => typeof value === "number" && Number.isFinite(value),
    object: () => isPlainObject(value),
    array: () => Array.isArray(value),
    boolean: () => typeof value === "boolean",
    null: () => value === null,
  });
}

function switchType(type, handlers) {
  if (type in handlers) {
    return handlers[type]();
  }
  throw new Error(`Unsupported JSON Schema type: ${type}`);
}

function readJson(path) {
  return JSON.parse(readFileSync(path, "utf8"));
}

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function deepEqual(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function isUri(value) {
  try {
    const url = new URL(value);
    return url.protocol.length > 1;
  } catch (_) {
    return false;
  }
}

function formatValue(value) {
  return JSON.stringify(value);
}
