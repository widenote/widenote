---
id: ADR-0008
title: Use dev and prod mobile flavors first
status: accepted
date: 2026-06-25
owners: [mobile, release]
tags: [mobile, android, flavors, release]
supersedes: []
superseded_by:
sources:
  - ../architecture/engineering-rules.md
  - ../../apps/mobile/README.md
  - https://github.com/memex-lab/memex/blob/main/BUILD.md
  - https://github.com/memex-lab/memex/blob/main/android/app/build.gradle.kts
---

# Use Dev and Prod Mobile Flavors First

## Context

WideNote needs development builds and formal release builds to coexist on the
same Android device. Memex uses separate market and channel variants, including
global, China, Early, and Dev packages. WideNote does not yet have concrete
store, compliance, provider-default, or distribution requirements that justify a
China/global split.

## Decision

Use a single mobile release-channel flavor axis for now:

- `dev`: development and QA builds, installed as `app.widenote.dev` and labeled
  `WideNote Dev`.
- `prod`: formal release builds, installed as `app.widenote` and labeled
  `WideNote`.

Do not add China/global flavors in the current phase.

## Considered Options

- Mirror Memex with `globalDev`, `cnDev`, `global`, `cn`, and possible Early
  variants.
- Use only Android build types, with no product flavor.
- Use one release-channel flavor axis: `dev` and `prod`.

## Rationale

The release-channel axis solves the immediate operational need: development
builds can be installed next to formal builds without data, launcher, or package
identity collisions.

Deferring China/global avoids encoding market assumptions before WideNote has
real store policy, provider default, privacy notice, update channel, or
compliance differences. If those differences become real, they can be added as a
second flavor axis instead of overloading debug and release semantics.

## Consequences

- Android run and build commands must pass `--flavor dev` or `--flavor prod`.
- The production Android package identity is `app.widenote`.
- Development builds use a visible `WideNote Dev` launcher label.
- Android `devRelease` builds may use debug signing for local QA.
- Android `prodRelease` builds must use configured release signing from local
  environment variables or gitignored `key.properties`; they must not silently
  fall back to debug signing.
- iOS scheme/config work should follow the same `dev`/`prod` channel model when
  an iOS project is added.
- Market-specific behavior must remain absent until a later ADR or RFC accepts a
  China/global split.

## Follow-ups

- Add iOS `dev` and `prod` schemes when the iOS project is introduced.
- Revisit market flavors only when store, provider, compliance, or update policy
  requirements make the split concrete.
