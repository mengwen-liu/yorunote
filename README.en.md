# Yorunote

<p align="center">
  <img src="docs/brand/%E5%A4%9C%E8%AE%80%E6%9C%88%E9%A0%81%E7%B2%BE%E9%9D%88_%E7%9C%A8%E7%9C%BC%E5%BE%AE%E7%AC%91.gif" width="170" alt="Animated Yorunote character: a green-haired, blue-eyed moon-and-book elf blinking and smiling / Yorunote 角色動畫：綠髮藍眼的月亮書頁精靈眨眼微笑">
</p>

<p align="center"><strong>A reading-focused Flutter comic reader<br>以閱讀為中心的 Flutter 漫畫閱讀器</strong></p>

<p align="center"><a href="README.md">繁體中文</a> · <strong>English</strong></p>

<p align="center"><a href="https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-preview.1">v0.1.0-preview.1 · Android</a> · <a href="https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-windows-preview.3">v0.1.0-windows-preview.3 · Windows x64</a> · <a href="#downloads-and-releases">Downloads</a> · <a href="CHANGELOG.md">Version history</a> · <a href="#upstream-features-and-fork-contributions">Fork contributions</a></p>

Yorunote is a personal open-source fork of [Venera](https://github.com/venera-app/venera). Work in this fork covers branding, interface maintenance, image-cache fixes, cover loading, and traceable engineering evidence.

The reader and comic-source system come from upstream. This repository is a maintenance project, not a claim to have created the entire application from scratch.

## Downloads and releases

**Android public preview: [v0.1.0-preview.1](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-preview.1)** (2026-11-05)

[Download Android ARM64 APK](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0-preview.1/Yorunote_29b590b_cover_timeout_arm64_profile.apk) · [SHA-256 checksum](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0-preview.1/Yorunote_29b590b_cover_timeout_arm64_profile.apk.sha256) · [All releases](https://github.com/mengwen-liu/yorunote/releases)

- This is an Android `arm64-v8a` **Profile test build**. The internal app version remains 1.6.3 (versionCode 2163), independently of the GitHub preview tag.
- [Bilingual release notes and known limitations](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-preview.1) describe the changes, existing test results, and installation guidance.
- APK size: 27,882,063 bytes. SHA-256: `7ad08033c204a1de62546ca588ea0c050a5ace8ec0d4945d8c7978e156f5057f`.
- [Development history](CHANGELOG.md) preserves candidate changes and development records; [Releases](https://github.com/mengwen-liu/yorunote/releases) is the reference for published versions.
- Original build evidence remains in [Actions run 41968314599](https://github.com/mengwen-liu/yorunote/actions/runs/41968314599). Use the Release assets above for downloads.

> **Installation compatibility:** the APK uses a disposable test certificate. It cannot update an installed app with the same package ID and a different signing certificate. Preserve the existing app and its data. A persistent signing and update channel has not been established.
>
> **Validation scope:** this is a public preview, with runtime acceptance on the S25+ and Tab S11 still pending. The 350 passing tests and static APK checks are existing CI results; this publication did not re-run tests or rebuild the APK.

### Windows x64 preview

**[v0.1.0-windows-preview.3](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-windows-preview.3)** (2026-11-07)

[Download Windows x64 ZIP](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0-windows-preview.3/Yorunote_windows_x64_07406c9f_preview.zip) · [SHA-256 checksum](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0-windows-preview.3/Yorunote_windows_x64_07406c9f_preview.zip.sha256) · [Bilingual release notes](docs/releases/v0.1.0-windows-preview.3.md)

- App source is fixed at `07406c9f`, built in **Release mode**. Extract the complete ZIP and run `Yorunote/yorunote.exe`; keep every DLL and the `data` directory together.
- Fixes `No Overlay widget found.` in the upper-left caption while retaining the 28×28 animated elf and tooltip. Inactive/reduced-motion states use the static image.
- ZIP: 22,015,039 bytes. SHA-256: `cf7d5a616af30867349bb9136a491188d7a28a12e0d4778f9a2a1c74e6257ed3`.
- [Windows CI and publication verification](https://github.com/mengwen-liu/yorunote/blob/3490fed98e698c2aa87eb9956d0d3da4a45679db/docs/verification/windows-overlay-fix-20261106/PUBLIC_RELEASE_3.md): 13 focused tests, 11 initial-process and 4 restart checks passed; separate downloads verified the ZIP, checksum and complete file manifest.
- On 2026-11-07, the user [confirmed elf animation and tooltip behavior](https://github.com/mengwen-liu/yorunote/blob/2d0d5375f5e4f53f96f3558ad10278a7762c8797/docs/verification/windows-overlay-fix-20261106/OWNER_ACCEPTANCE.md). This is a user-reported check of those two UI behaviors, not complete device acceptance.
- The unsigned build has no installer. Its separate `mengwen-liu / Yorunote` data directory does not automatically migrate existing Venera data.
- WebView2 login, all third-party sources, all DPI settings, multiple monitors and Windows ARM64 are not fully covered. This remains a preview.

## Current development state

The Android preview's application source is pinned by [tag `v0.1.0-preview.1`](https://github.com/mengwen-liu/yorunote/tree/v0.1.0-preview.1) at commit `29b590b`. `master` contains the project homepages and release documentation, but has not integrated that application code. Use the tag to obtain the source matching the APK; the [candidate branch and complete evidence](https://github.com/mengwen-liu/yorunote/tree/claude/yorunote-cover-timeout-20261105) retain the development history.

Windows source is separately pinned by [tag `v0.1.0-windows-preview.3`](https://github.com/mengwen-liu/yorunote/tree/v0.1.0-windows-preview.3) at `07406c9f`. Source commits, build modes and validation records are distinct for the two platforms; neither application snapshot has been merged into `master`.

| Area | Work included in the preview | Evidence |
| --- | --- | --- |
| Branding | Yorunote display name, Android adaptive/themed icons, About text | [Brand verification](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/yorunote-brand-v0.1/README.md) |
| Home presentation | Search entry, section heading, and history/local-comic cover shelves | [Integrated home-screen source](https://github.com/mengwen-liu/yorunote/blob/29b590b457378c16b19821f139b9bcad7d38f689/lib/pages/home_page.dart) |
| Reader cache | Invalid-image recovery, protection against concurrent replacement, unique cache paths | [R3.1 evidence](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/2026-11-04-r3.1/README.md) |
| Cover loading | Cache hits bypass the queue; 8 network slots; same-key sharing; cancellation propagation | [Thumbnail R2 report](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/thumbnail-r2-20261105/README.md) |
| Cover timeout | A native 30-second total timeout for each cover-image HTTP attempt | [Timeout report](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/cover-timeout-20261105/README.md) |

The home screen uses the search entry, section heading, and cover card. The recent-reading card and reading-progress components are not yet integrated into this home screen.

The Android application source is [`29b590b`](https://github.com/mengwen-liu/yorunote/commit/29b590b457378c16b19821f139b9bcad7d38f689). CI records (the existing run 41968314599; not re-run for this documentation update) **350 passing tests with no skips** and the same 8 existing analyzer infos, with no new warnings or errors. This does not establish Android runtime acceptance.

The 30-second timeout excludes queueing, source lookups, and retry delays. Four attempts plus the existing 2/4/8-second delays can take about 134 seconds, excluding queueing.

## Upstream features and fork contributions

| Origin | Scope |
| --- | --- |
| Upstream | Local/network comic reading, JavaScript comic sources, favorites, downloads, and source-dependent comments and tags |
| This fork | Branding and home-screen adjustments, reader-cache recovery, cover queueing/cancellation, native timeout protection, tests, and maintenance evidence |

## Building and testing

To reproduce the Android preview, check out the Android tag above and read its verification report. The validated toolchain is Flutter 3.41.4, Dart 3.11.1, JDK 17, Rust 1.85.1, Android SDK 36, and NDK 28.0.13004108.

The Android build configuration also needs a local `android/key.properties` file and signing key; neither belongs in Git. Host HTTP/JavaScript integration tests need the corresponding native rhttp and QuickJS libraries. See the [latest verification report](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/cover-timeout-20261105/README.md) for conditions and commands.

Windows builds use the [dedicated fixed-source workflow](https://github.com/mengwen-liu/yorunote/blob/ef9996a249b4b815b4688aa99576abd9d7899f3f/.github/workflows/yorunote-windows-preview.yml) without Build ALL. Running the ZIP does not require installing Flutter or the Android SDK. See the [Windows report](https://github.com/mengwen-liu/yorunote/blob/3490fed98e698c2aa87eb9956d0d3da4a45679db/docs/verification/windows-overlay-fix-20261106/PUBLIC_RELEASE_3.md) for exact build and runtime coverage.

## Documentation

- [Comic-source development](doc/comic_source.md) — original upstream documentation
- [Headless mode](doc/headless_doc.md) — original upstream documentation
- [Synthetic source and device acceptance](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/thumbnail-r2-20261105/ACCEPTANCE_SYNTHETIC.md)
- [Development history](CHANGELOG.md)
- [Android release notes](docs/releases/v0.1.0-preview.1.md)
- [Bilingual Windows release notes](docs/releases/v0.1.0-windows-preview.3.md)
- [Windows English instructions](https://github.com/mengwen-liu/yorunote/blob/v0.1.0-windows-preview.3/windows/README.en.md)
- [Publication record and maintainer procedure](docs/releases/PREVIEW_RELEASE_PROCESS.md)
- [繁體中文](README.md)

## Upstream, license, and acknowledgments

- Upstream: [Venera](https://github.com/venera-app/venera).
- Code license: **GPL-3.0**; see [LICENSE](LICENSE). Copyright and third-party notices are retained.
- The Android package ID remains `com.github.wgh136.venera`.
- Tag-translation data: [EhTagTranslation](https://github.com/EhTagTranslation/Database).
- AI assisted the maintenance work. Contributions are evidenced by actual commits, tests, and verification records.
- New presentation and release documentation uses Taiwan Traditional Chinese with English counterparts. Upstream documents, licenses, and historical evidence retain their original wording.
