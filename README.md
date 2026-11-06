# Yorunote

<p align="center">
  <img src="docs/brand/%E5%A4%9C%E8%AE%80%E6%9C%88%E9%A0%81%E7%B2%BE%E9%9D%88_%E7%9C%A8%E7%9C%BC%E5%BE%AE%E7%AC%91.gif" width="170" alt="Yorunote 角色動畫：綠髮藍眼的月亮書頁精靈眨眼微笑 / Animated Yorunote character: a green-haired, blue-eyed moon-and-book elf blinking and smiling">
</p>

<p align="center"><strong>以閱讀為中心的 Flutter 漫畫閱讀器<br>A reading-focused Flutter comic reader</strong></p>

<p align="center"><strong>繁體中文</strong> · <a href="README.en.md">English</a></p>

<p align="center"><a href="https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-preview.1">v0.1.0-preview.1｜Android</a> · <a href="https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-windows-preview.3">v0.1.0-windows-preview.3｜Windows x64</a> · <a href="#下載與版本">下載</a> · <a href="CHANGELOG.md">版本紀錄</a> · <a href="#功能與個人貢獻">維護成果</a></p>

Yorunote 是基於 [Venera](https://github.com/venera-app/venera) 的開源個人分支，持續整理外觀、修正圖片快取與封面載入問題，並保存可追溯的測試紀錄。

本專案承襲上游閱讀器與漫畫來源機制；本分支的貢獻是維護、介面調整及問題修正，並非從零開發整套 App。

## 下載與版本

**Android 公開預覽版：[v0.1.0-preview.1](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-preview.1)**（2026-11-05）

[下載 Android ARM64 APK](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0-preview.1/Yorunote_29b590b_cover_timeout_arm64_profile.apk) · [SHA-256 校驗檔](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0-preview.1/Yorunote_29b590b_cover_timeout_arm64_profile.apk.sha256) · [所有版本](https://github.com/mengwen-liu/yorunote/releases)

- 本版提供 Android `arm64-v8a` **Profile 測試建置**，App 內部版本維持 1.6.3（versionCode 2163）；GitHub 的預覽版標籤與 App 內部版本分開。
- [雙語發行說明與已知限制](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-preview.1)包含本次修改、既有測試結果與安裝注意事項。
- APK 大小為 27,882,063 位元組，SHA-256 為 `7ad08033c204a1de62546ca588ea0c050a5ace8ec0d4945d8c7978e156f5057f`。
- [開發紀錄](CHANGELOG.md)保留候選修改與開發歷程；公開版本以 [Releases](https://github.com/mengwen-liu/yorunote/releases) 為準。
- 原始建置證據保存在 [Actions run 41968314599](https://github.com/mengwen-liu/yorunote/actions/runs/41968314599)；日常下載請使用上方 Release 附件。

> **安裝相容性：** 測試 APK 使用一次性測試憑證。若裝置已安裝不同簽章的相同套件 App，無法直接覆蓋安裝。請保留現有 App 與資料；目前尚未建立固定簽章的更新管道。
>
> **驗證範圍：** 這是已公開的預覽版，尚未完成 S25+／Tab S11 實機驗收。350 項測試與 APK 靜態檢查為既有 CI 結果，本次發布沒有重跑測試或重新建置。

### Windows x64 預覽版

**[v0.1.0-windows-preview.3](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-windows-preview.3)**（2026-11-07）

[下載 Windows x64 ZIP](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0-windows-preview.3/Yorunote_windows_x64_07406c9f_preview.zip) · [SHA-256 校驗檔](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0-windows-preview.3/Yorunote_windows_x64_07406c9f_preview.zip.sha256) · [雙語發行說明](docs/releases/v0.1.0-windows-preview.3.md)

- 固定 App 來源 `07406c9f`，採 **Release 模式**建置；整份解壓縮後執行 `Yorunote/yorunote.exe`，保留所有 DLL 與 `data` 資料夾。
- 修正左上角 `No Overlay widget found.`，保留 28×28 精靈動畫與滑鼠提示；失焦或要求減少動畫時顯示靜態圖。
- ZIP 為 22,015,039 位元組；SHA-256：`cf7d5a616af30867349bb9136a491188d7a28a12e0d4778f9a2a1c74e6257ed3`。
- [Windows CI 與發布核對](https://github.com/mengwen-liu/yorunote/blob/3490fed98e698c2aa87eb9956d0d3da4a45679db/docs/verification/windows-overlay-fix-20261106/PUBLIC_RELEASE_3.md)：13 項指定測試，首次程序 11 項、重啟 4 項檢查通過；另行下載核對 ZIP、校驗檔與完整檔案清單。
- 使用者於 2026-11-07 [確認精靈動畫與滑鼠提示正常](https://github.com/mengwen-liu/yorunote/blob/2d0d5375f5e4f53f96f3558ad10278a7762c8797/docs/verification/windows-overlay-fix-20261106/OWNER_ACCEPTANCE.md)，屬這兩項 UI 行為的實機回報，並非整套功能驗收。
- 未經 Windows 程式碼簽章，沒有安裝程式；資料沿用獨立的 `mengwen-liu / Yorunote` 目錄，不自動遷移舊 Venera 資料。
- WebView2 登入、全部第三方來源、各種 DPI、多螢幕及 Windows ARM64 尚未完整驗證；本版仍為預覽版。

## 目前開發狀態

Android 公開預覽版的 App 原始碼固定在 [Tag `v0.1.0-preview.1`](https://github.com/mengwen-liu/yorunote/tree/v0.1.0-preview.1)，對應提交 `29b590b`。`master` 已有專案首頁與發行文件，尚未整合這份 App 程式；需要取得與 APK 相同的來源時，請使用上述 Tag。[候選分支與完整驗證紀錄](https://github.com/mengwen-liu/yorunote/tree/claude/yorunote-cover-timeout-20261105)另外保存開發歷程。

Windows App 原始碼另固定在 [Tag `v0.1.0-windows-preview.3`](https://github.com/mengwen-liu/yorunote/tree/v0.1.0-windows-preview.3)，對應 `07406c9f`；兩個平台的來源、建置模式及驗證紀錄分開。`master` 尚未整合這兩份 App 來源。

| 領域 | 預覽版包含的修改 | 證據 |
| --- | --- | --- |
| 名稱與角色圖示 | Yorunote 顯示名稱、Android 自適應及單色圖示、About 文案 | [品牌驗證紀錄](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/yorunote-brand-v0.1/README.md) |
| 首頁呈現 | 搜尋入口、區塊標題，以及歷史／本機漫畫封面列 | [已接入的首頁程式](https://github.com/mengwen-liu/yorunote/blob/29b590b457378c16b19821f139b9bcad7d38f689/lib/pages/home_page.dart) |
| 閱讀器快取修正 | 壞圖恢復、同鍵寫入競態防護、避免快取路徑重用 | [R3.1 保存紀錄](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/2026-11-04-r3.1/README.md) |
| 封面載入 | 快取命中繞過佇列、最多 8 個網路請求、同鍵合併、取消傳遞 | [封面載入 R2 紀錄](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/thumbnail-r2-20261105/README.md) |
| 封面逾時 | 每次封面圖片 HTTP 嘗試原生總逾時 30 秒 | [逾時驗證紀錄](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/cover-timeout-20261105/README.md) |

本版首頁已接入搜尋入口、區塊標題與封面卡；最近閱讀卡片與閱讀進度元件尚未接入這個首頁。

Android 預覽版 App 來源為 [`29b590b`](https://github.com/mengwen-liu/yorunote/commit/29b590b457378c16b19821f139b9bcad7d38f689)。CI 記錄（既有 run 41968314599 的結果，本次文件更新未重新執行）為 **350 項測試通過、0 跳過**；分析結果維持 8 項既有 info，沒有新增 warning 或 error。這些結果不等於已完成 Android 實機驗收。

封面逾時的 30 秒不包含排隊、來源資料查詢或重試等待。既有 4 次嘗試與 2／4／8 秒等待可能合計約 134 秒，另加排隊時間。

## 功能與個人貢獻

| 類別 | 內容 |
| --- | --- |
| 承襲上游 | 本機與網路漫畫閱讀、JavaScript 漫畫來源、收藏、下載，以及來源支援的留言與標籤等功能 |
| 本分支維護 | 品牌與首頁調整、閱讀器圖片快取修正、封面請求佇列與取消、原生逾時保護、測試及工程紀錄 |

## 建置與測試

要重現 Android 預覽版，請先取得 Android Tag 的 App 來源，閱讀對應驗證紀錄。既有驗證工具鏈為 Flutter 3.41.4、Dart 3.11.1、JDK 17、Rust 1.85.1、Android SDK 36 與 NDK 28.0.13004108。

建置還需要依專案設定準備本機 `android/key.properties` 與簽章金鑰；兩者不得提交。主機 HTTP／JavaScript 整合測試需要對應的 rhttp 與 QuickJS 原生函式庫。完整測試條件與建置命令見[最新驗證報告](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/cover-timeout-20261105/README.md)。

Windows 建置使用 [固定來源的獨立 workflow](https://github.com/mengwen-liu/yorunote/blob/ef9996a249b4b815b4688aa99576abd9d7899f3f/.github/workflows/yorunote-windows-preview.yml)，不呼叫 Build ALL；執行 ZIP 不需要自行安裝 Flutter 或 Android SDK。建置與操作驗證的範圍見 [Windows 報告](https://github.com/mengwen-liu/yorunote/blob/3490fed98e698c2aa87eb9956d0d3da4a45679db/docs/verification/windows-overlay-fix-20261106/PUBLIC_RELEASE_3.md)。

## 文件

- [建立漫畫來源](doc/comic_source.md)（上游原始文件）
- [Headless 模式](doc/headless_doc.md)（上游原始文件）
- [合成網路來源與裝置驗收](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/thumbnail-r2-20261105/ACCEPTANCE_SYNTHETIC.md)
- [開發與版本紀錄](CHANGELOG.md)
- [Android 發行說明](docs/releases/v0.1.0-preview.1.md)
- [Windows 雙語發行說明](docs/releases/v0.1.0-windows-preview.3.md)
- [Windows 繁中使用說明](https://github.com/mengwen-liu/yorunote/blob/v0.1.0-windows-preview.3/windows/README.md)
- [發行紀錄與維護者操作原則](docs/releases/PREVIEW_RELEASE_PROCESS.md)
- [English documentation](README.en.md)

## 上游、授權與致謝

- 上游：[Venera](https://github.com/venera-app/venera)。
- 程式授權：沿用 **GPL-3.0**，全文見 [LICENSE](LICENSE)；著作權與第三方授權聲明保留。
- Android 套件識別碼目前仍為 `com.github.wgh136.venera`。
- 標籤翻譯資料：[EhTagTranslation](https://github.com/EhTagTranslation/Database)。
- 維護過程使用 AI 協助；個人貢獻以實際提交、測試與驗證紀錄為依據。
- 新增首頁與發行說明採台灣繁體中文，並提供英文對照。上游原始文件、授權與歷史證據保留其原文。
