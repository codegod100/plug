set shell := ["bash", "-uc"]

# One-time environment setup: ensure TinyGo plugin and tools
setup:
    @echo "Ensuring TinyGo plugin is installed..."
    @if ! mise plugins ls | grep -qx 'tinygo'; then \
        echo "Installing mise plugin: tinygo"; \
        mise plugin add tinygo https://github.com/troyjfarrell/asdf-tinygo; \
    else \
        echo "TinyGo plugin already installed"; \
    fi
    @echo "Installing tools from .mise.toml"
    mise install

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
    scripts/build-go-plugin.sh

# Build the Zig plugin (WASI), writing plugin.wasm at repo root
build-zig-plugin:
    @echo "Building Zig plugin (wasm32-wasi)..."
    @mkdir -p .cache/zig/global .cache/zig/local
    @cd zigplugin && \
      ZIG_GLOBAL_CACHE_DIR=../.cache/zig/global \
      ZIG_LOCAL_CACHE_DIR=../.cache/zig/local \
      mise x -- zig build-exe -O ReleaseSmall -target wasm32-wasi -fno-entry -rdynamic -femit-bin=../plugin.wasm src/main.zig && \
      rm -f ../plugin.wasm.o

# Build host and run only the Zig plugin's run() entry
mandelbrot-zig w="100" h="30" iters="120" msg="":
    just build-zig-plugin
    just build-host
    @echo "Running Zig plugin mandelbrot demo with MANDEL_W={{w}} MANDEL_H={{h}} MANDEL_ITERS={{iters}}"
    @MANDEL_W={{w}} MANDEL_H={{h}} MANDEL_ITERS={{iters}} bash -c 'msg="$1"; if [ -n "$msg" ]; then export PLUG_MSG="$msg"; fi; exec ./target/release/plug mandelbrot' -- '{{msg}}'

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
