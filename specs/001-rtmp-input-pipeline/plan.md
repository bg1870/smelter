# Implementation Plan: RTMP Input Pipeline

**Branch**: `001-rtmp-input-pipeline` | **Date**: 2025-11-10 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-rtmp-input-pipeline/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Implement RTMP input capability to enable the Smelter system to receive live video streams from broadcasting software. The feature will accept incoming RTMP connections, demultiplex and decode video/audio streams, and integrate them into the existing pipeline architecture following patterns established by HLS, WebRTC, and RTP inputs.

## Technical Context

**Language/Version**: Rust 2024 edition
**Primary Dependencies**: FFmpeg (via ffmpeg-next) with native RTMP support, tokio for async runtime (optional for connection handling), crossbeam-channel for threading, tracing for logging
**Storage**: N/A (streaming data only, no persistence)
**Testing**: cargo nextest (unit tests), integration-tests crate (snapshot and pipeline tests)
**Target Platform**: Linux (primary), with potential support for other FFmpeg-compatible platforms
**Project Type**: Single project (smelter-core library)
**Performance Goals**: <500ms processing latency, support 5+ concurrent streams, maintain <50ms A/V sync drift
**Constraints**: Real-time processing requirements, must not block rendering pipeline, resource cleanup within 10 seconds
**Scale/Scope**: Single crate modification (smelter-core), ~5-10 new source files, integration with existing decoder infrastructure

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Verify compliance with `.specify/memory/constitution.md`:

- [x] **Modular Architecture**: This feature is contained within smelter-core and follows the existing pipeline input pattern. No API changes required initially (RTMP input is library-level functionality).
- [x] **Real-Time Performance**: Performance goals documented above (<500ms latency, 5+ concurrent streams). RTMP demuxing and decoding will use existing FFmpeg infrastructure proven in HLS input. Expected latency: 280-380ms (validated in research.md).
- [x] **API Compatibility**: CONFIRMED - No API changes required for initial implementation. RTMP input is library-level only (same pattern as HLS). If future HTTP API exposure needed, will follow constitution requirement for synchronized Rust + TypeScript updates.
- [x] **Test Coverage**: Will include unit tests for RTMP connection handling, integration tests for end-to-end streaming, and pipeline tests for decoded output validation. Test strategy documented in research.md.
- [x] **Cross-Platform**: Rendering output determinism not affected (RTMP input only affects ingestion, not rendering). Decoded frames fed to existing pipeline.
- [x] **Documentation**: Public API includes doc comments in data-model.md. Architecture decisions captured in research.md. Quickstart guide created. Internal contracts documented in contracts/README.md.
- [x] **Hardware Acceleration**: Optional Vulkan H.264 decoding supported (same as HLS). Fallback to FFmpeg software decode. Platform constraints inherited from existing decoder infrastructure.
- [x] **Observability**: Will use tracing crate with structured logging for connection events, errors, and stream metadata. Follows existing patterns from HLS/WebRTC inputs.

**Violations Requiring Justification**: None identified. Feature follows established patterns from HLS input implementation.

**Post-Phase-1 Re-evaluation**: ✅ COMPLETE - All constitution checks passed.

## Project Structure

### Documentation (this feature)

```text
specs/001-rtmp-input-pipeline/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command) - may be N/A if no API changes
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
smelter-core/
├── src/
│   ├── pipeline/
│   │   ├── rtmp/
│   │   │   ├── mod.rs                    # Module exports (RtmpInput, RtmpServer if needed)
│   │   │   ├── rtmp_output.rs            # Existing RTMP output (client)
│   │   │   ├── rtmp_input.rs             # NEW: Main RTMP input implementation
│   │   │   ├── rtmp_server.rs            # NEW: RTMP server socket/connection handling
│   │   │   ├── rtmp_connection.rs        # NEW: Per-connection state management
│   │   │   ├── rtmp_demuxer.rs           # NEW: Stream demultiplexing
│   │   │   └── stream_authentication.rs  # NEW: Stream key validation
│   │   ├── hls/                          # Reference implementation
│   │   ├── webrtc/                       # Reference implementation
│   │   └── rtp/                          # Reference implementation
│   ├── input.rs                          # Add Input::Rtmp variant
│   └── lib.rs
│
integration-tests/
├── tests/
│   ├── rtmp_input_tests.rs               # NEW: End-to-end RTMP streaming tests
│   └── snapshots/                         # Pipeline test output validation
└── src/
    └── bin/
        └── test_rtmp_publisher.rs         # NEW: Test utility to publish RTMP streams
```

**Structure Decision**: This follows the existing single-project structure where all pipeline inputs live under `smelter-core/src/pipeline/`. The RTMP input will mirror the organization of HLS input (which also uses FFmpeg for demuxing/decoding) with additional components for RTMP server functionality.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Not applicable - no constitution violations identified.

## Phase 0: Research & Discovery

### Research Tasks

The following unknowns from Technical Context require investigation:

1. **RTMP Protocol Library Selection**
   - **Unknown**: Which Rust RTMP library to use (if any) vs. implementing protocol handling directly
   - **Research Goal**: Identify mature Rtsp/RTMP libraries in Rust ecosystem, evaluate against requirements
   - **Alternatives**: FFmpeg librtmp, pure Rust implementations, custom protocol implementation

2. **RTMP Server Architecture Pattern**
   - **Unknown**: How to structure RTMP server to handle multiple concurrent connections
   - **Research Goal**: Determine async vs. threaded model, connection lifecycle management
   - **Context**: Must integrate with existing PipelineCtx threading model

3. **FFmpeg RTMP Integration Approach**
   - **Unknown**: Best approach to use FFmpeg for RTMP demuxing/decoding
   - **Research Goal**: Compare FFmpeg as RTMP protocol handler vs. just decoder (with separate Rust RTMP implementation)
   - **Context**: HLS input uses FFmpeg's `avformat_open_input` with URL - determine if similar approach works for RTMP server

4. **Stream Key Authentication Mechanism**
   - **Unknown**: How to implement stream key validation in RTMP handshake
   - **Research Goal**: Understand RTMP authentication flow, where to inject validation logic
   - **Context**: Need to support per-stream access control

### Integration Patterns

5. **Decoder Thread Integration**
   - **Reference**: HLS input spawns AudioDecoderThread and VideoDecoderThread
   - **Research Goal**: Confirm identical pattern applies for RTMP, identify any RTMP-specific considerations

6. **Input Buffer Management**
   - **Reference**: HLS uses InputBuffer::new(&ctx, opts.buffer)
   - **Research Goal**: Understand buffer configuration for real-time RTMP vs. pull-based HLS

7. **Resource Cleanup on Disconnect**
   - **Research Goal**: Determine how to detect RTMP disconnection cleanly and trigger resource cleanup
   - **Context**: RTMP is push-based (unlike HLS pull), disconnection detection may differ

### Output

All research findings will be consolidated in `research.md` with format:
- **Decision**: [what was chosen]
- **Rationale**: [why chosen]
- **Alternatives Considered**: [what else was evaluated]
- **Implementation Notes**: [key technical details]

## Phase 1: Design & Contracts

**Prerequisites**: `research.md` complete with all NEEDS CLARIFICATION resolved

### Data Model

Extract entities from feature spec into `data-model.md`:

1. **RTMP Connection**
   - Fields: connection_id, socket, state (connecting/active/disconnecting), stream_key, metadata (codec info, resolution, fps), authentication_status
   - Relationships: Owns AudioTrack and VideoTrack, associated with PipelineCtx
   - State Transitions: New → Authenticating → Active → Disconnecting → Closed

2. **Audio Track**
   - Fields: codec_info (from RTMP metadata), sample_rate, channels, decoder_handle
   - Relationships: Part of RTMP Connection, feeds InputBuffer
   - Validation: Codec must be supported by existing decoders

3. **Video Track**
   - Fields: codec_info, resolution, frame_rate, decoder_handle
   - Relationships: Part of RTMP Connection, feeds InputBuffer
   - Validation: Codec must be supported by existing decoders

4. **Stream Buffer**
   - Fields: Reuse existing InputBuffer from pipeline/utils/input_buffer
   - Relationships: Shared between demuxer and decoder threads

5. **RTMP Server State**
   - Fields: listening_port, active_connections (map of stream_key to RtmpConnection), configuration (timeouts, buffer sizes, max_connections)
   - Relationships: Manages multiple RtmpConnection instances

### API Contracts

**Evaluation**: NEEDS CLARIFICATION during research whether RTMP input configuration needs API exposure.

**If API changes required**:
- Add RTMP configuration to smelter-api types
- Generate OpenAPI schema updates
- Update TypeScript SDK types
- Document in contracts/ directory

**If no API changes** (RTMP configured at library level only):
- Document internal Rust API contracts only
- No TypeScript SDK changes needed

This will be determined in Phase 0 research based on configuration requirements.

### Agent Context Update

After design completion:
1. Run `.specify/scripts/bash/update-agent-context.sh claude`
2. Add RTMP library choice, server architecture pattern, FFmpeg integration approach to agent context
3. Preserve any existing manual additions between markers

## Phase 2: Task Generation

**Not performed by /speckit.plan** - This phase is handled by the `/speckit.tasks` command, which reads this plan and generates the detailed task breakdown in `tasks.md`.

## Notes

- RTMP input implementation will closely follow HLS input patterns (both use FFmpeg for demux/decode)
- Key difference: RTMP is push-based server vs. HLS pull-based client
- Existing decoder infrastructure (AudioDecoderThread, VideoDecoderThread) will be reused
- Phase 0 research is critical to determine RTMP library choice and server architecture
