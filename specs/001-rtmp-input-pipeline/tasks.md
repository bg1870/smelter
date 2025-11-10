# Tasks: RTMP Input Pipeline

**Input**: Design documents from `/specs/001-rtmp-input-pipeline/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Tests are NOT explicitly requested in the specification. Therefore, this task list focuses on implementation only. Test tasks can be added later if TDD approach is adopted.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- Single project structure: `smelter-core/src/` for implementation
- Integration tests: `integration-tests/tests/`
- All paths relative to repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create basic RTMP module structure and prepare for implementation

- [X] T001 Create RTMP module directory structure at smelter-core/src/pipeline/rtmp/
- [X] T002 Create module file smelter-core/src/pipeline/rtmp/mod.rs with basic exports
- [X] T003 Verify FFmpeg RTMP support is available in current ffmpeg-next version

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Implement FfmpegInputContext::new_rtmp_server() in smelter-core/src/pipeline/utils/ffmpeg_input_context.rs
- [X] T005 [P] Create RtmpInputOptions struct in smelter-core/src/pipeline/rtmp/rtmp_input.rs
- [X] T006 [P] Implement Default for RtmpInputOptions with RTMP-optimized buffer settings
- [X] T007 [P] Add Input::Rtmp variant to smelter-core/src/input.rs enum
- [X] T008 Create stream key validation helper functions in smelter-core/src/pipeline/rtmp/rtmp_input.rs

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Receive Live RTMP Stream (Priority: P1) 🎯 MVP

**Goal**: Enable basic RTMP stream ingestion with audio and video decoding

**Independent Test**: Configure an RTMP publisher (FFmpeg or OBS) to stream to the Smelter endpoint, verify that both audio and video packets are successfully received and decoded, and confirm that processed frames become available to the pipeline.

### Implementation for User Story 1

- [X] T009 [US1] Implement RtmpInput struct in smelter-core/src/pipeline/rtmp/rtmp_input.rs
- [X] T010 [US1] Implement RtmpInput::new_input() method with FFmpeg context initialization
- [X] T011 [US1] Implement audio track handling in RtmpInput::handle_audio_track() (reuse pattern from HLS)
- [X] T012 [US1] Implement video track handling in RtmpInput::handle_video_track() (reuse pattern from HLS)
- [X] T013 [US1] Implement demuxer thread spawning in RtmpInput::spawn_demuxer_thread()
- [X] T014 [US1] Implement demuxer loop with av_read_frame in demuxer thread
- [X] T015 [US1] Implement Drop trait for RtmpInput with graceful cleanup
- [X] T016 [US1] Add tracing/logging for connection events, stream metadata, and errors
- [X] T017 [US1] Integrate RtmpInput registration with pipeline in example or main process
- [ ] T018 [US1] Test with FFmpeg CLI publisher streaming H.264+AAC content
- [ ] T019 [US1] Test with OBS Studio streaming to verify real-world compatibility
- [ ] T020 [US1] Verify decoded frames are received through QueueDataReceiver channels

**Checkpoint**: At this point, User Story 1 should be fully functional - basic RTMP streaming works end-to-end

---

## Phase 4: User Story 2 - Handle Connection Interruptions (Priority: P2)

**Goal**: Gracefully handle network interruptions and disconnections without crashing or corrupting pipeline state

**Independent Test**: Intentionally disconnect an active RTMP stream mid-transmission and observe the system's error handling, resource cleanup, and readiness to accept new connections.

### Implementation for User Story 2

- [X] T021 [US2] Implement timeout detection in FFmpeg interrupt callback
- [X] T022 [US2] Implement network error handling in demuxer loop
- [X] T023 [US2] Implement EOF detection for clean client disconnection
- [X] T024 [US2] Add resource cleanup validation (verify cleanup completes within 10 seconds)
- [X] T025 [US2] Add error logging for disconnection events with context (network error, timeout, clean disconnect)
- [ ] T026 [US2] Test intentional mid-stream disconnection
- [ ] T027 [US2] Test reconnection after disconnection (same stream key)
- [ ] T028 [US2] Test packet loss/delay handling with network simulation

**Checkpoint**: At this point, User Stories 1 AND 2 should both work - basic streaming + robust error handling

---

## Phase 5: User Story 3 - Support Multiple Concurrent RTMP Inputs (Priority: P3)

**Goal**: Enable multiple broadcasters to simultaneously publish RTMP streams, each processed independently

**Independent Test**: Establish multiple concurrent RTMP connections from different publishers with different stream keys and verify that each stream is processed independently without interference.

### Implementation for User Story 3

- [X] T029 [US3] Implement support for multiple RtmpInput instances in pipeline
- [X] T030 [US3] Verify independent FFmpeg context per connection
- [X] T031 [US3] Add configuration for maximum concurrent streams limit (if needed)
- [ ] T032 [US3] Test with 2 concurrent RTMP streams (different stream keys)
- [ ] T033 [US3] Test with 5 concurrent RTMP streams (verify performance goals met)
- [ ] T034 [US3] Test disconnecting one stream while others remain active
- [ ] T035 [US3] Test connection rejection when exceeding max streams (if limit implemented)
- [ ] T036 [US3] Measure and verify resource usage (target ~70MB for 5 streams)

**Checkpoint**: All user stories should now be independently functional - full RTMP input capability delivered

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [X] T037 [P] Add comprehensive error types for InputInitError (RTMP-specific errors)
- [X] T038 [P] Verify codec validation (reject unsupported codecs cleanly)
- [X] T039 [P] Add stream metadata logging (resolution, framerate, codec info, bitrate)
- [ ] T040 [P] Verify audio-video synchronization (drift < 50ms over 1 hour)
- [ ] T041 [P] Performance profiling for latency measurement (target < 500ms)
- [X] T042 Update CLAUDE.md with RTMP technology stack via update-agent-context.sh
- [ ] T043 Create integration test helper in integration-tests/src/bin/test_rtmp_publisher.rs
- [X] T044 [P] Code cleanup and documentation review
- [X] T045 [P] Validate quickstart.md examples work correctly
- [X] T046 Run cargo clippy and address any warnings

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
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Extends US1 error handling but independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Builds on US1 pattern but independently testable

### Within Each User Story

**User Story 1**:
- T009-T010 (RtmpInput struct and new_input) must complete first
- T011-T012 (track handling) can run in parallel
- T013-T015 (demuxer thread and cleanup) depend on T009-T012
- T016-T020 (integration and testing) depend on T009-T015 completion

**User Story 2**:
- All tasks T021-T025 are implementation tasks that can be done together
- T026-T028 are testing tasks that depend on T021-T025

**User Story 3**:
- T029-T031 are setup/implementation tasks
- T032-T036 are testing tasks that depend on T029-T031

### Parallel Opportunities

- All Setup tasks can run in parallel (T001-T003)
- Foundational tasks T005, T006, T007 can run in parallel after T004 completes
- Within US1: T011 and T012 (track handling) can run in parallel
- Once Foundational phase completes, all user stories can start in parallel if team capacity allows
- All Polish tasks marked [P] can run in parallel

---

## Parallel Example: User Story 1

```bash
# After T009-T010 complete, launch track handling in parallel:
Task: "Implement audio track handling in RtmpInput::handle_audio_track()" [T011]
Task: "Implement video track handling in RtmpInput::handle_video_track()" [T012]

# In Polish phase, launch independent improvements together:
Task: "Add comprehensive error types for InputInitError" [T037]
Task: "Verify codec validation" [T038]
Task: "Add stream metadata logging" [T039]
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T008) - CRITICAL, blocks all stories
3. Complete Phase 3: User Story 1 (T009-T020)
4. **STOP and VALIDATE**: Test User Story 1 independently with FFmpeg and OBS
5. Verify latency < 500ms, A/V sync maintained, clean disconnect works
6. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
   - Basic RTMP streaming working end-to-end
3. Add User Story 2 → Test independently → Deploy/Demo
   - Now robust against network issues and interruptions
4. Add User Story 3 → Test independently → Deploy/Demo
   - Now supports multiple concurrent streams
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together (T001-T008)
2. Once Foundational is done:
   - Developer A: User Story 1 (T009-T020)
   - Developer B: Can start User Story 2 (T021-T028) or User Story 3 (T029-T036) in parallel
   - Developer C: Can work on Polish items (T037-T041) that don't require US completion
3. Stories complete and integrate independently

---

## Notes

- **95% Code Reuse**: Most implementation follows HLS input pattern exactly (hls_input.rs)
- **Key Differences**: Only RTMP URL format, FFmpeg dictionary options, and buffer configuration differ from HLS
- **No New Dependencies**: FFmpeg already has RTMP support built-in
- **Stream Key Authentication**: Post-connection validation via URL path extraction
- **Codec Support**: H.264 (AVCC) video + AAC audio (same as HLS)
- **Performance Target**: <500ms latency, 5+ concurrent streams, <50ms A/V sync drift
- **Cleanup Guarantee**: Resources released within 10 seconds on disconnect
- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence

---

## Summary

**Total Tasks**: 46 tasks
- Phase 1 (Setup): 3 tasks
- Phase 2 (Foundational): 5 tasks (BLOCKING)
- Phase 3 (US1 - MVP): 12 tasks
- Phase 4 (US2): 8 tasks
- Phase 5 (US3): 8 tasks
- Phase 6 (Polish): 10 tasks

**Parallel Opportunities**:
- Within Foundational: 3 tasks can run in parallel
- Within US1: 2 tasks can run in parallel
- Within Polish: 6 tasks can run in parallel
- All 3 user stories can be worked on in parallel after Foundational completes

**Independent Test Criteria**:
- US1: Stream H.264+AAC from FFmpeg/OBS, verify decoded frames available
- US2: Disconnect mid-stream, verify cleanup and reconnection
- US3: Stream from 5 sources concurrently, verify independence

**MVP Scope**: User Story 1 only (T001-T020) = ~20 tasks
- Delivers core RTMP streaming functionality
- Sufficient for initial deployment and validation
