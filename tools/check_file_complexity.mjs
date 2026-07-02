#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { resolve, sep } from "node:path";

const DEFAULT_LIMIT = 800;
const DEFAULT_BASELINE = "tools/file_complexity_baseline.json";
const SOURCE_EXTENSIONS = new Set([
  ".dart",
  ".java",
  ".js",
  ".jsx",
  ".kt",
  ".mjs",
  ".swift",
  ".ts",
  ".tsx",
]);
const EXCLUDED_SEGMENTS = new Set([
  ".dart_tool",
  "build",
  "generated",
  "integration_test",
  "node_modules",
  "RunnerTests",
  "test",
  "tests",
]);
const GENERATED_SUFFIXES = [
  ".freezed.dart",
  ".g.dart",
  ".gen.dart",
  ".generated.dart",
  ".gr.dart",
  ".mocks.dart",
];

const options = parseArgs(process.argv.slice(2));
const repoRoot = resolve(options.root);
const baselinePath = resolve(repoRoot, options.baseline);
const baseline = readBaseline(baselinePath);
const limit = options.limit ?? baseline.line_limit ?? DEFAULT_LIMIT;
const files = listSourceFiles(repoRoot);
const counts = new Map(
  files.map((filePath) => [filePath, countLines(resolve(repoRoot, filePath))]),
);
const baselineEntries = baseline.files ?? {};
const failures = [];
const improvements = [];

for (const [filePath, lineCount] of counts.entries()) {
  if (lineCount <= limit) {
    continue;
  }

  const baselineEntry = baselineEntries[filePath];
  if (!baselineEntry) {
    failures.push(
      `${filePath} has ${lineCount} lines, above the ${limit}-line limit, and is not in ${options.baseline}`,
    );
    continue;
  }

  if (!Number.isInteger(baselineEntry.max_lines)) {
    failures.push(`${filePath} baseline max_lines must be an integer`);
    continue;
  }

  if (lineCount > baselineEntry.max_lines) {
    failures.push(
      `${filePath} grew from baseline ${baselineEntry.max_lines} to ${lineCount} lines`,
    );
    continue;
  }

  if (lineCount < baselineEntry.max_lines) {
    improvements.push(
      `${filePath} is down to ${lineCount} lines from baseline ${baselineEntry.max_lines}`,
    );
  }
}

for (const [filePath, entry] of Object.entries(baselineEntries)) {
  if (!Number.isInteger(entry.max_lines)) {
    failures.push(`${filePath} baseline max_lines must be an integer`);
  }

  if (!counts.has(filePath)) {
    failures.push(
      `${filePath} is listed in ${options.baseline} but is missing or outside the checked source scope`,
    );
    continue;
  }

  const lineCount = counts.get(filePath);
  if (lineCount <= limit) {
    failures.push(
      `${filePath} is now ${lineCount} lines, at or below the ${limit}-line limit; remove it from ${options.baseline}`,
    );
  }
}

if (failures.length > 0) {
  console.error("File complexity check failed:");
  for (const failure of failures) {
    console.error(`  - ${failure}`);
  }
  if (improvements.length > 0) {
    console.error("");
    console.error("Files that improved but still need the baseline:");
    for (const improvement of improvements) {
      console.error(`  - ${improvement}`);
    }
  }
  process.exit(1);
}

console.log(
  `File complexity check passed: ${counts.size} production source files checked, ${Object.keys(baselineEntries).length} baseline debts, ${limit}-line limit.`,
);
if (improvements.length > 0) {
  console.log("Improved over-budget files:");
  for (const improvement of improvements) {
    console.log(`  - ${improvement}`);
  }
}

function parseArgs(args) {
  const parsed = {
    baseline: DEFAULT_BASELINE,
    root: process.cwd(),
  };

  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    if (arg === "--baseline") {
      parsed.baseline = readValue(args, ++index, arg);
    } else if (arg === "--limit") {
      const value = Number.parseInt(readValue(args, ++index, arg), 10);
      if (!Number.isInteger(value) || value <= 0) {
        throw new Error("--limit must be a positive integer");
      }
      parsed.limit = value;
    } else if (arg === "--root") {
      parsed.root = readValue(args, ++index, arg);
    } else if (arg === "--help" || arg === "-h") {
      printUsage();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return parsed;
}

function readValue(args, index, flag) {
  const value = args[index];
  if (!value) {
    throw new Error(`${flag} requires a value`);
  }
  return value;
}

function printUsage() {
  console.log(`Usage: node tools/check_file_complexity.mjs [options]

Options:
  --baseline <path>  Baseline JSON path. Defaults to ${DEFAULT_BASELINE}.
  --limit <lines>    Line limit. Defaults to the baseline line_limit or ${DEFAULT_LIMIT}.
  --root <path>      Repository root. Defaults to the current working directory.
`);
}

function readBaseline(filePath) {
  if (!existsSync(filePath)) {
    throw new Error(`Baseline file does not exist: ${filePath}`);
  }

  const baseline = JSON.parse(readFileSync(filePath, "utf8"));
  if (!baseline || typeof baseline !== "object" || Array.isArray(baseline)) {
    throw new Error("Baseline must be a JSON object");
  }
  if (!baseline.files || typeof baseline.files !== "object") {
    throw new Error("Baseline must contain a files object");
  }
  return baseline;
}

function listSourceFiles(root) {
  const output = execFileSync(
    "git",
    ["ls-files", "--cached", "--others", "--exclude-standard", "-z", "apps", "packages", "tools"],
    {
      cwd: root,
      encoding: "utf8",
      maxBuffer: 1024 * 1024 * 20,
    },
  );

  return output
    .split("\0")
    .filter(Boolean)
    .filter((filePath) => isSourceFile(filePath))
    .sort();
}

function isSourceFile(filePath) {
  const normalized = filePath.split(sep).join("/");
  if (!startsWithCheckedRoot(normalized)) {
    return false;
  }
  if (hasExcludedSegment(normalized)) {
    return false;
  }
  if (GENERATED_SUFFIXES.some((suffix) => normalized.endsWith(suffix))) {
    return false;
  }
  return SOURCE_EXTENSIONS.has(extensionOf(normalized));
}

function startsWithCheckedRoot(filePath) {
  return (
    filePath.startsWith("apps/") ||
    filePath.startsWith("packages/") ||
    filePath.startsWith("tools/")
  );
}

function hasExcludedSegment(filePath) {
  return filePath
    .split("/")
    .some((segment) => EXCLUDED_SEGMENTS.has(segment));
}

function extensionOf(filePath) {
  const basename = filePath.split("/").at(-1) ?? filePath;
  const dotIndex = basename.lastIndexOf(".");
  return dotIndex === -1 ? "" : basename.slice(dotIndex);
}

function countLines(filePath) {
  const contents = readFileSync(filePath, "utf8");
  if (contents.length === 0) {
    return 0;
  }

  const normalized = contents.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
  const trailingNewline = normalized.endsWith("\n") ? 1 : 0;
  return normalized.split("\n").length - trailingNewline;
}
