# 首頁／書架封面載入：可靠性與效能（thumbnail-perf-20261105）

> 狀態：**候選，尚未合併至 master**。只有主機測試、主機量測與 CI 靜態檢查；**尚未在 Android 實機啟動或驗收**。

## 1. 身分與提交

| 項目 | 值 |
|---|---|
| Repository | `mengwen-liu/yorunote`（ID 1421354314，以 GitHub API 核對） |
| 起點 | `claude/yorunote-arm64-ci-20261104` @ `7b6348a98cb85dd71c826134811fa02fcd302da8`（未改動） |
| 本輪分支 | `claude/yorunote-thumbnail-perf-20261105` |
| B（基準工具） | `49b0e3c8b5830bee268676d4dd6e35bc8db7552d`：重現測試、量測工具、基準數據；不含 App 修改 |
| **S（App＋測試）** | **`418efacd0bb03e1da180ff105c4566821a4e69fd`**，tree `bd2f77027cdd152682dadae4a1abec0335d77908`；CI 與 APK 的建置來源 |
| W1（workflow） | `31b50aa1639d59a615c8a59f2b73be0244ede361`：run 41881391792（失敗，見 §5） |
| W2（workflow 修正） | `084f296acf259efd90a479d32f9d2b6ce76be389`：run 41883419245（成功） |
| T（只改測試） | `4232bd5aa7415ce4e593828bb73d455ab0f189ce`：以突變驗證發現的空洞測試改寫；`lib/`、`android/`、`assets/`、`pubspec.*` 與 S 相同 |
| 證據提交 | 本目錄所在的後續提交（只含文件、證據、README） |

`pubspec.yaml`／`pubspec.lock` blob 與起點相同（`489d6ac…`／`c061e4f…`），未改相依、資料庫結構、資料位置、applicationId、namespace 或簽章設定。

## 2. 修正內容（S）

App 改動只在 `lib/network/images.dart`、新增 `lib/network/request_limiter.dart`、`CachedImageProvider`、`HistoryImageProvider`。

1. **封面專用載入 `ImageDownloader.loadCoverThumbnail`**：兩個封面 provider 改走這條路徑。
   - 磁碟快取有效命中直接回傳，**不排隊、不發請求**；`file://` 在 provider 內處理，也不排隊。
   - 網路請求先取得 `RequestLimiter(8)` 名額。名額釋放時以 Completer **事件**交給下一位（FIFO），不再固定 100 ms 輪詢；輪到時若該載入已停止則跳過，不占名額。名額在 `finally` 釋放，涵蓋成功、HTTP 錯誤、部分回應、解碼前錯誤與取消。
   - 同一個**磁碟快取鍵**（`url@sourceKey[@cid]`）同時進行的載入共用一個請求；只有所有共用者都已停止才中止請求。不同來源或 cid 的鍵不同，不會合併。
2. **壞快取失效 `ImageDownloader.invalidateCoverCache`**：provider 覆寫 `onInvalidImageData`。只處理由封面快取讀出或寫入的位元組（以 `Expando` 記錄其實際磁碟鍵）；確認該鍵目前檔案內容與失敗位元組完全相同，才以既有 `CacheManager.delete(..., onlyIfStoredIn: file)` 刪除。本機檔案、歷史本機封面、本機備援封面一律不刪；不新增自動重試，不對正常命中做額外解碼。
3. 移除 `CachedImageProvider.loadingCount`／`_kMaxLoadingCount`（全專案只在該檔使用，已以 grep 確認）。

未改動：`loadThumbnail`（下載任務封面、`LocalFavoriteImageProvider` 使用）、`BaseImageProvider` 的錯誤／重試、閱讀器圖片路徑與 R3.1 快取保護、本機備援邏輯。

行為差異（需知悉）：`HistoryImageProvider` 原本沒有並行上限，現在與一般封面共用 8 個名額；`cover.` 型 URL 的 `loadComicInfo` 不再位於上限之內（原本 CachedImageProvider 整段都在輪詢佇列內）。

## 3. 重現與前後結果

### 3.1 測試（同一份測試檔在基準與候選執行）

| 測試檔 | 基準 7b6348a | 候選 S／T |
|---|---|---|
| `thumbnail_cover_cache_test.dart`（14 項） | 9 過、**5 敗**：Cached／History 的壞資料、空資料未失效且重試仍失敗；壞下載被留在快取 | 14 過 |
| `thumbnail_cover_queue_test.dart`（6 項） | 2 過、**4 敗**：峰值 9、佇列滿時快取命中被擋（逾時）、同漫畫歷史＋封面 2 次請求、共用請求情境 2 次請求 | 6 過 |
| `request_limiter_test.dart`（6 項）、`thumbnail_cover_invalidation_test.dart`（3 項） | 使用新 API，基準無法編譯，未執行 | 全過 |

基準原本即通過、候選維持通過的情境：有效磁碟命中、記憶體命中、未命中、過期、壞的本機檔不刪、本機備援、同 URL 不同來源／cid 分開、來源 `getThumbnailLoadingConfig` 改寫 URL 與標頭、取消後名額歸還、403／404／500／部分回應後名額歸還且不寫快取。

### 3.2 主機量測（`results/`）

條件：x86_64 Linux 雲端容器、loopback HTTP、合成 160×240 灰階 PNG（1,020 位元組）、伺服器固定延遲 40 ms；暖機 1 次＋取樣 7 次；基準與候選依序在同一容器執行。**僅為主機數據，不能推論 S25+／Tab S11 的 FPS、捲動或耗電。**

| 指標 | 基準 7b6348a | 候選 S | 樣本 |
|---|---|---|---|
| 冷載 32 張：HTTP 請求數 | 32 | 32（0 變化） | 每次取樣 |
| 冷載 32 張：峰值並行 | **9** | **8** | 每次取樣 |
| 佇列滿（12 張保留中）時 16 張快取命中可先顯示 | 0／16 | 16／16 | 每次取樣 |
| 快取命中完成延遲 中位數／P95 | 1745.6／1760.0 ms（被保留 1.5 s 的網路擋住） | 38.7／45.8 ms | n=112 |
| 快取命中的 HTTP 請求 | 0 | 0（0 → 0） | 每次取樣 |
| 名額放行延遲 中位數／P95 | 100.9／102.1 ms | 8.6／10.8 ms | n=42 |
| 同 10 部漫畫的歷史＋封面同時載入 HTTP | 19–20 | 10 | 每次取樣 |
| 壞／空快取 6 筆：重試仍失敗 | 6／6 | 0／6（重試各 1 次請求） | 每次取樣 |
| provider 路徑有效命中 HTTP | 0 | 0（0 → 0，未改） | 每次取樣 |
| 直接完整消費 `loadThumbnail` 有效命中 HTTP | 1 | 1（未改，見 §7） | 每次取樣 |
| **冷載：首張可顯示** 中位數／P95 | 103.0／117.5 ms | 108.0／122.6 ms | n=7 |
| **冷載：全部完成** 中位數／P95 | 389.9／485.3 ms | **420.2**／451.4 ms | n=7 |
| **冷載：排隊等待** 中位數／P95 | 131.2／324.1 ms | **210.2**／351.0 ms | n=224 |
| **冷載：完成延遲** 中位數／P95 | 231.1／415.5 ms | **284.5**／427.6 ms | n=224 |

**取捨（未改善／退步）**：純冷載情境候選較慢（全部完成中位數 +30 ms、排隊等待中位數 +79 ms）。在拋棄式副本的歸因實驗（未出貨，`results/bench_experiment_*_scratch.json`）：

| 變體 | 全部完成 中位數 | 排隊等待 中位數 | 完成延遲 中位數 |
|---|---|---|---|
| 候選 S | 420.2 | 210.2 | 284.5 |
| 拿掉「取得名額後再查一次快取」 | 394.1 | 168.9 | 230.2 |
| 上限改 9（僅歸因，不建議提高） | 376.9 | 134.1 | 232.2 |

推論：退步主要來自取得名額後的第二次快取查詢（同步 SQLite＋檔案檢查落在名額關鍵路徑上），其次是上限由實際 9 改為明確 8。各變體只量一輪（7 取樣），有雜訊。App 已固定為 S 並完成 CI，重跑額度已用完，本輪不再改程式；列為後續事項 F1。

## 4. 驗證

| 項目 | 結果 |
|---|---|
| `flutter pub get --enforce-lockfile` | exit 0（本機與 CI） |
| 格式 | 新檔整檔 `dart format`；既有三檔只檢查新增行，239／22／17 行皆與 `dart format` 輸出一致，未重排既有格式 |
| `flutter analyze` | 基準與候選皆 8 項既有 info（`deprecated_member_use`），**清單完全相同**，exit 1（info 也回傳 1）；CI 以精確清單比對把關 |
| 完整 `flutter test` | 基準 +286；候選 S +313；候選 T +315；皆 0 跳過、exit 0（`logs/`） |
| 原生 HTTP | 依 rhttp 0.15.1 鎖定 `Cargo.lock`（SHA-256 `232c3f91…5eb4`）以 Rust 1.85.1 建置主機 `librhttp.so`；R3.1 閱讀器原生 HTTP 測試與本輪測試**實際執行**，0 跳過 |
| 乾淨副本 | 重新從 GitHub clone、checkout `7b6348a`、套用 `patches/THUMBNAIL_PERF_S_FROM_7b6348a.patch` 後 tree＝`bd2f770`，與遠端 S 無差異 |
| 突變驗證（`results/mutation_results*.json`） | 10 項突變。初跑 9 項被抓、M1（拿掉位元組比對）存活 → 發現該測試空洞並於 T 改寫 → 重跑 M1–M3 全被抓。最終 10／10 被抓；突變只在拋棄式副本，已還原 |

未涵蓋：`onlyIfStoredIn` 單獨移除（需在 findCache 與 delete 之間插入競態的掛鉤，本輪未加）；`onResponse`（需 QuickJS 主機函式庫）；`cover.` 型 URL 路徑；實際 App 內 `MyLogInterceptor`（主機測試 `App.isInitialized=false`，404 也會走 BaseImageProvider 的 2＋4＋8 秒重試）。另查明：Flutter `ImageCache.evict` 會把 keepAlive 釋放延到下一幀，單純 Widget 移除不會停止進行中的載入；測試以「evict＋推進一幀」模擬取消。

## 5. CI 與 APK

| Run | Workflow 提交 | 來源 | 結論 |
|---|---|---|---|
| [41881391792](https://github.com/mengwen-liu/yorunote/actions/runs/41881391792) | `31b50aa` | S `418efac` | 失敗：測試本身 27 項通過，但 GitHub Actions 上 `flutter test` 改用 github reporter，我的摘要解析找不到 expanded 格式的結尾行；未建置 APK |
| [41883419245](https://github.com/mengwen-liu/yorunote/actions/runs/41883419245) | `084f296`（加 `--reporter expanded`） | S `418efac` | **成功**：主機 librhttp 建置、封面回歸 +27、完整 +313（0 跳過）、analyzer 清單相同、APK 建置與靜態檢查、Git 完整性 |

共執行 2 次（1 次修正後重跑），未遇到 HTTP 429。

| APK | 值 |
|---|---|
| 檔名 | `Yorunote_418efac_thumbnail_perf_arm64_profile.apk` |
| 大小 | 27,865,243 位元組 |
| SHA-256 | `f300eecd9e7b3151f05e28b6e1fa0a2807e417660c18415fcd9dd74492e7b766`（下載 artifact 後本機重算一致） |
| Artifact | `yorunote-thumbnail-perf-arm64-profile-apk`（id 13351207705，zip digest `f9d81a33…dfe0b` 與下載檔一致），登入 GitHub 後於 run 頁面下載，2026-11-11 到期 |
| 套件／版本／名稱 | `com.github.wgh136.venera`、1.6.3（2163）、`Yorunote` |
| ABI／原生庫 | 只有 `arm64-v8a`；含 `libflutter.so`、`libapp.so`、`librhttp.so` 等 10 個；`libapp.so` 內可找到 `loadCoverThumbnail`、`coverRequestLimiter` 字串 |
| 完整性 | ZIP 測試通過、zipalign 4 通過（16 KB 對齊 yes，僅參考） |
| 圖示／About | 20 張圖示與儲存庫像素相同；adaptive XML 三層齊全；`app_icon.png` 雜湊一致 |
| 簽章 | apksigner Verifies（v2），1 位簽署者，CN=`Yorunote CI Disposable`，憑證 SHA-256 `a8144ca3d2a11a310de6c1f4ab6c8def90e39439a99d71b9a606b8a97b4489ca`，與 job 內金鑰相符 |

**一次性測試簽章**：與先前 R3.1、品牌 CI 的 APK 憑證都不同，無法覆蓋安裝以其他憑證簽署的同套件 App。本輪不要求卸載或清除資料。apksigner 只在 CI 執行（本容器未安裝 build-tools）。以上都是**靜態檢查，不代表已在 Android 啟動或驗收**。

## 6. 實機驗收

見 [`ACCEPTANCE.md`](ACCEPTANCE.md)。合成資料只能驗證啟動、品牌、本機漫畫與歷史本機封面；網路封面的佇列、合併、壞快取恢復需要一個測試用漫畫來源，**本輪未實作**。

## 7. 後續事項（本輪未做）

- F1：拿掉取得名額後的第二次快取查詢（§3.2 歸因數據），需新的 S 與 CI。
- F2：下載任務封面（`download.dart` 完整消費 `loadThumbnail`）在有效命中後仍會再請求 1 次；屬下載流程，未改。
- F3：`LocalFavoriteImageProvider` 仍使用預設失效（鍵不一致），目前 `lib/` 內沒有建立它的地方。
- F4：合成測試來源（JS）＋區網 HTTP 伺服器，讓網路封面行為能在實機以合成資料驗收。
- F5：`onResponse`、`cover.` 路徑與 `onlyIfStoredIn` 競態的測試。

## 8. 回復方式

起始分支 `claude/yorunote-arm64-ci-20261104` 未改動，可直接繼續使用。若要撤回本輪，在本分支依序 `git revert` 4232bd5、084f296、31b50aa、418efac、49b0e3c（或不採用本分支）。不自動回復、不刪除任何遠端分支。

## 9. 其他

- 點數：本工作階段無法讀取雲端點數餘額，未設定精確美元上限；未啟用任何付費或加值。
- 本目錄檔案清單與雜湊：[`EVIDENCE_SHA256SUMS.txt`](EVIDENCE_SHA256SUMS.txt)。日誌皆為合成資料執行結果，不含第三方封面、帳號或閱讀紀錄；提交前以 CI 同款偵測規則掃描，0 命中。

| 目錄 | 內容 |
|---|---|
| `baseline/` | 修正前第一次量測（保留，不覆寫） |
| `results/` | 最終量測 JSON／CSV、歸因實驗、突變結果、乾淨副本與 artifact 核對 |
| `logs/` | 工具版本、基準與候選的完整測試／analyze／量測日誌、主機 rhttp 建置 |
| `ci/` | 兩次 run 的脫敏日誌與證據、APK `.sha256`、`verification.txt` |
| `patches/` | S（相對 7b6348a）與 T（相對 S）補丁及 SHA-256 |
| `ci/workflow_from_7b6348a.diff` | 本分支 workflow（W2）相對起點的差異 |
