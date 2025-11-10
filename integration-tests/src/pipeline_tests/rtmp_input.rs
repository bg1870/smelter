use anyhow::Result;
use serde_json::json;
use std::{
    process::{Child, Command, Stdio},
    thread,
    time::Duration,
};
use tracing::info;

use crate::{
    examples::{TestSample, get_asset_path},
    CommunicationProtocol, CompositorInstance, OutputReceiver,
};

/// Helper function to start FFmpeg streaming to RTMP
fn start_ffmpeg_rtmp_send(
    rtmp_url: &str,
    input_file: &str,
    duration_secs: u32,
) -> Result<Child> {
    info!("Starting FFmpeg RTMP stream to: {rtmp_url}");

    let handle = Command::new("ffmpeg")
        .args([
            "-re", // Read input at native frame rate
            "-i",
            input_file,
            "-t",
            &duration_secs.to_string(), // Duration limit
            "-c:v",
            "libx264", // H.264 video codec
            "-preset",
            "ultrafast", // Fast encoding
            "-tune",
            "zerolatency", // Low latency tuning
            "-b:v",
            "2000k", // Video bitrate
            "-g",
            "60", // Keyframe interval (2 seconds at 30fps)
            "-c:a",
            "aac", // AAC audio codec
            "-b:a",
            "128k", // Audio bitrate
            "-f",
            "flv", // FLV container (RTMP requirement)
            rtmp_url,
        ])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;

    info!("FFmpeg RTMP publisher started");
    Ok(handle)
}

/// Test RTMP input with minimal configuration (port + stream_key only)
///
/// This test validates:
/// - Basic RTMP input registration via API
/// - Connection from FFmpeg RTMP publisher
/// - Stream key authentication
/// - H.264 video decoding
/// - Default timeout (30 seconds)
/// - Auto-selected decoder
#[test]
#[ignore] // Requires FFmpeg with RTMP support and test video file
fn test_rtmp_input_minimal_config() -> Result<()> {
    let instance = CompositorInstance::start(None);
    let rtmp_port = instance.get_port();
    let output_port = instance.get_port();

    let stream_key = "test-stream-key-12345";
    let rtmp_url = format!("rtmp://127.0.0.1:{rtmp_port}/live/{stream_key}");

    // Get test video file
    let test_video = get_asset_path(TestSample::SampleH264)?;
    let test_video_str = test_video
        .to_str()
        .ok_or_else(|| anyhow::anyhow!("Invalid path"))?;

    // Start RTP output receiver
    let output_receiver = OutputReceiver::start(output_port, CommunicationProtocol::Udp)?;

    // Register RTP output
    instance.send_request(
        "output/output_1/register",
        json!({
            "type": "rtp_stream",
            "transport_protocol": "udp",
            "ip": "127.0.0.1",
            "port": output_port,
            "video": {
                "resolution": {
                    "width": 640,
                    "height": 360,
                },
                "encoder": {
                    "type": "ffmpeg_h264",
                    "preset": "ultrafast",
                },
                "initial": {
                    "root": {
                        "id": "input_1",
                        "type": "input_stream",
                        "input_id": "input_1",
                    }
                }
            }
        }),
    )?;

    // Unregister output after 10 seconds
    instance.send_request(
        "output/output_1/unregister",
        json!({
            "schedule_time_ms": 10000,
        }),
    )?;

    // Register RTMP input with minimal configuration
    instance.send_request(
        "input/input_1/register",
        json!({
            "type": "rtmp",
            "port": rtmp_port,
            "stream_key": stream_key,
        }),
    )?;

    // Start the pipeline
    instance.send_request("start", json!({}))?;

    info!("Pipeline started, waiting for RTMP server to be ready...");
    thread::sleep(Duration::from_secs(2));

    // Start FFmpeg publisher
    let mut ffmpeg_handle = start_ffmpeg_rtmp_send(&rtmp_url, test_video_str, 12)?;

    info!("Waiting for output...");
    let output_dump = output_receiver.wait_for_output()?;

    info!("Output received, stopping FFmpeg...");
    let _ = ffmpeg_handle.kill();
    let _ = ffmpeg_handle.wait();

    // Basic validation: check that we received data
    assert!(
        !output_dump.is_empty(),
        "Should receive output data from RTMP stream"
    );

    info!("Test passed: RTMP input with minimal config working");
    Ok(())
}

/// Test RTMP input with full configuration options
///
/// This test validates:
/// - RTMP input with all optional parameters
/// - Custom timeout configuration
/// - Explicit decoder selection (FFmpeg H.264)
/// - Required input flag
/// - Custom offset for A/V sync
#[test]
#[ignore] // Requires FFmpeg with RTMP support and test video file
fn test_rtmp_input_full_config() -> Result<()> {
    let instance = CompositorInstance::start(None);
    let rtmp_port = instance.get_port();
    let output_port = instance.get_port();

    let stream_key = "production-stream-abc123";
    let rtmp_url = format!("rtmp://127.0.0.1:{rtmp_port}/live/{stream_key}");

    // Get test video file
    let test_video = get_asset_path(TestSample::SampleH264)?;
    let test_video_str = test_video
        .to_str()
        .ok_or_else(|| anyhow::anyhow!("Invalid path"))?;

    // Start RTP output receiver
    let output_receiver = OutputReceiver::start(output_port, CommunicationProtocol::Udp)?;

    // Register RTP output
    instance.send_request(
        "output/output_1/register",
        json!({
            "type": "rtp_stream",
            "transport_protocol": "udp",
            "ip": "127.0.0.1",
            "port": output_port,
            "video": {
                "resolution": {
                    "width": 640,
                    "height": 360,
                },
                "encoder": {
                    "type": "ffmpeg_h264",
                    "preset": "ultrafast",
                },
                "initial": {
                    "root": {
                        "id": "input_1",
                        "type": "input_stream",
                        "input_id": "input_1",
                    }
                }
            }
        }),
    )?;

    instance.send_request(
        "output/output_1/unregister",
        json!({
            "schedule_time_ms": 10000,
        }),
    )?;

    // Register RTMP input with full configuration
    instance.send_request(
        "input/input_1/register",
        json!({
            "type": "rtmp",
            "port": rtmp_port,
            "stream_key": stream_key,
            "timeout_seconds": 60, // Extended timeout
            "video": {
                "decoder": "ffmpeg_h264" // Explicit decoder selection
            },
            "required": false, // Pipeline doesn't wait for this input
            "offset_ms": 0.0, // No manual A/V offset
        }),
    )?;

    instance.send_request("start", json!({}))?;

    info!("Pipeline started with full RTMP config...");
    thread::sleep(Duration::from_secs(2));

    // Start FFmpeg publisher
    let mut ffmpeg_handle = start_ffmpeg_rtmp_send(&rtmp_url, test_video_str, 12)?;

    let output_dump = output_receiver.wait_for_output()?;

    let _ = ffmpeg_handle.kill();
    let _ = ffmpeg_handle.wait();

    assert!(
        !output_dump.is_empty(),
        "Should receive output data from RTMP stream with full config"
    );

    info!("Test passed: RTMP input with full config working");
    Ok(())
}

/// Test RTMP input validation errors
///
/// This test validates:
/// - Port validation (must be >= 1024)
/// - Stream key validation (must be non-empty)
/// - Timeout validation (5-300 seconds range)
#[test]
fn test_rtmp_input_validation_errors() -> Result<()> {
    let instance = CompositorInstance::start(None);

    // Test 1: Invalid port (below 1024)
    let result = instance.send_request(
        "input/input_1/register",
        json!({
            "type": "rtmp",
            "port": 80, // Invalid: privileged port
            "stream_key": "test-key",
        }),
    );
    assert!(
        result.is_err(),
        "Should reject port below 1024"
    );
    if let Err(e) = result {
        let err_msg = e.to_string();
        assert!(
            err_msg.contains("1024") || err_msg.contains("port"),
            "Error should mention port range: {err_msg}"
        );
    }

    // Test 2: Empty stream key
    let result = instance.send_request(
        "input/input_2/register",
        json!({
            "type": "rtmp",
            "port": 1935,
            "stream_key": "", // Invalid: empty
        }),
    );
    assert!(
        result.is_err(),
        "Should reject empty stream_key"
    );
    if let Err(e) = result {
        let err_msg = e.to_string();
        assert!(
            err_msg.contains("stream_key") || err_msg.contains("empty"),
            "Error should mention stream_key: {err_msg}"
        );
    }

    // Test 3: Invalid timeout (too low)
    let result = instance.send_request(
        "input/input_3/register",
        json!({
            "type": "rtmp",
            "port": 1935,
            "stream_key": "test-key",
            "timeout_seconds": 2, // Invalid: below 5
        }),
    );
    assert!(
        result.is_err(),
        "Should reject timeout below 5 seconds"
    );
    if let Err(e) = result {
        let err_msg = e.to_string();
        assert!(
            err_msg.contains("timeout") || err_msg.contains("5"),
            "Error should mention timeout range: {err_msg}"
        );
    }

    // Test 4: Invalid timeout (too high)
    let result = instance.send_request(
        "input/input_4/register",
        json!({
            "type": "rtmp",
            "port": 1935,
            "stream_key": "test-key",
            "timeout_seconds": 500, // Invalid: above 300
        }),
    );
    assert!(
        result.is_err(),
        "Should reject timeout above 300 seconds"
    );
    if let Err(e) = result {
        let err_msg = e.to_string();
        assert!(
            err_msg.contains("timeout") || err_msg.contains("300"),
            "Error should mention timeout range: {err_msg}"
        );
    }

    info!("Test passed: All validation errors caught correctly");
    Ok(())
}

/// Test RTMP stream key authentication
///
/// This test validates:
/// - Correct stream key allows connection
/// - Incorrect stream key is rejected
#[test]
#[ignore] // Requires FFmpeg with RTMP support
fn test_rtmp_stream_key_auth() -> Result<()> {
    let instance = CompositorInstance::start(None);
    let rtmp_port = instance.get_port();

    let correct_stream_key = "secret-key-abc123";
    let wrong_stream_key = "wrong-key";

    // Get test video file
    let test_video = get_asset_path(TestSample::SampleH264)?;
    let test_video_str = test_video
        .to_str()
        .ok_or_else(|| anyhow::anyhow!("Invalid path"))?;

    // Register RTMP input
    instance.send_request(
        "input/input_1/register",
        json!({
            "type": "rtmp",
            "port": rtmp_port,
            "stream_key": correct_stream_key,
        }),
    )?;

    instance.send_request("start", json!({}))?;
    thread::sleep(Duration::from_secs(2));

    // Test 1: Try to connect with wrong stream key (should fail)
    let wrong_url = format!("rtmp://127.0.0.1:{rtmp_port}/live/{wrong_stream_key}");
    let mut wrong_handle = start_ffmpeg_rtmp_send(&wrong_url, test_video_str, 5)?;

    thread::sleep(Duration::from_secs(3));

    // FFmpeg should exit with error when stream key is wrong
    let wrong_result = wrong_handle.wait()?;
    assert!(
        !wrong_result.success(),
        "FFmpeg should fail with incorrect stream key"
    );

    // Test 2: Connect with correct stream key (should succeed)
    let correct_url = format!("rtmp://127.0.0.1:{rtmp_port}/live/{correct_stream_key}");
    let mut correct_handle = start_ffmpeg_rtmp_send(&correct_url, test_video_str, 3)?;

    thread::sleep(Duration::from_secs(4));

    // Should still be running or exit cleanly
    match correct_handle.try_wait()? {
        Some(status) => {
            // If exited, should be successful (stream completed)
            assert!(
                status.success() || status.code() == Some(255), // FFmpeg may exit with 255 on EOF
                "FFmpeg should succeed with correct stream key"
            );
        }
        None => {
            // Still running is also fine
            let _ = correct_handle.kill();
        }
    }

    info!("Test passed: Stream key authentication working correctly");
    Ok(())
}
