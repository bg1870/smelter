<!--
SYNC IMPACT REPORT
==================
Version: 0.0.0 → 1.0.0 (MAJOR: Initial constitution ratification)

Modified Principles:
- All principles are new (initial creation)

Added Sections:
- Core Principles (8 principles total)
- Architecture Constraints
- Quality Standards
- Governance

Removed Sections:
- None (initial creation)

Templates Requiring Updates:
- ✅ .specify/templates/plan-template.md - Constitution Check section aligned
- ✅ .specify/templates/spec-template.md - Requirements sections aligned
- ✅ .specify/templates/tasks-template.md - Task categorization aligned
- ✅ .specify/templates/agent-file-template.md - No updates needed (generic)
- ✅ .specify/templates/checklist-template.md - No updates needed

Follow-up TODOs:
- None
-->

# Smelter Constitution

## Core Principles

### I. Modular Architecture (NON-NEGOTIABLE)

Smelter MUST maintain clear separation of concerns across its crate architecture:

- `smelter-core`: Library-first implementation with no HTTP dependencies
- `smelter-api`: Type definitions and JSON serialization separate from business logic
- `smelter-render`: Rendering engine independent of encoding/decoding
- Each crate MUST be independently testable and have a clear, singular purpose
- Dependencies MUST flow inward: api → core → render, never in reverse

**Rationale**: Modular architecture enables independent testing, flexible deployment models (standalone server, WASM, embedded), and prevents tight coupling that hinders evolution. This separation has proven critical for supporting both Node.js and browser WASM targets.

### II. Real-Time Performance First

All features MUST be designed with real-time, low-latency video composition as the primary constraint:

- Performance characteristics MUST be documented in implementation plans
- New features MUST include performance goals (e.g., frame rate, latency targets)
- CPU-intensive operations MUST be profiled and justified
- Memory allocations in hot paths MUST be minimized
- Breaking real-time guarantees requires explicit architecture review

**Rationale**: Smelter's core value proposition is real-time multimedia composition. Performance regressions directly impact user experience and production viability. Late-discovered performance issues are exponentially more costly to fix.

### III. API Compatibility & Stability

TypeScript SDK and Rust API MUST remain synchronized and backward compatible:

- API changes MUST land in the same PR for both Rust and TypeScript
- JSON schema MUST be regenerated via `cargo run -p tools --bin generate_json_schema`
- TypeScript types MUST be regenerated via `pnpm run generate-types`
- Breaking changes require MAJOR version bump and migration guide
- All `api.generated.ts` diff content MUST be addressed in the PR

**Rationale**: Cross-language API consistency prevents runtime failures and reduces integration friction. Automated schema generation ensures contract accuracy. Separate PRs create integration windows where SDK and server are incompatible.

### IV. Comprehensive Test Coverage

All code paths MUST be covered by appropriate test types:

- **Snapshot tests**: Rendering correctness (compare PNG outputs in `integration-tests/snapshots/render_snapshots/`)
- **Pipeline tests**: End-to-end video/audio generation (compare RTP dumps in `integration-tests/snapshots/rtp_packet_dumps/`)
- **Unit tests**: Business logic and edge cases
- **Contract tests**: API endpoint behavior and schema compliance

New features MUST include tests demonstrating the feature works before merge. Test-first development (writing tests before implementation) is STRONGLY RECOMMENDED but not mandatory. The focus is achieving comprehensive coverage that catches regressions.

**Rationale**: Multimedia composition has complex state interactions that are hard to reason about. Snapshot tests catch visual regressions. Pipeline tests ensure temporal correctness. Without comprehensive testing, refactoring becomes prohibitively risky.

### V. Cross-Platform Consistency

Rendering output MUST be deterministic and consistent across platforms:

- Snapshot tests MUST produce identical output on Linux, macOS, and Windows (where supported)
- Platform-specific code paths MUST be clearly isolated and documented
- WebGPU/Vulkan/Metal backends MUST produce visually equivalent results
- WASM builds MUST maintain functional parity with native builds where architecturally feasible

**Rationale**: Users expect consistent output regardless of deployment environment. Non-deterministic rendering breaks snapshot tests and erodes confidence. Platform-specific bugs are expensive to diagnose and fix.

### VI. Documentation & Developer Experience

Code and features MUST be documented for both library users and contributors:

- Public APIs MUST have doc comments explaining purpose, parameters, and examples
- Architecture decisions MUST be captured in `DEVELOPMENT.md` or design documents
- Breaking changes MUST include migration guides in `CHANGELOG`
- Build and test instructions MUST remain up-to-date in `README.md` and `DEVELOPMENT.md`

**Rationale**: Smelter serves both TypeScript developers (via SDK) and Rust developers (via library). Poor documentation creates friction, increases support burden, and slows onboarding. Complex multimedia systems require clear mental models.

### VII. Vulkan Video & Hardware Acceleration

Hardware acceleration features (`vk-video`) MUST maintain portability and fallback strategies:

- Features requiring Vulkan MUST gracefully degrade or provide CPU fallbacks where feasible
- Platform support matrix MUST be documented (Windows, Linux with Vulkan, exclusions)
- Hardware-accelerated paths MUST be optional features, not hard requirements
- Performance improvements from hardware acceleration MUST be measured and documented

**Rationale**: Hardware capabilities vary across deployment environments. Hard dependencies on GPU features limit portability. Graceful degradation maximizes Smelter's applicability while still leveraging available hardware.

### VIII. Observability & Debugging

All runtime behavior MUST be observable for production debugging:

- Structured logging MUST be used (via `tracing` crate with JSON output support)
- Performance-critical paths MUST include trace spans for profiling
- Error messages MUST be actionable (include context, suggest fixes)
- Integration tests MUST support debugging via `play_rtp_dump` and similar tools

**Rationale**: Multimedia composition failures are often time-dependent and hard to reproduce. Structured logging enables post-mortem analysis. Rich diagnostics reduce time-to-resolution for production issues.

## Architecture Constraints

### Crate Dependency Rules

- `smelter` (root) MAY depend on: `smelter-core`, `smelter-api`, `smelter-render`, `libcef`
- `smelter-core` MAY depend on: `smelter-render`, `vk-video`, but NOT `smelter-api`
- `smelter-api` MUST NOT depend on any other Smelter crates (pure types)
- `smelter-render` MAY depend on: `wgpu`, `glyphon`, but NOT `smelter-core` or `smelter-api`
- Circular dependencies between Smelter crates are FORBIDDEN

### Binary Organization

- Standalone server: `src/bin/main_process.rs`
- Chromium helper: `src/bin/process_helper.rs` (requires `web-renderer` feature)
- Internal tools: `tools/src/bin/`
- Test utilities: `integration-tests/src/bin/`

Each binary MUST have a single, well-defined purpose.

### Feature Flag Discipline

- Default features MUST represent the most common use case
- Platform-specific features MUST use Cargo target conditionals (e.g., `cfg(not(target_arch = "wasm32"))`)
- Optional integrations (DeckLink, web-renderer) MUST be behind feature flags
- Feature combinations MUST be tested in CI

## Quality Standards

### Test Requirements

All PRs MUST pass:

1. `cargo nextest run --workspace --profile ci`
2. Snapshot validation (no unexpected changes to committed snapshots)
3. Clippy lints (`cargo clippy --workspace`)
4. Format checks (`cargo fmt --check`)

### Snapshot Update Process

When snapshots intentionally change:

1. Run tests with `--features update_snapshots` for affected tests only
2. Create PR in `smelter-labs/smelter-snapshot-tests` repository with updated snapshots
3. Create PR in main repository linking to snapshot PR
4. Merge both PRs together (coordinate via PR comments)

### Code Review Focus

Reviewers MUST verify:

- Performance impact documented for rendering/encoding paths
- API changes include both Rust and TypeScript updates
- Tests cover new behavior (unit, integration, or snapshot as appropriate)
- Architecture constraints respected (crate dependencies, feature flags)
- Error handling includes context for debugging

## Governance

### Amendment Process

This constitution MAY be amended via:

1. Proposal documented in `.specify/memory/` with rationale
2. Team review and approval (async or in planning meeting)
3. Version bump following semantic versioning (see below)
4. Update all dependent templates (plan, spec, tasks, commands)

### Versioning Policy

- **MAJOR**: Backward incompatible changes (principle removal, contradictory additions)
- **MINOR**: New principles or sections that expand scope
- **PATCH**: Clarifications, wording improvements, non-semantic refinements

### Compliance

- All PRs MUST be reviewed for constitution compliance
- Constitution violations MUST be justified in PR description or rejected
- The `/speckit.plan` command MUST include a "Constitution Check" section verifying compliance
- Complexity that violates constraints MUST be documented in plan.md with alternatives considered

### Living Document

This constitution is a living document. It captures current consensus but MUST evolve as Smelter grows. Disagreements about interpretation MUST be resolved via amendment (clarification), not ignored.

**Version**: 1.0.0 | **Ratified**: 2025-11-10 | **Last Amended**: 2025-11-10
