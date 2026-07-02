# Tools

Repository automation and validation scripts live here.

## Current Tools

- `pack_validator/validate.mjs`: lightweight phase-one Agent Pack manifest
  validator for official manifests.
- `pack_validator/validate_test.mjs`: validator regression tests.
- `check_file_complexity.mjs`: production source file line-count ratchet with
  an explicit baseline for existing over-budget files.
- `file_complexity_baseline.json`: current over-budget file debt list and
  maximum allowed line counts.

Run the current manifest checks from the repository root:

```sh
node tools/pack_validator/validate_test.mjs
node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json packs/official/pkm_library/manifest.json packs/official/transcript_correction/manifest.json packs/marketplace/index.json
```

Schema fixture validation currently lives with the schema package:

```sh
node packages/schemas/validate_fixtures.mjs
```

Production source file complexity checks use the ratchet baseline:

```sh
node tools/check_file_complexity.mjs
```

## Expected Future Contents

- Schema code generation
- ADR/RFC linting
- Documentation consistency checks
- Local development helpers
