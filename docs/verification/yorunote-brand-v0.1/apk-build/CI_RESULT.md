# Yorunote ARM64 Profile APK — GitHub Actions 結果（取代 README.md 中「本機 429 失敗」的後續方案 b）

- **App 建置來源：** `a789d2a091c94d35f3c9ce9f2c9103c22383b922`（tree `f95c10f0…`，`pubspec.yaml`／`pubspec.lock` blob 與預期一致；建置後工作樹乾淨）。
- **Workflow Commit：** `e6b9750ae690ff9c9eea771b6dd174c83f9385b3`（分支 `claude/yorunote-arm64-ci-20261104`，僅改 `phase1a-android-baseline.yml`，差異見 `ci-run-41845996537/workflow.diff`）。只保留 `workflow_dispatch`，job 限定該分支，checkout 固定 a789d2a，`contents: read`，不使用 Secrets，新增 `actions/cache@v4.3.0`（釘選 `0057852b…`，由官方 repo tag 查得）。移除原流程的 analyze 與全量測試步驟（本輪只跑 `test/brand`）。
- **Run：** https://github.com/mengwen-liu/venera/actions/runs/41845996537 （workflow_dispatch，只執行 1 次，未 rerun；結論 success，21 個步驟全數成功）。
- **證據 Commit：** 本檔所在的後續 Commit（只含文件）。

## 結果
| 項目 | 結果 |
|---|---|
| `flutter pub get --enforce-lockfile` | Exit 0 |
| `flutter test --no-pub test/brand` | Exit 0（runner 上實際執行） |
| `flutter build apk --profile --target-platform android-arm64 --split-per-abi --no-pub` | Exit 0 |
| 工具 | Flutter 3.41.4／Dart 3.11.1、JDK 17.0.21、Rust 1.85.1、NDK 28.0.13004108、Android 36／Build-tools 36.0.0 |
| APK | `Yorunote_a789d2a_arm64_profile.apk`，27,859,067 位元組，SHA-256 `2b3034bb7374dab24b9d5c2f468215a4fb248b97f9adaa69d26a546818bfa69a`（下載 artifact 後本地重算一致） |
| ZIP／zipalign | 通過（4 位元組對齊）；16 KB 對齊為 yes（僅參考） |
| 合併 manifest | `com.github.wgh136.venera`、versionName 1.6.3、versionCode 2163、label `Yorunote`、icon `res/mipmap-anydpi-v26/ic_launcher.xml` |
| 圖示打包 | 一般／背景／前景／單色 × 5 密度共 20 張，與儲存庫像素逐一相同（0 項 NOT FOUND）；adaptive XML 含 background／foreground／monochrome；`assets/app_icon.png` SHA-256 與儲存庫一致 |
| ABI／原生庫 | 僅 `arm64-v8a`；含 libflutter、libapp、libsqlite3、librhttp、libqjs 等 10 個 `.so` |
| 簽章 | apksigner 通過，1 位簽署者，CN=`Yorunote CI Disposable`，憑證 SHA-256 `4e45e3b9580255d97d686322963dc760f2cb5a7f199ee6413d5d1a6487238201`，與 job 內金鑰相符（本機以 build-tools 36.0.0 另行驗證相同） |
| 建置後 Git 完整性 | `git_integrity_ok=1` |

## 簽章相容性（重要）
此為本 job 臨時產生的一次性測試金鑰，與 R3.1 舊憑證（`fbb1c751…f921a4`）**不同**；若手機上已有以不同憑證簽署的同 applicationId App，**無法直接覆蓋安裝**。你目前裝置上實際憑證未知。本輪不要求卸載或清除資料，也不嘗試繞過。

## Artifact（公開儲存庫，登入 GitHub 者可下載，保留 7 天，2026-11-11 到期）
- `yorunote-arm64-profile-apk`（APK、.sha256、verification.txt）：artifact id 13331413015
- `yorunote-diagnostic-logs`（已脫敏日誌）：artifact id 13332361005
APK 不提交進儲存庫；本目錄僅保存脫敏日誌與證據文字。

## 未做／限制
未實際啟動 App，圖示外觀、About 排版、下方髮角裁切均未驗收；未量測效能。全量測試與 analyzer 本輪未在 CI 重跑（前輪結果見 `../logs/33_*`、`35_*`）。`safe.directory` 全域設定為第 1 輪在雲端沙箱留下的副作用，未還原。

## 待使用者驗收（S25+／Tab S11）
1. 桌面名稱為 Yorunote。
2. 一般圖示在圓形／圓角方形遮罩下的外觀。
3. Android 13+ 主題單色圖示。
4. 下方髮角是否被裁切。
5. About 頭像與簡／繁／英文文案、排版。
6. 安裝方式：若與現有 App 簽章不同，需另行決定（本輪不處理）。
