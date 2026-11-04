# Yorunote 品牌外觀改版 v0.1 — 驗證索引

- 第 1 輪（名稱／文案，當時無 Logo、無工具鏈）：`README_round1_history.md`（原文保留）、`logs/00_*`、`10_*`、`20_*`。
- 第 2 輪（圖示導入與驗證，本檔）：以下。

**名稱與角色圖示僅為工程候選：** 使用者同意以附件作工程候選、背景 #17283B；角色／素材／商標權利**未清查**，不是公開發版授權。

## 第 2 輪結果
### 來源與資產
- 原稿：`brand/source/yorunote_logo_source_1254.webp`，1254×1254 RGBA、背景透明（alpha 0..255），SHA-256 `5976edff…7ca1`。對話附件以 WebP 形式到達，原始檔名未知（非 PNG、非向量）；為點陣原稿，不宣稱向量。已實際開圖確認為角色單圖，不是介面截圖。
- 產生：`python3 -I brand/scripts/make_icons.py <repo_root>`（可重現）。雜湊：`brand/ASSET_SHA256.txt`、`brand/GENERATED_ICONS_SHA256.txt`。
- 自適應圖示：前景透明，角色寬 64dp 置中（中央 66dp 安全區內，頭像下方兩角的頭髮略出圓外，眼、耳、月亮書頁飾件皆在內）；背景 #17283B 純色；單色層以亮度決定 alpha（暗線條、眼睛、衣領鏤空），實測非整張方塊。未預烘焙圓形遮罩或陰影。
- 傳統 `ic_launcher.png`（圓角方形底）五密度；`assets/app_icon.png` 1024 方形（About 以圓形裁切）。專案未宣告 `roundIcon`，未改 manifest。
- 預覽：`brand/previews/icon_preview.png`（圓形、圓角方形、單色、安全圓標示、48／32／24px）。小尺寸下綠髮、藍眼輪廓與深底仍可辨識；24px 時月亮飾件細節消失（限制）。
- 啟動畫面：既有為純白 `launch_background`，無品牌資產可替換，未改動；Android 12+ 系統啟動畫面使用 launcher 圖示。
- README：上游「停止維護」聲明已標為上游歷史聲明，原文保留。
### 驗證（工具：Flutter 3.41.4 rev ff37bef603 / Dart 3.11.1，隔離安裝於 /opt/tc；tarball SHA-256 與官方 releases_linux.json 一致；`logs/30_*`）
| 項目 | 結果 | 日誌 |
|---|---|---|
| `flutter pub get --enforce-lockfile` | Exit 0；`pubspec.lock`／`pubspec.yaml` 無差異 | 31 |
| 修改 Dart 檔格式 | `main.dart`、`about.dart` 在基準即未通過格式（Exit 1，與基準相同，未整檔重排）；本輪新增的行與新測試檔經格式器確認無需變動 | 32 |
| `flutter analyze --no-pub` | Exit 1；8 項 info，0 warning、0 error，與基準記載相同 | 33 |
| `flutter test --no-pub test/brand` | Exit 0，4 項通過 | 34 |
| `flutter test --no-pub`（全部） | Exit 0；**277 通過、0 失敗、9 跳過**（含新增 4 項）。9 項跳過為 `reader_image_cache*` 在本機缺原生 HTTP 函式庫時的 `skip: !_hasNativeHttp`；未覆蓋範圍＝這些閱讀器圖片快取測試，與品牌無關，未擴大研究。R3.1 的 282 項為歷史結果，不可直接比較 | 35 |
| XML／JSON／20 個圖示資源引用 | 通過 | 36 |
| applicationId／namespace／簽章／workflow | 無變動（`com.github.wgh136.venera`） | git diff |
### APK：未建置
本機沒有 Android SDK／NDK／JDK 17 以外的 Android 工具（`ANDROID_HOME` 未設、找不到 sdkmanager）。安裝需接受新的授權條款，依指示停止該步。故無 APK、無 manifest／ABI／簽章／SHA-256 檢查，也未建立測試金鑰。可於具備既有 Android 工具鏈的環境（例如先前 CI 做法：一次性測試金鑰、`flutter build apk --profile --target-platform android-arm64 --split-per-abi --no-pub`）補做。
### 待使用者實機驗收（S25+／Tab S11）
桌面圖示（一般、主題單色圖示、不同啟動器遮罩形狀）、名稱 Yorunote、About 頁頭像與文案（簡／繁／英）、深淺色背景下辨識度。均**未實測**。
### 未完成
APK 建置與檢查；實機驗收；權利／授權清查；其他平台名稱與圖示；新 applicationId／簽章／遷移。
### 回復
```bash
git revert --no-edit <本輪 Commit SHA>
```
