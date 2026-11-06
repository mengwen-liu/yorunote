# Windows 電腦驗收 / Windows device acceptance

## 繁體中文

以下尚未代使用者在自己的電腦執行。

1. 下載產品 ZIP 與同名 .zip.sha256。若使用 Actions artifact，先解開外層，取得真正產品 ZIP 與校驗檔。
2. 在 PowerShell 執行 `Get-FileHash -Algorithm SHA256 .\\Yorunote_windows_x64_71485c7d_preview.zip`，與 `.sha256` 及交付報告對照。
3. 整份解壓縮，保留 Yorunote/yorunote.exe、所有 DLL 與 data 在一起。執行 yorunote.exe。
4. 核對標題及圖示、繁中與 English、淺色與深色，調整視窗大小後確認畫面。
5. 匯入合成或自行選擇的來源，閱讀、翻頁、下載章節；確認頁碼與下載頁數。
6. 停止來源伺服器或斷網，閱讀下載章節。正常關閉再啟動，核對語言、主題、來源、歷史頁碼、下載與離線圖片。
7. 額外測試網頁登入、螢幕縮放、多螢幕及壓縮檔匯入時，另記 Windows 版本、來源或檔案格式與結果。

此版未簽章，沒有安裝程式，也不會搬移舊 Venera 資料。缺少執行階段時請從 Microsoft 官方取得 MSVC x64 或 WebView2，勿關閉安全保護。

回報問題請提供 ZIP 雜湊、BUILD_INFO.json 的 source_commit、重現步驟與非私人畫面；不要貼帳密、Cookie、私人收藏或真實漫畫頁。

## English

These steps have not been performed on the user's computer.

1. Download the product ZIP and its .zip.sha256. For Actions artifacts, extract the outer archive first.
2. Compare PowerShell `Get-FileHash -Algorithm SHA256 .\\Yorunote_windows_x64_71485c7d_preview.zip` with the checksum and delivery report.
3. Extract the complete ZIP. Keep yorunote.exe, all DLLs and data together; run yorunote.exe.
4. Check branding, Traditional Chinese/English, light/dark mode and window resizing.
5. Import a synthetic or user-selected source, read and turn pages, download a chapter, and verify the stored reading position and page count.
6. Stop the source or disconnect. Read downloaded pages, close normally, restart, and check settings, sources, history, downloads and offline images.
7. Record web login, DPI, multiple monitors and archive import as additional scenarios with the Windows version and source/format.

The build is unsigned and has no installer or Venera-data migration. Obtain missing MSVC x64 or WebView2 runtimes from Microsoft without disabling security protections. Reports should include the product digest, source_commit and non-private reproduction evidence, without accounts, cookies or real comic pages.
