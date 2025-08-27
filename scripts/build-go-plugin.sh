#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

mkdir -p .cache .cache/go-build .cache/gomod .cache/tmp

SIG_FILE=.cache/goplugin.sig

FILES=(".mise.toml")
[[ -f goplugin/go.mod ]] && FILES+=("goplugin/go.mod")
[[ -f goplugin/go.sum ]] && FILES+=("goplugin/go.sum")
while IFS= read -r -d '' f; do FILES+=("$f"); done < <(find goplugin -maxdepth 1 -name '*.go' -print0 2>/dev/null)

# Compute signature of inputs deterministically
SIG=$(tar --sort=name --mtime='UTC 1970-01-01' --owner=0 --group=0 --numeric-owner -cf - "${FILES[@]}" 2>/dev/null | sha256sum)
SIG=${SIG%% *}

OLD_SIG=""
[[ -f "$SIG_FILE" ]] && OLD_SIG=$(cat "$SIG_FILE")

if [[ -f plugin.wasm && "$SIG" == "$OLD_SIG" ]]; then
  echo "TinyGo plugin up-to-date, skipping build."
  exit 0
fi

echo "Building Go plugin with TinyGo..."
pushd goplugin >/dev/null
  XDG_CACHE_HOME="$ROOT_DIR/.cache" \
  GOCACHE="$ROOT_DIR/.cache/go-build" \
  GOMODCACHE="$ROOT_DIR/.cache/gomod" \
  GOTMPDIR="$ROOT_DIR/.cache/tmp" \
  mise x -- tinygo build -o ../plugin.wasm -target=wasi .
popd >/dev/null

echo "$SIG" > "$SIG_FILE"
echo "Wrote plugin.wasm"

