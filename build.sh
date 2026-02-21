#!/usr/bin/env bash
set -e

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[BUILD]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
die()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ─── Config ───────────────────────────────────────────────────────────────────
ANDROID_API=21
NDK_VERSION="r26b"
NDK_ZIP="android-ndk-${NDK_VERSION}-linux.zip"
NDK_URL="https://dl.google.com/android/repository/${NDK_ZIP}"
NDK_DIR="$HOME/android-ndk/android-ndk-${NDK_VERSION}"
NDK_BIN="$NDK_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin"
SLIPSTREAM_REPO="https://github.com/Mygod/slipstream-rust.git"
SLIPSTREAM_DIR="$HOME/slipstream-rust"
TARGET="aarch64-linux-android"
OUTPUT="$SLIPSTREAM_DIR/target/$TARGET/release/slipstream-client"

# ─── Parse args ───────────────────────────────────────────────────────────────
UPDATE_ONLY=0
[[ "${1:-}" == "--update" ]] && UPDATE_ONLY=1

# ─── Step 1: System packages ──────────────────────────────────────────────────
if [[ $UPDATE_ONLY -eq 0 ]]; then
  log "Installing system packages..."
  sudo apt-get update -qq
  sudo apt-get install -y -qq \
    git curl unzip zip build-essential pkg-config \
    cmake ninja-build python3 perl make libssl-dev ca-certificates
fi

# ─── Step 2: Rust ─────────────────────────────────────────────────────────────
if [[ $UPDATE_ONLY -eq 0 ]]; then
  if ! command -v rustup &>/dev/null; then
    log "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  else
    log "Rust already installed, skipping."
  fi
  source "$HOME/.cargo/env"
  log "Adding Android target..."
  rustup target add "$TARGET"
else
  source "$HOME/.cargo/env"
fi

# ─── Step 3: Android NDK ──────────────────────────────────────────────────────
if [[ $UPDATE_ONLY -eq 0 ]]; then
  if [[ ! -d "$NDK_DIR" ]]; then
    log "Downloading Android NDK ${NDK_VERSION}..."
    mkdir -p "$HOME/android-ndk"
    curl -L --progress-bar -o "$HOME/android-ndk/${NDK_ZIP}" "$NDK_URL"
    log "Extracting NDK..."
    unzip -q "$HOME/android-ndk/${NDK_ZIP}" -d "$HOME/android-ndk/"
  else
    log "NDK already present, skipping download."
  fi

  CLANG="$NDK_BIN/aarch64-linux-android${ANDROID_API}-clang"
  [[ -f "$CLANG" ]] || die "NDK clang not found at: $CLANG"
fi

# ─── Step 4: Cargo linker config ──────────────────────────────────────────────
if [[ $UPDATE_ONLY -eq 0 ]]; then
  log "Configuring Cargo linker..."
  CLANG_PATH="$NDK_BIN/aarch64-linux-android${ANDROID_API}-clang"
  mkdir -p "$HOME/.cargo"
  cat > "$HOME/.cargo/config.toml" <<EOF
[target.aarch64-linux-android]
linker = "${CLANG_PATH}"
EOF
fi

# ─── Step 5: Clone or update slipstream-rust ─────────────────────────────────
if [[ ! -d "$SLIPSTREAM_DIR" ]]; then
  log "Cloning slipstream-rust..."
  git clone "$SLIPSTREAM_REPO" "$SLIPSTREAM_DIR"
fi

cd "$SLIPSTREAM_DIR"

if [[ $UPDATE_ONLY -eq 1 ]]; then
  log "Pulling latest changes..."
  git fetch origin
  git reset --hard origin/$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
fi

log "Updating submodules..."
git submodule update --init --recursive

# ─── Step 6: Build ────────────────────────────────────────────────────────────
log "Starting build for $TARGET..."

export ANDROID_NDK_HOME="$NDK_DIR"
export ANDROID_API=$ANDROID_API
export CC="$NDK_BIN/aarch64-linux-android${ANDROID_API}-clang"
export AR="$NDK_BIN/llvm-ar"
export RUST_ANDROID_GRADLE_CC="$CC"
export RUST_ANDROID_GRADLE_AR="$AR"
export PICOQUIC_AUTO_BUILD=0
export PICOQUIC_BUILD_DIR="$SLIPSTREAM_DIR/.picoquic-build-android"

cargo clean -p slipstream-ffi
cargo build -p slipstream-client --release --target "$TARGET" --features openssl-vendored

# ─── Done ─────────────────────────────────────────────────────────────────────
[[ -f "$OUTPUT" ]] || die "Build finished but output binary not found!"

log "Build successful!"
log "Output: $OUTPUT"
echo
file "$OUTPUT"
