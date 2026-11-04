# 受控網路實機驗收流程（合成漫畫來源）

適用：本輪 CI 建出的 `Yorunote_cee5b03_thumbnail_r2_arm64_profile.apk`（SHA-256 `ad0d73c3b1ca5dd062086c32db8208ec11814ebe791bf890a38453a9252b475b`，見 `README.md` §8）安裝在 S25+／Tab S11 等 ARM64 裝置。安裝前在電腦以 `sha256sum` 核對雜湊。

**本流程尚未有人在實機執行。** 雲端只驗證了：合成來源經 App 的匯入程式碼載入、在主機版 QuickJS 中執行、封面／閱讀頁經 rhttp 與真實 provider 載入（`test/network/synthetic_source_test.dart`，8 項）。三星實機上的結果請另行記錄。

全部內容由 `tool/synthetic_source/` 產生：漫畫清單、詳情、章節、封面、閱讀頁都是程式畫出的色塊。不使用真實漫畫、帳號、Cookie 或閱讀紀錄。

## 0. 簽章與安裝前提

- APK 以 CI 一次性測試金鑰簽署，與先前所有 APK（含前輪 `f300eecd…`）憑證不同。若裝置已有 `com.github.wgh136.venera`，會因簽章不同而無法覆蓋安裝。**不要為了驗收卸載或清除既有資料**；請改用未安裝此套件的裝置或使用者設定檔。無可用環境時，記錄為「受簽章限制未驗收」。
- 合成來源只連到你啟動的合成伺服器，不影響其他來源；測試後依 §6 移除。

## 1. 在電腦啟動合成伺服器

需求：本分支的程式碼、Dart 3.11（Flutter 3.41.4 內含）。

### 方案 A：USB + `adb reverse`（建議）

```bash
dart run tool/synthetic_source/serve.dart --port 8765
```

```bash
adb reverse tcp:8765 tcp:8765
```

- 裝置上的 `127.0.0.1:8765` 會由 adb 轉到電腦的 `127.0.0.1:8765`；只有執行了 `adb reverse` 的那台裝置有效。
- 限制：需開啟 USB 偵錯並授權此電腦；拔線或 adb 重新啟動後需重做；多台裝置各自設定。
- 來源網址：`http://127.0.0.1:8765/source.js`

### 方案 B：同一區域網路

1. 自行確認電腦在該 Wi‑Fi 上的位址（可用下列指令列出本機介面，**由你選擇**，工具不會猜測）：

```bash
dart run tool/synthetic_source/serve.dart --list-interfaces
```

2. 以該位址啟動（`<電腦位址>` 換成你選的位址）：

```bash
dart run tool/synthetic_source/serve.dart --host 0.0.0.0 --port 8765 --public-url http://<電腦位址>:8765
```

- 未給 `--public-url` 時，綁定非迴路位址會直接拒絕啟動。
- 電腦防火牆需允許 TCP 8765；裝置與電腦需在同一網段。
- 不要在裝置上使用 `127.0.0.1`：那是裝置自己，不是電腦。

### 確認伺服器

在電腦瀏覽器開 `http://127.0.0.1:8765/`（狀態頁，每 2 秒更新）或：

```bash
curl -s http://127.0.0.1:8765/__stats
```

欄位：`image_requests`（圖片請求總數）、`active_image_requests`（目前進行中）、`peak_active_image_requests`（峰值並行）、`per_path`（每個路徑的請求次數）。伺服器終端機也會在數字變化時印一行摘要。

## 2. 匯入測試來源

App →「設定」→「漫畫源」→「添加漫畫源」→ 輸入 §1 的來源網址 → 確認。成功後出現「Yorunote 合成測試來源」，探索頁有「合成封面測試」。

- App 的網路請求走 rhttp（Rust 原生 socket），不經 Android 的明文 HTTP 政策；本輪**未修改**任何網路安全設定。若裝置上 `http://` 匯入被擋，請記錄錯誤訊息，不要放寬整個 App 的政策。此點未在實機驗證。

## 3. 控制指令（在電腦執行）

| 目的 | 指令 |
|---|---|
| 每張圖延遲 800 ms | `curl -s "http://127.0.0.1:8765/__control/delay?ms=800"` |
| 暫停所有圖片回應 | `curl -s http://127.0.0.1:8765/__control/pause` |
| 放行 | `curl -s http://127.0.0.1:8765/__control/release` |
| 讓 c2x 封面回 500 | `curl -s "http://127.0.0.1:8765/__control/fail?match=/img/cover/c2&status=500"` |
| 讓 c3x 封面變壞圖 | `curl -s "http://127.0.0.1:8765/__control/broken?match=/img/cover/c3"` |
| 解除所有錯誤規則 | `curl -s http://127.0.0.1:8765/__control/recover` |
| 全部重設（含計數） | `curl -s http://127.0.0.1:8765/__control/reset` |

方案 B 時把 `127.0.0.1` 換成 `<電腦位址>`（在電腦上執行時兩者皆可）。

## 4. 情境、預期與失敗判準

每個情境開始前先 `__control/reset`。「首次」指這些合成封面尚未進過 App 磁碟快取。

| # | 操作 | 預期畫面 | 伺服器預期 | 失敗判準 |
|---|---|---|---|---|
| 1 冷載與並行 | `delay?ms=800` 後開「探索 → 合成封面測試」並往下捲到第 2 頁 | 封面陸續出現，無崩潰 | `peak_active_image_requests` ≤ 8；每張封面 `per_path` 為 1 | 峰值 > 8；同一封面 > 1；崩潰／ANR |
| 2 快取命中 | 完全關閉 App 再開，回到同一頁 | 封面立即顯示 | `image_requests` 不增加 | 已顯示過的封面再次被請求 |
| 3 暫停時快取仍可顯示 | `pause` 後捲到尚未載入的區域（例如第 2 頁後段），再捲回第 1 頁 | 第 1 頁封面照常顯示；新區域轉圈 | `active_image_requests` 停在 ≤ 8；第 1 頁路徑不增加 | 第 1 頁封面也卡住 |
| 4 放行 | 接著 `release` | 轉圈的封面補齊 | 計數增加、active 回到 0 | 永久空白 |
| 5 失敗後重試 | `fail?match=/img/cover/c2&status=500` 後首次開第 2 頁 c20–c29；看到錯誤後 `recover`，離開再進入該頁 | 先顯示錯誤圖示（App 對 500 會先重試數次，約十多秒），恢復後重新進入即顯示 | `/img/cover/c2x.png` 次數在恢復後再增加 | 恢復後仍持續錯誤 |
| 6 壞圖恢復 | `broken?match=/img/cover/c3` 後首次開 c30–c36；看到錯誤後 `recover`，離開再進入 | 先錯誤，恢復後正常 | 恢復後各路徑再請求 1 次 | 恢復後仍顯示錯誤（壞快取未失效） |
| 7 onResponse | 看 c37（副標「onResponse 封面」） | 正常彩色封面 | `/img/cover/c37.png` 1 次 | c37 顯示錯誤 |
| 8 `cover.` 佔位 | 看 c38（副標「cover. 佔位封面」） | 正常封面 | `/api/comic/c38` 與 `/img/cover/c38.png` 各 1 次 | c38 顯示錯誤 |
| 9 閱讀頁 | 開 c03 → 第 1 話 | 5 張灰階條紋頁 | `/img/page/c03/1/*.png` 各 1 次 | 頁面無法載入 |
| 10 同鍵合併（觀察） | 從未看過的漫畫（例如 c39）進詳情再返回，使它同時出現在歷史列與探索列表 | 兩處封面相同 | `/img/cover/c39.png` 為 1 | 同一封面 ≥ 2（僅在兩處同時首次載入時有意義） |

限制：
- **取消**在 App 中只有圖片被 ImageCache 逐出時才會觸發（單純捲走不會取消進行中的載入），實機上難以直接觀察；取消行為以主機整合測試為準（`README.md` §2）。
- 在等待回應標頭（headers）階段被取消的請求，會等到標頭到達才關閉（rhttp 0.15.1 限制，見 `README.md` §2.3）；`pause` 期間取消的請求會在 `release` 後才結束。

## 5. 記錄

| 欄位 | 內容 |
|---|---|
| 裝置／Android 版本 | |
| APK SHA-256 | |
| 連線方式 | 方案 A／B |
| 各情境 | 通過／失敗／未執行（原因） |
| `__stats` 輸出 | 每個情境結束時一份 |
| 異常 | 現象、步驟、`adb logcat` 片段（移除私人路徑） |

## 6. 結束與清理

1. App →「設定」→「漫畫源」→ 刪除「Yorunote 合成測試來源」。
2. 電腦伺服器終端機按 Ctrl+C。
3. 方案 A：

```bash
adb reverse --remove tcp:8765
```

合成封面留在 App 的磁碟快取中，會依快取設定自然過期；本流程不要求清除任何使用者資料。
