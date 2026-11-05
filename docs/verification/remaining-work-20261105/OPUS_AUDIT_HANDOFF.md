# Yorunote 剩餘事項限時複核：工程交接報告

> 類型：**限時靜態複核**（約 2026-11-05 15:48–15:50 Asia/Taipei 查核，之後撰寫）。
> 本輪**沒有**修改程式、沒有執行測試、沒有建置 APK、沒有觸發 Actions、沒有實機操作。
> 文中「確認」只代表以 `git show`／`git grep`／GitHub API 讀到的內容；不代表執行驗收。

## 0. 來源與實際 SHA（開始時回讀）

| 代號 | 用途 | 預期 | 實際回讀 | 變動 |
|---|---|---|---|---|
| A | APK 的 App 原始碼 | `29b590b457378c16b19821f139b9bcad7d38f689` | 物件存在（commit） | 無 |
| B | 最新驗證報告 | `f003a708ca99a5c45f140ee554b4500ab5be8d49` | 物件存在（commit） | 無 |
| C | 發行文件分支 `claude/yorunote-preview-release-371ybm` | `71611f7f3aa52cb8e2b249f96a5ec4543e616bef` | `71611f7f3aa52cb8e2b249f96a5ec4543e616bef` | 無 |
| D | `master` | `9a709d27c69482a1e21cafa6ad90d2639248f328` | `9a709d27c69482a1e21cafa6ad90d2639248f328` | 無 |

- A **不是** master 的祖先；`git rev-list --count origin/master..A` = **23**；`git diff --stat master A -- lib` 為 15 個檔案、+2348/−659。
- master 與 C 的 App 程式都**不是**已建出 APK 的程式；APK 只對應 A。

---

## 1. 一頁摘要

**目前可確認（讀取證據）**
- Release 434819274：`draft=true`、`prerelease=true`、`tag_name=v0.1.0-preview.1`（GitHub MCP `list_releases` 回讀）。
- Tag `v0.1.0-preview.1`：`git ls-remote origin 'refs/tags/v0.1.0-preview.1*'` 無輸出 → **遠端不存在**。
- 附件來源：C 的 `docs/verification/preview-release-20261105/README.md` 記錄附件 APK 712333248（27,882,063 bytes）與 `.sha256` 712333328，來自 prepare run 41980565581；B 的 `cover-timeout-20261105/README.md` §4 記錄 run 41968314599 從 A 建出相同大小的 APK（SHA-256 `7ad08033…57f`）。**本輪未重新下載附件重算雜湊**，「附件仍是 A」為文件一致性推論，非本輪驗證。
- 封面共用請求、取消、逾時與壞快取失效的程式與專屬測試都存在於 A（見 §3）。壞快取失效以「位元組相等＋`onlyIfStoredIn: file`」保護，未發現誤刪較新資料的路徑。
- 350 項測試：B 的 cover-timeout README L53 記錄主機完整 `flutter test` +350（`logs/candidate/full_test_S.log`），CI run 41968314599 同為 +350，對應來源 A。

**還卡什麼**
1. 發布：Tag 未建、Release 仍為草稿；手動發布前必須處理 Build ALL 連動（C 文件 L54）；專用 workflow `publish` 路徑（GITHUB_TOKEN）對 Update a release 的權限**未驗證**。
2. 簽章：A 的 APK 用一次性測試憑證（`de02360d…e26f`），與先前各輪都不同；無固定簽章 → 無法覆蓋安裝、無長期更新路徑。
3. 實機：S25+／Tab S11 皆未驗收（B 兩份 README 明載）。

**建議先處理哪件事**
→ 先由使用者決定**固定簽章策略**，再談發布。原因：任何現在發出的預覽版都會綁死一把一次性金鑰，之後正式版無法覆蓋更新；這個決定成本最低、影響最大，且不需要寫程式。若使用者只想先把現有草稿發出去，則依 C 的手動步驟執行（需使用者本人操作，見 §4）。

---

## 2. 問題表

| 優先 | 問題 | 判定類型 | 來源 SHA／位置 | 影響 | 最小修正 | 需要的驗證 |
|---|---|---|---|---|---|---|
| P1 | 預覽版未發布：Tag 不存在、Release 草稿；Build ALL 會連動 AltStore；`publish` 路徑權限未驗證 | 發布阻礙 | C `71611f7…`：`docs/verification/preview-release-20261105/README.md` L3、L16–24、L32–54；`docs/releases/PREVIEW_RELEASE_PROCESS.md` | 使用者無法取得預覽版；網頁直接 Publish 可能誤觸 Build ALL | 維護者依 README L32–51 手動：停用 Build ALL → 更新本文 → 建 Tag 指向 A → Publish → 恢復 Build ALL | 回讀 Tag SHA = A、Release `draft=false`、附件 ID/大小不變、Build ALL 狀態回到 active、確認沒有新 Build ALL run |
| P2 | 一次性簽章，無固定金鑰 | 發布阻礙（產品決策） | B `f003a70…`：`docs/verification/cover-timeout-20261105/README.md` L64；C：`docs/releases/v0.1.0-preview.1.md` L50 | 使用者需卸載才能裝（會遺失資料），之後版本也無法覆蓋本版 | 決定：(a) 本版明示為「一次性測試版」維持現狀；或 (b) 建立固定 release keystore（存 GitHub Secrets），重新簽 A 的 APK 再發 | `apksigner verify --print-certs` 憑證 SHA-256 與既定金鑰一致；同金鑰兩版可覆蓋安裝（需實機） |
| P3 | 封面請求在**收到 headers 前**被全部消費者放棄後，仍佔用 limiter 名額直到 headers 抵達或 30 秒逾時；同時該 load 已從 `_coverLoads` 移除，同鍵新消費者會再開第二個請求 | 疑似風險＋測試缺口（**未重現**） | A `29b590b…`：`lib/network/images.dart` `_CoverLoad._abandonIfUnused`（約 L614–622，`if (headersReceived) cancelToken.cancel()`）、`_loadCover`（L203–229）、`_fetchCover` 取得名額 L309、headers 後檢查 L346–351；`_CoverLoad.cancelToken` 註解 L580–583 說明為刻意設計 | 快速來回捲動時，慢伺服器上可能短暫出現同鍵重複請求並擠占 8 個名額，新封面排隊變長；名額**不會**漏還（`finally { release(); }` L381–383） | 先補測試；若成立，最小修正方向：放棄但尚未有 headers 的 load 暫不從 `_coverLoads` 移除，允許新消費者「復活」接回（需重設 `_abandoned`，牽動 limiter `cancelSignal`，改動須謹慎） | 新測試：fake server 延遲 headers；消費者 1 取消 → 消費者 2 同鍵加入 → 斷言 server 收到請求數與 `coverRequestLimiter.active` 峰值。對照 `test/network/thumbnail_cover_cancel_test.dart` L101 的測試 A 是否已涵蓋（本輪只讀到測試名稱，未讀內容） |
| P4 | 30 秒總逾時的底層語意只由程式註解宣稱，本輪未讀 rhttp 0.15.1 原始碼 | 證據缺口（待查） | A：`lib/network/app_dio.dart` L177–205（`RHttpAdapter.totalTimeoutKey`、`_buildSettings` → `rhttp.TimeoutSettings(timeout: …)`）；測試 `test/network/thumbnail_cover_timeout_test.dart`（7 個 testWidgets，L123–348） | 若 reqwest timeout 不涵蓋 body 讀取，慢速 body 可能不受 30 秒限制；反之大圖會被誤傷（B README L32 已提） | 無需改碼；補證據 | 讀鎖定的 rhttp 0.15.1（`pubspec.lock` 版本＋`Cargo.lock` reqwest 版本）中 `TimeoutSettings.timeout` 如何映射到 reqwest `ClientBuilder::timeout`；本機 `~/.pub-cache` 無 rhttp，需 `flutter pub get` 或從 pub.dev 取原始碼 |
| P5 | 發行本文「首頁候選」未區分已接入與未接入的元件 | 文件完成度不一致（疑似） | A：`lib/components/home_widgets.dart` 中 `RecentComicCard`（L432）、`RecentComicCardData`（L45）、`ReadingProgress`（L16）在 `lib/` 其他檔案**無引用**（`git grep` 靜態結果）；`HomeCoverCard`、`HomeSearchEntry`、`HomeSectionHeading` 各有 1 個外部引用。C：`docs/releases/v0.1.0-preview.1.md` L14 | 使用者可能以為「最近閱讀卡片／閱讀進度」已上線 | 發行本文改寫為「已接入：搜尋入口、區塊標題、封面卡；已建立未接入：最近閱讀卡片、進度」 | 以 `git grep -n 'RecentComicCard\b' 29b590b -- lib` 再確認；實機開首頁截圖比對 |

未列為問題（已檢查，程式／測試已涵蓋）：
- **名額漏還／重複歸還**：`RequestLimiter.acquire` 回傳 releaser，`_fetchCover` 在 `try … finally { release(); }` 中只呼叫一次（A `images.dart` L309–383）。是否有 releaser 冪等保護未讀（`request_limiter.dart` `_releaser`），但呼叫端只有一處。
- **取消後未處理例外**：`_CoverConsumer.wait` 以 `Future.any` 同時監聽 load 與 stop 訊號，load 的後續錯誤被 `Future.any` 吸收（A L670–679）。邏輯推論，未執行。
- **壞快取誤刪較新資料**：`invalidateCoverCache`（A L183–200）先比對位元組、再以 `onlyIfStoredIn: file` 刪除；`test/network/thumbnail_cover_invalidation_test.dart` L33／L59／L77 分別涵蓋「刪來源條目」「讀後已修復則保留」「非快取位元組不刪」。本機封面（local comics）路徑本輪未查。

---

## 3. 驗證與實機缺口

| 項目 | 現況 | 需要 |
|---|---|---|
| 350 項測試 | 來源 A；主機（本機建 librhttp＋QuickJS，0 跳過）＋CI run 41968314599（B cover-timeout README L53、L60） | 無；勿把它套用到 master 或 C |
| APK 靜態檢查 | 套件 `com.github.wgh136.venera`、1.6.3（2163）、20 張圖示逐像素相同、apksigner 通過（B README L63） | 已足夠作靜態證據 |
| 實機 | S25+／Tab S11 未驗收；慢速網路、大圖 30 秒誤傷未量測（B README L68） | 實機安裝（需先卸載不同簽章版本或用新套件名）＋合成來源 |
| 合成來源驗收 | `tool/synthetic_source/` 存在、主機 QuickJS 8 項通過（B thumbnail-r2 README L120–128） | 缺**實機上**連到電腦端 `serve.dart` 的執行紀錄（同網段、手機可達的 host/port、限速設定）；本輪未逐項核對前置條件清單 |
| 冷載約 9% 退步 | **本輪未核對**。B thumbnail-r2 README L95 已更正舊 `queue_wait_ms` 定義為 `resolve_to_server_arrival_ms`；L101 指出為主機數據、不可推論手機 | 下一輪引用前，以 B `thumbnail-r2-20261105/stats/alternating_summary.json` 為準，確認 9% 出自哪個指標與定義 |
| 交錯順序測試 | B cover-timeout README L69：C、D 為機率性順序探測，未做突變或壓力測試 | 視 P3 結果決定是否加確定性排程測試 |

---

## 4. 給 GPT-6.1 Sol／Codex 的交接

### 4.1 取得來源

```bash
git fetch origin 29b590b457378c16b19821f139b9bcad7d38f689 f003a708ca99a5c45f140ee554b4500ab5be8d49
git fetch origin claude/yorunote-preview-release-371ybm master
git worktree add ../yn-app 29b590b457378c16b19821f139b9bcad7d38f689
```

- App（APK 來源）：`29b590b457378c16b19821f139b9bcad7d38f689`
- 驗證證據：`f003a708ca99a5c45f140ee554b4500ab5be8d49:docs/verification/{cover-timeout,thumbnail-r2}-20261105/`
- 發行文件：`claude/yorunote-preview-release-371ybm` @ `71611f7f3aa52cb8e2b249f96a5ec4543e616bef`
- master：`9a709d27c69482a1e21cafa6ad90d2639248f328`

### 4.2 建議先做的單一工作單元

**P3 的確定性測試（只加測試，不改產品碼）**，在 A 之上開新分支：
1. 讀 `test/network/thumbnail_cover_cancel_test.dart` 全部 7 個測試（L101、152、192、251、286、321、373）與 `test/network/thumbnail_test_support.dart`，確認是否已有「headers 前放棄 → 同鍵重新加入」情境。
2. 若沒有，新增一個測試：延遲 headers 的 fake server；消費者 1 取消；消費者 2 同鍵加入；斷言
   - server 實際收到的請求數（1 或 2），
   - `coverRequestLimiter.active` 峰值與最終歸零，
   - 兩個 future 的結果（消費者 1 `RequestCancelledException`，消費者 2 取得位元組）。
3. 只跑 `flutter test test/network/thumbnail_cover_cancel_test.dart test/network/request_limiter_test.dart`。
4. 驗收：測試結果寫成「現況行為紀錄」；若出現 2 個請求，再由使用者決定是否接受（目前設計註解 L580–583 表示為刻意取捨）。

### 4.3 可直接調查的檔案與符號（A）
- `lib/network/images.dart`：`ImageDownloader._loadCover`、`_forgetCoverLoad`、`_fetchCover`、`invalidateCoverCache`、`_coverCacheKeys`（`Expando<String>`，L133）、`_CoverLoad`、`_CoverConsumer`
- `lib/network/request_limiter.dart`：`RequestLimiter.acquire`、`_releaser`、`RequestCancelledException`
- `lib/network/app_dio.dart`：`RHttpAdapter.totalTimeoutKey`、`_buildSettings`
- `lib/foundation/image_provider/{base_image_provider,cached_image,history_image_provider}.dart`（本輪未讀）
- `lib/components/home_widgets.dart`：`RecentComicCard`、`ReadingProgress`

### 4.4 需要使用者另行授權
- 建 Tag、更新／發布 Release 434819274、停用／恢復 Build ALL（依 C 文件 L32–51，需已登入的網頁或有效 `gh`；本環境 `gh` Token 無效、GitHub MCP 無 workflow 停用功能，兩者為不同層面的限制）。
- 建立或使用固定簽章金鑰、寫入 Secrets。
- 合併任何候選分支到 master；觸發 CI；實機安裝與量測。

### 4.5 本輪未檢查或無法判定
- rhttp 0.15.1／flutter_rust_bridge 原始碼（本機無 pub cache）→ P4 待查。
- 附件位元組是否與 run 41968314599 的 APK 相同（未下載重算）。
- `BaseImageProvider`／`CachedImageProvider`／`HistoryImageProvider` 的取消接線；本機封面路徑。
- 專用 workflow `publish` job 的 `permissions:` 實際內容（只讀到文件「未驗證」的說法）。
- 冷載 9% 數字的出處與定義。
- 點數餘額：本環境無法讀取，未查。

### 4.6 本輪寫入
只新增本檔案於分支 `claude/yorunote-opus-audit-20261105`（起點 C `71611f7…`），提交訊息含 `[skip ci]`。
