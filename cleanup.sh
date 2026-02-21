#!/usr/bin/env bash
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[CLEAN]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $1"; }

log "Removing slipstream-rust..."
rm -rf "$HOME/slipstream-rust"

log "Removing Android NDK..."
rm -rf "$HOME/android-ndk"

log "Removing OpenSSL build..."
rm -rf "$HOME/openssl-android"
rm -rf "$HOME/openssl-src"

log "Removing Rust toolchain..."
if command -v rustup &>/dev/null; then
  rustup self uninstall -y
else
  warn "rustup not found, skipping."
fi

log "Removing Cargo config..."
rm -f "$HOME/.cargo/config.toml"

log "Done! Disk usage now:"
df -h /
