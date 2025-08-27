set shell := ["bash", "-uc"]

# Default: build plugin + host and run with defaults
all w="100" h="30" iters="120" msg="":
    just build
    just run {{w}} {{h}} {{iters}} {{msg}}

# Build both plugin (wasm) and host (native)
build: build-plugin build-host
    @echo "Build complete."

# Ensure the modern WASI target is installed
ensure-wasi-target:
    @if ! rustup target list --installed | grep -q -x 'wasm32-wasip1'; then \
        echo "Installing rust target wasm32-wasip1"; \
        rustup target add wasm32-wasip1; \
    else \
        echo "Target wasm32-wasip1 already installed"; \
    fi

# Build the WASM plugin and copy the artifact to repo root as plugin.wasm
build-plugin: ensure-wasi-target
    @echo "Building plugin (wasm32-wasip1, release)..."
    cargo build --manifest-path plugin/Cargo.toml --target wasm32-wasip1 --release
    cp plugin/target/wasm32-wasip1/release/plugin.wasm plugin.wasm
    @echo "Wrote ./plugin.wasm"

# Build the native host binary
build-host:
    @echo "Building host (release)..."
    cargo build --release

# Run the host with optional environment for the Mandelbrot demo
# Usage: just run [w] [h] [iters] [msg]
run w="100" h="30" iters="120" msg="":
    @echo "Running host with MANDEL_W={{w}} MANDEL_H={{h}} MANDEL_ITERS={{iters}}"
    @MANDEL_W={{w}} MANDEL_H={{h}} MANDEL_ITERS={{iters}} bash -c 'msg="$1"; if [ -n "$msg" ]; then export PLUG_MSG="$msg"; fi; exec ./target/release/plug' -- '{{msg}}'

# Clean build artifacts
clean:
    cargo clean
    (cd plugin && cargo clean)
    @echo "Cleaned workspace"
