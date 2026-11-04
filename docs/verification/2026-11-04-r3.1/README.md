# Venera R4-A + R2 + R3 + R3.1 驗證保存（2026-11-04）

本目錄保存已驗證候選版的補丁、報告與必要日誌。原始碼位於本分支第一個 Commit；本目錄只含文件與文字紀錄。**這是保存，不是新的功能開發。**

## 基準與來源
- 固定基準：`51de19d66a10c23e76e1948e96c2ff3344224a62`
- 來源差異：相對基準共 16 檔（9 修改、7 新增測試），無刪除、無權限變更；`pubspec.lock`、`pubspec.yaml` 與 workflow 均未變動。
- 累積補丁：`patches/ALL_FIXES_FROM_51de19d.patch`，SHA-256 `d2b455edddb5dba33c04fad0aa9b95e258d048980dcf06cf19ee0edb67feed95`；四份原始補丁依序為 R4-A、R2、R3、R3.1，雜湊見 `patches/*.sha256`。
- 保存時使用的來源 ZIP（未提交）SHA-256：`eca3911b68b1e134a4528ff1ef7d07a1569067d7f8a92ef22f78a365e3283702`（331 檔）；本分支 331 個來源檔案與其位元組、權限一致，清單見 `SOURCE_MANIFEST.sha256`（SHA-256、八進位權限、路徑）。

## 結果來源標示
以下均為**附件報告與日誌記載**（`reports/`、`logs/`），不是本次保存工作重新執行：
- 完整測試：282 項通過，0 失敗，0 跳過（`logs/qa/45_full_test_native_final.log`）。第一次執行因主機缺少 SQLite 載入名稱失敗，原始日誌 `40_…` 保留。
- Analyzer：Exit 1，8 項既有 info，0 warning、0 error。
- 格式檢查：Exit 1；6 個檔案在基準也未通過，**不宣稱格式全數通過**。
- ARM64 Profile APK 已成功建置並完成技術檢查（badging、簽章、zipalign、ELF）：檔名 `Venera_R3_1_arm64_profile.apk`，SHA-256 `4193a7bf69339e7b2e62d8473f12aac40bb8459609d479029ec58d3fe1aa7799`，簽章為一次性測試金鑰。**APK 本身不在儲存庫中。**
- `OWNER_REPORTED`：使用者於本次對話回報 S25+／Tab S11 實機驗收目前沒有問題。這是使用者的回報，不是 Claude 獨立操作裝置；未量測也不推論 FPS、記憶體或耗電改善。

## 本次保存工作重新執行的檢查
附件與壓縮檔雜湊、壓縮檔路徑安全性、內附 `SHA256SUMS.txt`；累積補丁 `git apply --check` 與套用；331 個來源檔案與來源 ZIP 逐位元組／權限比對；提交內容的秘密掃描。未重跑測試、analyzer、格式或建置。

## 歷史紀錄
`logs/handoff/10_…`、`11_…`、`12_…` 與 `reports/BUILD_HANDOFF.md` 記載當時 Maven Central HTTP 429 造成的建置失敗，以及「尚未建置、尚未實機測試」的狀態；它們是歷史證據，未改寫。之後的成功建置見 `reports/INDEPENDENT_REVIEW.md`。

## 未保存的內容
APK、各類 ZIP（交接包、QA 包、證據包）、建置輸出、依賴快取、簽章金鑰與 `key.properties`。`reports/DELIVERY_PRIVACY_CHECK.json` 記載原交付包不含私鑰與 key.properties。

## 還原
```bash
git clone https://github.com/mengwen-liu/venera
cd venera
git checkout claude/venera-r31-backup-20261104
```
或在基準上重現：`git checkout --detach 51de19d66a10c23e76e1948e96c2ff3344224a62 && git apply docs/verification/2026-11-04-r3.1/patches/ALL_FIXES_FROM_51de19d.patch`（需先取得補丁檔）。
完整性：`EVIDENCE_SHA256SUMS.txt` 為本目錄其餘檔案的 SHA-256（在本目錄執行 `sha256sum -c EVIDENCE_SHA256SUMS.txt`）。
