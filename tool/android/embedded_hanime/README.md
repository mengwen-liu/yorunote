# Windows ARM64 embedded Han1meViewer Debug build

The Yorunote baseline is `600a7b7e4e079ff9b8196730d6ebebbe9a195088`. The Git submodule pins Han1meViewer to `901a89ca4ebd557bf793d2dd6130b714e22b3109`. Its Apache-2.0 license stays in the submodule. The Library patch preserves applicable notices and records the R1 App-to-Library and R3 initialization, storage and Activity changes. Host sources contain the reviewed R2 and R3 changes.

1. Clone this branch and run `git submodule update --init -- third_party/Han1meViewer-Remastered`. Use a physical ASCII path for the clone and Windows native tools. A junction alone can expose the underlying Unicode paths to Ninja, MinGW or LLD.
2. Provide Flutter 3.47.9 (Dart 3.13.7), JDK 21, Android platform 37, Build Tools 36.0.0, NDK 28.0.13004108, plugin NDK 28.2.13676358, CMake 3.22.1, Python 3.11 or newer, and Rust 1.85.1 Windows GNU with the `aarch64-linux-android` target. The wrappers use Gradle 9.4.1. The projects use AGP 9.2.1 and Kotlin plugin 2.3.21. The Rust host linker is resolved from the selected sysroot, and `rustup.exe` is resolved from the selected Cargo bin directory.
3. Run the PowerShell build script in a child process. Supply paths to the installed toolchain. The optional `-Offline` switch requires populated Pub, Gradle and Cargo caches.

```powershell
pwsh -NoProfile -File tool/android/embedded_hanime/build-arm64.ps1 `
  -FlutterRoot D:/tools/flutter -AndroidSdk D:/tools/android-sdk `
  -JavaHome D:/tools/jdk-21 -RustupHome D:/tools/rustup `
  -CMakeRoot D:/tools/cmake-3.22.1 -CargoHome D:/tools/cargo
```

The script uses the committed Pub lockfile. Before applying the seven R2 Pub changes, it checks each original file's SHA-256 with LF normalization. It accepts an already patched cache after verifying the patched SHA-256, and rejects unexpected or mixed states. The cache lives in `.local-data/build-env/pub`.

The Library is rebuilt from a Git archive of the pinned submodule commit, excluding signing files. The source patch applies to the archive. The script runs its JVM tests and publishes both Debug AARs, including Maven dependency metadata, to `.local-data/build-env/r3-maven`. These generated inputs stay local. The Flutter host uses this Maven repository to package the original Compose Activity, Media3 and MPV.

The APK output is `build/app/outputs/flutter-apk/app-debug.apk`. This build uses the Debug-only local key under `.local-data/build-env` and application ID `com.mengwenliu.yorunote.candidate.v020`. APK hashes depend on signing and build inputs. Use the corresponding debug certificate to compare rebuilt outputs.

The R3 Widget and JVM tests cover the MethodChannel, duplicate launches and Library namespaces. The existing Flutter UX02 home ordering test may fail. Original account login and the Cloudflare challenge remain disabled. R4 reports are preliminary device observations from the user.
