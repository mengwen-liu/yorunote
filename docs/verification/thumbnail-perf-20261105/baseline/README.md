# 基準（修正前）紀錄

- 來源：`7b6348a98cb85dd71c826134811fa02fcd302da8`（起始分支 `claude/yorunote-arm64-ci-20261104`），
  於隔離的 git worktree 執行；只複製本輪新增的測試／量測檔，未改動 App 程式碼。
- 工具鏈：Flutter 3.41.4（ff37bef603）／Dart 3.11.1，主機版 `librhttp.so` 依 rhttp 0.15.1
  鎖定的 `Cargo.lock`（SHA-256 `232c3f91…5eb4`）以 Rust 1.85.1 建置。
- 環境：x86_64 Linux 雲端容器、本機 loopback HTTP 伺服器、合成 PNG、暫存資料目錄。
  數值為主機量測，不代表手機／平板的 FPS 或耗電。

| 檔案 | 內容 |
|---|---|
| `bench_baseline_7b6348a.json` | 量測原始資料（暖機 1 次＋取樣 7 次） |
| `bench_baseline_7b6348a.log` | 量測執行輸出 |
| `cover_cache_test_on_7b6348a.log` | 封面快取測試在基準上的結果（預期失敗 5 項） |

最終的基準／候選對照（以最終版測試重跑）見上層 `README.md`。
