# Yorunote Windows x64 預覽版驗證

本紀錄對應固定 App 提交及其 Windows CI 成品；Android 歷史 350 項測試不是本次 Windows 測試結果。

## 已確認結果

- App 來源：`71485c7de8799e30c9e1b5797ad83fba65668d51`。
- 建置 workflow 提交：`d11ec7f24f37f3c39c1c332448807fb3c6ca1ecd`。
- [Windows 建置與操作驗收 run 42091194413](https://github.com/mengwen-liu/yorunote/actions/runs/42091194413)：成功。
- [下載後重新核對 run 42183056556](https://github.com/mengwen-liu/yorunote/actions/runs/42183056556)：成功，重新取得原始 artifact。
- ZIP：`Yorunote_windows_x64_71485c7d_preview.zip`，21,528,589 bytes。
- SHA-256：`5bc2853adb6b303ef42ee9f070ac5bae9a6c9f5849f5b3fdc4e125dcbe9edac5`。
- 日常下載使用上述公開 Release 的 ZIP 與 .sha256；以下 Actions artifact 為有保留期限的備援證據。
- [下載 Windows ZIP 與 .sha256 的 Actions artifact](https://github.com/mengwen-liu/yorunote/actions/runs/42091194413/artifacts/13445514362)，保留至 2026-11-20 03:26（Asia/Taipei）。
- [Windows 公開預覽版](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-windows-preview.1)已於 2026-11-06 16:02:29（Asia/Taipei）發布；Tag 精確指向上述來源。公開附件與流程回讀見 [PUBLICATION.json](PUBLICATION.json)。

## 實作範圍

Windows 名稱、原生視窗、自訂標題列及圖示導入 Yorunote。七種 ICO 尺寸由既有品牌 PNG 產生。ZIP 包含執行檔、完整 DLL 與 data、繁中及英文 README、LICENSE、BUILD_INFO.json、SHA256SUMS.txt；未加入安裝程式。

應用程式資料目錄為 mengwen-liu / Yorunote，與既有 Venera 分離。本次沒有搬移、清除或遷移使用者原有資料。上游閱讀器及漫畫來源架構保留原歸屬，沿用 GPL-3.0。

App 基底為 `29b590b457378c16b19821f139b9bcad7d38f689`。pubspec.yaml、pubspec.lock、LICENSE 與 android/ 相對該基底未改動。master 的 App 並未因此合併 Windows 分支。

## 實際驗證

| 檢查 | 結果及範圍 |
| --- | --- |
| Flutter / Dart | 固定 3.41.4 / 3.11.1，Windows runner 為 windows-2022 x64 |
| 鎖定依賴 | flutter pub get --enforce-lockfile 通過；pubspec 與 lockfile 無差異 |
| analyzer | 驗收入口、新元件與新測試指定檢查通過；不是整個 App 的零診斷宣稱 |
| 格式 | 新增元件、測試及驗收入口通過固定 Dart formatter；既有大檔未整檔重排 |
| 品牌與回歸測試 | 7 項通過、exit 0；未重跑完整 350 項測試 |
| 新資料目錄問題重現 | 同一回歸測試在舊版 5d95b24 失敗（Null 傳入 String）；候選通過 |
| 正式 ZIP 啟動 | lib/main.dart Release 成品先封裝，實際啟動解壓後執行檔，視窗可見、可回應、正常關閉 exit 0 |
| 功能驗收 | 另編同一來源的驗收入口，真正呼叫 App 與原生套件；第一程序 9 項、重啟程序 3 項指定檢查通過 |
| 原生網路與 JS | rhttp HTTP、QuickJS 來源匯入、20 筆漫畫資料、XOR onResponse 與圖片解碼 |
| 閱讀 | 實際 600×900 圖片、Windows SendInput 右方向鍵、SQLite 保存第 2 頁 |
| 下載與離線 | 下載五頁逐一核對 fixture 雜湊；停止伺服器後讀取本機圖片 |
| 資料保存 | 新程序恢復語言、深色主題、來源、歷史、下載資料與五頁原始位元組，再次實際顯示離線圖片 |
| 另行下載核對 | 外層兩個 artifact digest、產品 ZIP、.sha256、CRC、53 個檔案雜湊、21 個 AMD64 PE |
| 程式內嵌圖示 | 從 exe 的 RT_ICON / RT_GROUP_ICON 重建 ICO，七尺寸與原稿縮放像素逐一一致 |
| Windows 簽章 | Get-AuthenticodeSignature 回傳 NotSigned |

完整操作使用專案生成的合成漫畫與 CI 127.0.0.1 伺服器，沒有帳密、Cookie、私人收藏或真實漫畫。

功能驗收入口 `tool/windows/smoke.dart` 不在交付執行檔中。交付執行檔已另測真正啟動及正常關閉；功能檢查則是同一提交另編入口，不能宣稱曾在使用者電腦實測。

## 找到並修正的問題

1. 新資料目錄未設定 followUpdatesFolder 時，閱讀回呼會把 null 傳給 existsFolder。加入型別檢查；舊版重現及候選測試均保留。
2. 鎖定的 PhotoView 在 didChangeDependencies 重設 loading，原閱讀器的 inline loadingBuilder 直接讀 Theme / MediaQuery，可能讓已解碼圖片在視窗尺寸或主題更新後重新卡住。將載入畫面拆成 ReaderImageLoading，隔離繼承資料訂閱。元件測試同時重現舊行為與驗證新行為；修正後 Windows 重啟離線閱讀通過。

[元件重現 run 42090569964](https://github.com/mengwen-liu/yorunote/actions/runs/42090569964) 的兩項測試與 scoped analyzer 通過。早期 Windows run 42081999129、42086650235 因重啟閱讀失敗而沒有交付 ZIP；保留其歷史證據，未弱化最終條件。

## 原生相依與限制

rhttp 0.15.1、flutter_rust_bridge 2.11.1、flutter_qjs 鎖定提交、sqlite3、視窗管理與 WebView2 loader 已完成 Windows 編譯及封裝；HTTP、JS、資料庫、視窗與圖片功能實際用到。每個 DLL 靜態存在不代表所有插件功能都已驗證。

- 使用者電腦、WebView2 網頁登入、所有第三方來源、長時間使用、多螢幕、DPI、壓縮檔匯入及 Windows ARM64 尚未完整驗證。
- 沒有程式碼簽章；缺少的 MSVC x64 或 WebView2 Runtime 由 Microsoft 官方取得。
- CI 的 C/C++ 相依套件有既有警告，沒有宣稱整個專案零警告。
- 固定來源及 SDK 版本不代表已證明逐位元組可重現。
- 另行下載核對仍由同一執行者執行；沒有第二位審查者的獨立程式審查。

## 照片與原始證據

- [繁中首頁](home-zh-TW-71485c7d.png)
- [英文深色首頁](home-en-US-dark-71485c7d.png)
- [重啟後離線閱讀](offline-after-restart-71485c7d.png)
- [下載後核對摘要](ARTIFACT_VERIFICATION.json)
- [首次程序](smoke-seed.json)、[重啟程序](smoke-restart.json)
- [使用者電腦驗收](ACCEPTANCE_WINDOWS.md)
- [待發布雙語說明](RELEASE_NOTES.md)

## 建置流程與變更邊界

Windows workflow 僅在指定 Windows 分支自己的 workflow 檔變更時觸發，並固定 checkout 上述 App SHA；不呼叫 Build ALL。workflow_dispatch 若要從 GitHub 一般手動入口使用，仍需先讓檔案存在於預設分支，這次沒有為此合併 App。

本輪未修改 Notion、Secrets、既有 Android Release、既有 Tag 或上游授權。維護者介面已暫停 Build ALL、從固定來源建立新 Windows Tag 並公開草稿，再恢復原本的 active 狀態；Build ALL 與 AltStore 的執行總數均為 0。既有 main.yml 的 release: published 規則沒有永久移除。

[附件流程 run 42184470095](https://github.com/mengwen-liu/yorunote/actions/runs/42184470095)只上傳既有草稿附件並回讀位元組，未執行發布。[公開下載回讀 run 42185249520](https://github.com/mengwen-liu/yorunote/actions/runs/42185249520)使用未帶授權標頭的 curl 下載兩個公開附件，重算大小與雜湊，核對 Tag、Build ALL 已恢復及沒有連動執行。

中英文首頁、CHANGELOG 與 Windows 發行說明以文件提交 4f93856d7d4bc2262a1f6d8e5da9f9060365e654 非強制快轉至 master。相對原 master 54a72f10b070d4009d642df013c447f235fbf26f 只改四份文件，30 個相對連結通過存在性檢查；遠端內容一致，瀏覽器確認 Windows 下載區。master 的 App、workflow 與依賴未因此改動。

使用者電腦的命令執行環境在啟動前受 sandbox provisioning 拒絕；沒有在使用者電腦啟動 App、安裝 SDK、變更 ACL 或安全設定。實際原生操作結果來自 Windows CI，兩者分開。

## 回復

Windows 分支可直接不採用。已建立的提交可逐一 git revert，不需 force push 或刪除分支。使用者原有 Venera 資料未改動；本報告不指示刪除資料以排障。

## 發布畫面

[公開發行頁畫面](release-published.png) · [首頁 Windows 下載區](homepage-windows.png)

首頁顯示的是明確標示為預覽版的 README 入口；沒有把 prerelease 改成穩定版或 Latest 來改變 GitHub 側欄的顯示。

首頁文件如需回復，可 git revert 4f93856d7d4bc2262a1f6d8e5da9f9060365e654；此指令僅供說明，未執行。已公開的 Tag 與附件不自動刪除或改指向。
