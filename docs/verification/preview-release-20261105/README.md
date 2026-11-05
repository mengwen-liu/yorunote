# 預覽版發行紀錄（2026-11-05）/ Preview release record

> **狀態：發布尚未執行（受阻）。** Release 434819274 仍為 `draft=true`、`prerelease=true`；Tag `v0.1.0-preview.1` 尚未建立；Build ALL 未被停用也未被改動。
> **Status: publication NOT performed (blocked).** The release is still a draft; the tag does not exist; Build ALL was not disabled or changed.

## 操作前狀態（以 API 回讀）/ Pre-operation state

| 項目 | 值 |
| --- | --- |
| master | `9a709d27c69482a1e21cafa6ad90d2639248f328` |
| Release | ID 434819274，`tag_name=v0.1.0-preview.1`，draft／prerelease，`published_at=null` |
| Tag | 無（`list_tags` 回傳空） |
| 附件（prepare run 41980565581） | APK 712333248（27,882,063 bytes）、`.sha256` 712333328（115 bytes） |
| Build ALL | workflow ID 386674685，`.github/workflows/main.yml`，state `active`（本輪未再次回讀，沿用上一輪列表） |

## 受阻原因 / Why blocked

本輪可用的存取方式無法完成三項必要寫入：

1. **停用 Build ALL**：GitHub MCP 工具集沒有 disable／enable workflow 的操作。
2. **更新／公開 Release 本文**：沒有 update release 工具。
3. **建立 Tag**：沒有 create tag／ref 工具。

`gh` CLI 的 Token 也無效（`gh auth status`：`The token in GH_TOKEN is invalid`）。依授權範圍，**不換憑證、不新建 PAT、不改用其他管道繞過**，因此停止受阻寫入。沒有任何設定被改動，無需恢復。

## 已保存 / Saved here

- [`original-release-body.md`](original-release-body.md)：操作前的草稿本文。
- [`final-release-body.md`](final-release-body.md)：準備好的雙語最終本文（連結均已回讀驗證有效；不含尚未驗證的下載網址）。
- 文件連結驗證：`f003a708…` 的兩份驗證文件、`29b590b…` 的 LICENSE、`9a709d2…` 的 `PREVIEW_RELEASE_PROCESS.md` 皆已以 API 讀取成功。

## 維護者手動步驟（在 GitHub 網頁或已登入的 `gh`）/ Manual steps

1. **確認無進行中的 Build ALL／Update AltStore Source run**；有就等待結束，不取消他人工作。
2. **停用 Build ALL**：Actions → Build ALL → ⋯ → Disable workflow；回讀確認為 disabled。（若原本已停用，結束時不要啟用。）
3. **更新草稿本文**：Release 434819274 → Edit，貼上 [`final-release-body.md`](final-release-body.md)；確認兩個附件仍在、雜湊未變。
4. **建立 Tag** `v0.1.0-preview.1` 指向 `29b590b457378c16b19821f139b9bcad7d38f689`，回讀核對完整 SHA。例：

```bash
gh api repos/mengwen-liu/yorunote/git/refs -f ref=refs/tags/v0.1.0-preview.1 -f sha=29b590b457378c16b19821f139b9bcad7d38f689
```

5. **公開**：保持 **Set as a pre-release**、**不要勾選 Set as the latest release**，按 Publish；或：

```bash
gh api -X PATCH repos/mengwen-liu/yorunote/releases/434819274 -F draft=false -F prerelease=true -f make_latest=false
```

6. 重新下載公開的 APK 與 `.sha256`，核對 `sha256sum -c`；確認 APK SHA-256 為 `7ad08033c204a1de62546ca588ea0c050a5ace8ec0d4945d8c7978e156f5057f`。
7. 約 30 秒後檢查 Actions，確認沒有新增 Build ALL／Update AltStore Source run。
8. **恢復 Build ALL 為 active**（若第 2 步是你停用的），並回讀確認。
9. 再請維護者或下一輪工作把 README／CHANGELOG 的「草稿」文案改成已公開。

> 注意：直接在網頁按 Publish 而未先停用 Build ALL，仍可能啟動 Build ALL 並連動 AltStore。專用 workflow 的 `publish` 路徑（GITHUB_TOKEN）在 Update a release 需要的權限上尚未驗證，本輪依指示未執行。

## 未完成 / Not done

- 發布、Tag、Release 本文更新、Build ALL 停用／恢復。
- S25+／Tab S11 對這份 APK 的實機驗收。
