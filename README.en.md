# Yorunote

<p align="center">
  <img src="docs/brand/%E5%A4%9C%E8%AE%80%E6%9C%88%E9%A0%81%E7%B2%BE%E9%9D%88_%E7%9C%A8%E7%9C%BC%E5%BE%AE%E7%AC%91.gif" width="170" alt="Animated Yorunote character: a green-haired, blue-eyed moon-and-book elf blinking and smiling / Yorunote 角色動畫：綠髮藍眼的月亮書頁精靈眨眼微笑">
</p>

<p align="center"><strong>A reading-focused Flutter comic reader<br>以閱讀為中心的 Flutter 漫畫閱讀器</strong></p>

<p align="center"><a href="README.md">繁體中文</a> · <strong>English</strong></p>

Yorunote is a personal open-source fork of [Venera](https://github.com/venera-app/venera). Work in this fork covers branding, interface maintenance, image-cache fixes, cover loading, and traceable engineering evidence.

The reader and comic-source system come from upstream. This repository is a maintenance project, not a claim to have created the entire application from scratch.

## Downloads and releases

- [GitHub Releases](https://github.com/mengwen-liu/yorunote/releases): no Yorunote release has been published yet. An unpublished Release draft (`draft`, `prerelease`) now carries the APK and `.sha256`, re-verified by the [controlled process](docs/releases/PREVIEW_RELEASE_PROCESS.md). Drafts are visible only to maintainers and no tag exists yet, so it is **not a public download**.
- [Development history](CHANGELOG.md) distinguishes candidate changes from published releases.
- [Bilingual notes for the proposed first preview](docs/releases/v0.1.0-preview.1.md): an unpublished working draft.
- The latest test APK is available from [Actions run 41968314599](https://github.com/mengwen-liu/yorunote/actions/runs/41968314599): `Yorunote_29b590b_cover_timeout_arm64_profile.apk`. It is an Android ARM64 **Profile test build**.
- The artifact expires on **2026-11-12 at 12:47 in Taiwan (UTC+8)**. GitHub sign-in is required. This is a temporary CI download, not a permanent release asset.

> **Installation compatibility:** the APK uses a disposable test certificate. It cannot update an installed app with the same package ID and a different signing certificate. Preserve the existing app and its data. A persistent signing and update channel has not been established.
>
> **Validation scope:** host tests and static APK checks have completed. Runtime acceptance of this candidate on the S25+ and Tab S11 is still pending.

## Current development state

`master` has not integrated the branding, home-screen, or cache candidates. The latest candidate is on [`claude/yorunote-cover-timeout-20261105`](https://github.com/mengwen-liu/yorunote/tree/claude/yorunote-cover-timeout-20261105). Cloning `master` alone does not provide that application code.

| Candidate area | Implemented work | Evidence |
| --- | --- | --- |
| Branding | Yorunote display name, Android adaptive/themed icons, About text | [Brand verification](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/yorunote-brand-v0.1/README.md) |
| Reader cache | Invalid-image recovery, protection against concurrent replacement, unique cache paths | [R3.1 evidence](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/2026-11-04-r3.1/README.md) |
| Cover loading | Cache hits bypass the queue; 8 network slots; same-key sharing; cancellation propagation | [Thumbnail R2 report](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/thumbnail-r2-20261105/README.md) |
| Cover timeout | A native 30-second total timeout for each cover-image HTTP attempt | [Timeout report](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/cover-timeout-20261105/README.md) |

The application source is [`29b590b`](https://github.com/mengwen-liu/yorunote/commit/29b590b457378c16b19821f139b9bcad7d38f689). CI records (the existing run 41968314599; not re-run for this documentation update) **350 passing tests with no skips** and the same 8 existing analyzer infos, with no new warnings or errors. This does not establish Android runtime acceptance.

The 30-second timeout excludes queueing, source lookups, and retry delays. Four attempts plus the existing 2/4/8-second delays can take about 134 seconds, excluding queueing.

## Upstream features and fork contributions

| Origin | Scope |
| --- | --- |
| Upstream | Local/network comic reading, JavaScript comic sources, favorites, downloads, and source-dependent comments and tags |
| This fork | Branding and home-screen adjustments, reader-cache recovery, cover queueing/cancellation, native timeout protection, tests, and maintenance evidence |

## Building and testing

Check out the intended candidate source and read its verification report. The validated toolchain is Flutter 3.41.4, Dart 3.11.1, JDK 17, Rust 1.85.1, Android SDK 36, and NDK 28.0.13004108.

The Android build configuration also needs a local `android/key.properties` file and signing key; neither belongs in Git. Host HTTP/JavaScript integration tests need the corresponding native rhttp and QuickJS libraries. See the [latest verification report](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/cover-timeout-20261105/README.md) for conditions and commands.

## Documentation

- [Comic-source development](doc/comic_source.md) — original upstream documentation
- [Headless mode](doc/headless_doc.md) — original upstream documentation
- [Synthetic source and device acceptance](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/thumbnail-r2-20261105/ACCEPTANCE_SYNTHETIC.md)
- [Development history](CHANGELOG.md)
- [繁體中文](README.md)

## Upstream, license, and acknowledgments

- Upstream: [Venera](https://github.com/venera-app/venera).
- Code license: **GPL-3.0**; see [LICENSE](LICENSE). Copyright and third-party notices are retained.
- The Android package ID remains `com.github.wgh136.venera`.
- Tag-translation data: [EhTagTranslation](https://github.com/EhTagTranslation/Database).
- AI assisted the maintenance work. Contributions are evidenced by actual commits, tests, and verification records.
- New presentation and release documentation uses Taiwan Traditional Chinese with English counterparts. Upstream documents, licenses, and historical evidence retain their original wording.
