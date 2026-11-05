# 預覽版受控發行流程 / Controlled preview-release process

適用版本 / Applies to: `v0.1.0-preview.1`（Release ID `434819274`）

Workflow：[`.github/workflows/yorunote-preview-release.yml`](../../.github/workflows/yorunote-preview-release.yml)
（名稱 / name: **Yorunote Preview Release**）

## 繁體中文

### 目的

既有的 `main.yml`（名稱「Build ALL」）設有 `release: published` 觸發規則；Build ALL 完成後，`update_alt_store.yml` 又以 `workflow_run: workflows: ["Build ALL"]` 連動。若以一般方式公開 Release，可能啟動多平台建置與 AltStore 更新。

本流程改由專用 workflow 使用**該次 job 自動產生的 `GITHUB_TOKEN`** 寫入 Release。依 GitHub 官方文件，`GITHUB_TOKEN` 觸發的事件（`workflow_dispatch`、`repository_dispatch` 除外）不會再建立新的 workflow run，因此可避免 Release 事件連動 Build ALL。

**重要限制：**

- 這**不是**永久取消 Build ALL 的 `release: published` 規則；`main.yml` 與 `update_alt_store.yml` 均未修改。
- 直接在 GitHub 網頁按「Publish release」，或改用 PAT／其他使用者憑證發布，**仍可能啟動 Build ALL**（再連動 AltStore 更新）。
- Release 事件使用 Tag 所指提交中的 workflow 定義；`29b590b` 中的 `main.yml` 仍含 `release: published`。所以「master 已加入新流程」或「提交訊息含 `[skip ci]`」都不能證明 Release 事件不會觸發（`[skip ci]` 只作用於 `push` 與 `pull_request`）。
- 在真正執行 publish 並回讀 Actions 紀錄之前，只能說**機制已準備**，不能說已實測無連動。

### 兩種操作

| 操作 | 觸發方式 | 會做的事 | 絕不會做的事 |
| --- | --- | --- | --- |
| `prepare`（預設） | Actions → Yorunote Preview Release → Run workflow，分支 `master`，operation 選 `prepare` | 核對儲存庫、草稿狀態、來源 run 41968314599 與 artifact 13389067967；下載 ZIP 並核對 ZIP 雜湊；安全解壓；核對 APK 大小與 SHA-256；產生 `.sha256`；附加至既有草稿；回讀並下載重算雜湊 | 公開 Release、建立／移動 Tag、覆蓋或刪除附件、建立另一份 Release |
| `publish` | 同上，operation 選 `publish`，並在 confirm 欄位輸入 `PUBLISH v0.1.0-preview.1 AT 29b590b457378c16b19821f139b9bcad7d38f689` | 重新核對兩個附件（下載重算）、Release ID、prerelease 狀態；確認 Tag 已存在且解析後指向 `29b590b…`；只將既有草稿公開為 prerelease，`make_latest=false` | 建立／移動／覆寫 Tag、變更附件、建立新版 Release、設為 latest |

固定常數（Release ID、Tag、App 來源 SHA、來源 run、artifact、雜湊）寫在 workflow 內，不接受任何儲存庫、URL、腳本或提交作為輸入。workflow 不 checkout 任何程式碼，也不執行 artifact 內的內容。權限只有 `actions: read`、`contents: write`；不使用 PAT、`ACTION_GITHUB_TOKEN` 或其他 Secrets。

### 公開前的步驟（須維護者明確同意）

1. 確認 `prepare` 已成功，草稿附件為下列兩個檔案且雜湊相符。
2. 由維護者以一般、已授權的使用者工具建立 **lightweight 或 annotated** Tag `v0.1.0-preview.1`，精確指向 `29b590b457378c16b19821f139b9bcad7d38f689`，並回讀確認。
   注意：只推送 Tag 不會建立 Release 事件；`main.yml` 沒有 `push: tags` 觸發。
3. 執行 `publish`（含確認字串）。workflow 若發現 Tag 缺少或指錯位置會直接停止。
4. 回讀 Release（`draft=false`、`prerelease=true`），並檢查 Actions 列表中沒有新增 Build ALL 或 Update AltStore Source 的 run。

### 復原方式

- 本流程與文件的提交可以 `git revert` 撤回，不影響 App 原始碼。
- 草稿附件可由維護者在 Release 編輯頁手動刪除；workflow 本身不提供刪除或覆蓋功能。

## English

### Purpose

The existing `main.yml` ("Build ALL") is triggered by `release: published`, and `update_alt_store.yml` follows it via `workflow_run: workflows: ["Build ALL"]`. Publishing a release normally can therefore start the multi-platform build and the AltStore update.

This process writes to the release only through a dedicated workflow using the job's **automatically generated `GITHUB_TOKEN`**. GitHub documents that events triggered by `GITHUB_TOKEN` (except `workflow_dispatch` and `repository_dispatch`) do not create new workflow runs, which avoids chaining into Build ALL.

**Limitations:**

- This does **not** permanently remove the `release: published` trigger; `main.yml` and `update_alt_store.yml` are unchanged.
- Clicking "Publish release" in the GitHub web UI, or publishing with a PAT or other user credential, **can still start Build ALL** (and then the AltStore update).
- A release event uses the workflow definitions in the tagged commit; `main.yml` at `29b590b` still contains `release: published`. Neither the new workflow on master nor `[skip ci]` (which only applies to `push` and `pull_request`) proves that release events will not trigger.
- Until `publish` has actually run and the Actions history has been checked, the mechanism is only **prepared**, not verified in practice.

### Operations

- `prepare` (default): verifies the repository, draft state, source run 41968314599 and artifact 13389067967; downloads the ZIP and checks its hash; extracts it safely; checks APK size and SHA-256; generates the `.sha256`; attaches both to the existing draft; reads them back and re-hashes the downloads. It never publishes, never creates or moves a tag, never overwrites or deletes assets.
- `publish`: requires the confirmation string `PUBLISH v0.1.0-preview.1 AT 29b590b457378c16b19821f139b9bcad7d38f689`. It re-verifies both assets, the release ID and pre-release state, requires the tag to already exist and resolve to `29b590b…`, then only flips the existing draft to a published pre-release with `make_latest=false`. It never creates, moves or overwrites tags, never changes assets, never creates a new release.

All identifiers are constants in the workflow; no repository, URL, script or commit is accepted as input. The workflow checks out no code and executes nothing from the artifact. Permissions are limited to `actions: read` and `contents: write`; no PAT, `ACTION_GITHUB_TOKEN` or other secret is used.

### Before publication (requires explicit maintainer approval)

1. Confirm that `prepare` succeeded and the two draft assets match the hashes below.
2. The maintainer creates the tag `v0.1.0-preview.1` at exactly `29b590b457378c16b19821f139b9bcad7d38f689` with normal, authorized user tools and reads it back. Pushing a tag alone does not create a release event; `main.yml` has no `push: tags` trigger.
3. Run `publish` with the confirmation string. It stops if the tag is missing or points elsewhere.
4. Read back the release (`draft=false`, `prerelease=true`) and check that no new Build ALL or Update AltStore Source run appeared.

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
| APK | `Yorunote_29b590b_cover_timeout_arm64_profile.apk` |
| APK 大小 / size | 27,882,063 bytes |
| APK SHA-256 | `7ad08033c204a1de62546ca588ea0c050a5ace8ec0d4945d8c7978e156f5057f` |
| 雜湊檔 / Checksum file | `Yorunote_29b590b_cover_timeout_arm64_profile.apk.sha256`（`sha256sum` 格式 / format） |
