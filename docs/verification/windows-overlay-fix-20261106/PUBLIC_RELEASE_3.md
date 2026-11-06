# Windows 預覽版 .3：公開發行與實機回報

[公開發行頁](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-windows-preview.3)；Release ID `436759456`，於 2026-11-07 00:59:20（Asia/Taipei）公開，為 prerelease。Tag `v0.1.0-windows-preview.3` 精確指向 `07406c9f6a6d105fd854cb3ddc22cfcc6dacfd9b`。既有預覽版及其附件保留。

## 成品與來源

- [Windows ZIP](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0-windows-preview.3/Yorunote_windows_x64_07406c9f_preview.zip)：`Yorunote_windows_x64_07406c9f_preview.zip`，22,015,039 bytes。
- [SHA-256 校驗檔](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0-windows-preview.3/Yorunote_windows_x64_07406c9f_preview.zip.sha256)。
- ZIP SHA-256：`cf7d5a616af30867349bb9136a491188d7a28a12e0d4778f9a2a1c74e6257ed3`。
- 原始建置：[run 42229100772](https://github.com/mengwen-liu/yorunote/actions/runs/42229100772)，建置流程提交 `ef9996a249b4b815b4688aa99576abd9d7899f3f`。
- [既有成品與原生驗收](ARTIFACT_VERIFICATION.json)：13 項指定測試、首次程序 11 項與重啟 4 項檢查；本次發行沒有重新建置或重跑完整測試。
- 發行採原 artifact `13510450166`，其 ZIP wrapper SHA-256 為 `a8da90ac2a1d0a65b84455a493ce0f5d4b13785e533f5cb10fb612660e80bbba`。
- [附件核對 run 42256983320](https://github.com/mengwen-liu/yorunote/actions/runs/42256983320)：上傳前核對來源、草稿、artifact、ZIP 與校驗檔，上傳後重新下載核對。歷史草稿回讀見 [ATTACHMENT_PREPARE_3.json](ATTACHMENT_PREPARE_3.json)。
- [公開下載核對 run 42257714216](https://github.com/mengwen-liu/yorunote/actions/runs/42257714216)：未帶授權標頭的 HTTPS 公開下載成功；兩個附件、54 份清單檔案與 GIF 雜湊相符。數值見 [PUBLICATION_3.json](PUBLICATION_3.json)。

## 使用者確認

使用者於 2026-11-07（Asia/Taipei）明確回報「精靈與滑鼠提示正常」，分類為 **OWNER_REPORTED**，只涵蓋這兩項 UI 行為。未從使用者電腦回讀檔案雜湊，也不代表全部功能、所有來源或長時間使用已完整驗收。詳見 [OWNER_ACCEPTANCE.md](OWNER_ACCEPTANCE.md)。

使用者提供的私人漫畫畫面未上傳。下圖只有本次公開 GitHub 發行頁。

![公開 Windows 預覽版 .3](release-preview3.png)

## 發行流程與範圍

- 原先 Build ALL 為 active；發布前透過維護者介面暫停，確認停用後公開，再恢復啟用。
- 公開下載核對確認 Build ALL 為 active；Build ALL 與 AltStore 的執行筆數皆維持 0。這不是永久移除 `release: published` 規則。
- 原 App 成品、資料目錄、依賴、授權與簽章不變，仍是未經 Authenticode 簽章的 Windows x64 Release 模式預覽版，沒有安裝程式。
- App 程式仍保存在來源 Tag／功能分支，未在本輪整合至 master。首頁與發行說明另以文件提交同步。
- 此紀錄沒有主張已完成另一位審查者的獨立程式碼審查。

## English

Preview .3 was published at 2026-11-07 00:59:20 Asia/Taipei from the exact application source `07406c9f6a6d105fd854cb3ddc22cfcc6dacfd9b`, reusing the existing verified ZIP without rebuilding. The user confirmed elf animation and hover tooltip behavior only. Public unauthenticated downloads, checksums, all 54 manifest-listed files, the GIF and tag were verified. Build ALL was temporarily paused and restored to active, with no Build ALL or AltStore runs. Existing releases remain unchanged. This is still an unsigned Windows x64 preview; full device coverage and application-code integration into master remain separate work.
