# Feature Specification: RTMP Input API Registration

**Feature Branch**: `002-rtmp-api-input`
**Created**: 2025-11-10
**Status**: Draft
**Input**: User description: "given this as a reference '/home/basil/sworks/genwin/smelter/smelter-api/src/input' '/home/basil/sworks/genwin/smelter/smelter-core/src/pipeline/rtmp' want to implement the `rtmp` input at the api layer so we can register an rtmp stream as an input"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Register Basic RTMP Stream (Priority: P1)

A video streaming application operator needs to configure the system to accept incoming RTMP streams from encoders or streaming software (like OBS, FFmpeg, or hardware encoders). They configure the RTMP input with a port number and stream key, then start streaming to that endpoint.

**Why this priority**: Core functionality - without the ability to register and receive RTMP streams, the feature provides no value. This is the foundation that all other functionality builds upon.

**Independent Test**: Can be fully tested by registering an RTMP input via API, connecting an RTMP publisher (OBS/FFmpeg), and verifying the stream is received and processed. Delivers immediate value by enabling basic RTMP ingest.

**Acceptance Scenarios**:

1. **Given** the API layer is running, **When** a user submits a valid RTMP input registration request with port and stream key, **Then** the system creates an RTMP server listening on the specified port
2. **Given** an RTMP input is registered on port 1935 with stream key "live123", **When** an encoder publishes to `rtmp://server:1935/live/live123`, **Then** the system accepts the connection and begins processing the stream
3. **Given** an RTMP stream is actively publishing, **When** the stream contains H.264 video, **Then** the video frames are decoded and available to the pipeline
4. **Given** an RTMP stream is actively publishing, **When** the stream contains AAC audio, **Then** the audio samples are decoded and available to the pipeline

---

### User Story 2 - Configure Stream Parameters (Priority: P2)

An operator needs to fine-tune RTMP input parameters for their specific use case - adjusting connection timeouts for unreliable networks, selecting hardware vs software decoders for performance, or configuring buffer settings for latency requirements.

**Why this priority**: Important for production deployments where default settings may not meet performance, latency, or reliability requirements. However, basic functionality works without these customizations.

**Independent Test**: Can be tested by registering RTMP inputs with various configurations (different timeouts, decoder types, buffer settings) and verifying each parameter affects system behavior as expected. Delivers value by enabling production-ready deployments.

**Acceptance Scenarios**:

1. **Given** the API layer accepts RTMP input requests, **When** a user specifies a connection timeout value, **Then** the RTMP server enforces that timeout when waiting for connections
2. **Given** the system supports multiple video decoder types, **When** a user specifies a preferred decoder (FFmpeg or Vulkan), **Then** the system uses that decoder for H.264 video
3. **Given** an operator needs low-latency streaming, **When** they configure buffer settings in the input request, **Then** the system applies those buffer parameters to the stream processing

---

### User Story 3 - Handle Stream Lifecycle Events (Priority: P3)

An operator monitoring the streaming system needs visibility into stream lifecycle events - when publishers connect, when streams start/stop, and when errors occur. This enables proper monitoring, logging, and troubleshooting.

**Why this priority**: Valuable for operational visibility but the core streaming functionality works without detailed lifecycle tracking. Primarily needed for production monitoring and debugging.

**Independent Test**: Can be tested by observing system behavior during connection, disconnection, and error scenarios. Delivers value by enabling operational monitoring and troubleshooting.

**Acceptance Scenarios**:

1. **Given** an RTMP input is registered, **When** a publisher attempts to connect with an incorrect stream key, **Then** the system rejects the connection and logs the authentication failure
2. **Given** an active RTMP stream is being processed, **When** the publisher disconnects, **Then** the system detects the disconnection and cleans up resources
3. **Given** an RTMP stream encounters decoding errors, **When** the error occurs, **Then** the system handles the error gracefully without crashing

---

### Edge Cases

- What happens when a user attempts to register an RTMP input on a port that's already in use?
- How does the system handle RTMP streams with unsupported codecs (non-H.264 video or non-AAC audio)?
- What happens when multiple publishers try to connect to the same stream key simultaneously?
- How does the system behave when an RTMP publisher sends malformed or corrupted packets?
- What happens when the RTMP connection times out while waiting for a publisher?
- How does the system handle streams that contain only video or only audio (not both)?
- What happens when buffer capacity is exceeded due to slow processing?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: API layer MUST provide an endpoint/method to register RTMP input streams with configuration parameters
- **FR-002**: API layer MUST accept RTMP input configuration including port number, stream key, timeout settings, and decoder preferences
- **FR-003**: API layer MUST validate RTMP input parameters before attempting to create the input (port range, non-empty stream key, valid timeout values)
- **FR-004**: System MUST translate API layer RTMP input requests into core layer RtmpInputOptions structure
- **FR-005**: System MUST support optional specification of video decoder type (FFmpeg H.264 or Vulkan H.264)
- **FR-006**: System MUST support optional specification of connection timeout in seconds
- **FR-007**: System MUST support optional specification of buffer configuration for latency control
- **FR-008**: API layer MUST return appropriate error responses when RTMP input registration fails (invalid parameters, port conflicts, etc.)
- **FR-009**: System MUST support RTMP streams containing H.264 video encoded in AVCC format
- **FR-010**: System MUST support RTMP streams containing AAC audio with AudioSpecificConfig
- **FR-011**: System MUST handle RTMP streams containing only video, only audio, or both video and audio
- **FR-012**: API layer MUST integrate with existing input registration patterns (similar to RTP, HLS, MP4, etc.)

### Key Entities

- **RTMP Input Registration Request**: Represents the API layer data structure for registering an RTMP input, containing port, stream key, optional timeout, optional decoder preferences, and optional buffer settings
- **RTMP Stream**: Represents an incoming RTMP connection from a publisher, carrying compressed video (H.264) and/or audio (AAC) data with timestamps
- **Stream Key**: Authentication identifier that publishers must provide to connect to a specific RTMP endpoint

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can successfully register an RTMP input via the API and receive RTMP streams from standard encoders (OBS, FFmpeg) without requiring custom configuration
- **SC-002**: System accepts RTMP connections from publishers within connection timeout period (default 30 seconds)
- **SC-003**: System processes RTMP streams containing H.264 video and AAC audio with frame-accurate decoding
- **SC-004**: API validation catches invalid RTMP input parameters before attempting to create the input, providing clear error messages
- **SC-005**: System handles graceful disconnection and resource cleanup when RTMP publishers stop streaming
- **SC-006**: RTMP input registration follows the same patterns and conventions as existing input types (RTP, HLS, WHIP, etc.)

## Assumptions

### Technical Assumptions

- The core RTMP input implementation (smelter-core/src/pipeline/rtmp) is fully functional and tested
- The existing input registration patterns (RTP, HLS, etc.) in smelter-api/src/input provide a proven template to follow
- The RTMP server listens on a user-specified port and expects publishers to connect to `rtmp://host:port/live/stream_key`
- The core layer RtmpInputOptions structure is stable and matches the documented interface
- FFmpeg is configured with RTMP support enabled
- The system will run on environments where the specified ports are available and not blocked by firewalls

### Business Assumptions

- Users of this feature are familiar with RTMP streaming concepts (stream keys, RTMP URLs, encoder configuration)
- The primary use case is accepting streams from OBS, FFmpeg, or similar encoding software
- Stream authentication via stream key matching is sufficient for the initial implementation
- Default configuration values (30 second timeout, auto-selected decoder) work for most common use cases

## Scope Boundaries

### In Scope

- API layer data structures for RTMP input registration (similar to RtpInput, HlsInput, etc.)
- Conversion logic from API layer structures to core layer RtmpInputOptions
- Integration with existing input registration endpoint/pattern
- Parameter validation at the API layer
- Support for standard RTMP streams with H.264/AAC from common encoders

### Out of Scope

- Core RTMP protocol implementation (already exists in smelter-core)
- Advanced RTMP authentication mechanisms beyond stream key matching
- Support for codecs other than H.264 video and AAC audio
- RTMP output/publishing functionality (separate feature)
- Custom RTMP extensions or non-standard protocol variants
- Load balancing across multiple RTMP inputs
- Automatic failover or redundancy mechanisms
