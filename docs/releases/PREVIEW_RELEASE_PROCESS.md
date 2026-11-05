# 預覽版受控發行流程 / Controlled preview-release process

適用版本 / Applies to: `v0.1.0-preview.1`（Release ID `434819274`）

Workflow：[`.github/workflows/yorunote-preview-release.yml`](../../.github/workflows/yorunote-preview-release.yml)
（名稱 / name: **Yorunote Preview Release**）

## 目前狀態 / Current status

| 項目 / Item | 狀態 / Status |
| --- | --- |
| `prepare` | **已實際執行且成功**：[run 41980565581](https://github.com/mengwen-liu/yorunote/actions/runs/41980565581) 將 APK（附件 ID 712333248）與 `.sha256`（附件 ID 712333328）附加到草稿，並下載回讀、重算雜湊相符 / **ran successfully**: both assets were attached and re-hashed after download |
| `publish` | **尚未實際執行，不能視為已驗證可用**；見下方「權限限制」/ **never executed; not verified to work**; see "Permission limitation" |
| Release 434819274 | 仍為草稿（`draft=true`、`prerelease=true`）/ still a draft |
| Tag `v0.1.0-preview.1` | 尚未建立 / not created |
| Build ALL | 本流程文件未改動其狀態 / state unchanged by this document |

## 繁體中文

### 背景

既有的 `main.yml`（名稱「Build ALL」）設有 `release: published` 觸發規則；Build ALL 完成後，`update_alt_store.yml` 又以 `workflow_run: workflows: ["Build ALL"]` 連動。若以一般方式公開 Release，可能啟動多平台建置與 AltStore 更新。

### 事件不連動 ≠ 有權限更新 Release

兩件事必須分開看：

1. **事件是否連動（官方機制）**：依 GitHub 官方文件，`GITHUB_TOKEN` 觸發的事件（`workflow_dispatch`、`repository_dispatch` 除外）不會建立新的 workflow run。這是專用 workflow 設計時採用 `GITHUB_TOKEN` 的理由，也是 `prepare` 能安全附加附件的原因。
2. **是否有權限更新 Release（權限限制）**：依官方 [Update a release](https://docs.github.com/en/rest/releases/releases#update-a-release) 文件，若解析後的目標提交相對預設分支新增或修改了 `.github/workflows/` 下的檔案，呼叫者必須被授權修改 workflow，否則端點回 `404 Not Found`（部分驗證路徑為 `403 Resource not accessible by integration`）。文件明寫：**Actions 內建的 `GITHUB_TOKEN` 無法取得此授權**。PAT（classic）需 `workflow` 範圍；fine-grained 權杖或 GitHub App 需 `Workflows` 寫入權限。

因此，「`GITHUB_TOKEN` 不連動其他 workflow」**不代表** `GITHUB_TOKEN` 一定能完成公開 Release 的更新。本專案的 Release 目標為 `29b590b`、預設分支 `master` 已含新 workflow 檔，是否落入上述限制**尚未實測**。

### 權限限制與 `publish` 的地位

- 專用 workflow 的 `publish` 操作**尚未實際執行**，不能寫成已驗證可用。
- 先前「先建立 Tag，再用 `GITHUB_TOKEN` 執行 `publish`」的做法**不再列為已確認可行的推薦步驟**；它可能在 Update a release 階段被拒絕（404／403）。
- 本專案不新增 PAT、GitHub App 或其他憑證。若 `publish` 被拒絕，應停止並改走下方維護者流程。
- `prepare` 只上傳附件與讀取，不呼叫 Update a release，已成功，不受上述限制影響。

### 待執行的維護者發布流程（尚未實際執行）

以下流程**本輪沒有執行**。正式操作須由已取得明確授權、且具有可用權限（可停用 workflow、可更新 Release、可建立 Tag）的環境執行。

1. **確認沒有進行中或排隊的 Build ALL／Update AltStore Source run**；有就等待結束，不取消他人的工作。
2. **記錄 Build ALL 的操作前狀態**（workflow ID、檔案路徑、`active` 或 `disabled_*`）。
3. **需要時暫停 Build ALL 並回讀確認**：原本 `active` 才停用（網頁：Actions → Build ALL → Disable workflow，或 `gh workflow disable`）；無法確認已停用就不要公開。**原本已停用者保持原狀，結束時不得擅自啟用。** 停用不會取消既有 run，且停用期間無法重跑。
4. **更新草稿本文**為準備好的雙語本文（[`final-release-body.md`](../verification/preview-release-20261105/final-release-body.md)），並回讀確認兩個附件、雜湊與 Release ID 未變。
5. **核對或建立 Tag** `v0.1.0-preview.1`，精確指向 `29b590b457378c16b19821f139b9bcad7d38f689`；同名 Tag 已存在且正確可沿用，指錯位置則停止，不移動、不覆寫。
6. **公開為 prerelease**：`draft=false`、`prerelease=true`、`make_latest=false`；不建立第二份 Release，不變更附件與 App 來源。
7. **核對公開結果**：重新下載公開的 APK 與 `.sha256`，重算 SHA-256 與固定值比對；再檢查 Actions 清單（發布後立即與約 30 秒後各一次），確認沒有新增的 Build ALL／Update AltStore Source run。
8. **恢復操作前狀態**：若本次改動過 Build ALL，將其恢復並回讀確認。**中途任何步驟失敗，也必須先恢復本次改動過的狀態**，再回報。恢復失敗須明確回報，不得宣稱已收尾。

說明：

- 暫時停用 Build ALL **沒有永久移除** `release: published` 規則；`main.yml` 與 `update_alt_store.yml` 均未修改，之後的每次發布仍須使用受控流程。
- 直接在網頁按「Publish release」而未先停用 Build ALL，或改用 PAT 發布，仍可能啟動 Build ALL（再連動 AltStore 更新）。
- 上述停用、發布、恢復流程**尚未實際執行**；在實際發布並回讀 Actions 紀錄之前，只能說機制已準備，不能說已實測無連動。

### 專用 workflow 的兩種操作

| 操作 | 觸發方式 | 會做的事 | 絕不會做的事 |
| --- | --- | --- | --- |
| `prepare`（預設，**已執行成功**） | Actions → Yorunote Preview Release → Run workflow，分支 `master`，operation 選 `prepare` | 核對儲存庫、草稿狀態、來源 run 41968314599 與 artifact 13389067967；下載 ZIP 並核對雜湊；安全解壓；核對 APK 大小與 SHA-256；產生 `.sha256`；附加至既有草稿；回讀並下載重算雜湊 | 公開 Release、建立／移動 Tag、覆蓋或刪除附件、建立另一份 Release |
| `publish`（**尚未執行、未驗證**） | 同上，operation 選 `publish`，confirm 欄位輸入 `PUBLISH v0.1.0-preview.1 AT 29b590b457378c16b19821f139b9bcad7d38f689` | 重新核對附件、Release ID、prerelease 狀態與 Tag；只將既有草稿公開為 prerelease，`make_latest=false`；**受上述權限限制，可能被拒絕** | 建立／移動／覆寫 Tag、變更附件、建立新版 Release、設為 latest |

固定常數（Release ID、Tag、App 來源 SHA、來源 run、artifact、雜湊）寫在 workflow 內，不接受任何儲存庫、URL、腳本或提交作為輸入。workflow 不 checkout 任何程式碼，也不執行 artifact 內的內容。權限只有 `actions: read`、`contents: write`；不使用 PAT、`ACTION_GITHUB_TOKEN` 或其他 Secrets。

### 復原方式

- 本流程與文件的提交可以 `git revert` 撤回，不影響 App 原始碼。
- 草稿附件可由維護者在 Release 編輯頁手動刪除；workflow 本身不提供刪除或覆蓋功能。

## English

### Background

The existing `main.yml` ("Build ALL") is triggered by `release: published`, and `update_alt_store.yml` follows it via `workflow_run: workflows: ["Build ALL"]`. Publishing a release normally can therefore start the multi-platform build and the AltStore update.

### "Events do not chain" is not "has permission to update the release"

Two separate questions:

1. **Do events chain? (official mechanism)** GitHub documents that events triggered by `GITHUB_TOKEN` (except `workflow_dispatch` and `repository_dispatch`) do not create new workflow runs. This is why the dedicated workflow uses `GITHUB_TOKEN`, and why `prepare` could safely attach the assets.
2. **Is the token allowed to update the release? (permission limitation)** Per the official [Update a release](https://docs.github.com/en/rest/releases/releases#update-a-release) documentation, if the resolved target commit adds or modifies any file under `.github/workflows/` relative to the default branch, the authenticating token must be authorized to modify workflows; otherwise the endpoint returns `404 Not Found` (some authentication paths surface `403 Resource not accessible by integration`). The documentation states that **the `GITHUB_TOKEN` available to GitHub Actions cannot be authorized for this**. Classic PATs need the `workflow` scope; fine-grained tokens and GitHub App installation tokens need the "Workflows" write permission.

So "`GITHUB_TOKEN` does not chain into other workflows" does **not** imply that `GITHUB_TOKEN` can publish the release. Whether this repository's release (target `29b590b`, default branch `master` already containing the new workflow file) falls under that limitation has **not been tested**.

### Permission limitation and the status of `publish`

- The workflow's `publish` operation has **never been executed** and must not be described as verified.
- The earlier "create the tag first, then run `publish` with `GITHUB_TOKEN`" approach is **no longer a confirmed, recommended procedure**; it may be rejected (404/403) at the Update-a-release step.
- This project adds no PAT, GitHub App or other credential. If `publish` is rejected, stop and use the maintainer procedure below.
- `prepare` only uploads assets and reads state; it does not call Update a release, it succeeded, and it is unaffected by this limitation.

### Pending maintainer procedure (NOT yet executed)

This procedure was **not executed**. The real operation must run in an environment that has explicit authorization and working permissions (disable workflows, update releases, create tags).

1. **Confirm no Build ALL / Update AltStore Source run is in progress or queued**; if any, wait and do not cancel other people's work.
2. **Record Build ALL's pre-operation state** (workflow ID, file path, `active` or `disabled_*`).
3. **Pause Build ALL if needed and read it back**: disable it only if it was `active` (web: Actions → Build ALL → Disable workflow, or `gh workflow disable`); do not publish if the disabled state cannot be confirmed. **If it was already disabled, leave it so and do not enable it at the end.** Disabling does not cancel existing runs and prevents re-running them while disabled.
4. **Update the draft body** with the prepared bilingual text ([`final-release-body.md`](../verification/preview-release-20261105/final-release-body.md)) and read back that both assets, hashes and the release ID are unchanged.
5. **Verify or create the tag** `v0.1.0-preview.1` at exactly `29b590b457378c16b19821f139b9bcad7d38f689`; reuse an existing correct tag; stop if it points elsewhere; never move or overwrite it.
6. **Publish as a pre-release**: `draft=false`, `prerelease=true`, `make_latest=false`; no second release, no asset or application-source changes.
7. **Verify the result**: re-download the public APK and `.sha256`, recompute SHA-256 and compare with the fixed values; check the Actions list right after publishing and again about 30 seconds later for any new Build ALL / Update AltStore Source run.
8. **Restore the pre-operation state**: if Build ALL was changed, restore it and read it back. **If any step fails midway, restore whatever this operation changed first**, then report. A failed restore must be reported explicitly, never described as finished.

Notes:

- Temporarily disabling Build ALL does **not** permanently remove the `release: published` rule; `main.yml` and `update_alt_store.yml` are unchanged, so every future release still needs the controlled procedure.
- Clicking "Publish release" in the web UI without first disabling Build ALL, or publishing with a PAT, can still start Build ALL (and then the AltStore update).
- The disable / publish / restore procedure has **not been executed**. Until it has run and the Actions history has been checked, the mechanism is only prepared, not verified.

### The workflow's two operations

| Operation | Trigger | Does | Never does |
| --- | --- | --- | --- |
| `prepare` (default, **ran successfully**) | Actions → Yorunote Preview Release → Run workflow, branch `master`, operation `prepare` | Verifies repository, draft state, source run 41968314599 and artifact 13389067967; downloads and hashes the ZIP; extracts safely; checks APK size and SHA-256; generates `.sha256`; attaches both to the existing draft; reads back and re-hashes the downloads | Publish, create/move tags, overwrite or delete assets, create another release |
| `publish` (**never executed, unverified**) | Same, operation `publish`, confirm `PUBLISH v0.1.0-preview.1 AT 29b590b457378c16b19821f139b9bcad7d38f689` | Re-verifies assets, release ID, pre-release state and tag; only flips the existing draft to a published pre-release with `make_latest=false`; **may be rejected because of the limitation above** | Create/move/overwrite tags, change assets, create a new release, set latest |

All identifiers are constants in the workflow; no repository, URL, script or commit is accepted as input. The workflow checks out no code and executes nothing from the artifact. Permissions are limited to `actions: read` and `contents: write`; no PAT, `ACTION_GITHUB_TOKEN` or other secret is used.

### Rollback

- The workflow and documentation commits can be reverted with `git revert`; application source is not affected.
- Draft assets can be removed manually by the maintainer on the release edit page; the workflow provides no delete or overwrite operation.

## 固定值 / Fixed values

| 項目 / Item | 值 / Value |
| --- | --- |
| App 來源 / Application source | `29b590b457378c16b19821f139b9bcad7d38f689` |
| 原建置 workflow 提交 / Build-workflow commit (run 41968314599) | `356be4942360501fcc9eab36e45577b34912f525` |
| Artifact | `yorunote-cover-timeout-arm64-profile-apk`（ID 13389067967） |
| Artifact ZIP SHA-256 | `9958057d90b33710c09c921809a8ec1b864af8ce40508b1ce4a7ae4ccceac275` |
| APK | `Yorunote_29b590b_cover_timeout_arm64_profile.apk`，27,882,063 bytes |
| APK SHA-256 | `7ad08033c204a1de62546ca588ea0c050a5ace8ec0d4945d8c7978e156f5057f` |
| 雜湊檔 / Checksum file | `Yorunote_29b590b_cover_timeout_arm64_profile.apk.sha256`，115 bytes，SHA-256 `e7c72a4a1e9f379829bfe5e1e9dc98b726852e9dcb6a73bea9c35f736936d52a` |
