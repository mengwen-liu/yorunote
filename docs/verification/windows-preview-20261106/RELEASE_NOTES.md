# Yorunote Windows x64 預覽版 / Windows x64 preview

> Windows x64、Release 模式的預覽建置，未經 Windows 程式碼簽章；使用者電腦驗收仍待進行。這不是穩定版。
>
> A Windows x64 Release-mode preview, not Authenticode-signed. User-device acceptance remains pending. This is not a stable release.

App 來源 / Application source: [`71485c7de8799e30c9e1b5797ad83fba65668d51`](https://github.com/mengwen-liu/yorunote/commit/71485c7de8799e30c9e1b5797ad83fba65668d51)

## 繁體中文

- Windows 執行檔、視窗名稱與圖示導入 Yorunote，附繁中及英文說明。
- 獨立 Windows 建置固定來源提交，不呼叫整套 Build ALL。
- 修正新資料目錄閱讀回呼的空值問題，以及視窗／主題更新後圖片可能卡在載入中的問題。
- CI 已實際驗證：正常執行檔啟動與關閉；同一來源另編驗收入口執行原生 HTTP、QuickJS / onResponse、閱讀翻頁、下載五頁、SQLite 歷史、設定與重啟後離線閱讀。
- 七項品牌及回歸測試通過；沒有重跑歷史完整 350 項測試。
- 另行下載 ZIP，核對 53 個檔案、21 個 AMD64 PE，以及 exe 內七尺寸圖示。
- 閱讀器與漫畫來源架構承襲 [Venera](https://github.com/venera-app/venera)，本 Fork 貢獻為維護、品牌與修正，沿用 GPL-3.0。

### 下載與使用

下載下方兩個附件，核對 .sha256 後把 ZIP 整份解壓縮；保留 yorunote.exe、DLL 與 data 在一起，再執行 yorunote.exe。這不是所有資料都存在解壓資料夾的完全可攜式程式；資料使用 Windows 應用程式資料目錄 mengwen-liu / Yorunote，與 Venera 分離，不自動遷移舊資料。

本版沒有安裝程式及 Authenticode 簽章。WebView2 登入、全部第三方來源、DPI、多螢幕、壓縮檔匯入、長時間使用與 Windows ARM64 尚未完整驗證。

| 項目 / Item | 值 / Value |
| --- | --- |
| ZIP | `Yorunote_windows_x64_71485c7d_preview.zip` |
| 大小 / Size | 21,528,589 bytes |
| SHA-256 | `5bc2853adb6b303ef42ee9f070ac5bae9a6c9f5849f5b3fdc4e125dcbe9edac5` |
| 模式 / Configuration | Windows x64 / Release |
| App 內部版本 / Internal version | 1.6.3，與 GitHub 預覽版標籤分開 / separate from the GitHub tag |

## English

This preview adds Yorunote Windows branding, a complete ZIP bundle and bilingual instructions through a dedicated workflow with a fixed source commit. It fixes a fresh-profile null-folder error and a loaded-image spinner regression on inherited size/theme changes.

Windows CI launched and normally closed the extracted production executable. A separate acceptance entry point built from the same source exercised real native HTTP, QuickJS/onResponse, reading with native keyboard input, five-page downloads, SQLite history, settings and offline reading after restart. Seven focused tests passed; the historic 350-test suite was not rerun.

A separate download check verified both artifact digests, the product ZIP and checksum, all 53 bundled files, 21 AMD64 PE files and all seven embedded icon sizes. These checks do not replace validation on the user's computer. No second-reviewer code audit is claimed.

Extract the whole ZIP and keep the executable, DLLs and data together. The app uses its own Windows application-data directory; it does not migrate or delete existing Venera data. This unsigned build has no installer. Embedded web login, all third-party sources, DPI, multiple monitors, archive import, long sessions and Windows ARM64 are not fully covered.

The reader and source architecture come from upstream Venera; this fork contributes maintenance, branding and fixes under GPL-3.0.

## 證據與授權 / Evidence and license

- [Windows CI build and runtime checks](https://github.com/mengwen-liu/yorunote/actions/runs/42091194413)
- [Downloaded-artifact verification](https://github.com/mengwen-liu/yorunote/actions/runs/42183056556)
- [驗證報告 / Report](https://github.com/mengwen-liu/yorunote/blob/codex/yorunote-windows-preview-20261106/docs/verification/windows-preview-20261106/README.md)
- [使用者電腦驗收 / Device checks](https://github.com/mengwen-liu/yorunote/blob/codex/yorunote-windows-preview-20261106/docs/verification/windows-preview-20261106/ACCEPTANCE_WINDOWS.md)
- [GPL-3.0 LICENSE](https://github.com/mengwen-liu/yorunote/blob/71485c7de8799e30c9e1b5797ad83fba65668d51/LICENSE)
