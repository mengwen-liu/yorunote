# Venera R3.1 來源獨立驗證與 APK 建置紀錄

驗證日期：2026-11-04T13:00:11+08:00（Asia/Taipei）。本輪以實際交接檔、GitHub 基準、程式差異與重新執行的測試為依據。

## 結果

ARM64 Profile APK 已建置成功並完成檔案技術檢查。候選版本完整測試為 **282 項通過、0 失敗、0 跳過**。App 原始碼、pubspec.lock 與 rhttp Cargo.lock 沒有額外變更。

這份 APK 尚未在 Galaxy S25+、Tab S11 或其他 Android 實機安裝、啟動及量測；無法據此宣稱實機幀率、捲動或翻頁流暢度已改善。這是候選測試包，後續需進行實機驗收。

## APK

| 項目 | 實際結果 |
|---|---|
| 檔名 | `Venera_R3_1_arm64_profile.apk` |
| 大小 | 26924355 bytes（26.9 MB） |
| SHA-256 | `4193a7bf69339e7b2e62d8473f12aac40bb8459609d479029ec58d3fe1aa7799` |
| 套件名稱 | `com.github.wgh136.venera` |
| 顯示版本／版本碼 | `1.6.3`／`2163` |
| Android 最低／目標 API | 24／36 |
| 原生架構 | 僅 `arm64-v8a` |
| 簽章 | APK v2 驗證成功；本輪一次性 RSA 2048 測試簽章 |
| 簽章憑證 SHA-256 | `fbb1c751962c1b6942c2117749d4f486c4e1013a03fb7605c2a39675b1f921a4` |
| 必要函式庫 | libapp、libflutter、rhttp、QuickJS、PNG、7zip 均存在 |
| ELF／ZIP 對齊 | 10 個原生函式庫均為 AArch64；ELF 載入區段至少 16 KB；zipalign 檢查 Exit 0 |

版本碼 2163 來自 Flutter 3.41.4 的 ARM64 分包規則：`2 × 1000 + 163`。已回讀所安裝 SDK 的 `FlutterPlugin.kt` 與 `FlutterPluginConstants.kt` 確認，並非修改 pubspec 的建置編號。

**安裝前請保留原 App 與資料。** 本包沿用原套件名稱，但使用本輪測試簽章，不能直接覆蓋不同簽章的既有版本；若安裝顯示簽章衝突，請停止，不要為了測試直接解除安裝原 App。若要並存安裝，需要另外決定測試版套件名稱。本輪沒有修改 Android 身分。

## 本輪實際執行的檢查

| 命令或檢查 | Exit | 結果／證據 |
|---|---:|---|
| 交接 ZIP 雜湊與 SHA256SUMS | 0 | 24 個檔案全數相符；`56_received_integrity.json` |
| 累積補丁正向、反向套用 | 0 | 正向 331 檔一致；反向工作樹乾淨、回到基準 324 檔 |
| 四份補丁依序套用 | 0 | 結果與來源 ZIP 的 331 檔位元組及執行模式一致 |
| `flutter pub get --enforce-lockfile` | 0 | App 鎖定檔未變；`31_pub_get.log` |
| `cargo build --release --locked`（主機版 rhttp） | 0 | 依套件原有 Cargo.lock 與 `--cfg reqwest_unstable` 建置；`34_host_rhttp_build.log` |
| `flutter test --no-pub --concurrency 2 --reporter expanded` | 0 | 282 通過、0 跳過；`45_full_test_native_final.log` |
| `flutter analyze --no-pub` | 1 | 0 error、0 warning、8 項既有 deprecated info；`41_analyze.log` |
| `dart format --output=none --set-exit-if-changed`（16 檔） | 1 | 6 檔未通過；相同 6 檔在 51de19d 也未通過；本輪未更動格式 |
| `flutter build apk --profile --target-platform android-arm64 --split-per-abi --no-pub` | 0 | 最終建置 122.674 秒；`77_profile_apk_build_linker_executable.log` |
| aapt2、apksigner、zipalign、ZIP CRC、ELF 檢查 | 0 | `70_apk_badging.log`、`71_apk_signature.log`、`72_apk_zipalign.log`、`73_apk_inspection.json` |
| 建置後來源比對 | 0 | 331 檔與交接來源一致；`78_source_after_build.json` |

第一次完整測試因主機缺少未帶版本的 `libsqlite3.so` 載入名稱而失敗。之後以隔離目錄的連結使用既有 SQLite 3.45.1，重跑得到 282 項通過。失敗原始日誌 `40_full_test_native.log` 有保留，沒有修改測試來避開失敗。

最終測試日誌有 3 筆被失效處理攔下的 `PathNotFoundException`：其中 2 筆來自 R3.1 的舊檔刪除交錯情境，另 1 筆來自 resize 開關並行恢復。相關測試仍成功，沒有把這些日誌宣稱為已消除。

本輪未重新執行舊版本的失敗對照或突變測試，也未執行實機功能回歸、APK 安裝、來源登入、下載、同步及 FPS／記憶體量測。單元測試不取代上述驗收。

## 建置環境與處理範圍

- Linux x64；Flutter 3.41.4／Dart 3.11.1；Gradle 8.13；最終 JDK 為 Eclipse Temurin 17.0.21+9，已實測 java、javac、jar。
- Rust 1.85.1；主 App 明定 NDK 28.0.13004108，Gradle 另外安裝 NDK 27.0.12077973。SDK 平台 33、34、35、36，Build-Tools 35.0.0 與 36.0.0，CMake 3.22.1。
- 修正單次命令的代理設定，避免環境既有 GRADLE_OPTS 指向無法連線的代理；未改儲存庫內的代理或 Maven 來源設定。
- 內建 Java 17.0.20 僅具執行環境，補裝完整 JDK 17.0.21 並核對官方 SHA-256。新 JDK 使用此執行環境既有受信任 CA 的隔離副本；TLS 驗證保持啟用。
- 一筆 Gradle 轉換快取與安裝層級不正確的 Android 33 平台目錄移入隔離區，再由官方工具重建；沒有清除整份快取。
- rhttp 的 `cargokit/run_build_tool.sh` 在連結時缺少執行權限，僅對隔離套件快取補上擁有者執行位元；檔案內容前後 SHA-256 相同。`76_cargokit_script_mode.json` 記錄差異。
- rhttp 的建置工具首次解析自身 25 個 Dart 工具依賴；其日誌中的 Changed dependencies 不表示 App 的 pubspec.lock 或 Rust Cargo.lock 被更新。
- SDK 安裝過程沿用工具接受的 Android SDK 授權。一次性簽章私鑰、密碼、key.properties 與各類依賴快取均未放入交付包。

## 來源與保存狀態

- GitHub Fork：https://github.com/mengwen-liu/venera
- 上游：https://github.com/venera-app/venera 。保留既有 GPL-3.0 授權與著作權；這是開源專案接手維護候選，不是從零原創 App。
- 固定基準：`51de19d66a10c23e76e1948e96c2ff3344224a62`。
- 原交接 ZIP：`Venera_R4A_Cache_R3_1_Build_Handoff.zip`，SHA-256 `ab84e99a10fccb5176c622ed89f00a08e7585ada29b9226df1148a4cca9f7ba4`。
- 來源 ZIP：`Venera_R4A_R2_R3_R3_1_source.zip`，SHA-256 `eca3911b68b1e134a4528ff1ef7d07a1569067d7f8a92ef22f78a365e3283702`。
- 累積補丁：`ALL_FIXES_FROM_51de19d.patch`，SHA-256 `d2b455edddb5dba33c04fad0aa9b95e258d048980dcf06cf19ee0edb67feed95`。
- App pubspec.lock：`f3869427e394ef2a45e572af9066aed8cc31553de9f1a2c35b0cc1384cb0bbb7`。
- rhttp Cargo.lock：`232c3f91d09446ff821cb15f2d86b15934da29e6395e856eb3afd8571eff5eb4`，建置後仍與交接參考檔相同。

本輪沒有 Commit、Push、PR、Merge、GitHub Actions、Release、Notion 或 Google Drive 寫入，也沒有開始其他 UX 階段。編譯後的 App 來源仍與交接包逐檔相同。

官方工具來源（本輪已開啟或實際下載驗證）：

- Flutter SDK Archive：https://docs.flutter.dev/install/archive
- Android CLI：https://developer.android.com/tools/agents/android-cli
- Eclipse Temurin JDK：https://github.com/adoptium/temurin17-binaries/releases/tag/jdk-17.0.21%2B9

下一步是在保留既有資料與簽章邊界下，完成 S25+／Tab S11 的安裝與閱讀、快取重讀、錯圖重試測試，再量測實機效能。目前沒有實機數據足以支持更換 Flutter 或重寫底層。
