# slipstream-android-build

A bash script to build [slipstream-client](https://github.com/Mygod/slipstream-rust) for Android arm64 (`aarch64-linux-android`) on an Ubuntu server.

The output binary runs natively on Android via Termux, using Android's Bionic libc instead of glibc.

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

The script will automatically:
1. Install all required system packages
2. Install Rust with the `aarch64-linux-android` target
3. Download and extract Android NDK r26b
4. Configure Cargo linker
5. Clone `slipstream-rust` and its submodules
6. Build OpenSSL for Android arm64
7. Build picoquic for Android
8. Build `slipstream-client` and output the binary

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

## Transfer to Android

Download the binary to your phone, then move it to Termux using the [Files by Marc](https://play.google.com/store/apps/details?id=com.marc.files&hl=en) app.

1. Download `slipstream-client` from your server to your phone (via browser, SFTP, or any file transfer method)
2. Open **Files by Marc** and navigate to the downloaded file
3. Move or copy it to the Termux home directory:
   ```
   /data/data/com.termux/files/home/
   ```
4. Open **Termux** and run:
   ```bash
   chmod +x ~/slipstream-client
   ./slipstream-client --help
   ```

---

## Rebuild after source update

```bash
bash build.sh --update
```

This will pull the latest changes from `slipstream-rust` and rebuild.

---

## Cleanup

After downloading the binary, you can remove all build artifacts to free up disk space:

```bash
bash cleanup.sh
```

This removes:
- `~/slipstream-rust`
- `~/android-ndk`
- `~/openssl-android` and `~/openssl-src`
- Rust and rustup
- Cargo config
