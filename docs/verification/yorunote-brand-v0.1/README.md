# Yorunote 品牌外觀改版 v0.1 — 名稱修改候選／圖示待導入

**狀態：未完成。** 本工作階段沒有收到任何角色 Logo（PNG／SVG）；`/mnt/attach`、`/mnt/user-data/uploads` 皆為空，也找不到相關檔案。依指令不自行繪製替代角色，也不把參考影片當圖示。因此只完成名稱與文案，圖示導入未做。

基準：`59866aa3d70314d5b6b8ccbce8eec559db0d9619`（起始 HEAD 與遠端一致，工作樹乾淨）。
名稱「Yorunote」為使用者選定；商標／名稱可用性**未查核**，不主張任何權利。

## 已修改的品牌觸點（Android 範圍）
| 觸點 | 檔案 | 前 → 後 |
|---|---|---|
| Android 桌面顯示名稱 | `android/app/src/main/AndroidManifest.xml` | `venera` → `Yorunote` |
| Flutter App 標題 | `lib/main.dart` | `venera` → `Yorunote` |
| About 說明與 Fork 聲明 | `lib/pages/settings/about.dart`、`assets/translation.json`（簡／繁新增 2 句） | 原句 → Yorunote 為 Venera 個人 Fork；個人修改僅限外觀與問題修正，其餘來自上游 |
| README 開頭 | `README.md` | 新增 Fork 說明，原內容保留 |

## 刻意不動
Dart 套件名、`package:venera`、MethodChannel／EventChannel（`venera/...`）、`.venera` 副檔名、User-Agent、快取標頭、`com.github.wgh136.venera`（applicationId／namespace）、簽章、資料庫與儲存位置、上游網址（GitHub／Telegram／更新檢查）、LICENSE、`docs/verification/2026-11-04-r3.1/`。

## 圖示與資產：待導入（缺件）
目前圖示仍為上游原圖：`assets/app_icon.png`（About 頁與 pubspec 資產）、`android/app/src/main/res/mipmap-*/ic_launcher*.png`、`mipmap-anydpi-v26/ic_launcher.xml`。
需要使用者提供：
1. 正式角色 Logo 原檔（SVG 優先，或 ≥1024×1024 透明背景 PNG），並確認可用於 GPL 專案發佈的授權／來源。
2. 若需頭像簡化版：由設計方確認，或授權由我依同一份 Logo 裁切（不重繪角色）。
3. 背景色確認（Night Mist Blue 的色碼）。
取得後的製作規格：自適應圖示 108dp 畫布、前景主體置於中央 66dp 安全區；背景層 Night Mist Blue 純色；單色層為單一色剪影（Android 13 主題圖示）；產出 mdpi–xxxhdpi 與 512px 預覽，並附圓形／圓角方形裁切預覽；透明背景與 48/32/24px 小尺寸辨識逐項檢查。

## 其他平台品牌殘留（僅記錄，未驗證、未修改）
`lib/components/window_frame.dart:132` 標題列文字 `Venera`；`ios/Runner/Info.plist`（Venera／venera）；`macos/Runner/Configs/AppInfo.xcconfig`；`windows/runner/Runner.rc`、`main.cpp`；`linux/CMakeLists.txt`、`linux/my_application.cc`；`debian/*`（.desktop 名稱／圖示）；各平台圖示檔。

## 驗證
見 `logs/`。**本環境沒有 Flutter／Dart 工具鏈**，故 `pub get`、`analyze`、`test`、格式檢查與 APK 建置**均未執行**，不宣稱通過。已執行：JSON 語法檢查、身分檔雜湊前後比對。Workflow：`analyze.yml` 只在 PR 與 push master 觸發，其餘為手動／release／issue 事件；本分支 push 不觸發 Actions，Commit 仍加 `[skip ci]`。

## 還原
`git checkout claude/venera-r31-backup-20261104`（未動）；或 `git revert` 本分支 Commit。

## 下一輪需決策
新 applicationId（供新舊並存）、長期簽章方案、資料遷移方式；Logo 授權與正式檔案；是否同步其他平台名稱。
