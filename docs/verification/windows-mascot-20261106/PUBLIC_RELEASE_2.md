# Windows 精靈動畫預覽版 .2 發布紀錄

[v0.1.0-windows-preview.2](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-windows-preview.2) 已於 **2026-11-06 19:58:41（Asia/Taipei）**公開為預覽版，Release ID `436440069`。既有 Windows .1 與 Android Release 保留；本版不標為穩定版。

## 已確認的版本與附件

- Tag 精確指向 App 來源 `6df02c0fda1978319355a51fc2c75f7d66ea6d7f`。
- ZIP：`Yorunote_windows_x64_6df02c0f_preview.zip`，22,013,335 bytes，附件 ID `717004172`。
- ZIP SHA-256：`33338805489e5f4068b83ed2d37a22ed374c4189646b460f0c880d0e735a0bb1`。
- 校驗檔附件 ID `717004170`，108 bytes；SHA-256：`f1c335fb2d9cfa13c287317bfe6dbf25de13627bee88696153217a46aae8ab20`。
- [公開 ZIP](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0-windows-preview.2/Yorunote_windows_x64_6df02c0f_preview.zip) · [公開 .sha256](https://github.com/mengwen-liu/yorunote/releases/download/v0.1.0-windows-preview.2/Yorunote_windows_x64_6df02c0f_preview.zip.sha256)。

沿用 [Windows 建置 run 42202302352](https://github.com/mengwen-liu/yorunote/actions/runs/42202302352) 的成品，沒有重新建置或更改原始 ZIP。10 項測試及首次程序 10 項、重啟 3 項操作檢查是該來源的既有 CI 結果，不能套用到 master 的 App，也不是使用者電腦實測。

## 實際發布與回讀

1. 建立固定來源分支 `codex/yorunote-windows-6df02c0f`，發行頁以該分支為目標，避免 Tag 指向文件用 master。
2. 在維護者介面建立預覽草稿，填入台灣繁體中文／英文說明，並保留尚待裝置驗收與未簽章的限制。
3. [附件流程 run 42213462355](https://github.com/mengwen-liu/yorunote/actions/runs/42213462355) 成功。GITHUB_TOKEN 使用 Actions read／Contents write，先核對固定來源 run、artifact、ZIP、校驗檔及 GIF，再上傳兩個附件，逐一下載回讀。此流程不建立 Tag、不公開 Release、不使用 PAT 或 Secrets。
4. 發布前確認 Build ALL 沒有進行中的執行，原狀態為 active；透過維護者介面暫停並確認停用後公開既有草稿。Tag 在公開時建立，回讀為上述 App SHA。
5. 公開後恢復 Build ALL，介面確認成功啟用。
6. [公開下載核對 run 42214592162](https://github.com/mengwen-liu/yorunote/actions/runs/42214592162) 成功。使用未帶授權標頭的 curl 下載兩個公開附件，重算大小、SHA-256、ZIP CRC 與 54 個清單檔案，核對 GIF 與 BUILD_INFO 來源。
7. 同一流程回讀 Build ALL 為 active，Build ALL 與 AltStore 執行總數都是 0。既有 main.yml 的 release: published 規則沒有永久移除，日後發布仍需處理連動。

## 畫面與原始資料

- [公開發行頁](release-preview2.png) · [附件區](release-preview2-assets.png)
- [附件準備回讀](ATTACHMENT_PREPARE_2.json)：保留當時的 draft=true 狀態，屬發布前證據。
- [公開下載、Tag 與 workflow 狀態](PUBLICATION_2.json)：發布後的實際結果。
- [原始 Logo 候選版報告](https://github.com/mengwen-liu/yorunote/blob/a4cb5d34c21103e785823f939b64764409bba599/docs/verification/windows-mascot-20261106/README.md)：保留候選階段的歷史狀態，沒有覆寫原始測試證據。

## 範圍與限制

本版仍未經 Authenticode 簽章。使用者先前回報 .1 能開啟並試用；.2 的使用者電腦驗收仍待確認。全部第三方來源、WebView2 登入、DPI、多螢幕與長時間使用沒有因此變成完整驗證。

本輪僅處理發行、附件及文件；沒有再次執行 App 測試、安裝工具鏈或更動使用者電腦上的 App／資料。未寫入 Notion、Secrets 或長期簽章；沒有第二位審查者的獨立程式審查。

本版的上游閱讀器與漫畫來源架構仍歸屬 Venera，本 Fork 貢獻為品牌、維護與修正，保留 GPL-3.0 及第三方著作權聲明。公開 Tag 與舊附件不自動刪除或改指向；如需回退，仍可下載 Windows .1。首頁文件可用 git revert 回復，不需要 force push。

## 首頁同步結果

中英文 README、CHANGELOG 與新版雙語發行說明，已由 `4f93856d7d4bc2262a1f6d8e5da9f9060365e654` 非強制快轉至文件提交 `f551750db68617a0be2d66f116e263d73af52fe7`。相對起始 master 只有這四份文件變更，App、workflow、依賴及 LICENSE 未改；35 個相對連結皆有目標。

GitHub 網頁實際確認繁中首頁與英文 README 的 Windows .2 入口及 ZIP 下載網址。[首頁實際畫面](homepage-preview2.png) · [同步核對紀錄](HOMEPAGE_SYNC_2.json)。

文件提交含 [skip ci]；沒有為文件更新重新跑 App 測試或建置。若需撤回首頁變更，可使用 `git revert f551750db68617a0be2d66f116e263d73af52fe7`；此指令未執行，且不會刪除公開 Release 或 Tag。
