# Venera R4-A＋R2＋R3＋R3.1 Android 建置交接（2026-11-04）

本交接包對應**最終已測試的候選版**：51de19d66a10c23e76e1948e96c2ff3344224a62，加上 R4-A、R2、R3、R3.1 四份補丁。本次只整理與驗證既有成果，沒有做任何 Android 建置。**目前沒有可用的 APK，實機測試尚待進行。**

## 1. 內容

| 檔案 | 說明 |
|---|---|
| `Venera_R4A_R2_R3_R3_1_source.zip` | 完整候選來源（331 個檔案，最上層資料夾為 `venera-51de19d-R4A-R2-R3-R3.1/`） |
| `ALL_FIXES_FROM_51de19d.patch` | 累積補丁：51de19d → 最終候選（涵蓋 R4-A、R2、R3、R3.1，含新增檔案） |
| `patches/` | 四份原始補丁與各自的 `.sha256` |
| `evidence/` | R3 與 R3.1 的證據包（補丁、報告、重現測試、日誌） |
| `reference/rhttp-0.15.1-rust-Cargo.lock` | 參考用的 Rust lockfile（見 §3） |
| `logs/` | 本次的驗證日誌，以及先前兩次 Android 建置被 HTTP 429 擋下的日誌 |
| `SHA256SUMS.txt` | 本交接包內所有檔案的 SHA-256 |

## 2. 來源 ZIP（`Venera_R4A_R2_R3_R3_1_source.zip`）
- **SHA-256：** 見 `SHA256SUMS.txt`。
- **納入範圍：** 最終候選 `git ls-files -co --exclude-standard` 列出的 331 個檔案：
  - 51de19d 追蹤的 324 個檔案（含 `LICENSE`、`pubspec.yaml`、`pubspec.lock`、`rust-toolchain.toml`、`assets/`、各平台目錄與 `.github/`）。
  - 四輪新增的 7 個測試檔。
- **排除：** `.git/`、`.dart_tool/`、`build/` 與其他 `.gitignore` 排除的內容，以及 pub／Gradle／Cargo 快取。檔案清單中沒有 `key.properties`、`local.properties`、`*.jks`、`*.keystore`、`*.p12`、`.env`、`google-services*`。
- **驗證**（`logs/01_source_zip_verify.log`）：在空目錄解壓後，331 個檔案與最終候選逐位元組相同、權限模式相同，沒有多出或缺少的檔案。

## 3. 鎖定檔
- **`pubspec.lock`：** 已納入（與 51de19d 相同，四輪都沒有修改；建置時請使用 `--enforce-lockfile`）。
- **Rust：** 專案本身**沒有** `Cargo.lock`，只有 `rust-toolchain.toml`（Rust 1.85.1，含 Android targets）。Rust 原生碼來自 pub 套件 `rhttp 0.15.1`（`pubspec.lock` 已鎖定，sha256 `b111638045b730f825a85cb045017b5bd3dfb47b38e98eb293b0519ee6050f2e`），其 `Cargo.lock` 位於該套件內。為方便核對，另附一份 `reference/rhttp-0.15.1-rust-Cargo.lock`（SHA-256 `232c3f91d09446ff821cb15f2d86b15934da29e6395e856eb3afd8571eff5eb4`）。它是參考檔，不屬於專案來源。

## 4. 補丁
### 4.1 原始四份補丁（依序套用）
| 順序 | 檔案 | SHA-256 |
|---|---|---|
| 1 | `R4A_FROM_51de19d.patch` | `a6a742e68099b728ff4e52c18feb3e8ebc5168ca023010c5f28ca0241f464a7a` |
| 2 | `CACHE_HIT_RECOVERY_ON_R4A.patch`（R2） | `3e528269cff86e982ce7c5255940f51219cacc68dc3abd0434cd20ddcba67457` |
| 3 | `CACHE_RACE_FIX_ON_R2.patch`（R3） | `2a5f70573b8f9ff4d99de571ca5ab4005eca4d733ed55b05a18ac04952f04cf8` |
| 4 | `CACHE_PATH_REUSE_FIX_ON_R3.patch`（R3.1） | `3643fd62c7b635c1801e597e8b1e3727862ded9e7945add245ea5a6d4dc601a7` |

### 4.2 累積補丁 `ALL_FIXES_FROM_51de19d.patch`
SHA-256 見 `SHA256SUMS.txt`。共 16 個檔案（9 個修改、7 個新增），沒有刪除，也沒有權限模式變更：

| 狀態 | 檔案 | 51de19d blob → 最終 blob |
|---|---|---|
| M | lib/components/home_widgets.dart | a5679533… → 1ca411ae… |
| M | lib/foundation/cache_manager.dart | 301637c2… → 372769d2… |
| M | lib/foundation/image_provider/base_image_provider.dart | 47651a78… → 3861574b… |
| M | lib/foundation/image_provider/reader_image.dart | ac2a5a6d… → 59d804cc… |
| M | lib/network/images.dart | 8f311d77… → 3038c080… |
| M | lib/pages/follow_updates_page.dart | 64e1a59a… → 611a6fac… |
| M | lib/pages/home_page.dart | ecd06d30… → 81323da8… |
| M | lib/pages/reader/images.dart | 45d1b0d0… → 00d28bbe… |
| M | test/ui/home_widgets_test.dart | 13d74332… → 8c4bdcb8… |
| A | test/network/reader_image_cache_test.dart（R2） | → 27e9fcf7… |
| A | test/network/reader_image_cache_race_test.dart（R3） | → 4821b5af… |
| A | test/network/reader_image_cache_path_reuse_test.dart（R3.1） | → d1128e72… |
| A | test/ui/home_page_test.dart（R4-A） | → 95d897f7… |
| A | test/ui/home_visual_r2_test.dart（R4-A） | → 5ca6d447… |
| A | test/ui/home_visual_r3_test.dart（R4-A） | → 629f473a… |
| A | test/ui/home_visual_r4_test.dart（R4-A） | → f9d674ef… |

完整 40 碼 blob 見 `logs/03_cumulative_patch_verify.log`。R4-A 八個檔案的最終 blob 與 10/21 紀錄的 OID 一致。

### 4.3 驗證結果
- **累積補丁**（`logs/03_cumulative_patch_verify.log`，全新隔離副本，無 Git 遠端）：
  - 16 個檔案的基準 blob 都與 51de19d 相符；7 個新增檔在基準中都不存在。
  - `git apply --check` 成功，套用後 331 個檔案與最終候選逐位元組一致，檔案集合相同。
  - 反向套用後工作樹乾淨，`git diff HEAD` 為空，也就是回到 51de19d。
- **補丁鏈一致性**（`logs/04_patch_chain_consistency.log`）：四份原始補丁依序套用後，與最終候選逐位元組一致。**沒有發現不一致。**

### 4.4 套用方式（擇一）
```bash
git checkout --detach 51de19d66a10c23e76e1948e96c2ff3344224a62
git apply --check ALL_FIXES_FROM_51de19d.patch
git apply ALL_FIXES_FROM_51de19d.patch
```
還原：`git apply -R ALL_FIXES_FROM_51de19d.patch`。也可以依 §4.1 的順序逐一套用四份原始補丁，或直接解壓來源 ZIP。

## 5. 實際使用的工具版本（本雲端工作階段）
| 工具 | 版本 |
|---|---|
| Flutter | 3.41.4 stable，framework rev ff37bef603，engine 99578ad0355d（`pubspec.yaml` 的 `environment.flutter` 也鎖定 3.41.4）；SDK archive SHA-256 `c9c4e741ebcf83ee88303404176f7e22c3b6abfc8e9d60781098b6d4104327a9`（與官方 releases_linux.json 相符） |
| Dart | 3.11.1 stable |
| JDK | Temurin 17.0.21+9（Adoptium，SHA-256 已核對） |
| Rust | 1.85.1（`rust-toolchain.toml`），已安裝 aarch64／armv7／x86_64-linux-android targets |
| Android SDK | cmdline-tools 23.0（package 16111833）、platforms;android-36（rev 2）、build-tools 36.0.0 |
| Android NDK | 28.0.13004108（`android/app/build.gradle` 的 `ndkVersion`） |
| Gradle | wrapper 8.13（`gradle-8.13-all.zip`） |
| AGP／Kotlin 外掛 | `com.android.application` 8.12.3；`org.jetbrains.kotlin.android` 2.1.0（Flutter Gradle 外掛另會解析 Kotlin 2.0.21 相關構件） |

## 6. 既有測試證據
| 版本 | 完整 `flutter test --no-pub` | 說明 |
|---|---|---|
| R4-A | +263，exit 0 | 基準 |
| R2 | +274，exit 0 | 新增 11 項 |
| R3 | +278，exit 0 | 新增 4 項競態測試 |
| **R3.1（最終）** | **+282，exit 0**（有主機版 librhttp）；**+273，跳過 9，exit 0**（沒有 librhttp） | 新增 4 項路徑重用測試 |

- **librhttp 的作用：** 「有主機版 librhttp」是指設定 `FRB_DART_LOAD_EXTERNAL_LIBRARY_NATIVE_LIB_DIR`，指向依 rhttp 0.15.1 `Cargo.lock` 建置的 Linux 版 `librhttp.so`（`RUSTFLAGS='--cfg reqwest_unstable' cargo build --release --locked`）。沒有設定時，需要真實 HTTP 的 9 項測試會跳過。
- **analyzer：** `flutter analyze --no-pub` 為 exit 1，原因是 8 項 info，都是既有的 deprecated 用法（`TickerMode.of`、`Share`／`shareXFiles`）；0 warning、0 error，四輪都逐行相同。
- **重現與修正證據：**
  - R3 競態測試：在 R2 失敗 4/4、在 R3 通過 4/4。
  - R3.1 路徑重用測試：在 R3 失敗 4/4、在 R3.1 通過 4/4。
  - 兩者連跑 5 次結果都相同。
  - R2 的 14 個 HTTP 情境在 R3、R3.1 上都與 R2 相同。
  - 詳見 `evidence/` 內的報告。

## 7. 已知格式問題（`logs/05_format_status.log`）
`dart format --output=none --set-exit-if-changed` 的結果（1 = 會被改動）：

| 檔案 | 最終候選 | 51de19d |
|---|---|---|
| lib/foundation/cache_manager.dart | 1 | 1 |
| lib/foundation/image_provider/base_image_provider.dart | 1 | 1 |
| lib/foundation/image_provider/reader_image.dart | 1 | 1 |
| lib/network/images.dart | 1 | 1 |
| lib/pages/follow_updates_page.dart | 1 | 1 |
| lib/pages/reader/images.dart | 1 | 1 |
| 其餘 10 個檔案（含 7 個新增測試） | 0 | — |

- **都是既有狀態：** 這 6 個檔案在 51de19d 就未通過格式檢查。R2、R3.1 新增的行都已符合格式。
- **唯一例外：** R3 改動的既有 SQL 語句參數列 `''', [key, dir, name]);`（`cache_manager.dart`）。格式器會把這個檔案所有 `_db.execute('''…''', [...])` 改成多行，因此維持檔案原本的寫法。
- **`follow_updates_page.dart`：** 這是 R4-A 原樣還原的檔案，blob 已固定，所以沒有重排。
- **注意：** 「51de19d」一欄是把基準版檔案複製到套件外暫存檔後檢查的結果。

## 8. PathNotFoundException（預期中的錯誤日誌）
- **出現位置：** R3.1 測試 `reader_image_cache_path_reuse_test.dart` 中「before the broken file is removed」的兩項（直接寫入、新請求）。
- **原因：** 舊的失效操作停在刪除壞檔之前；這段期間同鍵寫入流程已先刪掉壞檔並寫入新檔（新檔名）。舊操作放行後刪除已不存在的舊檔，`CacheManager.delete` 拋出 `PathNotFoundException`，由 `ReaderImageProvider.onInvalidImageData` 的 try/catch 攔下並以 `Log.error` 記錄。
- **影響：** 好圖的索引與檔案不受影響，測試通過。為維持最小修改，沒有另外吞掉這個錯誤。在測試日誌中出現這段堆疊屬預期行為。

## 9. 建置阻塞：Maven Central HTTP 429
本工作階段兩次 Android 建置都在 Gradle 解析外掛相依時被 `repo.maven.apache.org` 以 HTTP 429 Too Many Requests 拒絕，沒有進入編譯，也沒有產生 APK：

| 時間 | 命令 | 第一個失敗的相依 | 日誌 |
|---|---|---|---|
| 11/03（R4-A） | `flutter build apk --debug --target-platform android-arm64 --split-per-abi --no-pub` | `org.jetbrains.kotlin:kotlin-build-statistics:2.0.21`（.pom） | `logs/10_r4a_debug_apk_build_429.log` |
| 11/03（R4-A 單次探測） | `curl` 同一 URL | HTTP 429，沒有 `Retry-After` | `logs/11_r4a_maven_probe_429.txt` |
| 11/03（R3） | `flutter build apk --profile --target-platform android-arm64 --split-per-abi --no-pub` | `org.jetbrains.kotlin:kotlin-build-tools-impl:2.0.21`（.pom） | `logs/12_r3_profile_apk_build_429.log` |

這是建置環境對 Maven Central 的限流問題，與程式碼無關。另一個環境若能正常存取 Maven Central，應可越過這一步（**未驗證**）。

## 10. Android ARM64 Profile APK 建置
### 10.1 必要環境
- §5 的 Flutter 3.41.4／Dart 3.11.1、JDK 17、Rust 1.85.1（含 `aarch64-linux-android`）、Android SDK platform 36、build-tools 36.0.0、NDK 28.0.13004108。
- 設定 `ANDROID_HOME`（或 `ANDROID_SDK_ROOT`）與 `JAVA_HOME`；`flutter doctor` 應能找到 Android 工具鏈。
- 網路：
  - 必要：pub.dev、`pubspec.yaml` 中的 GitHub git 相依、Maven Central、Google Maven、Gradle Plugin Portal、services.gradle.org，以及 crates.io（rhttp 原生碼經 cargokit 以 cargo 編譯）。
  - 選用：GitHub release（cargokit 可能先嘗試下載預編譯檔，**未驗證**）。
- **簽章金鑰（必要）：**
  - `android/app/build.gradle` 會無條件讀取 `android/key.properties`。Profile 建置使用 debug 的 `signingConfig`（Flutter Gradle 外掛的 profile 類型以 debug 為基礎，**此專案未實測**），所以需要自備一次性金鑰。
  - 這個檔案已被 `android/.gitignore` 排除，**請勿提交或打包**。
  - 參考 `.github/workflows/phase1a-android-baseline.yml` 的「Create disposable signing key」步驟：
```bash
umask 077; D="$(mktemp -d)"; KS_PW="$(openssl rand -hex 24)"; export KS_PW
keytool -genkeypair -keystore "$D/disposable.jks" -alias venera_disposable \
  -keyalg RSA -keysize 2048 -validity 7 -storepass:env KS_PW -keypass:env KS_PW \
  -dname "CN=Venera Test Only, O=Test Only"
printf 'storePassword=%s\nkeyPassword=%s\nkeyAlias=venera_disposable\nstoreFile=%s\n' \
  "$KS_PW" "$KS_PW" "$D/disposable.jks" > android/key.properties
keytool -list -v -keystore "$D/disposable.jks" -alias venera_disposable -storepass:env KS_PW | grep SHA256
unset KS_PW
```
  記下 `SHA256` 憑證指紋，供 §10.3 比對。

### 10.2 命令
```bash
unzip Venera_R4A_R2_R3_R3_1_source.zip
cd venera-51de19d-R4A-R2-R3-R3.1
flutter --version
flutter pub get --enforce-lockfile
flutter test --no-pub
flutter build apk --profile --target-platform android-arm64 --split-per-abi --no-pub
```
- **`flutter --version`：** 應為 3.41.4／Dart 3.11.1。
- **`flutter test --no-pub`：** 選用。沒有主機版 librhttp 時，預期 +273，跳過 9。
- **預期輸出：** `build/app/outputs/flutter-apk/app-arm64-v8a-profile.apk`。檔名依 Flutter 慣例推定，**未驗證**。
- **遇到 429：** 請保留完整日誌，記錄第一個失敗的相依 URL 與 HTTP 狀態。

### 10.3 建置成功後的 APK 檢查
```bash
APK=build/app/outputs/flutter-apk/app-arm64-v8a-profile.apk
BT=$ANDROID_HOME/build-tools/36.0.0
sha256sum "$APK"
"$BT/aapt2" dump badging "$APK" | grep -E "^package:|application-debuggable|native-code"
"$BT/apksigner" verify --verbose --print-certs "$APK"
unzip -l "$APK" | grep -E ' lib/' | awk '{print $4}' | sort
```
- [ ] `sha256sum`：記錄 APK 的 SHA-256。
- [ ] `aapt2`：`package: name='com.github.wgh136.venera'`；`versionName='1.6.3'`（`pubspec.yaml` 為 `1.6.3+163`）；記錄實際 `versionCode`（split-per-abi 會套用 ABI 覆寫，**實際值未驗證**）。
- [ ] `aapt2`：`native-code` 只有 `arm64-v8a`。
- [ ] `aapt2`：記錄 `application-debuggable` 是否出現。
- [ ] `apksigner`：簽章驗證通過，簽署者憑證 SHA-256 等於 §10.1 的一次性金鑰指紋。
- [ ] `unzip -l`：`lib/` 下只有 `lib/arm64-v8a/`，且至少包含 `librhttp.so`、`libflutter.so`、`libapp.so`。
- [ ] 建置後刪除 `android/key.properties` 與一次性 keystore，不得隨產物散布。
- [ ] 實機驗收（尚待進行）：正常命中不發請求；壞圖或空快取重試一次可恢復；捲動與記憶體依先前的實機流程另行量測。
