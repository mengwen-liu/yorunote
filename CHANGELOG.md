# 開發與版本紀錄 / Development and release history

[繁體中文首頁](README.md) · [English](README.en.md) · [GitHub Releases](https://github.com/mengwen-liu/yorunote/releases)

本檔保存可追溯的開發里程碑。下列候選提交尚未合併至 master，也不代表已發布的版本。
This file records traceable development milestones. Candidate commits below are not merged into master and are not published releases.

## 尚未發布 / Unreleased

### 受控預覽版發行流程 / Controlled preview-release workflow

- 新增僅限手動觸發的 [Yorunote Preview Release](.github/workflows/yorunote-preview-release.yml) 與[操作文件](docs/releases/PREVIEW_RELEASE_PROCESS.md)：`prepare` 只將已核對的 APK 與 `.sha256` 附加至既有草稿；`publish` 需另填確認字串，且要求 Tag 事先存在並指向 `29b590b`。
  Added a manual-only workflow and process document: `prepare` only attaches the verified APK and checksum to the existing draft; `publish` needs a confirmation string and a pre-existing tag at `29b590b`.
- 既有 Build ALL、AltStore 與 App 建置 workflow 未修改；`release: published` 規則仍存在。
  Existing Build ALL, AltStore and app-build workflows are unchanged; their `release: published` trigger remains.

### 文件與展示素材 / Documentation and media

- 首頁（[繁體中文](README.md)、[English](README.en.md)）改用角色動畫 [`夜讀月頁精靈_眨眼微笑.gif`](docs/brand/README.md)（512×512、6 影格、494,501 位元組）；素材來源與雜湊見該目錄說明。
  Both homepages now show the character animation; source and hash are in the media README.
- 這是純文件與展示素材變更，不含 App 程式、版本、圖示、依賴或 workflow 修改；`master` 仍未整合最新 App 候選。
  Documentation and media only: no app code, version, icons, dependencies or workflows changed; `master` still does not include the latest app candidate.
- GitHub Release 草稿（ID 434819274）仍為 draft／prerelease、未發布、無附件。
  The GitHub Release draft (ID 434819274) remains an unpublished draft/pre-release with no assets.

### v0.1.0-preview.1（發行說明工作稿 / Proposed preview）

- 說明：[雙語發行說明](docs/releases/v0.1.0-preview.1.md)。
- 目標 App 來源 / Intended application source: [`29b590b`](https://github.com/mengwen-liu/yorunote/commit/29b590b457378c16b19821f139b9bcad7d38f689)。
- GitHub 預覽版標籤與 APK 內部版本分開：APK 仍為 1.6.3（versionCode 2163）。
  The proposed GitHub preview label does not change the APK's internal version, which remains 1.6.3 (2163).
- 尚無已發布的 Yorunote Release；不得將此工作稿當成正式發行紀錄。
  No Yorunote release has been published; this draft is not a release announcement.

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
