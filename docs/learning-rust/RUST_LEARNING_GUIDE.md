# Learning Rust Through the Smelter Codebase

A guide for Java, Python, TypeScript, and Elixir developers

## Table of Contents
1. [What is Smelter?](#what-is-smelter)
2. [Rust Concepts Map](#rust-concepts-map)
3. [Key Rust Concepts in This Codebase](#key-rust-concepts-in-this-codebase)
4. [Learning Path](#learning-path)
5. [Recommended Files to Study](#recommended-files-to-study)

---

## What is Smelter?

Smelter is a **real-time, low-latency video and audio composition toolkit**. It handles:
- Multimedia streaming from different sources
- Video encoding/decoding (H264, VP8, VP9)
- Audio encoding/decoding (Opus, AAC)
- WebRTC (WHIP/WHEP protocols)
- GPU rendering (via wgpu)
- Real-time frame synchronization

This is an excellent codebase for learning Rust because it demonstrates:
- **Systems programming** (FFI with C libraries like FFmpeg)
- **Concurrency** (threads, channels, async/await)
- **Type safety** (enums, pattern matching, error handling)
- **Performance** (zero-cost abstractions, ownership system)

---

## Rust Concepts Map

### For Java Developers

| Rust Concept | Java Equivalent | Key Difference |
|--------------|-----------------|----------------|
| `struct` | `class` | No inheritance; use composition and traits |
| `enum` | `enum` + sealed classes | Rust enums can hold data (algebraic data types) |
| `trait` | `interface` | Can provide default implementations |
| `Result<T, E>` | `Optional` + exceptions | Explicit error handling, no exceptions |
| `Option<T>` | `Optional<T>` | Very similar, but more idiomatic |
| `Arc<T>` | `AtomicReference<T>` | Thread-safe reference counting |
| `Mutex<T>` | `synchronized` | Explicit locking, prevents data races at compile time |
| Ownership | Garbage collection | No GC; memory freed deterministically |

### For Python Developers

| Rust Concept | Python Equivalent | Key Difference |
|--------------|-------------------|----------------|
| `struct` | `@dataclass` | Strongly typed, compile-time checked |
| `enum` | `Enum` | Can contain different types of data |
| `match` | `match` (Python 3.10+) | Exhaustive, compiler-enforced |
| `Result<T, E>` | Try/except | Errors are values, not exceptions |
| `Vec<T>` | `list` | Typed, contiguous memory |
| `HashMap<K, V>` | `dict` | Typed keys and values |
| Lifetimes | (none) | Explicit memory management without GC |
| `async/await` | `async/await` | Similar syntax, different runtime model |

### For TypeScript Developers

| Rust Concept | TypeScript Equivalent | Key Difference |
|--------------|----------------------|----------------|
| `struct` | `interface` / `type` | Runtime representation, not just types |
| `enum` | Discriminated unions | Built into language, pattern matching |
| `Option<T>` | `T \| null \| undefined` | Explicit, no null/undefined confusion |
| `Result<T, E>` | (none) | Explicit error handling |
| Ownership | (none) | Memory safety without GC |
| `trait` | `interface` | Can be implemented for existing types |
| Generics | Generics | Monomorphization (compile-time specialization) |

### For Elixir Developers

| Rust Concept | Elixir Equivalent | Key Difference |
|--------------|-------------------|----------------|
| `enum` | Tagged tuples | Similar to pattern matching |
| `match` | `case` | Very similar! Exhaustive checking |
| `Result<T, E>` | `{:ok, value} \| {:error, reason}` | Nearly identical concept! |
| `Option<T>` | `value \| nil` | Explicit handling with pattern matching |
| `struct` | `%Module{}` | Similar, but more rigid type checking |
| Channels | `GenServer` / processes | OS threads instead of lightweight processes |
| `Arc<Mutex<T>>` | Process state | Shared memory instead of message passing |
| Ownership | Immutability | Different approach to same goal |

---

## Key Rust Concepts in This Codebase

### 1. **Ownership & Borrowing**

The core of Rust's memory safety. Every value has exactly one owner.

**Example in `smelter-core/src/queue.rs:164`:**

```rust
pub(crate) fn new(opts: QueueOptions, ctx: &Arc<PipelineCtx>) -> Arc<Self> {
    // `opts` is moved (ownership transferred)
    // `ctx` is borrowed (reference, no ownership transfer)
    let queue = Arc::new(Queue {
        video_queue: Mutex::new(VideoQueue::new(
            sync_point,
            ctx.event_emitter.clone(),  // Clone the Arc (cheap, just increments refcount)
            opts.ahead_of_time_processing,
        )),
        // ...
    });
    queue  // Return ownership to caller
}
```

**Key Points:**
- `opts: QueueOptions` - Takes ownership (like passing by value in C++)
- `ctx: &Arc<PipelineCtx>` - Borrows a reference (like passing by reference)
- `Arc::new()` - Reference counted pointer (like Python's references, but explicit)
- `.clone()` on Arc is cheap - just increments a counter

**Similar to:**
- **Elixir**: Immutability by default, but Rust uses move semantics
- **Java**: Like having strict control over when objects are copied vs. shared
- **Python**: Everything is a reference, but Rust makes ownership explicit

---

### 2. **Enums & Pattern Matching**

Rust enums are powerful - they can contain data!

**Example in `smelter-core/src/types.rs:6-9`:**

```rust
pub enum PipelineEvent<T> {
    Data(T),
    EOS,  // End of Stream
}
```

**Usage with pattern matching:**

```rust
match event {
    PipelineEvent::Data(frame) => {
        // `frame` is extracted from the Data variant
        process_frame(frame);
    }
    PipelineEvent::EOS => {
        // Handle end of stream
        cleanup();
    }
}
```

**Similar to:**
- **Elixir**: `{:ok, data} | :error` - Very similar concept!
- **TypeScript**: Discriminated unions, but with runtime checks
- **Java**: Sealed classes + pattern matching (Java 17+)

---

### 3. **Error Handling with Result**

No exceptions! Errors are values.

**Example in `smelter-core/src/error.rs:11-27`:**

```rust
#[derive(Debug, thiserror::Error)]
pub enum InitPipelineError {
    #[error(transparent)]
    InitRendererEngine(#[from] InitRendererEngineError),

    #[error("Failed to create a download directory.")]
    CreateDownloadDir(#[source] std::io::Error),

    // ... more error variants
}
```

**Usage:**

```rust
fn initialize() -> Result<Pipeline, InitPipelineError> {
    let renderer = init_renderer()?;  // `?` propagates errors
    let download_dir = create_dir()
        .map_err(InitPipelineError::CreateDownloadDir)?;

    Ok(Pipeline::new(renderer, download_dir))
}
```

**The `?` operator:**
- Like `try/catch` but reversed
- Automatically converts and propagates errors up the call stack
- Similar to Elixir's `with` construct

**Similar to:**
- **Elixir**: `{:ok, result} | {:error, reason}` - Nearly identical!
- **Java**: Checked exceptions, but as return values
- **Python**: Like returning `(value, error)` tuples, but type-safe
- **TypeScript**: Like `Either` type from functional programming

---

### 4. **Traits** (Polymorphism)

Traits define shared behavior, like interfaces.

**Example in `smelter-core/src/types.rs:38-47`:**

```rust
impl fmt::Debug for AudioSamples {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            AudioSamples::Mono(samples) =>
                write!(f, "AudioSamples::Mono(len={})", samples.len()),
            AudioSamples::Stereo(samples) =>
                write!(f, "AudioSamples::Stereo(len={})", samples.len()),
        }
    }
}
```

**Key Points:**
- Implementing `Debug` trait enables `println!("{:?}", value)`
- Can implement traits for types you don't own
- Traits can have default implementations

**Similar to:**
- **Java**: `interface` + default methods
- **TypeScript**: `interface` with implementations
- **Elixir**: Protocols
- **Python**: Duck typing, but compile-time checked

---

### 5. **Generics**

Type-safe code reuse.

**Example in `smelter-core/src/types.rs:5-9`:**

```rust
pub enum PipelineEvent<T> {
    Data(T),
    EOS,
}
```

**Usage:**

```rust
// Can be specialized for any type:
let video_event: PipelineEvent<Frame> = PipelineEvent::Data(frame);
let audio_event: PipelineEvent<AudioSamples> = PipelineEvent::Data(samples);
```

**Key Difference:**
- Rust uses **monomorphization**: generates specialized code for each type at compile time
- Zero runtime cost (unlike Java's type erasure or Python's generic runtime checks)

**Similar to:**
- **TypeScript**: Very similar syntax
- **Java**: Similar, but Rust has no type erasure
- **Elixir**: Specs, but not enforced at runtime

---

### 6. **Concurrency with Threads and Channels**

Safe concurrency without data races.

**Example in `smelter-core/src/queue.rs:165-166`:**

```rust
let (queue_start_sender, queue_start_receiver) = bounded(0);
let (scheduled_event_sender, scheduled_event_receiver) = bounded(0);
```

**Using channels:**

```rust
// Sender side
sender.send(event).unwrap();

// Receiver side
match receiver.recv() {
    Ok(event) => process(event),
    Err(_) => println!("Channel closed"),
}
```

**Key Points:**
- `crossbeam_channel` provides CSP-style channels
- Type-safe: can only send/receive specific types
- Compiler prevents data races

**Similar to:**
- **Elixir**: Process mailboxes - Very similar concept!
- **Java**: `BlockingQueue`
- **Python**: `queue.Queue`
- **TypeScript**: (none) - Node.js has event emitters

---

### 7. **Shared State with Arc and Mutex**

Thread-safe shared memory.

**Example in `smelter-core/src/queue.rs:72-73`:**

```rust
pub struct Queue {
    video_queue: Mutex<VideoQueue>,
    audio_queue: Mutex<AudioQueue>,
    // ...
}
```

**Usage:**

```rust
let queue = Arc::new(Queue { /* ... */ });

// Thread 1
let queue_clone = queue.clone();  // Clone Arc, not Queue
std::thread::spawn(move || {
    let mut video = queue_clone.video_queue.lock().unwrap();
    video.add_frame(frame);
});

// Thread 2
let audio = queue.audio_queue.lock().unwrap();
audio.process();
```

**Key Points:**
- `Arc<T>` = Atomic Reference Counted (thread-safe shared ownership)
- `Mutex<T>` = Mutual exclusion (locks the data)
- `.lock()` returns a guard that releases lock when dropped
- Compiler prevents accessing data without locking!

**Similar to:**
- **Java**: `AtomicReference` + `synchronized`
- **Elixir**: Agent / GenServer state (different paradigm)
- **Python**: `threading.Lock` but compile-time enforced

---

### 8. **Lifetimes** (Advanced)

Lifetimes ensure references are always valid.

**Example:**

```rust
// This won't compile - dangling reference!
fn bad() -> &String {
    let s = String::from("hello");
    &s  // ERROR: `s` is dropped here!
}

// This works - lifetime explicit
fn good<'a>(s: &'a str) -> &'a str {
    s  // OK: returns a reference with same lifetime as input
}
```

**In practice:**
- Often inferred by compiler
- Prevents use-after-free bugs at compile time
- No equivalent in other languages

**Skip lifetimes for now** - focus on ownership first!

---

### 9. **Module System**

**Example in `smelter-core/src/lib.rs:1-24`:**

```rust
mod audio_mixer;  // Private module
pub mod codecs;   // Public module

pub use pipeline::*;  // Re-export everything from pipeline
```

**Key Points:**
- `mod` declares a module
- `pub` makes things public
- `use` imports items
- `pub use` re-exports (like TypeScript's `export * from`)

**Similar to:**
- **TypeScript**: `import/export`
- **Python**: `import` and `__init__.py`
- **Java**: `package` and `import`

---

### 10. **Cargo & Workspace**

Rust's build system and package manager.

**In `Cargo.toml:7-23`:**

```toml
[workspace]
members = [
    "smelter-api",
    "smelter-core",
    "smelter-render",
    # ... more crates
]
```

**Key Commands:**
- `cargo build` - Build the project
- `cargo test` - Run tests
- `cargo run` - Build and run
- `cargo check` - Check for errors without building
- `cargo doc --open` - Generate and open documentation

**Similar to:**
- **TypeScript**: `npm` + `package.json`
- **Python**: `pip` + `requirements.txt` or `poetry`
- **Elixir**: `mix`

---

## Learning Path

### Phase 1: Understand the Basics (Week 1-2)

Start with these concepts in order:

1. **Ownership Basics**
   - Read: `smelter-core/src/types.rs`
   - Focus on: How data is moved vs. borrowed

2. **Enums and Pattern Matching**
   - Read: `smelter-core/src/types.rs` (MediaKind, AudioSamples)
   - Try: Add a new enum variant

3. **Error Handling**
   - Read: `smelter-core/src/error.rs`
   - Focus on: `#[derive(thiserror::Error)]` pattern
   - Compare to: Elixir's `{:ok, result}` pattern you know well!

4. **Module System**
   - Read: `smelter-core/src/lib.rs`
   - Read: `smelter-api/src/lib.rs`
   - Understand: How modules are organized

### Phase 2: Dive into Application Logic (Week 3-4)

5. **Structs and Methods**
   - Read: `smelter-core/src/queue.rs`
   - Focus on: Queue struct definition (line 71-97)
   - Focus on: Methods implementation (line 163-261)

6. **Concurrency with Channels**
   - Read: `smelter-core/src/queue.rs`
   - Focus on: Channel creation (line 165-166)
   - Focus on: How data flows between threads

7. **Shared State**
   - Read: `smelter-core/src/queue.rs`
   - Focus on: `Arc<Mutex<>>` pattern
   - Compare to: Elixir's process state

### Phase 3: Advanced Features (Week 5-6)

8. **Traits**
   - Read: `smelter-core/src/types.rs:38-47` (Debug implementation)
   - Read: `smelter-core/src/error.rs:225-419` (From implementations)

9. **Conditional Compilation**
   - Read: `smelter-api/src/lib.rs:10-26`
   - Focus on: `#[cfg(not(target_arch = "wasm32"))]`

10. **FFI (Foreign Function Interface)**
    - Read: `src/main.rs:14-28`
    - See: How Rust calls C libraries (FFmpeg, libcef)

11. **Async/Await** (if interested)
    - Look for: `async fn` and `.await` in WebRTC code
    - File: `smelter-core/src/pipeline/webrtc/`

### Phase 4: Build Something! (Week 7+)

Pick a task to implement:

**Beginner:**
- Add a new codec enum variant in `smelter-core/src/codecs/`
- Add a new error type in `smelter-core/src/error.rs`

**Intermediate:**
- Add logging to track frame processing times
- Implement a simple input source

**Advanced:**
- Contribute to an actual feature or bug fix!

---

## Recommended Files to Study

### Start Here (Easy → Intermediate)

1. **`smelter-core/src/types.rs`** (62 lines)
   - Simple enums and structs
   - Pattern matching examples
   - Good for understanding Rust basics

2. **`smelter-core/src/error.rs`** (420 lines)
   - Error handling patterns
   - Enum variants with data
   - Trait implementations (From conversions)

3. **`smelter-core/src/lib.rs`** (24 lines)
   - Module organization
   - Re-exports

4. **`src/lib.rs`** (10 lines)
   - Top-level module structure

### Intermediate

5. **`smelter-core/src/queue.rs`** (287 lines)
   - Struct definitions
   - Concurrency (channels, Arc, Mutex)
   - Thread management
   - Real application logic

6. **`src/main.rs`** (37 lines)
   - Entry point
   - Conditional compilation
   - FFI basics

7. **`Cargo.toml`**
   - Workspace configuration
   - Dependencies
   - Features

### Advanced

8. **`smelter-core/src/pipeline/`**
   - Complex state management
   - More advanced patterns

9. **`smelter-render/`**
   - GPU programming
   - WGPU usage

10. **`vk-video/`**
    - FFI with Vulkan
    - Unsafe Rust

---

## Key Differences Coming from Your Languages

### From Elixir

**What's familiar:**
- Pattern matching (even better in Rust!)
- Error handling with Result type
- Thinking about data flow

**What's different:**
- Shared memory instead of message passing (different concurrency model)
- Mutable state is allowed (but controlled)
- Compile-time type checking (no runtime surprises)
- No garbage collection (ownership system instead)

### From Java

**What's familiar:**
- Strong type system
- Interfaces (traits)
- Generics (but better!)

**What's different:**
- No inheritance (composition over inheritance)
- No null (use Option<T>)
- No exceptions (use Result<T, E>)
- No garbage collection (ownership instead)
- Explicit memory layout control

### From Python

**What's familiar:**
- Modern syntax
- Pattern matching (Python 3.10+)

**What's different:**
- Everything is typed
- Compile-time checks
- No runtime duck typing
- Explicit error handling
- Manual memory management (but safe!)

### From TypeScript

**What's familiar:**
- Type annotations
- Generics
- Modern syntax

**What's different:**
- Types exist at runtime
- No `null` or `undefined` (use Option<T>)
- Memory control
- True enums with data
- Zero-cost abstractions

---

## Resources

### Official Documentation
- [The Rust Book](https://doc.rust-lang.org/book/) - Start here!
- [Rust by Example](https://doc.rust-lang.org/rust-by-example/)
- [Rustlings](https://github.com/rust-lang/rustlings) - Interactive exercises

### For Your Background
- Coming from Java: [Rust for Java Developers](https://github.com/Dhghomon/rust_for_java_developers)
- Coming from Python: [Python to Rust](https://github.com/rochacbruno/py2rs)
- Coming from TypeScript: [Rust for TypeScript Developers](https://github.com/pretzelhammer/rust-blog/blob/master/posts/tour-of-rusts-standard-library-traits.md)

### Smelter-Specific
- Run: `cargo doc --open` to see generated documentation
- Check: `DEVELOPMENT.md` for building the project

---

## Quick Start Commands

```bash
# Check if everything compiles
cargo check

# Build the project
cargo build

# Run tests
cargo test

# Build and run
cargo run

# Generate documentation
cargo doc --open

# Format code
cargo fmt

# Run linter
cargo clippy

# Build specific crate
cargo build -p smelter-core
```

---

## Common Patterns You'll See

### 1. Constructor Pattern

```rust
impl Queue {
    pub fn new(opts: QueueOptions) -> Self {
        Self {
            // initialize fields
        }
    }
}
```

### 2. Builder Pattern

```rust
let server = Server::builder()
    .port(8080)
    .timeout(Duration::from_secs(30))
    .build()?;
```

### 3. Error Propagation

```rust
fn do_work() -> Result<(), Error> {
    let file = open_file()?;  // Returns early if error
    let data = read_data(file)?;
    process(data)?;
    Ok(())
}
```

### 4. Arc + Mutex for Shared State

```rust
let state = Arc::new(Mutex::new(State::new()));
let state_clone = state.clone();

thread::spawn(move || {
    let mut s = state_clone.lock().unwrap();
    s.update();
});
```

### 5. Channels for Communication

```rust
let (tx, rx) = channel();

thread::spawn(move || {
    tx.send(42).unwrap();
});

let value = rx.recv().unwrap();
```

---

## Tips for Learning

1. **Start Small**: Don't try to understand everything at once
2. **Use the Compiler**: Rust's error messages are excellent teachers
3. **cargo check Often**: Fast feedback loop
4. **Read Error Messages Carefully**: They often suggest fixes
5. **Use rust-analyzer**: IDE support is excellent (VS Code, IntelliJ)
6. **Don't Fear the Borrow Checker**: It's teaching you memory safety
7. **Compare to Elixir**: The Result pattern will feel natural to you!

---

## Next Steps

1. Install Rust: `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
2. Read chapters 1-6 of [The Rust Book](https://doc.rust-lang.org/book/)
3. Start with Phase 1 of the learning path above
4. Try compiling smelter: `cargo build`
5. Pick a simple task from Phase 4 and implement it!

Happy learning! 🦀
