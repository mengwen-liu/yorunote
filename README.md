# Yorunote

Yorunote 是基於 [Venera](https://github.com/venera-app/venera) 的開源 Flutter 漫畫閱讀器個人 Fork，用於閱讀本機與網路來源的漫畫。

本儲存庫並非從零開發的原創 App。功能主要承襲上游，本 Fork 的調整限於外觀、維護與問題修正。

## 上游與授權

- 上游專案：<https://github.com/venera-app/venera>
- 授權：沿用上游的 GPL-3.0，全文見 [LICENSE](LICENSE)。
- 著作權聲明與第三方授權檔均保持原樣。
- Android 套件名稱（`com.github.wgh136.venera`）等上游識別資訊目前尚未更動。

| 類別 | 內容 |
| --- | --- |
| 承襲上游 | 下方功能摘要、漫畫來源機制與 Headless 模式 |
| 本 Fork | 外觀（名稱、圖示、首頁與 About 文案）調整、維護、閱讀器圖片快取問題修正 |

## 目前狀態

`master` 目前尚未整合品牌與快取修正，內容仍是上游程式加上 CI 設定。相關成果在各自分支，**尚未合併至 master**：

| 分支 | 內容 |
| --- | --- |
| [`claude/venera-r31-backup-20261104`](https://github.com/mengwen-liu/yorunote/tree/claude/venera-r31-backup-20261104) | 首頁、閱讀器圖片快取修正的候選來源與驗證保存 |
| [`claude/yorunote-brand-v01-20261104`](https://github.com/mengwen-liu/yorunote/tree/claude/yorunote-brand-v01-20261104) | 在上述候選上加入 Yorunote 名稱、About 文案與圖示 |
| [`claude/yorunote-arm64-ci-20261104`](https://github.com/mengwen-liu/yorunote/tree/claude/yorunote-arm64-ci-20261104) | 上列品牌分支加上 ARM64 測試建置的 CI 設定與證據 |
| [`claude/yorunote-thumbnail-perf-20261105`](https://github.com/mengwen-liu/yorunote/tree/claude/yorunote-thumbnail-perf-20261105) | 以上一列為起點（`7b6348a`）的首頁／書架封面載入可靠性與效能候選（本 README 所在分支） |

驗證紀錄（位於 `claude/yorunote-arm64-ci-20261104`）：

- [R3.1 驗證保存](https://github.com/mengwen-liu/yorunote/blob/claude/yorunote-arm64-ci-20261104/docs/verification/2026-11-04-r3.1/README.md)
- [品牌 v0.1 驗證索引](https://github.com/mengwen-liu/yorunote/blob/claude/yorunote-arm64-ci-20261104/docs/verification/yorunote-brand-v0.1/README.md)
- [ARM64 CI 結果](https://github.com/mengwen-liu/yorunote/blob/claude/yorunote-arm64-ci-20261104/docs/verification/yorunote-brand-v0.1/apk-build/CI_RESULT.md)
- 封面載入候選（位於本分支）：[docs/verification/thumbnail-perf-20261105/README.md](docs/verification/thumbnail-perf-20261105/README.md)

> 本 README 由 `master`（`42bdf2d`）的 README 複製而來，只在本分支補上封面候選與建置前置條件；本分支與其候選**都尚未合併至 master**。

## 建置與測試用 APK

- 目前沒有正式發行版，也沒有 Yorunote 的發行管道。上游的 Release、AUR、F-Droid 等版本不是 Yorunote。
- 複製 `master` 不會得到品牌候選版；需切換到上列分支。
- 測試用 APK 來自 [Actions run 41845996537](https://github.com/mengwen-liu/yorunote/actions/runs/41845996537)（手動觸發，建置來源 `a789d2a`），其限制如下：
  - artifact 登入 GitHub 後才能下載，保留至 2026-11-11 到期，過期後須重新建置。
  - 僅 `arm64-v8a`，使用一次性測試金鑰簽章；若裝置上已有不同簽章的同套件名稱 App，無法直接覆蓋安裝。
  - 僅完成靜態檢查，尚未做 Android 實機驗收。
- 封面載入候選的測試用 APK 來自 [Actions run 41883419245](https://github.com/mengwen-liu/yorunote/actions/runs/41883419245)（手動觸發，建置來源 `418efac`，SHA-256 `f300eecd9e7b3151f05e28b6e1fa0a2807e417660c18415fcd9dd74492e7b766`，2026-11-11 到期）。限制同上：登入 GitHub 才能下載、僅 `arm64-v8a`、一次性測試簽章（與前一項 APK 的憑證也不同）、僅靜態檢查。詳見[本分支驗證報告](docs/verification/thumbnail-perf-20261105/README.md)。
- 自行建置：見下一節「建置前置條件」，切換到想建置的分支後再執行建置指令。

## 建置前置條件

下列版本是本分支 CI 實際使用並驗證過的組合（[`.github/workflows/phase1a-android-baseline.yml`](.github/workflows/phase1a-android-baseline.yml)）。版本不同時未經驗證。

| 項目 | 版本／設定 | 來源或備註 |
| --- | --- | --- |
| Flutter | 3.41.4（framework `ff37bef603`） | `pubspec.yaml` 的 `environment.flutter` |
| Dart | 3.11.1 | 隨 Flutter 3.41.4 |
| JDK | 17 | `android/app/build.gradle` 的 Java 17 設定 |
| Rust | 1.85.1，含 `aarch64-linux-android` 等 target | `rust-toolchain.toml`；`rhttp` 等原生套件經 cargokit 以 cargo 編譯 |
| Android SDK | platform `android-36`、build-tools `36.0.0` | CI 以 cmdline-tools 安裝，並在拋棄式 runner 中接受 SDK 授權 |
| Android NDK | `28.0.13004108` | `android/app/build.gradle` 的 `ndkVersion` |
| Gradle | wrapper 8.13（自動下載） | `android/gradle/wrapper/gradle-wrapper.properties` |

相依套件一律以 `flutter pub get --enforce-lockfile` 安裝，不更新 `pubspec.lock`。

### 簽章：`android/key.properties`

`android/app/build.gradle` 會無條件讀取 `android/key.properties`，**缺少此檔時 Android 建置會失敗**；debug 與 release 的簽章設定都讀取其中的金鑰（CI 建出的 Profile APK 經 apksigner 確認同樣以此金鑰簽署）。格式：

```properties
storePassword=<keystore 密碼>
keyPassword=<key 密碼>
keyAlias=<別名>
storeFile=<keystore 的絕對路徑>
```

- `key.properties` 已列於 `android/.gitignore`；keystore 與密碼不得提交、上傳或寫進日誌。
- CI 每次執行都在 runner 內以 `keytool` 產生**一次性測試金鑰**（CN=`Yorunote CI Disposable`，效期 7 天），僅供測試。用它簽署的 APK 無法覆蓋安裝以其他憑證簽署的同套件名稱 App（目前套件名稱仍為 `com.github.wgh136.venera`）。
- 本儲存庫尚未設定正式、長期的簽章金鑰。

### 建置與測試指令

```bash
flutter pub get --enforce-lockfile
```

```bash
flutter build apk --profile --target-platform android-arm64 --split-per-abi --no-pub
```

```bash
flutter test --no-pub
```

- 部分網路與快取測試需要主機版 `librhttp.so`：依 pub 快取中 `rhttp-0.15.1/rust/Cargo.lock`（SHA-256 `232c3f91…5eb4`）執行 `RUSTFLAGS='--cfg reqwest_unstable' cargo +1.85.1 build --release --locked`，再把輸出目錄設給 `FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR`。未設定時，這些測試會標示為跳過，不代表通過。
- 歷史紀錄與本輪結果的差別：
  - [R3.1 建置交接](https://github.com/mengwen-liu/yorunote/blob/claude/yorunote-arm64-ci-20261104/docs/verification/2026-11-04-r3.1/reports/BUILD_HANDOFF.md)與[品牌 ARM64 CI 結果](https://github.com/mengwen-liu/yorunote/blob/claude/yorunote-arm64-ci-20261104/docs/verification/yorunote-brand-v0.1/apk-build/CI_RESULT.md)是**歷史紀錄**，描述的是當時的來源（`a789d2a` 等），其中的本機 Maven 429 失敗與 APK 雜湊不適用於本分支。
  - 本分支的建置來源、測試數與 APK 雜湊，以[本分支驗證報告](docs/verification/thumbnail-perf-20261105/README.md)為準。

## 功能（承襲上游）

- 閱讀本機漫畫
- 使用 JavaScript 建立漫畫來源
- 閱讀網路來源的漫畫
- 管理收藏
- 下載漫畫
- 若來源支援，可檢視留言、標籤等資訊，並登入後留言、評分等

## 文件

- [建立漫畫來源](doc/comic_source.md)
- [Headless 模式](doc/headless_doc.md)

## 致謝

- 上游 [Venera](https://github.com/venera-app/venera) 及其貢獻者。
- 標籤中文翻譯來自 [EhTagTranslation](https://github.com/EhTagTranslation/Database)。
