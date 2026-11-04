# Yorunote

Yorunote 是基於 [Venera](https://github.com/venera-app/venera) 的開源 Flutter 漫畫閱讀器個人 Fork，用於閱讀本機與網路來源的漫畫。

本儲存庫並非從零開發的原創 App。功能主要承襲上游，本 Fork 的調整限於外觀、維護與問題修正。

## 上游與授權

- 上游專案：<https://github.com/venera-app/venera>
- 授權：沿用上游的 GPL-3.0，全文見 [LICENSE](LICENSE)。
- 著作權聲明與第三方授權檔均保持原樣。
- Android 套件名稱（`com.github.wgh136.venera`）等上游識別資訊目前尚未更動。

| 類別 | 內容 |
| --- | --- |
| 承襲上游 | 下方功能摘要、漫畫來源機制與 Headless 模式 |
| 本 Fork | 外觀（名稱、圖示、首頁與 About 文案）調整、維護、閱讀器圖片快取問題修正 |

## 目前狀態

`master` 目前尚未整合品牌與快取修正，內容仍是上游程式加上 CI 設定。相關成果在各自分支，**尚未合併至 master**：

| 分支 | 內容 |
| --- | --- |
| [`claude/venera-r31-backup-20261104`](https://github.com/mengwen-liu/yorunote/tree/claude/venera-r31-backup-20261104) | 首頁、閱讀器圖片快取修正的候選來源與驗證保存 |
| [`claude/yorunote-brand-v01-20261104`](https://github.com/mengwen-liu/yorunote/tree/claude/yorunote-brand-v01-20261104) | 在上述候選上加入 Yorunote 名稱、About 文案與圖示 |
| [`claude/yorunote-arm64-ci-20261104`](https://github.com/mengwen-liu/yorunote/tree/claude/yorunote-arm64-ci-20261104) | 上列品牌分支加上 ARM64 測試建置的 CI 設定與證據 |

驗證紀錄（位於 `claude/yorunote-arm64-ci-20261104`）：

- [R3.1 驗證保存](https://github.com/mengwen-liu/yorunote/blob/claude/yorunote-arm64-ci-20261104/docs/verification/2026-11-04-r3.1/README.md)
- [品牌 v0.1 驗證索引](https://github.com/mengwen-liu/yorunote/blob/claude/yorunote-arm64-ci-20261104/docs/verification/yorunote-brand-v0.1/README.md)
- [ARM64 CI 結果](https://github.com/mengwen-liu/yorunote/blob/claude/yorunote-arm64-ci-20261104/docs/verification/yorunote-brand-v0.1/apk-build/CI_RESULT.md)

## 建置與測試用 APK

- 目前沒有正式發行版，也沒有 Yorunote 的發行管道。上游的 Release、AUR、F-Droid 等版本不是 Yorunote。
- 複製 `master` 不會得到品牌候選版；需切換到上列分支。
- 測試用 APK 來自 [Actions run 41845996537](https://github.com/mengwen-liu/yorunote/actions/runs/41845996537)（手動觸發，建置來源 `a789d2a`），其限制如下：
  - artifact 登入 GitHub 後才能下載，保留至 2026-11-11 到期，過期後須重新建置。
  - 僅 `arm64-v8a`，使用一次性測試金鑰簽章；若裝置上已有不同簽章的同套件名稱 App，無法直接覆蓋安裝。
  - 僅完成靜態檢查，尚未做 Android 實機驗收。
- 自行建置：
  1. 安裝 [Flutter](https://docs.flutter.dev/get-started/install) 與 [Rust](https://rustup.rs/)。CI 工作流使用 Flutter 3.41.4、Rust 1.85.1。
  2. 切換到想建置的分支後，執行 `flutter build apk` 等指令。

## 功能（承襲上游）

- 閱讀本機漫畫
- 使用 JavaScript 建立漫畫來源
- 閱讀網路來源的漫畫
- 管理收藏
- 下載漫畫
- 若來源支援，可檢視留言、標籤等資訊，並登入後留言、評分等

## 文件

- [建立漫畫來源](doc/comic_source.md)
- [Headless 模式](doc/headless_doc.md)

## 致謝

- 上游 [Venera](https://github.com/venera-app/venera) 及其貢獻者。
- 標籤中文翻譯來自 [EhTagTranslation](https://github.com/EhTagTranslation/Database)。
