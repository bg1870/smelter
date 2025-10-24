use std::sync::Arc;

use ash::Entry;

mod command;
mod debug;
mod graphics;
mod mem;
mod parameter_sets;
mod sync;
mod video;
mod vk_extensions;

pub use command::*;
pub use debug::*;
pub use graphics::*;
pub use mem::*;
pub use parameter_sets::*;
pub use sync::*;
pub use video::*;
pub use vk_extensions::*;

pub struct Instance {
    pub instance: ash::Instance,
    pub _entry: Arc<Entry>,
    pub video_queue_instance_ext: ash::khr::video_queue::Instance,
    pub video_encode_queue_instance_ext: ash::khr::video_encode_queue::Instance,
    pub debug_utils_instance_ext: ash::ext::debug_utils::Instance,
}

impl Drop for Instance {
    fn drop(&mut self) {
        unsafe { self.destroy_instance(None) };
    }
}

impl std::ops::Deref for Instance {
    type Target = ash::Instance;

    fn deref(&self) -> &Self::Target {
        &self.instance
    }
}

pub struct Device {
    pub device: ash::Device,
    pub video_queue_ext: ash::khr::video_queue::Device,
    pub video_decode_queue_ext: ash::khr::video_decode_queue::Device,
    pub video_encode_queue_ext: ash::khr::video_encode_queue::Device,
    pub external_memory_fd: ash::khr::external_memory_fd::Device,
    pub _instance: Arc<Instance>,
}

impl std::ops::Deref for Device {
    type Target = ash::Device;

    fn deref(&self) -> &Self::Target {
        &self.device
    }
}

impl Drop for Device {
    fn drop(&mut self) {
        unsafe { self.destroy_device(None) };
    }
}
