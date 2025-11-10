# Implementation Plan: RTMP Input API Registration

**Branch**: `002-rtmp-api-input` | **Date**: 2025-11-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-rtmp-api-input/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement RTMP input registration at the smelter-api layer by creating API data structures (RtmpInput) and conversion logic (TryFrom implementation) to translate API requests into core layer RtmpInputOptions. This enables users to register RTMP streams via the API by specifying port, stream key, timeout, decoder preferences, and buffer settings. The implementation follows established patterns from existing inputs (RTP, HLS, WHIP) and leverages the already-functional RTMP core implementation.

## Technical Context

**Language/Version**: Rust 2024 edition
**Primary Dependencies**: schemars (JSON schema), serde (serialization), smelter-core (RTMP implementation), ffmpeg-next (via core)
**Storage**: N/A (streaming data only, no persistence)
**Testing**: cargo test (unit tests for conversion logic), integration tests (end-to-end RTMP streaming)
**Target Platform**: Linux server (primary), macOS (development), Docker containers
**Project Type**: Single project (library crate: smelter-api)
**Performance Goals**: Real-time video processing (30-60 fps), low-latency RTMP ingest (<2 second glass-to-glass latency)
**Constraints**: Must not introduce blocking operations in API layer, validation must complete in <10ms, integration with existing input registration pattern
**Scale/Scope**: API layer additions only (~200-300 LOC), 2 new files (rtmp.rs, rtmp_into.rs), updates to input.rs module

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Verify compliance with `.specify/memory/constitution.md`:

- [x] **Modular Architecture**: ✅ PASS - Feature adds API layer structs in smelter-api crate only, uses existing core layer RtmpInputOptions. No new dependencies between crates. Flow is api → core (correct direction).
- [x] **Real-Time Performance**: ✅ PASS - Performance goals documented (30-60 fps, <2s latency, <10ms validation). API layer only performs lightweight validation and type conversion (non-blocking). Heavy lifting (RTMP protocol, decoding) already in core.
- [x] **API Compatibility**: ✅ PASS - New API structs (RtmpInput) require JSON schema + TypeScript type generation. Will run `cargo run -p tools --bin generate_json_schema` and `pnpm run generate-types` as part of implementation.
- [x] **Test Coverage**: ✅ PASS - Unit tests for TryFrom conversion logic planned. Integration tests will leverage existing RTMP core tests (already functional). Contract tests via JSON schema validation.
- [x] **Cross-Platform**: ✅ PASS - API layer is pure Rust data structures (platform-independent). Core RTMP implementation handles platform specifics. No rendering changes, so output determinism unaffected.
- [x] **Documentation**: ✅ PASS - Public API structs will have doc comments explaining RTMP concepts. This plan.md captures architecture decisions. Quickstart.md will provide usage examples.
- [x] **Hardware Acceleration**: ✅ PASS - Decoder selection (FFmpeg vs Vulkan H.264) exposed as optional API parameter. Fallback strategy inherited from core implementation (auto-select based on Vulkan support).
- [x] **Observability**: ✅ PASS - Error messages from conversion failures will include field-level context. Structured logging happens in core layer (already implemented). API layer errors use TypeError for actionable messages.

**Violations Requiring Justification**: None

## Project Structure

### Documentation (this feature)

```text
specs/002-rtmp-api-input/
├── spec.md              # Feature specification (already created)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── README.md        # API contract documentation
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
smelter-api/src/
├── input/
│   ├── rtmp.rs          # NEW: RtmpInput API struct with JSON schema
│   ├── rtmp_into.rs     # NEW: TryFrom<RtmpInput> for core::RegisterInputOptions
│   ├── rtp.rs           # EXISTING: Reference implementation
│   ├── rtp_into.rs      # EXISTING: Reference implementation
│   ├── whip.rs          # EXISTING: Reference implementation
│   ├── whip_into.rs     # EXISTING: Reference implementation
│   └── ...              # Other input types
├── input.rs             # MODIFIED: Add rtmp module declaration and re-exports
└── lib.rs               # UNCHANGED: Already re-exports input module

smelter-core/src/
├── pipeline/rtmp/       # EXISTING: Core RTMP implementation (already functional)
│   ├── rtmp_input.rs    # EXISTING: RtmpInput struct and server logic
│   └── ...
├── protocols/rtmp.rs    # EXISTING: RtmpInputOptions struct
└── input.rs             # EXISTING: ProtocolInputOptions enum (already has Rtmp variant)

integration-tests/
└── snapshots/           # EXISTING: Will add RTMP-specific tests if needed
    └── rtp_packet_dumps/

tools/src/bin/
└── generate_json_schema.rs  # EXISTING: Will include new RtmpInput in generated schema
```

**Structure Decision**: Single project (library crate). This feature only adds API layer structures to the existing smelter-api crate. Following the established pattern:
- `rtmp.rs` contains the public API struct (RtmpInput) with serde/schemars derives
- `rtmp_into.rs` contains the TryFrom implementation to convert API types to core types
- Both files mirror the structure of existing inputs (RTP, WHIP, HLS)
- No new crates or binaries required

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

N/A - No constitution violations. All principles pass.

## Post-Design Constitution Review

*Re-evaluated after Phase 1 (Design) completion*

All constitution checks remain **PASS**:

- ✅ **Modular Architecture**: Confirmed - Only smelter-api crate modified (rtmp.rs, rtmp_into.rs, input.rs). No cross-crate dependencies added.
- ✅ **Real-Time Performance**: Confirmed - API layer validation lightweight (<10ms). Data model documented in data-model.md shows minimal allocations.
- ✅ **API Compatibility**: Confirmed - Contracts documented in contracts/README.md with JSON schema and TypeScript generation steps.
- ✅ **Test Coverage**: Confirmed - Contract tests defined. Unit tests for TryFrom conversions. Integration tests reuse existing RTMP core tests.
- ✅ **Cross-Platform**: Confirmed - API types are platform-agnostic. No platform-specific code in API layer.
- ✅ **Documentation**: Confirmed - quickstart.md created with usage examples. data-model.md documents all entities. Doc comments planned for public API.
- ✅ **Hardware Acceleration**: Confirmed - Decoder selection exposed at API level. Fallback to FFmpeg documented. Vulkan requirements noted.
- ✅ **Observability**: Confirmed - Error handling strategy documented in research.md. TypeError messages include field context.

**Design Artifacts Generated**:
- ✅ research.md - Technical decisions and alternatives
- ✅ data-model.md - Entity structures and relationships
- ✅ contracts/README.md - API contracts and JSON schema
- ✅ quickstart.md - Usage examples and troubleshooting

**Conclusion**: Feature design complies with all constitution principles. Ready for implementation (Phase 2: Tasks).
