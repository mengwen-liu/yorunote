# Yorunote

<p align="center">
  <img src="docs/brand/%E5%A4%9C%E8%AE%80%E6%9C%88%E9%A0%81%E7%B2%BE%E9%9D%88_%E7%9C%A8%E7%9C%BC%E5%BE%AE%E7%AC%91.gif" width="170" alt="Yorunote 角色動畫：綠髮藍眼的月亮書頁精靈眨眼微笑 / Animated Yorunote character: a green-haired, blue-eyed moon-and-book elf blinking and smiling">
</p>

<p align="center"><strong>以閱讀為中心的 Flutter 漫畫閱讀器<br>A reading-focused Flutter comic reader</strong></p>

<p align="center"><strong>繁體中文</strong> · <a href="README.en.md">English</a></p>

Yorunote 是基於 [Venera](https://github.com/venera-app/venera) 的開源個人分支，持續整理外觀、修正圖片快取與封面載入問題，並保存可追溯的測試紀錄。

本專案承襲上游閱讀器與漫畫來源機制；本分支的貢獻是維護、介面調整及問題修正，並非從零開發整套 App。

## 下載與版本

**目前公開預覽版：[v0.1.0-preview.1](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-preview.1)**（2026-11-05）

[下載 Android ARM64 APK](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0-preview.1/Yorunote_29b590b_cover_timeout_arm64_profile.apk) · [SHA-256 校驗檔](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0-preview.1/Yorunote_29b590b_cover_timeout_arm64_profile.apk.sha256) · [所有版本](https://github.com/mengwen-liu/yorunote/releases)

- 本版提供 Android `arm64-v8a` **Profile 測試建置**，App 內部版本維持 1.6.3（versionCode 2163）；GitHub 的預覽版標籤與 App 內部版本分開。
- [雙語發行說明與已知限制](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-preview.1)包含本次修改、既有測試結果與安裝注意事項。
- APK 大小為 27,882,063 位元組，SHA-256 為 `7ad08033c204a1de62546ca588ea0c050a5ace8ec0d4945d8c7978e156f5057f`。
- [開發紀錄](CHANGELOG.md)保留候選修改與開發歷程；公開版本以 [Releases](https://github.com/mengwen-liu/yorunote/releases) 為準。
- 原始建置證據保存在 [Actions run 41968314599](https://github.com/mengwen-liu/yorunote/actions/runs/41968314599)；日常下載請使用上方 Release 附件。

> **安裝相容性：** 測試 APK 使用一次性測試憑證。若裝置已安裝不同簽章的相同套件 App，無法直接覆蓋安裝。請保留現有 App 與資料；目前尚未建立固定簽章的更新管道。
>
> **驗證範圍：** 這是已公開的預覽版，尚未完成 S25+／Tab S11 實機驗收。350 項測試與 APK 靜態檢查為既有 CI 結果，本次發布沒有重跑測試或重新建置。

## 目前開發狀態

`master` 尚未整合品牌、首頁與快取修正。最新候選位於 [`claude/yorunote-cover-timeout-20261105`](https://github.com/mengwen-liu/yorunote/tree/claude/yorunote-cover-timeout-20261105)。只複製 `master` 不會取得最新 App 候選程式碼。

| 候選內容 | 已完成的修改 | 證據 |
| --- | --- | --- |
| 名稱與角色圖示 | Yorunote 顯示名稱、Android 自適應及單色圖示、About 文案 | [品牌驗證紀錄](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/yorunote-brand-v0.1/README.md) |
| 閱讀器快取修正 | 壞圖恢復、同鍵寫入競態防護、避免快取路徑重用 | [R3.1 保存紀錄](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/2026-11-04-r3.1/README.md) |
| 封面載入 | 快取命中繞過佇列、最多 8 個網路請求、同鍵合併、取消傳遞 | [封面載入 R2 紀錄](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/thumbnail-r2-20261105/README.md) |
| 封面逾時 | 每次封面圖片 HTTP 嘗試原生總逾時 30 秒 | [逾時驗證紀錄](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/cover-timeout-20261105/README.md) |

最新 App 來源為 [`29b590b`](https://github.com/mengwen-liu/yorunote/commit/29b590b457378c16b19821f139b9bcad7d38f689)。CI 記錄（既有 run 41968314599 的結果，本次文件更新未重新執行）為 **350 項測試通過、0 跳過**；分析結果維持 8 項既有 info，沒有新增 warning 或 error。這些結果不等於已完成 Android 實機驗收。

封面逾時的 30 秒不包含排隊、來源資料查詢或重試等待。既有 4 次嘗試與 2／4／8 秒等待可能合計約 134 秒，另加排隊時間。

## 功能與個人貢獻

| 類別 | 內容 |
| --- | --- |
| 承襲上游 | 本機與網路漫畫閱讀、JavaScript 漫畫來源、收藏、下載，以及來源支援的留言與標籤等功能 |
| 本分支維護 | 品牌與首頁調整、閱讀器圖片快取修正、封面請求佇列與取消、原生逾時保護、測試及工程紀錄 |

## 建置與測試

先切換到要建置的候選來源，閱讀對應驗證紀錄。既有驗證工具鏈為 Flutter 3.41.4、Dart 3.11.1、JDK 17、Rust 1.85.1、Android SDK 36 與 NDK 28.0.13004108。

建置還需要依專案設定準備本機 `android/key.properties` 與簽章金鑰；兩者不得提交。主機 HTTP／JavaScript 整合測試需要對應的 rhttp 與 QuickJS 原生函式庫。完整測試條件與建置命令見[最新驗證報告](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/cover-timeout-20261105/README.md)。

## 文件

- [建立漫畫來源](doc/comic_source.md)（上游原始文件）
- [Headless 模式](doc/headless_doc.md)（上游原始文件）
- [合成網路來源與裝置驗收](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/thumbnail-r2-20261105/ACCEPTANCE_SYNTHETIC.md)
- [開發與版本紀錄](CHANGELOG.md)
- [English documentation](README.en.md)

## 上游、授權與致謝

- 上游：[Venera](https://github.com/venera-app/venera)。
- 程式授權：沿用 **GPL-3.0**，全文見 [LICENSE](LICENSE)；著作權與第三方授權聲明保留。
- Android 套件識別碼目前仍為 `com.github.wgh136.venera`。
- 標籤翻譯資料：[EhTagTranslation](https://github.com/EhTagTranslation/Database)。
- 維護過程使用 AI 協助；個人貢獻以實際提交、測試與驗證紀錄為依據。
- 新增首頁與發行說明採台灣繁體中文，並提供英文對照。上游原始文件、授權與歷史證據保留其原文。
