# Yorunote Windows x64 預覽版

[English](README.en.md)

這是基於 Venera 的 Yorunote Windows 桌面候選版，採 Release 模式建置；不是 Android APK，也不是正式穩定版。來源提交與檔案雜湊見同一資料夾的 BUILD_INFO.json、SHA256SUMS.txt。測試結果請以交付時的 CI 紀錄與驗收報告為準。

## 使用方式

1. 在 Windows x64 電腦將整份 ZIP 解壓縮。
2. 保留 yorunote.exe、所有 DLL 與 data 資料夾在一起，再執行 yorunote.exe。
3. 到設定切換「繁體中文」或 English，並依需要匯入漫畫來源。

本包未附安裝程式，也沒有 Windows 程式碼簽章。若系統缺少 Microsoft Visual C++ x64 執行階段，請由 Microsoft 官方取得：
https://learn.microsoft.com/en-us/cpp/windows/latest-supported-vc-redist

使用內嵌網頁登入時，也可能需要 Microsoft Edge WebView2 Runtime：
https://developer.microsoft.com/en-us/microsoft-edge/webview2/

## 資料與既有 Venera

程式使用 Windows 應用程式資料位置保存設定、歷史紀錄、SQLite 資料庫及下載內容；ZIP 解壓執行不代表資料都存放在解壓資料夾。

本版 Windows 產品資料為 mengwen-liu / Yorunote，與舊 Venera 分開。不執行舊安裝程式，不清除或搬移既有 Venera 資料；尚未提供兩者之間的資料遷移。

## 驗證與限制

自動驗收只使用專案產生的合成漫畫，不含私人帳號、Cookie 或漫畫內容。Windows CI 的啟動、閱讀、下載與重新啟動結果，不能代替你的電腦與實際來源驗收。內嵌網頁登入、所有第三方來源、長時間使用、螢幕縮放比例與 Windows ARM64 不在本次完整驗證範圍內。

## 來源與授權

Yorunote：https://github.com/mengwen-liu/yorunote
上游 Venera：https://github.com/venera-app/venera

閱讀器與漫畫來源架構承襲上游，本分支負責維護、品牌與修正。沿用 GPL-3.0，保留上游著作權與第三方授權；完整條款見 LICENSE，Flutter 第三方聲明也隨 data/flutter_assets 一同保留。
