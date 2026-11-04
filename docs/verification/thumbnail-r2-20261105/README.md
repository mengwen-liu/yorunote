# 封面載入 r2：取消傳遞、排隊期間快取一致性、統計校正、合成網路來源（thumbnail-r2-20261105）

> 狀態：**候選，尚未合併**。主機整合測試、主機量測與 CI 靜態檢查；**尚未在 S25+／Tab S11 實機驗收**。時間以 Asia/Taipei 記錄。

## 1. 身分與提交

| 項目 | 值 |
|---|---|
| Repository | `mengwen-liu/yorunote`（ID 1421354314，GitHub API 回讀） |
| 起點 | `claude/yorunote-thumbnail-perf-20261105` @ `a37f5a9d65bc85590e32556c5d2806760e6b1e1c`（未改動；開始時的所有遠端分支 SHA 見 `refs/refs_start.txt`） |
| 本輪分支 | `claude/yorunote-thumbnail-r2-20261105` |
| B2（重現） | `fec7580f360e143468f9e7275387549cf4f00f15`：只加測試（原始 socket 伺服器＋取消／adapter／排隊快取測試），不含 App 修改 |
| **S2（App＋測試）** | **`cee5b03043152cf96a1f444e1d88be46a44b8c08`**，tree `be394dabeef2fdac47b64ad82e66b6cc7f59ff3d`；CI 與 APK 的建置來源 |
| W（workflow） | `767022107a80a2f64c2ff1104cbd018b4657bb16`：只改 `.github/workflows/phase1a-android-baseline.yml` |
| 證據提交 | 本目錄所在的後續提交（只含文件與證據） |

`pubspec.yaml`／`pubspec.lock` 未變（`flutter pub get --enforce-lockfile` exit 0，Git 無差異）；未改 applicationId、資料庫結構、資料位置或簽章方案。

### 修改檔案與理由（S2 相對起點）

| 檔案 | 理由 |
|---|---|
| `lib/foundation/image_provider/base_image_provider.dart` | 新增事件式停止訊號：`loadCancellable(chunkEvents, checkStop, stopped)`，預設直接呼叫 `load`，其他 provider（閱讀器、本機等）行為不變 |
| `lib/foundation/image_provider/cached_image.dart`、`history_image_provider.dart` | 覆寫 `loadCancellable`，把停止訊號傳給封面載入 |
| `lib/network/images.dart` | 共用載入：停止的消費者立即返回；所有消費者都停止時放棄該載入（移出可加入表、移出排隊、取消請求）；取得名額後的二次查詢保留，並把空資料／無法解碼視為未命中；測試用計時掛鉤（App 內為 null） |
| `lib/network/request_limiter.dart` | `acquire(cancelSignal:)`：排隊中被取消立即離隊 |
| `lib/network/app_dio.dart`（`RHttpAdapter`） | 有取消訊號時才建立 rhttp `CancelToken`，且只在 headers 到達後取消（§2.3）；取消後把 rhttp 串流排空到結束，讓 rhttp 的取消錯誤有接收者。沒有取消訊號的既有呼叫完全不變（`lib/` 內原本沒有任何呼叫者傳 CancelToken） |
| `test/…`、`tool/…` | 測試、合成來源與伺服器、量測與統計工具（§3–§6） |

## 2. 取消傳遞

路徑：ImageProvider → 共用封面載入 → RequestLimiter → AppDio → RHttpAdapter → rhttp 0.15.1（已讀取鎖定版本原始碼：`CancelToken`、`make_http_request_receive_stream` 的 `tokio::select!`；Dio 5.9.2 的 `cancelFuture` 與 `handleResponseStream`）。

### 2.1 重現與修正（真實 provider 路徑，原始 socket 伺服器，以 Completer／伺服器事件決定先後）

| 測試（`thumbnail_cover_cancel_test.dart`） | 起點 a37f5a9 | S2 |
|---|---|---|
| A 8 個請求卡在 headers 前被取消：之後送 headers，用戶端立即關閉連線，名額歸還，健康請求完成 | **失敗** | 通過 |
| B headers 已到、body 停在中途時取消：連線被關閉、名額歸還 | **失敗** | 通過 |
| C 排隊中取消、HTTP 500、成功：每個名額只歸還一次，最後 active=0、waiting=0 | 通過 | 通過 |
| D1 共用請求一個消費者取消，另一個仍成功，只有 1 次請求 | 通過 | 通過 |
| D2 共用請求所有消費者取消：連線被關閉 | **失敗** | 通過 |
| D3 全部取消後立刻有新消費者：不加入已放棄的請求，另發新請求並成功，舊連線被關閉 | **失敗** | 通過 |
| E 20 輪「取消後立刻放行 headers」：行程不 abort | 通過 | 通過 |

`rhttp_adapter_cancel_test.dart`（7 項）：起點 4 過、3 敗（body 中取消、headers 前取消、headers 到達瞬間取消）；S2 全過。前 4 項確認**沒有取消訊號、或有但未取消**時行為與原本相同（完整回應、截斷回應仍報錯）。

「底層請求確實結束」的證據：伺服器端偵測到用戶端主動關閉 socket（`HeldRequest.isClosedByClient`），而非只看 Dart 端 Future 結束或計數歸零。

### 2.2 發現：rhttp 0.15.1 在取消時可能使行程 abort

第一版實作在取消時立刻取消 rhttp，完整測試中舊佇列測試觸發：

```
thread '<unnamed>' panicked at .../flutter_rust_bridge-2.11.1/src/dart_fn/handler.rs:61:45
TestDeviceException(Shell subprocess crashed with SIGABRT (-6).)
```

（`logs/candidate/first_implementation_sigabrt_r1_queue_test.log`）。原因（讀原始碼確認）：rhttp 以 `panic = "abort"` 建置；取消時 `tokio::select!` 丟棄內部 future，若它正在等 Dart 回呼（`on_response`／`on_error`）的回覆，回覆送達時 frb 的 `completer.send(..).unwrap()` panic，整個行程 abort。這在 App 中就是閃退。

### 2.3 最終設計與受阻範圍

- headers 已到達（且再隔一個 event-loop turn，frb 的回覆已送出）後，Rust 端只剩 body 串流，取消安全：S2 在這時取消。
- **headers 尚未到達時無法安全地立即終止底層請求**。S2 讓該請求保持開啟並**繼續占用名額**，直到 headers 到達（立即關閉）或連線失敗；不以 `Future.any` 提早歸還名額而讓請求繼續跑。
- 迴歸保護：adapter 層 200 次「送出 headers 後立刻取消」測試，S2 全過；把 adapter 改回「立刻取消」的突變在 5 次執行中有 2 次 abort（機率性偵測，`logs/mutation/mutant_R1_race200_*.log`）。
- **阻礙（需決策）**：App 內 `RHttpAdapter` 對 headers 沒有逾時（rhttp `TimeoutSettings` 只設 `connectTimeout: 15s`），所以「已連線但永不回應 headers」的伺服器會讓該名額一直被占用，與起點相同。可選方向：(a) 升級或修補 rhttp／frb（依賴變更，本輪未授權）；(b) 對封面請求設定 rhttp 的總逾時 `TimeoutSettings.timeout`（走錯誤路徑、不會 abort，但會改變請求行為，需你決定時間值）；(c) 接受現狀。

## 3. 排隊期間的快取一致性與 F1

`thumbnail_cover_queue_cache_test.dart`（8 個名額全被卡住，目標封面排隊；等待期間由另一條實際路徑寫入同鍵）：

| 情境 | 起點 | S2 |
|---|---|---|
| E1 下載任務的 `loadThumbnail` 寫入好圖 → 取得名額後使用快取，不再請求（HTTP 1 → 1） | 通過 | 通過 |
| E2 等待期間寫入空資料 → 不可視為命中，改走網路並覆蓋 | **失敗** | 通過 |
| E2 等待期間寫入無法解碼的資料 → 同上 | **失敗** | 通過 |
| E3 不同 sourceKey／cid 的同 URL 快取 → 不被當成命中，也不被覆蓋 | 通過 | 通過 |

舊失效流程不刪除後來寫入的好圖：沿用前輪 `thumbnail_cover_invalidation_test.dart`，S2 仍通過。

**F1 評估**：二次查詢在 E1 中確實避免了多餘請求，予以保留。計時拆解（S2，冷載 32 張，7 次執行；`stats/timing_S2.json`）：

| 區段 | 各次中位數的中位數 [範圍] |
|---|---|
| resolve → 進入排隊 | 4.86 ms [4.03, 7.00] |
| 限制器內等待（enqueue → granted） | 134.22 ms [128.31, 154.94] |
| 取得名額 → 送出請求（含二次查詢） | **0.28 ms** [0.22, 0.34] |
| 送出請求 → 伺服器收到 | 20.60 ms [18.05, 22.32] |

二次查詢在主機上約 0.3 ms，前輪「二次查詢造成冷載退步」的歸因不成立（前輪單輪、7 取樣，雜訊大）。並行上限維持 8。

## 4. 統計校正

- 前輪 `_stats` 以 `sorted[round((n−1)p)]` 取值：n 為偶數時中位數取的是**上中位數**。本輪改為一般中位數（奇數取中間值；偶數取中間兩值平均），百分位數採線性內插（Hyndman–Fan type 7，NumPy／R 預設）。`tool/thumbnail_bench/bench_stats.{dart,py}` 有已知小型資料的檢查（`bench_stats_test.dart` 4 項；`bench_stats.py --self-test`）。
- 前輪的 `queue_wait_ms` 實際端點是「呼叫 `ImageProvider.resolve` → 伺服器收到請求」，包含快取查詢、排隊與連線時間；本輪稱為 `resolve_to_server_arrival_ms`。限制器純等待時間前輪沒有量，也不從舊資料推算；本輪只對 S2 另外記錄（§3）。
- 舊原始資料不動，重算結果在 `stats/r1_recomputed.json`（來源 SHA-256 與指令一併記錄）。例：前輪候選 S 的 `resolve_to_server_arrival_ms` 合併中位數 210.2 ms（舊規則）→ **181.5 ms**（一般中位數）；以每次執行為單位：177.9 ms [164.8, 199.5]（7 次）。這是定義差異，不是原始資料有誤。前輪報告中「排隊等待中位數 131 → 210 ms」應理解為「131 → 181 ms」。
- 獨立單位：一次 benchmark 程序執行（invocation）。同一次內的 7 次取樣與 32 張圖片不視為彼此獨立。

## 5. 主機量測：固定起點 vs 最終候選（交替執行）

條件：同一容器、同一 fixture（合成 160×240 PNG）、同一伺服器設定（固定延遲 40 ms）、並行上限都是 8、每次執行先暖機 1 次再取樣 7 次；起點與候選依 start, candidate, start, … 交替各 5 次。數值為「各次執行中位數」的中位數與範圍（`stats/alternating_summary.json`，原始檔 `stats/runs/`）。**主機數據，不能推論手機 FPS 或耗電。**

| 指標 | 起點 a37f5a9 | 候選 S2 |
|---|---|---|
| 冷載 32 張：HTTP 請求數／峰值並行 | 32／8 | 32／8 |
| 冷載：首張可顯示 | 97.7 ms [93.8, 105.0] | 106.3 ms [100.2, 109.6] |
| 冷載：全部完成 | 374.7 ms [367.4, 382.0] | **407.2 ms** [397.8, 433.3] |
| 冷載：resolve → 伺服器收到 | 157.2 ms [150.9, 163.1] | 170.8 ms [167.3, 181.6] |
| 冷載：單張完成 | 230.9 ms [225.4, 236.1] | 250.2 ms [249.3, 270.6] |
| 佇列滿時 16 張快取命中先顯示 | 16／16 | 16／16 |
| 快取命中完成 | 31.7 ms [30.2, 38.6] | 33.1 ms [30.6, 37.2] |
| 名額放行延遲 | 7.4 ms [7.2, 7.7] | 8.7 ms [8.2, 9.1] |
| 同 10 部漫畫歷史＋封面 HTTP | 10 | 10 |
| 壞／空快取重試後仍失敗 | 0 | 0 |

**取捨（退步）**：候選的冷載比起點慢約 30 ms／32 張（範圍不重疊）。歸因實驗（拋棄式副本，只拿掉傳給 Dio 的 CancelToken，各 3 次交替，`stats/experiment_summary.json`）：全部完成 384.3 ms [356.2, 396.4] vs 候選 413.1 ms [391.5, 427.9]；首張 97.0 vs 105.7 ms。推論：主要成本來自 rhttp 可取消請求在送出前多一次 Rust→Dart 回呼（`on_cancel_token`）往返，即「真正可取消」的代價。本輪未以犧牲取消能力換取數字。

## 6. 合成網路驗收來源

- 內容：`tool/synthetic_source/`（`serve.dart` 電腦端 CLI、`synthetic_server.dart` 伺服器、`yorunote_synthetic_source.js` 來源腳本）。40 部合成漫畫、每部 2 話各 5 頁、封面與閱讀頁由程式繪製；c37 封面以 XOR 編碼（只能經 `onThumbnailLoad` 的 `onResponse` 還原），c38 在清單中是 `cover.` 佔位（需經 `loadInfo` 取得真實封面）。
- 控制：延遲、暫停／放行、指定路徑回 HTTP 錯誤、壞圖、空回應、恢復、重設；計數：總請求、圖片請求、活躍數、峰值、每路徑次數（`/__stats`、狀態頁、CLI 終端摘要）。
- **QuickJS 實際執行**：依鎖定的 flutter_qjs `8feae95` 原始碼以上游 CMake 相同參數建置主機版 `libflutter_qjs_plugin.so`（本機 SHA-256 `5c2ac257…5a8d24`；本機模擬 CI 步驟重建結果相同；GitHub runner 以其編譯器建出 `74170776…42a3fd`，原始碼與參數相同但二進位不同）。`test/network/synthetic_source_test.dart`（8 項，S2 全過）：
  1. 以 `AppDio` 下載 `/source.js`，經 `ComicSourceParser.createAndParse`（與「添加漫畫源」相同）匯入，在 QuickJS 中執行探索、詳情、章節；
  2. 20 張封面經 `CachedImageProvider` 載入，峰值 ≤ 8，第二次全為快取命中；
  3. **`onResponse` 路徑**：c37 的 XOR 封面經 JS 還原後顯示，快取存的是還原後的 PNG；
  4. **`cover.` 路徑**：c38 經 `loadInfo` 解析後載入，`/api/comic/c38` 與封面各 1 次；
  5. 歷史＋封面同鍵只請求 1 次；6. 壞圖→錯誤→恢復後重試成功；7. 暫停時快取封面照常顯示；8. 閱讀頁經 `ReaderImageProvider` 載入。
- 過程中查到的既有限制（未修改）：來源腳本必須提供 `search` 物件，否則 parser 在 `search.onTagSuggestionSelected` 檢查時丟例外。
- 電腦端 CLI 驗證：`logs/candidate/serve_cli_probe.txt`（`/source.js` 帶入位址、封面、壞圖與 404 規則、計數）；`--host 0.0.0.0` 未給 `--public-url` 時拒絕啟動（exit 64）。
- 實機流程：[`ACCEPTANCE_SYNTHETIC.md`](ACCEPTANCE_SYNTHETIC.md)（adb reverse 與區網兩種方式、各情境預期畫面／伺服器計數／失敗判準、清理）。**雲端通過不代表三星實機已驗收。**

## 7. 驗證總表（本輪實際執行）

| 項目 | 結果 |
|---|---|
| `flutter pub get --enforce-lockfile` | exit 0，lockfile 不變 |
| 格式 | 新檔整檔 `dart format`；既有檔只檢查新增行，`images.dart` 201／`app_dio.dart` 76／`base_image_provider.dart` 22／兩個 provider 各 14 行，皆與格式化輸出一致 |
| 完整 `flutter test`（主機 librhttp＋QuickJS） | 起點 a37f5a9 自身：+315、exit 0；**S2：+343、0 跳過、exit 0**（`logs/candidate/final_full_test.log`） |
| 關鍵測試（CI 同一組） | +61、0 跳過 |
| `flutter analyze` | 起點與 S2 皆 8 項既有 info（`deprecated_member_use`），逐項相同，無 warning／error；exit 1（info 也回 1） |
| 突變驗證（`logs/mutation/`） | R1–R9：9 項有效突變全被抓到；R4 初版因編譯失敗屬無效突變，已改為「保留介面但永不送出停止訊號」後重跑並被抓到（B、D3 失敗）。另做 R1＋R6 合併（等同第一版立即取消）：A 失敗，兩次未重現 abort；abort 以 adapter 200 次競態測試機率性抓到（2／5） |
| 乾淨副本 | 重新從 GitHub clone、checkout `a37f5a9`、套用 `patches/R2_S2_FROM_a37f5a9.patch` 後 tree＝`be394da`，與遠端 S2 無差異 |
| 只過濾的例外 | 取消測試只忽略 BaseImageProvider 針對已取消載入回報的 `_ImageLoadingStopException`；其他錯誤照常使測試失敗 |

## 8. CI 與 APK

本輪手動觸發 **1 次**（授權上限 2 次）：[run 41899724426](https://github.com/mengwen-liu/yorunote/actions/runs/41899724426)，workflow 提交 `7670221`、建置來源 S2 `cee5b03`，結論 success。推送本分支前後以 API 確認沒有自動觸發任何 run（觸發條件只有 master push、PR、release、`workflow_run` of Build ALL、手動）。

| 步驟 | 結果（真實 Exit Code，`ci/run-41899724426/evidence/exit_codes.txt`） |
|---|---|
| `flutter pub get --enforce-lockfile` | 0 |
| 主機 librhttp（rhttp 0.15.1 Cargo.lock 核對）／主機 flutter_qjs（ref `8feae95` 核對） | 0／0 |
| 關鍵測試（expanded reporter，數量與跳過一併檢查） | 0，`+61: All tests passed!`，合成來源未跳過 |
| 完整測試 | 0，`+343: All tests passed!`，0 跳過 |
| analyzer | exit 1（info），診斷清單與已知 8 項逐項相同 |
| ARM64 Profile APK 建置 | 0 |
| 建置後 Git 完整性 | HEAD＝S2、工作樹乾淨 |

| APK | 值 |
|---|---|
| 檔名 | `Yorunote_cee5b03_thumbnail_r2_arm64_profile.apk` |
| 大小 | 27,881,187 位元組 |
| SHA-256 | `ad0d73c3b1ca5dd062086c32db8208ec11814ebe791bf890a38453a9252b475b`（下載 artifact 後本機重算一致；artifact zip `34c63b48…10976b` 與 GitHub 記錄一致） |
| Artifact | `yorunote-thumbnail-r2-arm64-profile-apk`（id 13357779497），登入 GitHub 後於 run 頁面下載；到期 2026-11-11 19:58:24 UTC（Asia/Taipei 2026-11-12 03:58:24） |
| manifest | applicationId `com.github.wgh136.venera`、versionName 1.6.3、versionCode 2163、名稱 `Yorunote` |
| ABI／原生庫 | 只有 `arm64-v8a`；含 `libflutter.so`、`libapp.so`、`librhttp.so`、`libqjs.so` 等 10 個；`libapp.so` 內可找到 `loadCancellable`、`coverRequestLimiter` 字串，測試掛鉤名稱 `debugCoverLoadEvent` 不在其中 |
| ZIP／zipalign | 完整（CI 與本機 `unzip -t`）；4 位元組對齊通過；16 KB 對齊 yes（僅參考） |
| 圖示／About 資產 | 20 張圖示與儲存庫像素相同；adaptive XML 三層齊全；`app_icon.png` SHA-256 `4f40bc60…` 與儲存庫一致 |
| 簽章 | apksigner Verifies（v2），1 位簽署者，CN=`Yorunote CI Disposable`，憑證 SHA-256 `96ee97a721f3f935984c68d12533e0d189e74c9eff113768bc8b82f6782004f7`，與 job 內金鑰相符 |

**一次性測試簽章**：與先前所有 APK（含前輪 `f300eecd…`，憑證 `a8144ca3…`）都不同，不能覆蓋安裝；不要求卸載或清除資料。以上為靜態檢查，**不代表已在 Android 啟動或驗收**。apksigner 只在 CI 執行（本容器未安裝 Android build-tools）。

## 9. 沿用前輪的歷史證據（本輪未重跑）

- 前輪 S `418efac` 的 CI run 41883419245 建置 S（+313），不涵蓋前輪 T 的 315 項；前輪 APK `f300eecd…` 使用另一把一次性金鑰。
- 前輪報告中的冷載退步歸因（二次查詢）已由本輪 §3 計時拆解推翻；前輪「排隊等待中位數」數值的定義問題見 §4。前輪報告與資料保持原樣，未修改。

## 10. 仍待 S25+／Tab S11 實測

- §6 合成來源的匯入（含 `http://` 在裝置上是否可用）、各情境的畫面與伺服器計數。
- 取消在實機上的觸發時機（ImageCache 逐出）與實際體感；本輪只以主機整合測試驗證。
- 任何 FPS、捲動流暢度或耗電影響。

## 11. 回復方式

起點分支 `claude/yorunote-thumbnail-perf-20261105` 未改動，可直接使用。撤回本輪：在本分支依序 `git revert` 證據提交、`7670221`、`cee5b03`、`fec7580`，或不採用本分支。不自動回復、不刪除任何遠端分支。

## 12. 其他

- 本工作階段無法讀取雲端點數餘額，未設定精確美元上限；未啟用付費或加值。
- 不含 APK、ZIP、快取、金鑰或本機設定；提交前以 CI 同款規則掃描秘密與私人資訊。
- 檔案雜湊清單：[`EVIDENCE_SHA256SUMS.txt`](EVIDENCE_SHA256SUMS.txt)。
