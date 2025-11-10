# Tasks: RTMP Input Pipeline

**Input**: Design documents from `/specs/001-rtmp-input-pipeline/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Tests are NOT explicitly requested in this specification, so test tasks are minimal (integration tests only).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This is a single-project repository (smelter-core library):
- Source: `smelter-core/src/`
- Tests: `integration-tests/tests/`
- Utilities: `integration-tests/src/bin/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Create RTMP module directory at smelter-core/src/pipeline/rtmp/
- [ ] T002 [P] Verify FFmpeg RTMP support is available in existing ffmpeg-next dependency

**Checkpoint**: Project structure ready for RTMP implementation

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T003 Add Rtmp variant to Input enum in smelter-core/src/input.rs
- [ ] T004 [P] Create RtmpInputOptions struct in smelter-core/src/pipeline/rtmp/mod.rs
- [ ] T005 [P] Create RtmpInput struct skeleton in smelter-core/src/pipeline/rtmp/mod.rs
- [ ] T006 Add FfmpegInputContext::new_rtmp_server() method in smelter-core/src/pipeline/utils/ffmpeg_input_context.rs
- [ ] T007 Export RtmpInput and RtmpInputOptions from smelter-core/src/pipeline/rtmp/mod.rs

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Receive Live RTMP Stream (Priority: P1) 🎯 MVP

**Goal**: Enable the system to accept RTMP connections from broadcasting software and successfully ingest and decode video/audio streams

**Independent Test**: Configure an RTMP publisher (FFmpeg or OBS) to stream to the Smelter endpoint, verify that both audio and video packets are received and decoded, and confirm processed frames are available to the pipeline

### Implementation for User Story 1

- [ ] T008 [US1] Implement RtmpInputOptions with validation in smelter-core/src/pipeline/rtmp/mod.rs (port, stream_key, buffer, video_decoders, timeout)
- [ ] T009 [US1] Implement FfmpegInputContext::new_rtmp_server() with FFmpeg listen mode configuration in smelter-core/src/pipeline/utils/ffmpeg_input_context.rs
- [ ] T010 [US1] Implement stream key validation function in smelter-core/src/pipeline/rtmp/mod.rs (extract from URL and validate)
- [ ] T011 [US1] Implement RtmpInput::new_input() method in smelter-core/src/pipeline/rtmp/mod.rs (create FFmpeg context, validate stream key)
- [ ] T012 [US1] Implement audio track handling in RtmpInput following HLS pattern in smelter-core/src/pipeline/rtmp/mod.rs (spawn AudioDecoderThread)
- [ ] T013 [US1] Implement video track handling in RtmpInput following HLS pattern in smelter-core/src/pipeline/rtmp/mod.rs (spawn VideoDecoderThread)
- [ ] T014 [US1] Implement demuxer thread spawning in smelter-core/src/pipeline/rtmp/mod.rs (av_read_frame loop, packet routing)
- [ ] T015 [US1] Add RTMP-optimized InputBufferOptions defaults in smelter-core/src/pipeline/utils/input_buffer.rs (500ms buffer_duration for low latency)
- [ ] T016 [US1] Add structured logging for RTMP connection events in smelter-core/src/pipeline/rtmp/mod.rs (connection, stream info, codec details)
- [ ] T017 [US1] Handle audio-only and video-only streams correctly in smelter-core/src/pipeline/rtmp/mod.rs (gracefully handle missing tracks)

**Checkpoint**: At this point, User Story 1 should be fully functional - can receive RTMP stream, decode audio/video, and provide frames to pipeline

---

## Phase 4: User Story 2 - Handle Connection Interruptions (Priority: P2)

**Goal**: Gracefully handle network interruptions, disconnections, and errors without crashing or corrupting pipeline state

**Independent Test**: Intentionally disconnect an active RTMP stream mid-transmission and verify the system logs the disconnection, releases resources, and remains ready to accept new connections

### Implementation for User Story 2

- [ ] T018 [US2] Implement Drop trait for RtmpInput in smelter-core/src/pipeline/rtmp/mod.rs (set should_close flag, trigger cleanup)
- [ ] T019 [US2] Implement timeout handling in FfmpegInputContext interrupt callback in smelter-core/src/pipeline/utils/ffmpeg_input_context.rs (check should_close flag)
- [ ] T020 [US2] Implement disconnect detection in demuxer thread in smelter-core/src/pipeline/rtmp/mod.rs (EOF detection, error handling)
- [ ] T021 [US2] Implement graceful resource cleanup in demuxer thread in smelter-core/src/pipeline/rtmp/mod.rs (close channels, send EOS to decoders)
- [ ] T022 [US2] Add error logging for connection failures in smelter-core/src/pipeline/rtmp/mod.rs (network errors, timeout, unexpected disconnect)
- [ ] T023 [US2] Implement buffer synchronization handling for packet loss in smelter-core/src/pipeline/rtmp/mod.rs (use existing StreamState for discontinuity detection)
- [ ] T024 [US2] Add validation that cleanup completes within 10 seconds per spec SC-005 in smelter-core/src/pipeline/rtmp/mod.rs

**Checkpoint**: At this point, User Stories 1 AND 2 should both work - streams are received AND graceful error handling works independently

---

## Phase 5: User Story 3 - Support Multiple Concurrent RTMP Inputs (Priority: P3)

**Goal**: Enable multiple broadcasters to simultaneously publish RTMP streams with independent processing

**Independent Test**: Establish multiple concurrent RTMP connections from different publishers (with different stream keys) and verify each stream processes independently without interference

### Implementation for User Story 3

- [ ] T025 [US3] Verify per-connection architecture supports concurrent streams in smelter-core/src/pipeline/rtmp/mod.rs (each RtmpInput::new_input call is independent)
- [ ] T026 [US3] Add concurrent stream resource isolation documentation in smelter-core/src/pipeline/rtmp/mod.rs (Arc usage, separate FFmpeg contexts)
- [ ] T027 [US3] Add port reuse validation to prevent conflicts in smelter-core/src/pipeline/rtmp/mod.rs (warn if same port used with different stream keys)
- [ ] T028 [US3] Verify connection limit handling in RtmpInputOptions in smelter-core/src/pipeline/rtmp/mod.rs (document max concurrent streams recommendation)

**Checkpoint**: All user stories should now be independently functional - single stream, error handling, and multi-stream all work

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [ ] T029 [P] Create integration test for single RTMP stream in integration-tests/tests/rtmp_input_tests.rs (spawn FFmpeg publisher, verify frames received)
- [ ] T030 [P] Create integration test for concurrent streams in integration-tests/tests/rtmp_input_tests.rs (5 streams, verify independence)
- [ ] T031 [P] Create integration test for authentication in integration-tests/tests/rtmp_input_tests.rs (valid/invalid stream keys)
- [ ] T032 [P] Create integration test for timeout/disconnect in integration-tests/tests/rtmp_input_tests.rs (verify cleanup)
- [ ] T033 [P] Create test utility RTMP publisher in integration-tests/src/bin/test_rtmp_publisher.rs (FFmpeg wrapper for tests)
- [ ] T034 [P] Add doc comments to public API in smelter-core/src/pipeline/rtmp/mod.rs (RtmpInput, RtmpInputOptions, all public methods)
- [ ] T035 [P] Validate quickstart.md examples are accurate in specs/001-rtmp-input-pipeline/quickstart.md
- [ ] T036 Code cleanup and refactoring across RTMP implementation (remove dead code, optimize imports)
- [ ] T037 Performance validation with 5 concurrent streams (verify meets <500ms latency, <50ms A/V sync)
- [ ] T038 Security review for stream key validation and input validation (prevent injection, validate all user inputs)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3, 4, 5)**: All depend on Foundational phase completion
  - User stories CAN proceed in parallel if multiple developers available
  - OR sequentially in priority order: US1 (P1) → US2 (P2) → US3 (P3)
- **Polish (Phase 6)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Extends US1 but independently testable (error scenarios)
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Architecture supports this inherently, mainly validation work

### Within Each User Story

**User Story 1 sequence:**
1. T008 (options) and T009 (FFmpeg context) can be parallel
2. T010 (validation) can be parallel with T008/T009
3. T011 (new_input) requires T008, T009, T010
4. T012 (audio), T013 (video), T014 (demuxer) require T011
5. T015 (buffer), T016 (logging), T017 (edge cases) can be parallel

**User Story 2 sequence:**
1. T018-T024 mostly sequential (build on US1 implementation)
2. T022 (error logging) can be parallel with T020-T021

**User Story 3 sequence:**
1. T025-T028 are mostly validation/documentation tasks
2. All can run in parallel once US1 and US2 complete

### Parallel Opportunities

- **Setup Phase**: T002 can run while T001 executes
- **Foundational Phase**: T004, T005, T007 can run in parallel; T003, T006 are independent
- **US1 Implementation**: T008, T009, T010 can start together
- **US1 Later Tasks**: T015, T016, T017 can run in parallel
- **US3 Tasks**: T025, T026, T027, T028 can all run in parallel
- **Polish Phase**: T029-T035 (all tests and docs) can run in parallel

---

## Parallel Example: User Story 1 Early Tasks

```bash
# Launch foundational tasks together:
Task: "Create RtmpInputOptions struct in smelter-core/src/pipeline/rtmp/mod.rs"
Task: "Create RtmpInput struct skeleton in smelter-core/src/pipeline/rtmp/mod.rs"

# Launch US1 initial implementation together:
Task: "Implement RtmpInputOptions with validation"
Task: "Implement FfmpegInputContext::new_rtmp_server()"
Task: "Implement stream key validation function"

# Launch US1 polish tasks together:
Task: "Add RTMP-optimized InputBufferOptions defaults"
Task: "Add structured logging for RTMP connection events"
Task: "Handle audio-only and video-only streams correctly"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (~5 minutes)
2. Complete Phase 2: Foundational (~30 minutes)
3. Complete Phase 3: User Story 1 (~4-6 hours)
4. **STOP and VALIDATE**: Test User Story 1 independently
   - Use FFmpeg CLI to publish test stream
   - Verify frames received and decoded
   - Check latency meets <500ms requirement
5. Deploy/demo if ready

**Expected MVP completion time**: ~5-7 hours (given 95% code reuse from HLS)

### Incremental Delivery

1. **Setup + Foundational** → Foundation ready (~35 minutes)
2. **Add User Story 1** → Test independently → Deploy/Demo (MVP! ~6 hours total)
3. **Add User Story 2** → Test error handling independently → Deploy/Demo (~2-3 hours)
4. **Add User Story 3** → Test multi-stream independently → Deploy/Demo (~1-2 hours)
5. **Polish** → Integration tests and docs (~2-3 hours)

**Total estimated time**: 11-15 hours (benefits from proven HLS pattern)

### Parallel Team Strategy

With multiple developers:

1. **Team completes Setup + Foundational together** (~35 minutes)
2. **Once Foundational is done:**
   - Developer A: User Story 1 (core functionality) - PRIORITY
   - Developer B: Integration test infrastructure (T033) in parallel
   - Developer C: Documentation validation (T035) in parallel
3. **After US1 complete:**
   - Developer A: User Story 2 (error handling)
   - Developer B: User Story 3 (multi-stream validation)
   - Developer C: Integration tests (T029-T032)
4. **Final**: Code review, polish (T036-T038) together

---

## Task Count Summary

- **Total Tasks**: 38
- **Setup (Phase 1)**: 2 tasks
- **Foundational (Phase 2)**: 5 tasks (blocks all stories)
- **User Story 1 (Phase 3)**: 10 tasks (MVP)
- **User Story 2 (Phase 4)**: 7 tasks
- **User Story 3 (Phase 5)**: 4 tasks
- **Polish (Phase 6)**: 10 tasks

### Tasks by User Story

- **US1**: 10 implementation tasks
- **US2**: 7 implementation tasks
- **US3**: 4 validation tasks
- **Infrastructure**: 7 tasks (Setup + Foundational)
- **Testing/Polish**: 10 tasks

### Parallel Opportunities Identified

- **Foundational phase**: 3 parallel groups
- **User Story 1**: 2 parallel groups (T008/T009/T010 and T015/T016/T017)
- **User Story 3**: 4 tasks can all run in parallel
- **Polish phase**: 7 tasks can run in parallel (all tests and docs)

---

## Notes

- **Code Reuse**: 95% from HLS input (research.md) - expect rapid implementation
- **Critical Path**: Setup → Foundational → US1 (T008-T014) → US2 → US3 → Tests
- **MVP Definition**: Complete through User Story 1 only (receive and decode RTMP streams)
- **Testing Strategy**: Integration tests in Polish phase (no unit tests requested in spec)
- **Performance Goals**: <500ms latency, 5+ concurrent streams, <50ms A/V sync (validate in T037)
- **[P] tasks**: Can run in parallel - different files, no dependencies
- **[Story] label**: Maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
