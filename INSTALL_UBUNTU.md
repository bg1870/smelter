# Installing Smelter on Ubuntu Linux

This guide covers installing all prerequisites needed to build and run Smelter on Ubuntu.

## Quick Start

For most users, run the automated installation script:

```bash
./install_prerequisites_ubuntu.sh
```

This script will:
- Install all system dependencies
- Attempt to install FFmpeg 6.x (required)
- Install Rust toolchain if needed
- Verify everything is set up correctly

## Supported Ubuntu Versions

- **Ubuntu 24.04 (Noble)** ✅ Recommended - FFmpeg 6.x in default repositories
- **Ubuntu 22.04 (Jammy)** ⚠️ Requires PPA or source build
- **Ubuntu 20.04 (Focal)** ⚠️ Requires PPA or source build

## FFmpeg 6.x Requirement

**IMPORTANT**: Smelter requires FFmpeg 6.x or higher due to the new audio channel layout API (`AVChannelLayout`, `AVChannelOrder`).

### Option 1: Automatic Installation (Recommended)

The main installation script will automatically:
1. Detect your Ubuntu version
2. Use default repositories (Ubuntu 24.04+)
3. Attempt PPA installation (Ubuntu 20.04/22.04)
4. Prompt you to build from source if PPA fails

### Option 2: Build FFmpeg from Source

If the PPA fails or you're on Ubuntu 20.04/22.04, build FFmpeg from source:

```bash
./install_ffmpeg6_from_source.sh
```

This will:
- Download FFmpeg 6.1.2 source code
- Build with all necessary codecs
- Install to `/usr/local`
- Takes 10-30 minutes depending on your system

### Verify FFmpeg Version

After installation, verify you have FFmpeg 6.x:

```bash
ffmpeg -version | head -1
```

Expected output:
```
ffmpeg version 6.x.x ...
```

## Troubleshooting

### PPA Repository Errors

If you see GPG key errors or repository failures when running the script on Ubuntu 20.04/22.04:

```
W: GPG error: https://pkg.jenkins.io/debian-stable binary/ Release: ...
```

**Solution**: These are unrelated to Smelter. The FFmpeg installation will fail gracefully and prompt you to build from source:

```bash
./install_ffmpeg6_from_source.sh
```

### Build Errors Related to FFmpeg

If you see compilation errors like:
```
error[E0433]: failed to resolve: could not find `AVChannelOrder` in `ffi`
error[E0422]: cannot find struct `AVChannelLayout` in crate `ffmpeg::ffi`
error[E0609]: no field `ch_layout` on type `&mut AVCodecParameters`
```

**Cause**: You have FFmpeg 4.x or 5.x installed, but Smelter needs 6.x.

**Solution**: Install FFmpeg 6.x using the source build script:
```bash
./install_ffmpeg6_from_source.sh
```

### Missing Development Libraries

If you get pkg-config errors:
```
error: failed to run custom build command for `ffmpeg-sys-next`
```

**Solution**: Make sure you ran the prerequisites script:
```bash
./install_prerequisites_ubuntu.sh
```

## Manual Installation

If you prefer to install manually:

### 1. Install Build Tools
```bash
sudo apt-get update
sudo apt-get install -y build-essential cmake curl git pkg-config \
    ca-certificates software-properties-common
```

### 2. Install Development Libraries
```bash
sudo apt-get install -y libssl-dev libclang-dev clang llvm-dev \
    libegl1-mesa-dev libgl1-mesa-dri libvulkan-dev mesa-vulkan-drivers \
    libx11-dev libxcb-xfixes0-dev xvfb dbus dbus-x11 \
    libgtk-3-0 libgdk-pixbuf2.0-0 libatk1.0-0 libatk-bridge2.0-0 libnss3
```

### 3. Install FFmpeg 6.x

**Ubuntu 24.04:**
```bash
sudo apt-get install -y ffmpeg libavcodec-dev libavformat-dev \
    libavfilter-dev libavdevice-dev libavutil-dev libswscale-dev \
    libswresample-dev libopus-dev
```

**Ubuntu 20.04/22.04:**
```bash
./install_ffmpeg6_from_source.sh
```

### 4. Install Rust
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### 5. Build Smelter
```bash
git submodule update --init --checkout
cargo build --release
```

## Next Steps

After successful installation:

1. **Initialize submodules** (if not done already):
   ```bash
   git submodule update --init --checkout
   ```

2. **Build Smelter**:
   ```bash
   cargo build --release
   ```

3. **Run Smelter**:
   ```bash
   ./start_smelter.sh
   ```

## GPU Requirements

Smelter requires GPU support with Vulkan:

- **AMD/Intel**: Works with Mesa Vulkan drivers (installed by script)
- **NVIDIA**: Install NVIDIA proprietary drivers:
  ```bash
  sudo apt-get install nvidia-driver-XXX  # Replace XXX with version
  ```

Verify Vulkan support:
```bash
sudo apt-get install vulkan-tools
vulkaninfo
```

## Additional Resources

- [Smelter Documentation](https://smelter.dev)
- [FFmpeg Official Site](https://ffmpeg.org)
- [Report Issues](https://github.com/software-mansion/smelter/issues)
