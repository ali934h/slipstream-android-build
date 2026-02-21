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
ANDROID_ABI="arm64-v8a"
OPENSSL_VERSION="3.3.3"
OPENSSL_BUILD_DIR="$HOME/openssl-android"
PICOQUIC_BUILD_DIR="$SLIPSTREAM_DIR/.picoquic-build-android"
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

# ─── Step 6: Export build env vars ─────────────────────────────────────────
log "Setting up environment variables..."
export ANDROID_NDK_HOME="$NDK_DIR"
export ANDROID_API=$ANDROID_API
export ANDROID_ABI=$ANDROID_ABI
export ANDROID_PLATFORM="android-${ANDROID_API}"
export TARGET="$TARGET"
export CC="$NDK_BIN/aarch64-linux-android${ANDROID_API}-clang"
export CXX="$NDK_BIN/aarch64-linux-android${ANDROID_API}-clang++"
export AR="$NDK_BIN/llvm-ar"
export RANLIB="$NDK_BIN/llvm-ranlib"
export RUST_ANDROID_GRADLE_CC="$CC"
export RUST_ANDROID_GRADLE_AR="$AR"
export PICOQUIC_AUTO_BUILD=0
export PICOQUIC_BUILD_DIR="$PICOQUIC_BUILD_DIR"

# ─── Step 7: Build OpenSSL for Android ───────────────────────────────────
if [[ ! -f "$OPENSSL_BUILD_DIR/lib/libssl.a" ]]; then
  log "Building OpenSSL ${OPENSSL_VERSION} for Android arm64..."
  OPENSSL_SRC="$HOME/openssl-src"
  if [[ ! -d "$OPENSSL_SRC" ]]; then
    curl -L -o /tmp/openssl.tar.gz "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
    mkdir -p "$OPENSSL_SRC"
    tar -xzf /tmp/openssl.tar.gz -C "$OPENSSL_SRC" --strip-components=1
    rm /tmp/openssl.tar.gz
  fi
  mkdir -p "$OPENSSL_BUILD_DIR"
  cd "$OPENSSL_SRC"
  export PATH="$NDK_BIN:$PATH"
  ./Configure android-arm64 \
    -D__ANDROID_API__=$ANDROID_API \
    --prefix="$OPENSSL_BUILD_DIR" \
    no-shared no-tests \
    CC="$CC" AR="$AR" RANLIB="$RANLIB"
  make -j$(nproc)
  make install_sw
  cd "$SLIPSTREAM_DIR"
else
  log "OpenSSL already built, skipping."
fi

export OPENSSL_ROOT_DIR="$OPENSSL_BUILD_DIR"
export OPENSSL_INCLUDE_DIR="$OPENSSL_BUILD_DIR/include"
export OPENSSL_CRYPTO_LIBRARY="$OPENSSL_BUILD_DIR/lib/libcrypto.a"
export OPENSSL_SSL_LIBRARY="$OPENSSL_BUILD_DIR/lib/libssl.a"
export OPENSSL_USE_STATIC_LIBS=TRUE

# ─── Step 8: Build picoquic for Android ────────────────────────────────────
log "Building picoquic for Android..."
rm -rf "$PICOQUIC_BUILD_DIR"
bash "$SLIPSTREAM_DIR/scripts/build_picoquic.sh"

# ─── Step 9: Build slipstream-client ─────────────────────────────────────────
log "Starting build for $TARGET..."
cd "$SLIPSTREAM_DIR"
cargo clean -p slipstream-ffi
cargo build -p slipstream-client --release --target "$TARGET" --features openssl-vendored

# ─── Done ─────────────────────────────────────────────────────────────────────
[[ -f "$OUTPUT" ]] || die "Build finished but output binary not found!"

log "Build successful!"
log "Output: $OUTPUT"
echo
file "$OUTPUT"
