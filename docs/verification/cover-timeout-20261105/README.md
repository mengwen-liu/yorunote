# 封面請求逾時保護（cover-timeout-20261105）

> 狀態：**候選，尚未合併**。主機整合測試、主機 rhttp／QuickJS 完整測試與 CI 靜態檢查；**未在 S25+／Tab S11 實機驗收**。

## 1. 身分與提交

| 項目 | 值 |
|---|---|
| Repository | `mengwen-liu/yorunote`（ID 1421354314） |
| 起點 | `claude/yorunote-thumbnail-r2-20261105` @ `6e85d6b00c7a694c337d437e2d939fe81ceb49e7`（未改動；所有遠端分支前後 SHA 見 `refs/`） |
| 本輪分支 | `claude/yorunote-cover-timeout-20261105` |
| B（只加測試） | `8feaa7a449adedc8c168d37a9eea920b013b58d0`：新增 `thumbnail_cover_timeout_test.dart`，輔助函式為 no-op；用來在起點重現 |
| **S（App＋測試，最終 App SHA）** | **`29b590b457378c16b19821f139b9bcad7d38f689`**，tree `603f9aae…`；CI 與 APK 的建置來源 |
| W（workflow） | `356be4942360501fcc9eab36e45577b34912f525`：只改 `.github/workflows/phase1a-android-baseline.yml`（分支、SHA、blob、測試數與名稱，見 `workflow_changes_vs_start.diff`） |
| 證據 Commit | 本目錄所在的後續提交（只含文件與證據） |

`pubspec.yaml`／`pubspec.lock` 與起點無差異（`flutter pub get --enforce-lockfile` Exit 0）；未改依賴、applicationId、資料位置、簽章方案。App 差異僅 `lib/network/app_dio.dart`、`lib/network/images.dart`（`app_changes_vs_start.diff`）。

## 2. 行為定義與 30 秒的實際涵蓋範圍

實作：`loadCoverThumbnail` 建立的 Dio 請求在 `RequestOptions.extra['rhttpTotalTimeout']` 帶 `Duration(seconds: 30)`；`RHttpAdapter.fetch` 只在該鍵存在且為正的 Duration 時，把它放進 rhttp `TimeoutSettings.timeout`。沒有該鍵的請求（閱讀器、下載、其他來源 API、`loadThumbnail`、資料同步）行為不變；共用的 `settings` getter 沒有加入全域逾時。

已核對鎖定版本原始碼：rhttp 0.15.1 `client.rs` 把 `timeout` 傳給 `reqwest::ClientBuilder::timeout`；reqwest 0.12.25（`.crate` SHA-256 `b6eff932…701a` 與 rhttp `Cargo.lock` 相符）在 `client.rs` 的 `Pending` 設定 `total_timeout`，並在 `body.rs` 以 `TotalTimeoutBody` 包住回應本體。因此：

| 階段 | 是否在這 30 秒內 |
|---|---|
| DNS、連線、TLS、重新導向、送出請求、等待 headers | 是（headers 前逾時：`execute` 回 timeout → rhttp `RhttpTimeoutError` → Dart `RhttpTimeoutException`；由 Rust 自己結束請求，不經取消／丟棄 future，不走先前 flutter_rust_bridge panic 的路徑） |
| headers 之後讀取 body | 是（逾時時 body 串流以錯誤結束，連線關閉） |
| 排隊等名額、來源 `getThumbnailLoadingConfig`、`cover.` 額外資料查詢（`loadComicInfo`，JS 來源自己的網路）、寫入快取、解碼 | **否** |
| 影像供應器的重試（失敗後 2 s、4 s、8 s 等待，共 4 次嘗試） | **否**；每次嘗試各有自己的 30 秒 |

`cover.` 額外資料查詢本身不受此限制；查到真正封面網址後，遞迴的封面請求才受 30 秒限制。副作用（需知道）：總逾時涵蓋整個 body，超過 30 秒才下載完的慢速大圖會失敗並重試。

**既有重試造成的最壞等待**：一直沒有 headers 時，4 次嘗試 × 30 秒 ＋ 2＋4＋8 秒等待 ≈ **134 秒**（不含排隊）。以 300 ms 逾時的實測：`F: attempts=4 elapsed=0:00:15.23`（4×0.3 s ＋ 14 s）。404／403 與含 "handshake" 的錯誤沿用原本的重試規則。

不使用 `Future.timeout` 提早返回，也沒有恢復「headers 前立即取消」。

## 3. 驗證（`test/network/thumbnail_cover_timeout_test.dart`，7 項，真實 provider／limiter／AppDio／rhttp 路徑，原始 socket 伺服器）

| 測試 | 起點（B 8feaa7a） | 候選（S 29b590b） |
|---|---|---|
| A 8 個已連線但不送 headers 的請求（第 9 個排隊）：連線被客戶端關閉、名額歸還、健康請求完成 | **失敗**（仍開著） | 通過 |
| B headers 已到、body 停滯：逾時、關閉、名額歸還、**沒有快取**，伺服器恢復後同一網址重試成功並寫入快取 | **失敗** | 通過 |
| C headers 在期限前後 −60…+120 ms 到達（8 種偏移）：都結束、無 panic、名額歸還且無排隊殘留 | **失敗** | 通過（機率性探測，不是無競態證明） |
| D 取消與逾時交錯（headers 前／body 中 × 5 種偏移）：無 SIGABRT／未處理例外、連線結束、名額歸還 | **失敗** | 通過（機率性探測） |
| E 正常請求、同鍵共用（1 次請求）、快取命中（無請求）、非封面 `AppDio` 請求在 4 倍短逾時後仍開著並可完成 | 通過 | 通過 |
| F 影像供應器重試：4 次嘗試、14 s 以上等待、全部被逾時結束 | **失敗**（60 s 內無結果） | 通過 |
| G 正式 30 秒設定：`coverRequestTimeout == 30 s`，靜默請求在到達後 **30000 ms**（日誌 `G: ended 30000 ms`）被關閉 | **失敗** | 通過 |

結果：起點 +1 −6；候選 +7 −0（`logs/start/…`、`logs/candidate/timeout_tests_S.log`）。「底層連線結束」的證據是伺服器端偵測到客戶端關閉 socket，名額歸還以 `RequestLimiter.active == 0 && waiting == 0` 判定（每個名額只歸還一次，沿用既有釋放函式）。

候選最終程式碼：
- 完整 `flutter test`（主機 librhttp＋QuickJS，**0 跳過**）：**+350，exit 0**（`logs/candidate/full_test_S.log`）；CI 同為 +350（key 68 項、完整 350 項）。
- `flutter analyze --no-pub`：exit 1，**8 項 info，與起點逐項相同**（`logs/candidate/analyze_diff` 與 CI `analyze_diff.txt`），0 warning、0 error。
- 格式：`images.dart`、`app_dio.dart` 在起點即未通過 `dart format`（未整檔重排）；本輪新增的行與新測試檔符合格式。
- 起點、候選的主機 `librhttp.so` 由鎖定 rhttp 0.15.1 原始碼本機建置（`Cargo.lock` SHA-256 `232c3f91…`），CI 另在 runner 重建。

## 4. CI 與 APK（run 41968314599）

- Run：https://github.com/mengwen-liu/yorunote/actions/runs/41968314599（`workflow_dispatch`，只執行一次，未 rerun，結論 success）。head_sha 即 W `356be49`，App 來源固定 checkout S `29b590b`；`git_integrity_ok=1`。
- Artifact（公開儲存庫，保留 7 天，**2026-11-12 04:47 UTC 到期**）：`yorunote-cover-timeout-arm64-profile-apk`（id 13389067967）、`yorunote-cover-timeout-diagnostic-logs`（id 13389362341）。不含金鑰或個人資料；APK 不在 Git 中。
- APK `Yorunote_29b590b_cover_timeout_arm64_profile.apk`：27,882,063 位元組，SHA-256 `7ad08033c204a1de62546ca588ea0c050a5ace8ec0d4945d8c7978e156f5057f`（下載後本機重算一致）。
- 靜態檢查：套件 `com.github.wgh136.venera`、1.6.3（2163）、label `Yorunote`、自適應圖示 20 張像素逐一相同、About 資產雜湊一致、僅 `arm64-v8a`（含 libflutter／libapp／librhttp 等）、ZIP／zipalign 通過、apksigner 通過；`libapp.so` 內可找到 `rhttpTotalTimeout` 字串。
- **簽章**：一次性測試金鑰，憑證 SHA-256 `de02360d542d99c807a97c1265f20ce387f98020ea4146ba47b70be71374e26f`；與先前各輪的測試憑證**都不同**，**不能直接覆蓋**簽章不同的既有安裝；本輪不要求卸載或清除資料。

## 5. 尚未驗證

- 未在 S25+／Tab S11 實機驗收；未量測實機上慢速網路、大圖是否被 30 秒誤傷。
- C、D 為機率性順序探測；未做突變或大規模壓力測試。
- 其他呼叫路徑（閱讀器、下載等）刻意不加逾時，其卡住風險維持原狀。

## 6. 回復

```bash
git revert --no-edit 29b590b   # 取消逾時與測試（workflow 的 W 356be49 可一併 revert）
```
或不合併此分支。
