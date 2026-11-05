# 開發與版本紀錄 / Development and release history

[繁體中文首頁](README.md) · [English](README.en.md) · [GitHub Releases](https://github.com/mengwen-liu/yorunote/releases)

本檔分開記錄已發布的預覽版、文件更新與歷史開發里程碑。App 修改是否已發布、是否已合併至 master，以及是否完成實機驗收，分別記錄。
This file distinguishes public previews, documentation updates, and development milestones. Publication, integration into master, and device acceptance are separate states.

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
