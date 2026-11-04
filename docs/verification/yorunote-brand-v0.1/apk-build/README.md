# Yorunote ARM64 Profile APK 建置（固定來源 a789d2a）— 結果：建置失敗，無 APK

**建置來源：** `a789d2a091c94d35f3c9ce9f2c9103c22383b922`（隔離 clone，HEAD 與來源一致，追蹤檔無差異；`pubspec.yaml`／`pubspec.lock` 未變）。本目錄的文件是**後續僅保存驗證文件的 Commit**，不屬於建置來源。

## 結論
`flutter build apk --profile --target-platform android-arm64 --split-per-abi --no-pub` **Exit 1**。原因：Maven Central 對 Gradle 下載回 **HTTP 429 Too Many Requests**（日誌中 11 個不同 POM 檔，例如 `kotlin-build-tools-impl-2.0.21.pom`、`httpmime-4.5.6.pom`、`commons-io-2.16.1.pom`）。Flutter 內建重試 1 次後仍失敗；依指示停止，**未**手動重跑、清快取或改鏡像。**沒有產生 APK**，沒有可交付附件，也沒有 APK 靜態檢查（manifest、圖示、ABI、apksigner、zipalign、SHA-256）可做。這是網路／來源端限制，非程式或圖示問題；錯誤全部為下載階段，未見編譯錯誤。

## 已完成
| 項目 | 結果 | 日誌 |
|---|---|---|
| 隔離副本固定於 a789d2a、工作樹乾淨 | 通過 | — |
| 工具鏈安裝（專案外 `/opt/tc`） | JDK 17.0.21+9 Temurin（SHA-256 對 Adoptium API 通過）、Android cmdline-tools 16111833（SHA-1 與 phase1a workflow 釘選值一致）、platform android-36、build-tools 36.0.0、NDK 28.0.13004108、platform-tools、Rust 1.85.1（rustup 依 `rust-toolchain.toml` 安裝，含 aarch64-linux-android）、Flutter 3.41.4／Dart 3.11.1 | 38、39 |
| 接受的 SDK 授權 | `android-sdk-license`（hash 見 `39_toolchain.txt`），僅限本隔離環境，依你授權 | 39 |
| `flutter pub get --enforce-lockfile` | Exit 0，lockfile 未變 | 40 |
| `flutter test --no-pub test/brand` | Exit 0，4 項通過 | 41 |
| 建置 | **Exit 1（Maven 429）** | 42 |
前輪（a789d2a 之前）日誌：完整測試 277 通過／0 失敗／9 跳過、analyzer 8 info、格式問題同基準，見 `../logs/33_*`、`35_*`；本輪未重跑。

## 簽章
找不到先前測試金鑰。已在儲存庫外建立一次性測試金鑰（`/opt/tc/signing`，30 天效期；只寫入已忽略的 `android/key.properties`），**未使用也未提交**，因為建置未成功。R3.1 舊憑證 SHA-256 `fbb1c751…f921a4` 僅為參考；新金鑰不可能與之相容，若日後以此類一次性金鑰建置，覆蓋安裝相容性**未確認**，且不得要求卸載。

## 如何續做（需你決定）
429 為 Maven Central 的暫時性限流。選項：(a) 稍後在同一隔離副本重跑一次同一指令（本環境工具鏈已就緒）；(b) 授權使用其他方式取得 Gradle 相依（如 Google Maven／鏡像、或以 CI 建置）。我未自行採用任何一項。

## 驗收清單（S25+／Tab S11）— 因無 APK，全部待使用者驗收
桌面名稱 Yorunote；一般圖示遮罩（圓形／圓角方形等）；主題單色圖示；下方髮角裁切（已知預覽顯示下方兩角略出安全圓）；About 頭像與簡／繁／英文文案。

## 備註
第 1 輪為了執行 Flutter 曾對使用者環境加入 `git config --global safe.directory /opt/tc/flutter`（隔離雲端環境，非儲存庫設定）；本輪未再修改全域設定。
