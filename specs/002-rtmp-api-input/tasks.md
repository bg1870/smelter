# Tasks: RTMP Input API Registration

**Input**: Design documents from `/specs/002-rtmp-api-input/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/README.md

**Tests**: Not explicitly requested in feature specification - tests are excluded from this task list.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: smelter-api crate at repository root
- Source: `smelter-api/src/`
- Module: `smelter-api/src/input/`

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Review existing input pattern from smelter-api/src/input/rtp.rs and smelter-api/src/input/rtp_into.rs
- [X] T002 Review core RTMP implementation in smelter-core/src/pipeline/rtmp/ and smelter-core/src/protocols/rtmp.rs

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 [P] Create RtmpInput API struct in smelter-api/src/input/rtmp.rs with serde and schemars derives
- [X] T004 [P] Create InputRtmpVideoOptions struct in smelter-api/src/input/rtmp.rs
- [X] T005 [P] Create RtmpVideoDecoderOptions enum in smelter-api/src/input/rtmp.rs with FfmpegH264 and VulkanH264 variants
- [X] T006 Implement TryFrom<RtmpInput> for RegisterInputOptions in smelter-api/src/input/rtmp_into.rs with validation logic
- [X] T007 Add rtmp module declaration to smelter-api/src/input.rs with public re-exports
- [ ] T008 Verify JSON schema generation includes RtmpInput by running cargo run -p tools --bin generate_json_schema

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Register Basic RTMP Stream (Priority: P1) 🎯 MVP

**Goal**: Enable users to register RTMP inputs with port and stream key, accept connections from encoders (OBS/FFmpeg), and process H.264/AAC streams

**Independent Test**: Register RTMP input via API, connect RTMP publisher (OBS/FFmpeg), verify stream is received and processed

### Implementation for User Story 1

- [ ] T009 [US1] Add doc comments to RtmpInput struct explaining RTMP concepts in smelter-api/src/input/rtmp.rs
- [ ] T010 [US1] Add doc comments to InputRtmpVideoOptions and RtmpVideoDecoderOptions in smelter-api/src/input/rtmp.rs
- [ ] T011 [US1] Implement port validation (1024-65535 range) in TryFrom conversion in smelter-api/src/input/rtmp_into.rs
- [ ] T012 [US1] Implement stream_key validation (non-empty) in TryFrom conversion in smelter-api/src/input/rtmp_into.rs
- [ ] T013 [US1] Implement default value application for timeout_seconds (default: 30) in smelter-api/src/input/rtmp_into.rs
- [ ] T014 [US1] Implement default value application for buffer (default: LatencyOptimized) in smelter-api/src/input/rtmp_into.rs
- [ ] T015 [US1] Implement default value application for required (default: false) in smelter-api/src/input/rtmp_into.rs
- [ ] T016 [US1] Implement conversion of video decoder options to core RtmpInputVideoDecoders in smelter-api/src/input/rtmp_into.rs
- [ ] T017 [US1] Implement conversion of offset_ms to Duration in QueueInputOptions in smelter-api/src/input/rtmp_into.rs
- [ ] T018 [US1] Construct RegisterInputOptions with ProtocolInputOptions::Rtmp and QueueInputOptions in smelter-api/src/input/rtmp_into.rs
- [ ] T019 [US1] Add unit test for minimal RtmpInput JSON deserialization (port + stream_key only) in smelter-api/src/input/rtmp.rs
- [ ] T020 [US1] Add unit test for full RtmpInput JSON deserialization (all fields) in smelter-api/src/input/rtmp.rs
- [ ] T021 [US1] Add unit test for deny_unknown_fields validation in smelter-api/src/input/rtmp.rs
- [ ] T022 [US1] Add unit test for successful TryFrom conversion with valid parameters in smelter-api/src/input/rtmp_into.rs
- [ ] T023 [US1] Add unit test for TryFrom conversion with default values in smelter-api/src/input/rtmp_into.rs
- [ ] T024 [US1] Generate TypeScript types by running pnpm run generate-types in typescript-sdk directory
- [ ] T025 [US1] Verify TypeScript SDK compiles successfully by running pnpm run build in typescript-sdk directory

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently - basic RTMP registration with port and stream key works

---

## Phase 4: User Story 2 - Configure Stream Parameters (Priority: P2)

**Goal**: Allow operators to fine-tune RTMP parameters including connection timeouts, decoder selection, and buffer settings for production deployments

**Independent Test**: Register RTMP inputs with various configurations (different timeouts, decoder types, buffer settings) and verify each parameter affects system behavior as expected

### Implementation for User Story 2

- [ ] T026 [US2] Implement timeout_seconds validation (5-300 range) in TryFrom conversion in smelter-api/src/input/rtmp_into.rs
- [ ] T027 [US2] Add error messages with field context for timeout validation in smelter-api/src/input/rtmp_into.rs
- [ ] T028 [US2] Add error messages with field context for port validation in smelter-api/src/input/rtmp_into.rs
- [ ] T029 [US2] Add error messages with field context for stream_key validation in smelter-api/src/input/rtmp_into.rs
- [ ] T030 [US2] Add unit test for TryFrom conversion failure with invalid port (< 1024) in smelter-api/src/input/rtmp_into.rs
- [ ] T031 [US2] Add unit test for TryFrom conversion failure with invalid port (> 65535) in smelter-api/src/input/rtmp_into.rs
- [ ] T032 [US2] Add unit test for TryFrom conversion failure with empty stream_key in smelter-api/src/input/rtmp_into.rs
- [ ] T033 [US2] Add unit test for TryFrom conversion failure with invalid timeout (< 5) in smelter-api/src/input/rtmp_into.rs
- [ ] T034 [US2] Add unit test for TryFrom conversion failure with invalid timeout (> 300) in smelter-api/src/input/rtmp_into.rs
- [ ] T035 [US2] Add unit test for decoder option conversion (FfmpegH264) in smelter-api/src/input/rtmp_into.rs
- [ ] T036 [US2] Add unit test for decoder option conversion (VulkanH264) in smelter-api/src/input/rtmp_into.rs
- [ ] T037 [US2] Add unit test for decoder option conversion (None/auto-select) in smelter-api/src/input/rtmp_into.rs
- [ ] T038 [US2] Add unit test for buffer option conversion (LatencyOptimized) in smelter-api/src/input/rtmp_into.rs
- [ ] T039 [US2] Add unit test for buffer option conversion (Const duration) in smelter-api/src/input/rtmp_into.rs
- [ ] T040 [US2] Add unit test for buffer option conversion (None) in smelter-api/src/input/rtmp_into.rs
- [ ] T041 [US2] Verify generated JSON schema includes validation constraints (port range, timeout range) in typescript-sdk/src/api.generated.ts

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently - parameter validation and configuration options are fully functional

---

## Phase 5: User Story 3 - Handle Stream Lifecycle Events (Priority: P3)

**Goal**: Provide operational visibility into stream lifecycle events including connections, disconnections, and errors for monitoring and troubleshooting

**Independent Test**: Observe system behavior during connection attempts with incorrect stream keys, publisher disconnections, and error scenarios

### Implementation for User Story 3

- [ ] T042 [US3] Document error handling strategy for stream key mismatch in smelter-api/src/input/rtmp.rs doc comments
- [ ] T043 [US3] Document error handling strategy for timeout scenarios in smelter-api/src/input/rtmp.rs doc comments
- [ ] T044 [US3] Document error handling strategy for decoder unavailability in smelter-api/src/input/rtmp.rs doc comments
- [ ] T045 [US3] Add example error messages to doc comments for TypeError cases in smelter-api/src/input/rtmp_into.rs
- [ ] T046 [US3] Verify error messages include field-level context for all validation failures in smelter-api/src/input/rtmp_into.rs
- [ ] T047 [US3] Add unit test for error message content and structure in smelter-api/src/input/rtmp_into.rs
- [ ] T048 [US3] Document expected runtime errors from core layer in smelter-api/src/input/rtmp.rs doc comments
- [ ] T049 [US3] Verify TypeScript types include error type information in typescript-sdk/src/api.generated.ts

**Checkpoint**: All user stories should now be independently functional - lifecycle event handling documentation is complete

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T050 [P] Update CLAUDE.md to include RTMP API layer technologies in active technologies section
- [ ] T051 [P] Add usage examples to doc comments for common RTMP configurations in smelter-api/src/input/rtmp.rs
- [ ] T052 [P] Verify all public API items have rustdoc comments in smelter-api/src/input/rtmp.rs
- [ ] T053 [P] Verify all public API items have rustdoc comments in smelter-api/src/input/rtmp_into.rs
- [ ] T054 Run cargo clippy on smelter-api crate and fix any warnings
- [ ] T055 Run cargo test on smelter-api crate and verify all tests pass
- [ ] T056 Verify JSON schema generation produces correct TypeScript types by running cargo run -p tools --bin generate_json_schema
- [ ] T057 Verify TypeScript SDK build succeeds with new types by running pnpm run build in typescript-sdk
- [ ] T058 [P] Create integration test example in integration-tests/ demonstrating RTMP registration (optional)
- [ ] T059 Cross-reference quickstart.md examples with actual API implementation to verify accuracy

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Extends validation logic from US1
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Documents error handling from US1 and US2

### Within Each User Story

- Struct definitions before conversion logic
- Conversion logic before unit tests
- Core implementation before integration tests
- Story complete before moving to next priority

### Parallel Opportunities

- T003, T004, T005 can run in parallel (different structs in same file)
- T009, T010 can run in parallel (different struct doc comments)
- T019, T020, T021 can run in parallel (different unit tests)
- T030-T041 can run in parallel (different unit tests)
- T042-T049 can run in parallel (different documentation tasks)
- T050, T051, T052, T053 can run in parallel (different documentation files)
- User Stories 1, 2, 3 can be developed in parallel after Foundational phase

---

## Parallel Example: Foundational Phase

```bash
# Launch struct creation tasks together:
Task: "Create RtmpInput API struct in smelter-api/src/input/rtmp.rs"
Task: "Create InputRtmpVideoOptions struct in smelter-api/src/input/rtmp.rs"
Task: "Create RtmpVideoDecoderOptions enum in smelter-api/src/input/rtmp.rs"
```

## Parallel Example: User Story 1

```bash
# Launch doc comment tasks together:
Task: "Add doc comments to RtmpInput struct in smelter-api/src/input/rtmp.rs"
Task: "Add doc comments to InputRtmpVideoOptions in smelter-api/src/input/rtmp.rs"

# Launch unit test tasks together:
Task: "Add unit test for minimal RtmpInput JSON deserialization"
Task: "Add unit test for full RtmpInput JSON deserialization"
Task: "Add unit test for deny_unknown_fields validation"
```

## Parallel Example: User Story 2

```bash
# Launch validation test tasks together:
Task: "Add unit test for invalid port (< 1024)"
Task: "Add unit test for invalid port (> 65535)"
Task: "Add unit test for empty stream_key"
Task: "Add unit test for invalid timeout (< 5)"
Task: "Add unit test for invalid timeout (> 300)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T002)
2. Complete Phase 2: Foundational (T003-T008) - CRITICAL - blocks all stories
3. Complete Phase 3: User Story 1 (T009-T025)
4. **STOP and VALIDATE**: Test User Story 1 independently with OBS or FFmpeg
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready (T001-T008)
2. Add User Story 1 → Test independently → Deploy/Demo (T009-T025) - MVP with basic RTMP registration!
3. Add User Story 2 → Test independently → Deploy/Demo (T026-T041) - Production-ready with parameter validation!
4. Add User Story 3 → Test independently → Deploy/Demo (T042-T049) - Operational monitoring complete!
5. Polish phase → Final quality pass (T050-T059)

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (T001-T008)
2. Once Foundational is done:
   - Developer A: User Story 1 (T009-T025)
   - Developer B: User Story 2 (T026-T041)
   - Developer C: User Story 3 (T042-T049)
3. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files or independent areas, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Total: 59 tasks across 6 phases
- MVP scope: Phases 1-3 (T001-T025) = 25 tasks
- Production-ready: Add Phase 4 (T001-T041) = 41 tasks
- Full feature: All phases (T001-T059) = 59 tasks
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- Integration with existing input registration endpoint is assumed to work via pattern matching (out of scope for this feature)
