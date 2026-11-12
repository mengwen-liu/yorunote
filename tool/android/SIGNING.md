# Yorunote Android 0.1.0 離線簽章

本包包含正式套件 ID `com.mengwenliu.yorunote` 的 ARM64 待簽 APK，以及版號較低的覆蓋更新測試 APK。2026-11-13 的 S25+、Tab S11 安裝與首頁顯示由使用者回報，對應獨立套件的候選版；正式套件仍需實機驗證。

1. 準備 JDK 與 Android SDK Build-Tools 36.0.0。若已持有本專案的正式金鑰，沿用原金鑰。首次建立可在本機使用以下指令，將金鑰放在儲存庫以外並備份。
   ```powershell
   keytool -genkeypair -storetype PKCS12 -keystore "D:\Private\yorunote-release.p12" -alias yorunote -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Yorunote"
   ```
   將範例路徑換成已存在的私人目錄。密碼由工具互動詢問。金鑰與密碼留在本機。
2. 在解壓後的資料夾執行以下指令。若 SDK 位於自訂路徑，加上 `-BuildTools "<SDK>/build-tools/36.0.0"`。
   ```powershell
   .\Sign-Yorunote.ps1 -Keystore "D:\Private\yorunote-release.p12" -KeyAlias yorunote
   ```
   腳本先核對兩份輸入 SHA-256，再驗證簽章、版號與相同憑證，輸出至 `signed`。
3. 在實機先安裝版號 2162 的 `upgrade-base` APK，建立測試用閱讀紀錄、收藏、設定與離線下載，再**不解除安裝**地覆蓋安裝版號 2172 的正式 APK。確認這些資料仍可讀取。備份匯入與離線下載搬移另外確認。
4. 對外發行只使用版號 2172 的 `Yorunote-0.1.0-android-arm64.apk` 與對應 SHA-256。版號 2162 的 APK 僅供驗證。

參考 [Android App signing](https://developer.android.com/studio/publish/app-signing) 與 [apksigner](https://developer.android.com/tools/apksigner)。
