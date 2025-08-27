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
    @echo "Running all with MANDEL_W={{w}} MANDEL_H={{h}} MANDEL_ITERS={{iters}}"
    @MANDEL_W={{w}} MANDEL_H={{h}} MANDEL_ITERS={{iters}} bash -c 'msg="$1"; if [ -n "$msg" ]; then export PLUG_MSG="$msg"; fi; exec ./target/release/plug all' -- '{{msg}}'

# Run only the Mandelbrot demo
mandelbrot w="100" h="30" iters="120" msg="":
    just build
    @echo "Running mandelbrot with MANDEL_W={{w}} MANDEL_H={{h}} MANDEL_ITERS={{iters}}"
    @MANDEL_W={{w}} MANDEL_H={{h}} MANDEL_ITERS={{iters}} bash -c 'msg="$1"; if [ -n "$msg" ]; then export PLUG_MSG="$msg"; fi; exec ./target/release/plug mandelbrot' -- '{{msg}}'

# Run only fib with an argument
fib n="10":
    just build
    @echo "Running fib {{n}}"
    ./target/release/plug fib {{n}}

# Run only add with two integers
add a b:
    just build
    @echo "Running add {{a}} {{b}}"
    ./target/release/plug add {{a}} {{b}}

# Build the Go plugin with TinyGo only
build-go-plugin:
    @echo "Building Go plugin with TinyGo..."
    # Use a workspace-local cache to avoid writing to $HOME (sandbox)
    @mkdir -p .cache/go-build .cache/gomod .cache/tmp
    # Use mise to ensure the pinned TinyGo is used
    (cd goplugin && \
      XDG_CACHE_HOME="$(pwd)/../.cache" \
      GOCACHE="$(pwd)/../.cache/go-build" \
      GOMODCACHE="$(pwd)/../.cache/gomod" \
      GOTMPDIR="$(pwd)/../.cache/tmp" \
      mise x -- tinygo build -o ../plugin.wasm -target=wasi .)

# Build host and run only the Go plugin's run() entry
mandelbrot-go w="100" h="30" iters="120" msg="":
    just build-go-plugin
    just build-host
    @echo "Running Go plugin mandelbrot-like demo with MANDEL_W={{w}} MANDEL_H={{h}} MANDEL_ITERS={{iters}}"
    @MANDEL_W={{w}} MANDEL_H={{h}} MANDEL_ITERS={{iters}} bash -c 'msg="$1"; if [ -n "$msg" ]; then export PLUG_MSG="$msg"; fi; exec ./target/release/plug mandelbrot' -- '{{msg}}'

# Clean build artifacts
clean:
    cargo clean
    (cd plugin && cargo clean)
    @echo "Cleaned workspace"
