# Yorunote

<p align="center">
  <img src="docs/brand/%E5%A4%9C%E8%AE%80%E6%9C%88%E9%A0%81%E7%B2%BE%E9%9D%88_%E7%9C%A8%E7%9C%BC%E5%BE%AE%E7%AC%91.gif" width="170" alt="Animated Yorunote character: a green-haired, blue-eyed moon-and-book elf blinking and smiling / Yorunote 角色動畫：綠髮藍眼的月亮書頁精靈眨眼微笑">
</p>

<p align="center"><strong>A reading-focused Flutter comic reader<br>以閱讀為中心的 Flutter 漫畫閱讀器</strong></p>

<p align="center"><a href="README.md">繁體中文</a> · <strong>English</strong></p>

<p align="center"><a href="https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0/Yorunote-0.1.0-android-arm64.apk">Download Android ARM64 APK</a> · <a href="https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0/Yorunote-0.1.0-windows-x64.zip">Download Windows x64 ZIP</a> · <a href="https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0">v0.1.0 release notes</a> · <a href="#downloads-and-releases">Downloads</a> · <a href="CHANGELOG.md">Version history</a> · <a href="#upstream-features-and-fork-contributions">Fork contributions</a></p>

Yorunote is a personal open-source fork of [Venera](https://github.com/venera-app/venera). Work in this fork covers branding, interface maintenance, image-cache fixes, cover loading, and traceable engineering evidence.

The reader and comic-source system come from upstream. This repository is a maintenance project, not a claim to have created the entire application from scratch.

## Downloads and releases

### Android ARM64 release

**[v0.1.0](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0)** (2026-11-13)

[Download Android ARM64 APK](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0/Yorunote-0.1.0-android-arm64.apk) · [Build source](https://github.com/mengwen-liu/yorunote/tree/a685c4a9e2360f2b4af507a0870d25b640c53dd4) · [CI verification](https://github.com/mengwen-liu/yorunote/actions/runs/43312975285)

- Package ID: `com.mengwenliu.yorunote`. ABI: `arm64-v8a`. Version: `0.1.0` (versionCode `2172`). The APK uses the Yorunote release signing key.
- The maintainer confirmed in-place upgrade from `2162` to `2172`, app launch, and data retention on a Galaxy S25+ and a Galaxy Tab S11 (Android 17 / One UI 9.0).
- APK SHA-256: `37ef9c55c99e262a04f0205ad73cc1107b429d98874d3f52384c52d682f8e0d5`.
- The [old public Android preview](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-preview.1) uses `com.github.wgh136.venera`. Android treats the release as a separate app. Data migration between these packages remains unverified.

### Windows x64 release

**[v0.1.0](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0)**

[Download Windows x64 ZIP](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0/Yorunote-0.1.0-windows-x64.zip) · [SHA-256 checksum](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0/Yorunote-0.1.0-windows-x64.zip.sha256) · [Build and verification](https://github.com/mengwen-liu/yorunote/actions/runs/43090132160)

- Extract the full ZIP and run `Yorunote/yorunote.exe`. Keep every DLL and the `data` directory together.
- Windows x64 CI checked the EXE version, ZIP hashes, title bar, synthetic-source reading, downloads and offline reading after restart.
- The ZIP is unsigned and runs without an installer.

## Release sources and development history

The Android APK was built from [commit `a685c4a`](https://github.com/mengwen-liu/yorunote/tree/a685c4a9e2360f2b4af507a0870d25b640c53dd4). The Windows ZIP was built from the commit pinned by the `v0.1.0` tag.

### Preview builds and historical verification

The Android preview APK source is pinned by [tag `v0.1.0-preview.1`](https://github.com/mengwen-liu/yorunote/tree/v0.1.0-preview.1) at commit `29b590b`. [Development and validation record](https://github.com/mengwen-liu/yorunote/commit/f003a708ca99a5c45f140ee554b4500ab5be8d49).

The Windows application is integrated into `master`. [Tag `v0.1.0`](https://github.com/mengwen-liu/yorunote/tree/v0.1.0) pins the release source at commit `7aa1ca09`.

| Area | Work included in the preview | Evidence |
| --- | --- | --- |
| Branding | Yorunote display name, Android adaptive/themed icons, About text | [Brand verification](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/yorunote-brand-v0.1/README.md) |
| Home presentation | Search entry, section heading, and history/local-comic cover shelves | [Integrated home-screen source](https://github.com/mengwen-liu/yorunote/blob/29b590b457378c16b19821f139b9bcad7d38f689/lib/pages/home_page.dart) |
| Reader cache | Invalid-image recovery, protection against concurrent replacement, unique cache paths | [R3.1 evidence](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/2026-11-04-r3.1/README.md) |
| Cover loading | Cache hits bypass the queue; 8 network slots; same-key sharing; cancellation propagation | [Thumbnail R2 report](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/thumbnail-r2-20261105/README.md) |
| Cover timeout | A native 30-second total timeout for each cover-image HTTP attempt | [Timeout report](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/cover-timeout-20261105/README.md) |

The preview home screen uses the search entry, section heading, and cover card. The recent-reading card and reading-progress components are not yet integrated into this home screen.

The Android application source is [`29b590b`](https://github.com/mengwen-liu/yorunote/commit/29b590b457378c16b19821f139b9bcad7d38f689). CI records (the existing run 41968314599; not re-run for this documentation update) **350 passing tests with no skips** and the same 8 existing analyzer infos, with no new warnings or errors. This does not establish Android runtime acceptance.

The 30-second timeout excludes queueing, source lookups, and retry delays. Four attempts plus the existing 2/4/8-second delays can take about 134 seconds, excluding queueing.

## Upstream features and fork contributions

| Origin | Scope |
| --- | --- |
| Upstream | Local/network comic reading, JavaScript comic sources, favorites, downloads, and source-dependent comments and tags |
| This fork | Branding and home-screen adjustments, reader-cache recovery, cover queueing/cancellation, native timeout protection, tests, and maintenance evidence |

## Building and testing

See the [Android release CI run](https://github.com/mengwen-liu/yorunote/actions/runs/43312975285) for the stable build and verification.

To reproduce the Android preview, check out the Android tag above and read its verification report. The validated toolchain is Flutter 3.41.4, Dart 3.11.1, JDK 17, Rust 1.85.1, Android SDK 36, and NDK 28.0.13004108.

The Android build configuration also needs a local `android/key.properties` file and signing key; neither belongs in Git. Host HTTP/JavaScript integration tests need the corresponding native rhttp and QuickJS libraries. See the [preview verification report](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/cover-timeout-20261105/README.md) for conditions and commands.

Windows builds use the [dedicated fixed-source workflow](https://github.com/mengwen-liu/yorunote/blob/ef9996a249b4b815b4688aa99576abd9d7899f3f/.github/workflows/yorunote-windows-preview.yml) without Build ALL. Running the ZIP does not require installing Flutter or the Android SDK. See the [Windows report](https://github.com/mengwen-liu/yorunote/blob/3490fed98e698c2aa87eb9956d0d3da4a45679db/docs/verification/windows-overlay-fix-20261106/PUBLIC_RELEASE_3.md) for exact build and runtime coverage.

## Documentation

- [Comic-source development](doc/comic_source.md) — original upstream documentation
- [Headless mode](doc/headless_doc.md) — original upstream documentation
- [Synthetic source and device acceptance](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/thumbnail-r2-20261105/ACCEPTANCE_SYNTHETIC.md)
- [Development history](CHANGELOG.md)
- [Stable release notes](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0)
- [Historical Android preview notes](docs/releases/v0.1.0-preview.1.md)
- [Bilingual Windows release notes](docs/releases/v0.1.0-windows-preview.3.md)
- [Windows English instructions](https://github.com/mengwen-liu/yorunote/blob/v0.1.0-windows-preview.3/windows/README.en.md)
- [Publication record and maintainer procedure](docs/releases/PREVIEW_RELEASE_PROCESS.md)
- [繁體中文](README.md)

## Upstream, license, and acknowledgments

- Upstream: [Venera](https://github.com/venera-app/venera).
- Code license: **GPL-3.0**; see [LICENSE](LICENSE). Copyright and third-party notices are retained.
- Tag-translation data: [EhTagTranslation](https://github.com/EhTagTranslation/Database).
- AI assisted the maintenance work. Contributions are evidenced by actual commits, tests, and verification records.
- New presentation and release documentation uses Taiwan Traditional Chinese with English counterparts. Upstream documents, licenses, and historical evidence retain their original wording.
