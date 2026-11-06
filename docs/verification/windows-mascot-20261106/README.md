# Yorunote Windows 標題列角色 Logo 候選版

本輪依使用者的 Windows 畫面回饋，將標題列左上方小字換成既有角色動畫。這是候選版，既有公開 Windows 預覽版及 master 沒有因此更新。

## 修改範圍

- 固定 App 來源：`6df02c0fda1978319355a51fc2c75f7d66ea6d7f`，基底為已發布 Windows 版的 `71485c7de8799e30c9e1b5797ad83fba65668d51`。
- 新增 WindowsTitleBrand：28×28 圖示，置中於 72×36 品牌區；滑鼠提示及無障礙名稱為 Yorunote。
- 活動視窗使用既有 GIF；失焦或 MediaQuery 要求減少動畫時顯示既有靜態 app_icon.png。
- 以 RepaintBoundary 隔離圖示重繪，依裝置像素比設定解碼尺寸；沒有量測 CPU 或耗電改善。
- Windows 的原生程式名稱、資料目錄、拖曳處理及系統按鈕沿用既有實作。
- pubspec.yaml 僅增加一筆素材宣告，依賴宣告與 pubspec.lock 不變。沒有變更 Android 或其他平台的標題呈現。
- 繁中／英文 Windows 說明同步補上動畫行為，未加入新的來源登入設定。

## 原始素材

沿用已在儲存庫的 docs/brand/夜讀月頁精靈_眨眼微笑.gif，透過相同 Git blob 複製到 assets/brand/yorunote_mascot.gif，沒有重新編碼。494,501 bytes，512×512，6 影格，各 220 ms，無限循環。

SHA-256：`4331c743dc0005ab2b55063221d7adcee027115dca928a4e2c96ac81d88e8fcb`。

## 驗證結果

- [Windows 建置與操作驗收 run 42202302352](https://github.com/mengwen-liu/yorunote/actions/runs/42202302352) 成功；workflow 提交 `4eedee2d2a4293f41156512caab9ed63a0a1544a` 固定建置上述 App 來源。
- [另行下載核對 run 42204532603](https://github.com/mengwen-liu/yorunote/actions/runs/42204532603) 成功；下載原始 artifact 後重新計算 ZIP 與 .sha256，核對內部清單及原始 GIF。
- 10 項品牌／回歸測試通過，exit 0；其中新增 3 項實際 GIF 解碼換幀、減少動畫與失焦恢復測試。元件及驗收入口的指定 analyzer 與格式檢查通過。
- 解壓後的正式 Release 執行檔實際啟動，視窗可見、可回應，正常關閉。另編同一來源的驗收入口，首次程序 10 項、重啟程序 3 項通過，包含實際標題 GIF 換幀、原生 HTTP／QuickJS、閱讀及鍵盤翻頁、下載五頁與 SQLite／設定保存。
- ZIP 有 55 個項目，清單涵蓋的 54 個檔案原始位元組雜湊逐一通過；21 個 PE 為 AMD64。打包後 GIF 與原始位元組相同，仍為 6 影格無限循環。
- 文字來源比對涵蓋 init.js、兩份 Windows README 及 LICENSE。Windows checkout 使用 CRLF，Linux checkout 為 LF；僅在這四份文字檔的來源對照正規化換行，其餘內容一致。ZIP 完整性及內部雜湊仍以原始位元組檢查。
- 早期檢查 run 42200747442 因未取得基底 Git 提交而停在前置步驟，補上明確 fetch 後 run 42201769429 通過。第一次另行下載核對 run 42204173825 遇到上述文字換行差異；修正核對腳本後重新下載驗證成功，沒有為此重建 Windows 成品或放寬 GIF／產品雜湊檢查。
- Windows Authenticode 狀態：`NotSigned`，與現有預覽版相同，未加入安裝程式或程式碼簽章。

## 下載

[候選附件包（ZIP 與 .sha256）](https://github.com/mengwen-liu/yorunote/actions/runs/42202302352/artifacts/13494594716)，需登入 GitHub，保留至 2026-11-20 18:36（Asia/Taipei）。

附件包內的產品檔為 `Yorunote_windows_x64_6df02c0f_preview.zip`，22,013,335 bytes。先關閉舊版，再解壓候選 ZIP 並執行 Yorunote/yorunote.exe；沿用 Yorunote 的資料位置，沒有資料遷移或清除步驟。

產品 ZIP SHA-256：

`33338805489e5f4068b83ed2d37a22ed374c4189646b460f0c880d0e735a0bb1`

`.sha256` 檔 SHA-256：

`f1c335fb2d9cfa13c287317bfe6dbf25de13627bee88696153217a46aae8ab20`

此附件包是候選成品，沒有取代公開 v0.1.0-windows-preview.1。

## 畫面與證據

所有公開畫面均來自 Windows CI 的合成資料；沒有複製使用者附圖或私人漫畫／來源設定。

- [繁中淺色首頁](home-zh-TW.png) · [左上角局部](title-logo-light.png)
- [重啟後的英文深色首頁](home-en-US-dark.png)：使用已完成主題切換的既有截圖，另經 [run 42204854987](https://github.com/mengwen-liu/yorunote/actions/runs/42204854987) 從相同 evidence artifact 讀回。
- [成品下載核對摘要](ARTIFACT_VERIFICATION.json)
- [首次程序](smoke-seed.json) · [重啟程序](smoke-restart.json) · [素材資訊](mascot-asset.json)

上述截圖均為實際 Windows CI 視窗；淺色局部圖僅裁切原截圖，沒有合成或替換 Logo。深色首頁不採用剛切換主題途中拍到的過渡畫面。

## 已知範圍

使用者回報前一個公開 Windows x64 版已開啟並試用，基本操作沒有問題，屬使用者回報；本候選版尚待使用者電腦確認。第三方來源登入、所有來源及所有 DPI／多螢幕組合不在這次驗證結果的支持範圍內。

本輪另做下載後重新核對，仍由同一執行者執行。程式碼及實際操作檢查由同一執行者完成，另行下載核對也不是第二位審查者的獨立審查。沒有宣稱完整 App 測試套件全部通過。

## 儲存庫與回復

本輪只更新 `codex/yorunote-windows-mascot-20261106`。既有公開 Release、Tag、master、Notion、Secrets 及儲存庫設定沒有修改。

可直接繼續使用已發布的 v0.1.0-windows-preview.1。候選分支可不採用，或用 git revert 撤回其提交；不需要改寫歷史，也不指示刪除使用者資料。
