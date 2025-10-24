use std::error::Error;

use ash::vk;
use vk_video::{VulkanInstance, wrappers::Image};

fn main() -> Result<(), Box<dyn Error>> {
    let instance = VulkanInstance::new()?;
    let adapter = instance.create_adapter(None)?;
    let device = adapter.create_device(wgpu::Features::empty(), wgpu::Limits::default())?;

    let image = Image::new_export(&device.device, device.allocator.clone())?;

    let device_memory = image
        .allocator
        .get_allocation_info(&image.allocation)
        .device_memory;
    let fd_info = vk::MemoryGetFdInfoKHR::default()
        .memory(device_memory)
        .handle_type(vk::ExternalMemoryHandleTypeFlags::OPAQUE_FD);
    let mem_fd = unsafe { device.device.external_memory_fd.get_memory_fd(&fd_info)? };
    println!("Mem fd {mem_fd}");
    Ok(())
}
