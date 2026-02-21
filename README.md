# slipstream-android-build

A bash script to build [slipstream-client](https://github.com/Mygod/slipstream-rust) for Android arm64 (`aarch64-linux-android`) on an Ubuntu server.

The output binary runs natively on Android via Termux or ADB, using Android's Bionic libc instead of glibc.

---

## Requirements

- Ubuntu 20.04 or later (server or WSL2)
- Internet access
- ~5 GB free disk space
- `curl`, `git`, `unzip` (installed by the script if missing)

---

## Usage

### 1. Clone this repository

```bash
git clone https://github.com/ali934h/slipstream-android-build.git
cd slipstream-android-build
```

### 2. Run the build script

```bash
bash build.sh
```

The script will:
1. Install all required system packages
2. Install Rust with the `aarch64-linux-android` target
3. Download and extract Android NDK r26b
4. Configure Cargo linker
5. Clone and build `slipstream-rust`
6. Output the binary at `~/slipstream-rust/target/aarch64-linux-android/release/slipstream-client`

---

## Output

After a successful build:

```
~/slipstream-rust/target/aarch64-linux-android/release/slipstream-client
```

Verify with:

```bash
file ~/slipstream-rust/target/aarch64-linux-android/release/slipstream-client
```

Expected output:
```
ELF 64-bit LSB shared object, ARM aarch64, interpreter /system/bin/linker64
```

---

## Transfer to Android (ADB)

```bash
adb push ~/slipstream-rust/target/aarch64-linux-android/release/slipstream-client /data/local/tmp/slipstream-client
adb shell chmod +x /data/local/tmp/slipstream-client
adb shell /data/local/tmp/slipstream-client --help
```

---

## Rebuild after source update

```bash
bash build.sh --update
```

This will pull the latest changes from `slipstream-rust` and rebuild.
