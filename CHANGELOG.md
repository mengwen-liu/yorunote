# 開發與版本紀錄 / Development and release history

[繁體中文首頁](README.md) · [English](README.en.md) · [GitHub Releases](https://github.com/mengwen-liu/yorunote/releases)

本檔分開記錄已發布的預覽版、文件更新與歷史開發里程碑。App 修改是否已發布、是否已合併至 master，以及是否完成實機驗收，分別記錄。
This file distinguishes public previews, documentation updates, and development milestones. Publication, integration into master, and device acceptance are separate states.

## v0.1.0-windows-preview.3 — 2026-11-07

- **已公開的 Windows 標題列修正版**：[發行頁](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-windows-preview.3) · [雙語說明](docs/releases/v0.1.0-windows-preview.3.md)。Release ID 436759456，2026-11-07 00:59:20（Asia/Taipei）公開。
  **Public Windows caption fix**; release ID 436759456, published at 2026-11-07 00:59:20 Asia/Taipei.
- Tag 固定來源 `07406c9f6a6d105fd854cb3ddc22cfcc6dacfd9b`。修正 `No Overlay widget found.`，保留原精靈 GIF、提示、視窗操作與資料目錄。
  Pins the caption Overlay fix while retaining the original GIF, tooltip, controls and data directory.
- 使用者已[確認精靈動畫與滑鼠提示正常](https://github.com/mengwen-liu/yorunote/blob/2d0d5375f5e4f53f96f3558ad10278a7762c8797/docs/verification/windows-overlay-fix-20261106/OWNER_ACCEPTANCE.md)，分類為 **OWNER_REPORTED**，只涵蓋這兩項 UI 行為。
  The user confirmed animation and tooltip behavior only; this does not establish full device acceptance.
- 沿用 [CI 42229100772](https://github.com/mengwen-liu/yorunote/actions/runs/42229100772) 原成品：13 項指定測試、首次程序 11 項與重啟 4 項指定檢查通過；本次發行沒有重新建置或重跑完整測試。
  Reuses the existing verified ZIP without rebuilding or rerunning the full suite.
- ZIP 為 22,015,039 bytes，SHA-256 `cf7d5a616af30867349bb9136a491188d7a28a12e0d4778f9a2a1c74e6257ed3`。[公開下載核對](https://github.com/mengwen-liu/yorunote/blob/3490fed98e698c2aa87eb9956d0d3da4a45679db/docs/verification/windows-overlay-fix-20261106/PUBLIC_RELEASE_3.md)確認附件、檔案清單、GIF 及 Tag 一致；Build ALL 恢復 active，Build ALL／AltStore 皆無新增執行。
  Public downloads, manifest, GIF and tag were verified, with Build ALL restored and no linked runs.
- 同步中英文首頁與本發行說明，未把 App 程式合併至 master；既有 Release 附件保留。仍未經 Authenticode 簽章，完整裝置驗收與主線整合另行處理。
  Documentation sync does not merge application code into master or replace earlier assets; this remains an unsigned preview.

## v0.1.0-windows-preview.2 — 2026-11-06

- **已公開的 Windows 精靈動畫預覽版**：[發行頁](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-windows-preview.2) · [雙語說明](docs/releases/v0.1.0-windows-preview.2.md)。Release ID 436440069，2026-11-06 19:58:41（Asia/Taipei）公開。
  **Public Windows animated-title preview**; release ID 436440069, published at 2026-11-06 19:58:41 Asia/Taipei.
- Tag 固定 App 來源 `6df02c0fda1978319355a51fc2c75f7d66ea6d7f`。左上角改為既有 28×28 精靈動畫，失焦或減少動畫時使用靜態圖；保留原資料目錄及視窗操作。
  The tag pins the animated title mark; inactive/reduced-motion states use the static icon, retaining the existing data directory and window controls.
- 沿用 [Windows CI 42202302352](https://github.com/mengwen-liu/yorunote/actions/runs/42202302352) 的 ZIP：22,013,335 bytes，10 項品牌／回歸測試與首次程序 10 項、重啟 3 項指定檢查通過。[下載後驗證 42204532603](https://github.com/mengwen-liu/yorunote/actions/runs/42204532603)核對產品、GIF 及檔案清單。本次發布沒有重新建置或重跑完整測試。
  Reuses the verified ZIP: 10 focused tests and 10 initial/3 restart checks passed. Separate download verification covered the package, GIF and manifest. Publication did not rebuild or rerun the full test suite.
- 發行時暫停 Build ALL，公開後恢復原狀態；公開下載與是否連動的核對見[發布紀錄](https://github.com/mengwen-liu/yorunote/blob/05228479a11a93c17b0812ebe03f7ea1ed5d6112/docs/verification/windows-mascot-20261106/PUBLIC_RELEASE_2.md)。既有 Windows .1 與 Android Release 保留，App 程式未合併至 master。
  Build ALL was paused and restored for publication. The publication record documents public download and linked-workflow checks; existing releases remain available and application code is not merged into master.
- 本版仍為未經 Authenticode 簽章的預覽版，使用者電腦驗收待補；先前對 Windows .1 的回報不套用到新版。
  This unsigned preview still needs user-device acceptance; the earlier report for .1 does not validate this new build.

## v0.1.0-windows-preview.1 — 2026-11-06

- **已公開的 Windows x64 預覽版**：[發行頁面](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-windows-preview.1) · [雙語說明](docs/releases/v0.1.0-windows-preview.1.md)。Release ID 436235827，2026-11-06 16:02:29（Asia/Taipei）公開。
  **Public Windows x64 preview**; release ID 436235827, published at 2026-11-06 16:02:29 Asia/Taipei.
- Tag 精確指向 `71485c7de8799e30c9e1b5797ad83fba65668d51`，ZIP 為 Release 模式、21,528,589 bytes；[Windows CI](https://github.com/mengwen-liu/yorunote/actions/runs/42091194413) 與[另行下載核對](https://github.com/mengwen-liu/yorunote/actions/runs/42183056556)通過。
  The tag pins the exact Release-mode ZIP source; build, native runtime checks and separate artifact verification passed.
- 導入 Windows 品牌、七尺寸圖示、ZIP 與雙語使用說明；修正新資料目錄閱讀空值與圖片載入狀態重設問題。7 項指定測試通過，未重跑歷史 350 項測試。
  Added Windows branding, seven icon sizes, ZIP packaging and bilingual instructions; fixed fresh-profile and loaded-image state regressions. Seven focused tests passed; the historical full suite was not rerun.
- 採維護者網頁發布，Build ALL 暫停後恢復；App、workflow 與完整證據保存在 Windows 分支，這次首頁同步不把 App 程式碼合併至 master。
  Published through the maintainer interface with Build ALL paused and restored. Windows code/workflows/evidence remain on their branch; the homepage update does not merge application code into master.
- 尚無 Authenticode 簽章及使用者電腦驗收；WebView2、全部第三方來源、DPI、多螢幕與 Windows ARM64 仍有驗證限制。
  No Authenticode signing or user-device validation; embedded web login, all real sources, DPI, multiple monitors and ARM64 remain outside full coverage.

## v0.1.0-preview.1 — 2026-11-05

- **已公開的 Android 預覽版**：[發行頁面](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-preview.1) · [儲存庫內雙語發行說明](docs/releases/v0.1.0-preview.1.md)。公開時間為 2026-11-05 20:57:32（Asia/Taipei），Release ID 434819274。
  **Public Android preview**: see the release page and bilingual notes above. Published at 2026-11-05 20:57:32 Asia/Taipei; release ID 434819274.
- Tag `v0.1.0-preview.1` 指向 App 來源 `29b590b457378c16b19821f139b9bcad7d38f689`；APK 內部版本維持 1.6.3（versionCode 2163）。`master` 尚未整合此 App 來源。
  The tag pins the application source at that commit; the APK remains version 1.6.3 (2163). That application code is not yet integrated into master.
- 沿用原始 ARM64 Profile APK 與 `.sha256` 附件，未重新建置；本版包含品牌、部分首頁呈現、閱讀器快取修正，以及封面佇列、取消與 30 秒逾時保護。
  The original ARM64 Profile APK and checksum were retained without rebuilding. Included work covers branding, selected home-screen presentation, reader-cache fixes, and cover queueing, cancellation, and 30-second timeout protection.
- 實際採用維護者網頁發布：暫停 Build ALL、從固定來源建立 Tag 並公開既有草稿、核對後恢復啟用。發布前後 Actions 均為 7 筆，沒有新增 Build ALL／AltStore 執行；[發行紀錄與核對限制](docs/releases/PREVIEW_RELEASE_PROCESS.md)。
  Publication used the maintainer web interface with Build ALL paused and then restored. The Actions count stayed at 7 with no new Build ALL or AltStore runs; verification limits are recorded in the process document.
- 350 項完整測試及 68 項關鍵測試為既有 CI 結果，本次發布沒有重跑。仍為一次性測試簽章，S25+／Tab S11 對此 APK 的實機驗收待補。
  The 350 full-suite and 68 key-test passes are existing CI results, not new publication-time tests. The APK retains disposable signing; device acceptance of this APK on the S25+ and Tab S11 is pending.

## 文件與發行準備 / Documentation and release preparation

### 文件同步與首頁整理 / Documentation and homepage update

- 同步中英文首頁、公開版發行說明、版本紀錄與實際發行流程；首頁加入版本導覽，區分上游功能、本分支成果與尚未接入首頁的元件。
  Synchronised the two homepages, release notes, version history, and actual publication process. Homepage navigation highlights the preview and distinguishes upstream features, fork work, and components not yet integrated into the home screen.
- 本次只更新文件與首頁資訊，不變更 App、workflow、依賴、授權、既有 Tag 或 Release 附件；沒有重新執行 App 測試或建置。
  This update changes documentation and homepage information only; no application, workflow, dependency, license, existing tag, or release-asset changes, and no application tests or builds were re-run.

### 首次發行準備（歷史）/ First-release preparation (historical)

- [Yorunote Preview Release](.github/workflows/yorunote-preview-release.yml) 是固定在此版本來源與附件的單次流程。[prepare run 41980565581](https://github.com/mengwen-liu/yorunote/actions/runs/41980565581) 曾將 APK（712333248）與 `.sha256`（712333328）附加到當時的草稿，並下載回讀、重算雜湊相符。
  The dedicated workflow is pinned to this version's source and assets. Its prepare run attached and re-hashed both files while the release was still a draft.
- workflow 的 `publish` job 未曾執行；不得把本版網頁發布成功當成該 job 已驗證可用。權限限制與後續操作原則見[發行流程文件](docs/releases/PREVIEW_RELEASE_PROCESS.md)。
  The workflow publish job was never executed. Successful web publication does not validate that job; see the process document for its permission limitations.
- 首頁角色動畫為 [`夜讀月頁精靈_眨眼微笑.gif`](docs/brand/README.md)（512×512、6 影格、494,501 位元組），來源與雜湊保存在品牌文件。動畫導入屬文件與展示素材，不代表修改 APK 的圖示或版本。
  The homepage animation is documented with its source and hash in the brand notes. Importing that media did not change the APK's icon or version.
- 發行準備期間的草稿、無附件或未建立 Tag 等描述只適用於當時；目前版本狀態以本檔最上方的公開預覽版紀錄為準。
  Earlier draft, missing-asset, and missing-tag descriptions apply only to their preparation stage. The public-preview entry above records the current publication state.

## 2026-11-05：封面請求逾時 / Cover-request timeout

- [App 提交 / Commit `29b590b`](https://github.com/mengwen-liu/yorunote/commit/29b590b457378c16b19821f139b9bcad7d38f689)。
- 封面圖片每次 HTTP 嘗試原生總逾時 30 秒，避免不回應的請求無限占用名額。
  Native 30-second total timeout per cover-image HTTP attempt, bounding stalled requests.
- 保留重試、8 個名額、同鍵合併與快取行為；不將新逾時套用至閱讀器或下載。
  Preserves retries, 8 slots, sharing, and cache behavior; other request paths do not opt in.
- [CI 41968314599](https://github.com/mengwen-liu/yorunote/actions/runs/41968314599)：完整測試 350 項、關鍵測試 68 項通過，0 跳過。
  CI: 350 full-suite and 68 key tests passed with no skips.
- [驗證與限制 / Evidence and limits](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/cover-timeout-20261105/README.md)。

## 2026-11-05：取消、快取一致性與合成來源 / Cancellation, cache consistency, and synthetic source

- [App 提交 / Commit `cee5b03`](https://github.com/mengwen-liu/yorunote/commit/cee5b03043152cf96a1f444e1d88be46a44b8c08)。
- 加入停止訊號與原生取消傳遞、排隊期間快取有效性檢查、合成網路漫畫來源及統計校正。
  Added stop signals, native cancellation propagation, queued-cache validation, a synthetic source, and corrected statistical definitions.
- headers 前無法立即安全取消的限制，由後續逾時提交補上有限等待保護。
  Immediate pre-header cancellation remains restricted; the later timeout change bounds the wait.
- 主機冷載整批完成時間有約 9% 退步；這是指定主機情境的結果，不能外推手機 FPS 或耗電。
  Host cold-batch completion regressed by about 9%; this is not a device FPS or power measurement.
- [CI 41899724426](https://github.com/mengwen-liu/yorunote/actions/runs/41899724426)：343 項完整測試通過。
  CI: 343 full-suite tests passed.
- [完整紀錄 / Full report](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/thumbnail-r2-20261105/README.md)。

## 2026-11-05：封面佇列與同鍵合併 / Cover queueing and request sharing

- [App 提交 / Commit `418efac`](https://github.com/mengwen-liu/yorunote/commit/418efacd0bb03e1da180ff105c4566821a4e69fd)。
- 快取命中繞過網路佇列、事件式 8 名額限制、同鍵合併與壞快取恢復。
  Cache hits bypass the queue; event-driven 8-slot limiting, same-key sharing, and invalid-cache recovery.
- [CI 41883419245](https://github.com/mengwen-liu/yorunote/actions/runs/41883419245)：建置 App 提交 S，完整測試 313 項通過。
  CI built commit S and passed 313 tests.
- 後續僅測試提交 T 的 315 項為主機紀錄，並非該次 CI 結果。
  The later test-only commit T has a host record of 315 passing tests, not a result from that CI run.
- [完整紀錄與後續校正 / Report and subsequent corrections](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/thumbnail-perf-20261105/README.md)；統計與歸因校正見後續 R2 報告。

## 2026-11-04：品牌與閱讀器快取候選 / Branding and reader-cache candidates

- Yorunote 名稱、About 文案與 Android 圖示已導入候選分支。
  Yorunote naming, About text, and Android icons were added to the candidate branch.
- 閱讀器快取恢復與競態修正已保存於獨立分支。
  Reader-cache recovery and race fixes were preserved on a separate branch.
- [品牌紀錄 / Branding](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/yorunote-brand-v0.1/README.md) · [R3.1 保存紀錄 / R3.1 evidence](https://github.com/mengwen-liu/yorunote/blob/f003a708ca99a5c45f140ee554b4500ab5be8d49/docs/verification/2026-11-04-r3.1/README.md)。
- 舊 R3.1 的三星裝置回報不能視為本次最新 APK 已完成實機驗收。
  Earlier owner-reported device results for R3.1 do not validate the current APK.
