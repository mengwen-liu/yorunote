# 實機驗收流程（合成資料）

對象：`Yorunote_418efac_thumbnail_perf_arm64_profile.apk`（SHA-256 `f300eecd9e7b3151f05e28b6e1fa0a2807e417660c18415fcd9dd74492e7b766`），
ARM64 Android 裝置（例如 S25+、Tab S11）。本流程尚未有人執行；結果請另行記錄，不要把截圖中的第三方封面、帳號或閱讀紀錄放進公開儲存庫。

## 0. 範圍說明

| 可用合成資料驗收 | 需要測試用漫畫來源（本輪**未實作**） |
|---|---|
| 安裝、啟動、名稱與圖示、About | 網路封面的並行上限與事件放行 |
| 本機漫畫封面、歷史列的本機封面（`HistoryImageProvider` 本機分支） | 同一漫畫歷史＋封面只請求一次 |
| App 不因封面載入崩潰、無永久空白 | 壞／空封面快取的恢復：此 Profile APK 的 badging 含 `application-debuggable`，可用 `run-as` 進入 App 資料，但沒有網路來源就沒有可破壞的網路封面快取 |

網路封面相關行為目前只有主機測試與主機量測（見 `README.md` §3）。若要在實機以合成資料驗證，需要另做一個 JS 測試來源與區網 HTTP 伺服器（後續事項 F4）。

## 1. 安裝前

1. 在電腦核對 APK 雜湊：

```bash
sha256sum Yorunote_418efac_thumbnail_perf_arm64_profile.apk
```

   判斷：輸出必須是 `f300eecd9e7b3151f05e28b6e1fa0a2807e417660c18415fcd9dd74492e7b766`。
2. 簽章相容性：此 APK 以 CI 一次性測試金鑰簽署（憑證 SHA-256 `a8144ca3…89ca`）。若裝置上已有 `com.github.wgh136.venera`（Venera、R3.1 或先前的 Yorunote 測試版），安裝會因簽章不同而失敗。**不要為了驗收卸載或清除既有 App 資料**；請改用沒有安裝該套件的裝置、工作設定檔或模擬器以外的另一台實機。若無可用環境，記錄為「受簽章限制未驗收」。

## 2. 安裝與啟動

```bash
adb install Yorunote_418efac_thumbnail_perf_arm64_profile.apk
```

| 檢查 | 通過條件 |
|---|---|
| 安裝 | 顯示 `Success` |
| 啟動器 | 名稱 `Yorunote`，圖示為新品牌圖示 |
| 首次啟動 | 30 秒內進入首頁，無崩潰對話框 |
| About | 顯示 Yorunote 名稱與文案 |

## 3. 合成本機漫畫（不含第三方內容）

1. 在電腦產生 3 本各 5 頁的純色 PNG 漫畫資料夾（任何能輸出 PNG 的工具皆可；例如 ImageMagick）：

```bash
for c in 1 2 3; do mkdir -p synthetic_comic_$c; for p in 1 2 3 4 5; do convert -size 600x900 xc:"gray$((c*20+p*5))" synthetic_comic_$c/$p.png; done; done
```

2. 複製到裝置：

```bash
adb push synthetic_comic_1 synthetic_comic_2 synthetic_comic_3 /sdcard/Download/
```

3. 在 App 的本機漫畫匯入功能中選擇資料夾匯入這三個資料夾（App 支援單本／多本資料夾匯入；選單文字依介面語言而定）。

| 檢查 | 通過條件 |
|---|---|
| 本機書架 | 三本都顯示封面（第一頁的灰色），沒有永久轉圈或空白 |
| 開啟閱讀 | 每本翻 2 頁後返回，首頁歷史列出現三本，封面正常 |
| 重新啟動 App | 歷史列封面仍正常（本機封面不會因任何錯誤被刪除） |
| 快速捲動書架／歷史 | 無崩潰；停下後所有封面在數秒內顯示 |

## 4. 選用：使用你既有的漫畫來源（非合成、結果不公開）

只做目視確認，不截圖上傳：首頁、探索、收藏的封面能正常顯示；快速來回捲動後停止，封面在數秒內補齊、沒有永久空白；開關飛航模式後重新進入頁面，失敗的封面重新整理後可恢復。此項只能說明「未見異常」，不能量化並行數或請求數。

## 5. 記錄格式

| 欄位 | 內容 |
|---|---|
| 裝置／Android 版本 | |
| APK SHA-256 | |
| 各檢查結果 | 通過／失敗／未執行（原因） |
| 異常 | 現象、重現步驟、`adb logcat` 片段（移除帳號、URL 中的權杖與私人路徑） |

本流程通過也只代表上述檢查通過，不代表網路封面佇列在實機上已驗證。
