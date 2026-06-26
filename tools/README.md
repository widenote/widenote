# Tools

Repository automation and validation scripts live here.

## Current Tools

- `pack_validator/validate.mjs`: lightweight phase-one Agent Pack manifest
  validator for official manifests.
- `pack_validator/validate_test.mjs`: validator regression tests.

Run the current manifest checks from the repository root:

```sh
node tools/pack_validator/validate_test.mjs
node tools/pack_validator/validate.mjs packs/official/default/manifest.json packs/official/todo/manifest.json
```

Schema fixture validation currently lives with the schema package:

```sh
node packages/schemas/validate_fixtures.mjs
```

## Expected Future Contents

- Schema code generation
- ADR/RFC linting
- Documentation consistency checks
- Local development helpers
