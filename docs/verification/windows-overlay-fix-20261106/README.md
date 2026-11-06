# Windows 標題列眨眼動畫修正

本輪修正使用者回報的 `No Overlay widget found.`。使用者提供的私人畫面未入庫；本目錄畫面僅使用 CI 的合成測試資料。

The fix addresses the Windows caption's missing Overlay. Evidence images use disposable CI profiles and synthetic fixtures only.

## 原因與修改

`MaterialApp.builder` 的 `WindowFrame` 將標題列放在 Navigator 旁邊，因此新加入的 `Tooltip` 沒有 Overlay 祖先。前版元件測試把 Logo 放在一般頁面內，原生驗收也沒有實際滑鼠懸停，因而漏掉此結構。

在 `WindowFrame` 的 Windows 分支以 Flutter 3.41.4 的 `Overlay.wrap` 包住原有框架；App 程式差異僅新增 5 行。GIF、Logo 大小、視窗按鈕、資料保存位置、依賴與授權均沿用原來源。新增 3 項實際框架測試，並加強原生滑鼠與提示的驗收。

- 原版 App：`6df02c0fda1978319355a51fc2c75f7d66ea6d7f`。
- 修正版 App：`07406c9f6a6d105fd854cb3ddc22cfcc6dacfd9b`。
- 建置流程提交：`ef9996a249b4b815b4688aa99576abd9d7899f3f`。
- 修正分支：`codex/yorunote-windows-overlay-fix-20261106`。

## 驗證

| 實際檢查 | 結果 |
| --- | --- |
| 固定 SDK | Flutter 3.41.4／Dart 3.11.1，Windows Server 2022 x64 |
| 起點重現 | 同組 3 項框架情境在原 App 為 0 通過／3 失敗，均顯示缺少 Overlay |
| `flutter analyze --no-pub`（7 個指定檔） | Exit 0，0 診斷 |
| `dart format --output=none --set-exit-if-changed`（7 個指定檔） | Exit 0，0 檔變更 |
| `flutter test --no-pub --reporter expanded`（5 個指定測試檔） | Exit 0，13 通過／0 失敗／0 跳過 |
| `flutter build windows --release --no-pub` | Exit 0，一般發行入口 |
| `flutter build windows --release --no-pub --target tool/windows/smoke.dart` | Exit 0，另建的驗收入口 |
| `run_smoke.ps1 -Phase distribution` | Exit 0，實際解壓程式啟動、原生滑鼠懸停、截圖、正常關閉 |
| `run_smoke.ps1 -Phase seed` | Exit 0，11 項檢查通過 |
| `run_smoke.ps1 -Phase restart` | Exit 0，4 項檢查通過 |
| `python windows/build.py` 與另一台 Linux runner 的下載核對 | Exit 0，ZIP 55 個項目、54 份檔案清單雜湊及 21 個 AMD64 PE 檔案核對 |

新增框架測試涵蓋真實 `MaterialApp.builder → WindowFrame → Navigator` 結構、GIF 解碼、滑鼠提示、主題／尺寸變更、頁面與對話框及隱藏／恢復標題列。原生驗收以真實 Windows 滑鼠移入與移出確認提示顯示／消失及 GIF 繼續播放；淺色與重啟後深色各一次。另驗證原生 HTTP、QuickJS、線上閱讀、鍵盤翻頁、5 頁下載、離線閱讀和 SQLite 資料保存。兩份原生報告的 `flutter_errors`、`app_errors` 皆為空。

已人工檢視重新下載的實際視窗截圖，標題列 Logo 與提示可見，未顯示原錯誤文字。

| 淺色標題列 | 深色標題列 |
| --- | --- |
| ![淺色原生滑鼠提示](title-hover-light.png) | ![深色原生滑鼠提示](title-hover-dark.png) |

[一般發行入口的實際懸停畫面](distribution-title-hover.png)。詳細數值與原生檢查清單見 [ARTIFACT_VERIFICATION.json](ARTIFACT_VERIFICATION.json)。

第一個探針重現原錯誤，但候選測試的淡出／換頁等待時序不正確；第二個探針修正等待後 13 項測試全過，另抓到新測試缺少大括號的 info。已修正該診斷，最終建置重新執行必要檢查。這兩次探針的整體結論都是 failure，不能記為整條 CI 成功。

- [第一次探針](https://github.com/mengwen-liu/yorunote/actions/runs/42227470490)
- [第二次探針](https://github.com/mengwen-liu/yorunote/actions/runs/42228324373)
- [最終建置](https://github.com/mengwen-liu/yorunote/actions/runs/42229100772)
- [獨立下載核對](https://github.com/mengwen-liu/yorunote/actions/runs/42231651219)

## Windows 測試包

- [下載已驗證的候選產物（內含 ZIP 與 `.sha256`）](https://github.com/mengwen-liu/yorunote/actions/runs/42229100772/artifacts/13510450166)。
- 產物：`Yorunote_windows_x64_07406c9f_preview.zip`，22,015,039 bytes。
- SHA-256：`cf7d5a616af30867349bb9136a491188d7a28a12e0d4778f9a2a1c74e6257ed3`。
- [獨立的文字雜湊檔](Yorunote_windows_x64_07406c9f_preview.zip.sha256)。
- Actions artifact 保留至 `2026-11-20T14:09:35Z`。需要登入 GitHub 下載。
- 先關閉舊版，解開 artifact 外層 ZIP，再將內含的 Windows ZIP 完整解壓到新資料夾執行 `Yorunote/yorunote.exe`。本輪沒有要求卸載或清除資料。
- 保留既有未簽章狀態（Authenticode：`NotSigned`），未建立或使用任何新簽章。

此為 Windows x64 Release 候選包。原生驗收在 GitHub 的 Windows Server 2022 桌面執行，涵蓋實際解壓 ZIP 的一般入口，以及同來源另建的驗收入口；後者可檢查真實 App、原生 HTTP、QuickJS、SQLite、閱讀、下載和重新啟動。兩個入口須分開解讀。尚未由使用者在自己的 Windows 裝置驗收本修正版。

Public preview .2 and its existing assets remain unchanged. This candidate has not been published as a new Release.

## 範圍與回復

只推送上述修正分支，master、既有分支與 Release／Tag 未移動；未寫入 Notion。未執行完整 Flutter 測試或 Android 建置。本輪沒有使用使用者的漫畫來源、收藏或閱讀紀錄。

回復 App 修正可還原本來源相對原版的 `lib/components/window_frame.dart` 5 行新增；或繼續使用原有版本。本輪不刪除既有版本、附件或使用者資料。
