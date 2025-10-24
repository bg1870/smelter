use std::error::Error;

use ash::vk;
use vk_video::{wrappers::Image, VulkanInstance};

fn main() -> Result<(), Box<dyn Error>> {
    let instance = VulkanInstance::new()?;
    let adapter = instance.create_adapter(None)?;
    let device = adapter.create_device(wgpu::Features::empty(), wgpu::Limits::default())?;

    let image = Image::new_export(&device.device, device.allocator.clone())?;

    Ok(())
}
