# 預覽版受控發行流程 / Controlled preview-release process

適用版本 / Applies to: `v0.1.0-preview.1`（Release ID `434819274`）

[公開預覽版 / Public preview](https://github.com/mengwen-liu/yorunote/releases/tag/v0.1.0-preview.1) · [雙語發行說明 / Bilingual notes](v0.1.0-preview.1.md) · [版本紀錄 / Version history](../../CHANGELOG.md)

## 已確認的發行現況 / Confirmed publication state

| 項目 / Item | 狀態 / State |
| --- | --- |
| Release | 已公開預覽版 / published pre-release：`draft=false`、`prerelease=true`；未設為 Latest / not marked latest |
| 公開時間 / Published | `2026-11-05T12:57:32Z`；台灣時間 / Asia/Taipei：2026-11-05 20:57:32 |
| Tag / App source | `v0.1.0-preview.1` → `29b590b457378c16b19821f139b9bcad7d38f689` |
| 附件 / Assets | 原 APK `712333248` 與 `.sha256` `712333328` 沿用 / original assets retained |
| `prepare` | [run 41980565581](https://github.com/mengwen-liu/yorunote/actions/runs/41980565581) 已成功；當時下載回讀並重算附件雜湊 / succeeded and re-hashed both assets before publication |
| workflow `publish` | 未執行、未驗證 / never executed or validated；本版實際透過維護者網頁發布 / actual publication used the maintainer web interface |
| Build ALL | 發布前啟用 → 暫停 → 發布後恢復啟用 / active → paused → restored to active |
| Actions | 發布前後均為 7 筆；沒有新增 Build ALL／AltStore 執行 / remained at 7; no new Build ALL or AltStore runs |

## 繁體中文

### 本版實際採用的步驟

1. 回讀儲存庫、既有草稿與附件；確認固定來源分支 `codex/yorunote-preview-29b590b` 仍指向上述 App 提交，沒有進行中或排隊的建置。
2. 記錄 Build ALL 原為啟用，暫停並從網頁確認已停用。
3. 更新雙語本文，保留既有兩個附件與預覽版標記。GitHub 網頁在發布時從固定目標建立 Tag，並公開原有 Release 434819274，沒有建立第二份 Release。
4. 從 GitHub API 回讀 Tag 精確指向 App 來源、公開狀態、本文、附件 ID／大小／GitHub SHA-256 記錄，並在發布後分次核對 Actions 清單。
5. 確認沒有新增 Build ALL／AltStore 執行後，恢復 Build ALL 啟用並回讀成功訊息。App、workflow 檔與簽章均未修改，也未重新建置。

### 已核對與尚待補齊

- `prepare` 的下載後雜湊核對是既有 run 的結果。公開發布後，瀏覽器下載校驗檔遭 `ERR_BLOCKED_BY_CLIENT` 阻擋，本機命令執行環境亦無法啟動，因此**公開後的獨立重新下載與重算雜湊未完成**；沒有繞過封鎖。附件 ID、大小與 GitHub 提供的 digest 均與原值相同。
- 公開預覽版與 ARM64 Profile 測試建置是不同層面的名稱；本次沒有轉成 Flutter Release 模式，也沒有新增固定簽章。
- 350 項完整測試、68 項關鍵測試與 APK 靜態檢查是[原建置 run 41968314599](https://github.com/mengwen-liu/yorunote/actions/runs/41968314599) 的結果。本次發布及文件同步未重跑；最新 APK 的 S25+／Tab S11 實機驗收仍待補。
- 本版未設為 Latest。發布當次首頁右側僅列出 Tag；README 已提供明確的預覽版版本、下載與校驗檔入口。

### 既有 workflow 的用途與權限限制

[Yorunote Preview Release](../../.github/workflows/yorunote-preview-release.yml) 的 Release ID、App SHA、來源 run、artifact 與雜湊固定在本版。它保留為發行準備的紀錄；本版已公開，**不要為文件同步或下一版發行重新執行這個單次流程**。

- `prepare` 已成功，證據如上。`publish` job 從未執行；不能由網頁發布成功推論該 job 可用。
- [GitHub 的事件規則](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow)限制 `GITHUB_TOKEN` 造成的 Release 事件連鎖觸發，但這不等於該 Token 具有發布所需的權限。
- [Update a release](https://docs.github.com/en/rest/releases/releases#update-a-release) 另規定：若解析後目標提交相對預設分支改動 workflow，呼叫者須具 workflow 修改權限；內建 `GITHUB_TOKEN` 不能取得該授權。本專案未實際嘗試 workflow `publish`，沒有此操作回傳 403／404 的實測結果。

### 下一版發行前

這是下一次操作的原則，不代表已建立通用發版自動化。

1. 先確認下一版授權範圍、App 來源、版本、簽章與附件；既有 Tag 不移動、不覆寫。本版 App 仍未整合進 master，不能直接把 master 當成下一個 App 來源。
2. 檢查目標提交的 workflow 觸發規則與有無進行中的 Build ALL／AltStore 執行。既有 `main.yml` 的 `release: published` 與 AltStore 連動仍在；本次只是暫停後恢復，沒有永久移除。
3. 需要暫停時，先記錄原狀態、確認停用成功，再發布。原本已停用者保持停用；中途失敗也須恢復本次改動過的狀態。停用不會取消既有 run，詳見[官方說明](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/disable-and-enable-workflows?tool=webui)。
4. 發布前核對來源與附件，發布後回讀實際 Tag、Release、下載內容與 Actions；未執行的檢查明確記錄。遇到權限或瀏覽器封鎖時停止相依操作，不更換憑證或繞過限制。
5. 同步中英文 README、CHANGELOG 與該版發行說明；區分 App 來源、建置 workflow 提交及文件提交。通用 Android 發版流程、固定簽章與實機驗收屬後續工作。

### 文件復原

本次文件提交可用 `git revert` 撤回。這不會撤銷既有公開 Release、移動 Tag、刪除附件或恢復儲存庫簡介；這些項目須分別處理。歷史驗證目錄保留原文。

## English

### What actually ran for this version

1. Read back the repository, existing draft, and assets. The fixed source branch `codex/yorunote-preview-29b590b` still pointed at the application commit above, and no build was running or queued.
2. Record that Build ALL was active, disable it, and confirm the disabled state in the web interface.
3. Update the bilingual notes while retaining both assets and the pre-release flag. GitHub created the tag from the fixed target during publication and published the existing release 434819274; no second release was created.
4. Use GitHub API readbacks to verify the tag target, public state, body, asset IDs, sizes, and GitHub digests. Check the Actions list more than once after publication.
5. With no new Build ALL or AltStore runs, re-enable Build ALL and confirm success. Application code, workflow files, and signing were unchanged; nothing was rebuilt.

### Verification scope

- The prepare run's successful download-and-hash checks are historical CI evidence. After publication, Chrome blocked the checksum download with `ERR_BLOCKED_BY_CLIENT`, and local command execution was unavailable. **An independent post-publication download and hash calculation was not completed.** The block was not bypassed; asset IDs, sizes, and GitHub digests remained unchanged.
- Publishing a GitHub pre-release did not convert the ARM64 Profile APK into a Flutter Release-mode build or establish persistent signing.
- The 350 full-suite tests, 68 key tests, and static APK checks belong to [build run 41968314599](https://github.com/mengwen-liu/yorunote/actions/runs/41968314599). Neither publication nor this documentation update re-ran them. Device acceptance of this APK on the S25+ and Tab S11 remains pending.
- This preview was not marked latest. At publication time the native homepage sidebar listed the tag; both READMEs provide explicit preview-version and download links.

### Existing workflow and permissions

The [Yorunote Preview Release workflow](../../.github/workflows/yorunote-preview-release.yml) pins this version's release, source, run, artifact, and hashes. It is a record of the one-time preparation, **not a workflow to re-run for documentation updates or the next release**.

- `prepare` succeeded. The workflow's `publish` job never ran; successful web publication does not validate it.
- GitHub's [token-event behavior](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow) prevents a token-originated release event from recursively starting workflows. Permission to publish is a separate requirement.
- Under [Update a release](https://docs.github.com/en/rest/releases/releases#update-a-release), a target with workflow changes relative to the default branch requires workflow-write authorization, unavailable to the built-in `GITHUB_TOKEN`. This repository did not attempt that publish job, so no 403/404 from that operation was observed.

### Before the next release

This is guidance for the next operation, not a claim that reusable release automation already exists.

1. Confirm the authorized scope, application source, version, signing, and assets. Never move or overwrite an existing tag. The published application code is not yet integrated into master.
2. Inspect the workflows at the target commit and any active or queued Build ALL or AltStore runs. The release-published trigger and AltStore linkage remain; the temporary pause did not remove them.
3. If a pause is needed, record and verify it before publishing. Preserve workflows that were already disabled, and restore only state changed by this operation, including on failure. [Disabling a workflow](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/disable-and-enable-workflows?tool=webui) does not cancel existing runs.
4. Verify source and assets before publication; read back the resulting tag, release, downloaded contents, and Actions afterward. Record missing checks explicitly. Stop affected work on permission or browser blocks rather than changing credentials or bypassing restrictions.
5. Synchronise both READMEs, CHANGELOG, and version-specific notes. Keep application, build-workflow, and documentation commits distinct. Reusable Android release automation, persistent signing, and device acceptance are follow-up work.

### Documentation rollback

Revert the documentation commit with `git revert` if needed. This does not unpublish the release, move its tag, delete assets, or restore repository metadata. Those are separate operations. Historical verification files remain unchanged.

## 固定來源與附件 / Fixed source and assets

| 項目 / Item | 值 / Value |
| --- | --- |
| App | `29b590b457378c16b19821f139b9bcad7d38f689` |
| 原建置 workflow / Original build-workflow commit | `356be4942360501fcc9eab36e45577b34912f525`；run `41968314599` |
| 原 artifact / Original artifact | `13389067967`；ZIP SHA-256 `9958057d90b33710c09c921809a8ec1b864af8ce40508b1ce4a7ae4ccceac275` |
| APK | `Yorunote_29b590b_cover_timeout_arm64_profile.apk`；27,882,063 bytes；asset `712333248` |
| APK SHA-256 | `7ad08033c204a1de62546ca588ea0c050a5ace8ec0d4945d8c7978e156f5057f` |
| Checksum | `Yorunote_29b590b_cover_timeout_arm64_profile.apk.sha256`；115 bytes；asset `712333328` |
| Checksum file SHA-256 | `e7c72a4a1e9f379829bfe5e1e9dc98b726852e9dcb6a73bea9c35f736936d52a` |
