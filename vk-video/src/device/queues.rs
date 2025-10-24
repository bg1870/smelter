use std::sync::{Arc, Mutex};

use ash::vk;

use crate::VulkanCommonError;
use crate::wrappers::*;

#[derive(Clone)]
pub struct Queue {
    pub queue: Arc<Mutex<vk::Queue>>,
    pub idx: usize,
    pub _video_properties: vk::QueueFamilyVideoPropertiesKHR<'static>,
    pub query_result_status_properties:
        vk::QueueFamilyQueryResultStatusPropertiesKHR<'static>,
    pub device: Arc<Device>,
}

impl Queue {
    pub fn supports_result_status_queries(&self) -> bool {
        self.query_result_status_properties
            .query_result_status_support
            == vk::TRUE
    }

    pub fn submit_chain_semaphore<S>(
        &self,
        buffer: &CommandBuffer,
        tracker: &mut Tracker<S>,
        wait_stages: vk::PipelineStageFlags2,
        signal_stages: vk::PipelineStageFlags2,
        new_wait_state: S,
    ) -> Result<(), VulkanCommonError> {
        let buffer_submit_info =
            [vk::CommandBufferSubmitInfo::default().command_buffer(buffer.buffer)];

        let signal_value = tracker.next_sem_value();
        let signal_info = vk::SemaphoreSubmitInfo::default()
            .semaphore(tracker.semaphore.semaphore)
            .value(signal_value)
            .stage_mask(signal_stages);

        let wait_info = match tracker.wait_for.take() {
            Some(wait_for) => Some(
                vk::SemaphoreSubmitInfo::default()
                    .semaphore(tracker.semaphore.semaphore)
                    .value(wait_for.value)
                    .stage_mask(wait_stages),
            ),
            _ => None,
        };

        let mut submit_info = vk::SubmitInfo2::default()
            .signal_semaphore_infos(std::slice::from_ref(&signal_info))
            .command_buffer_infos(&buffer_submit_info);

        if let Some(wait_info) = wait_info.as_ref() {
            submit_info = submit_info.wait_semaphore_infos(std::slice::from_ref(wait_info));
        }

        unsafe {
            self.device.queue_submit2(
                *self.queue.lock().unwrap(),
                &[submit_info],
                vk::Fence::null(),
            )?
        };

        tracker.wait_for = Some(TrackerWait {
            value: signal_value,
            _state: new_wait_state,
        });

        Ok(())
    }
}

pub struct Queues {
    pub transfer: Queue,
    pub h264_decode: Option<Queue>,
    pub h264_encode: Option<Queue>,
    pub wgpu: Queue,
}

pub struct QueueIndex<'a> {
    pub idx: usize,
    pub video_properties: vk::QueueFamilyVideoPropertiesKHR<'a>,
    pub query_result_status_properties: vk::QueueFamilyQueryResultStatusPropertiesKHR<'a>,
}

pub struct QueueIndices<'a> {
    pub transfer: QueueIndex<'a>,
    pub h264_decode: Option<QueueIndex<'a>>,
    pub h264_encode: Option<QueueIndex<'a>>,
    pub graphics_transfer_compute: QueueIndex<'a>,
}

impl QueueIndices<'_> {
    pub fn queue_create_infos(&self) -> Vec<vk::DeviceQueueCreateInfo<'_>> {
        [
            self.h264_decode.as_ref().map(|q| q.idx),
            self.h264_encode.as_ref().map(|q| q.idx),
            Some(self.transfer.idx),
            Some(self.graphics_transfer_compute.idx),
        ]
        .into_iter()
        .flatten()
        .collect::<std::collections::HashSet<usize>>()
        .into_iter()
        .map(|i| {
            vk::DeviceQueueCreateInfo::default()
                .queue_family_index(i as u32)
                .queue_priorities(&[1.0])
        })
        .collect::<Vec<_>>()
    }
}
