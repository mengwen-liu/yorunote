# Yorunote 合成漫畫來源

受控網路驗收用的測試來源與伺服器。所有內容（清單、詳情、章節、封面、閱讀頁）都由程式產生，不含真實漫畫、帳號、Cookie 或閱讀紀錄。

| 檔案 | 用途 |
|---|---|
| `serve.dart` | 在電腦啟動伺服器：`dart run tool/synthetic_source/serve.dart [--host H] [--port N] [--public-url URL] [--list-interfaces]` |
| `synthetic_server.dart` | 伺服器本體（純 `dart:io`），測試也直接匯入 |
| `yorunote_synthetic_source.js` | 漫畫來源腳本；伺服器在 `/source.js` 提供已填入位址的版本 |

- 綁定非迴路位址時必須給 `--public-url`；工具不猜測區域網路位址。
- 控制端點與計數：`/__control/*`、`/__stats`、狀態頁 `/`（說明見 `synthetic_server.dart` 開頭）。
- 雲端驗證：`test/network/synthetic_source_test.dart`（需主機版 `librhttp.so` 與 `libflutter_qjs_plugin.so`）。
- 實機操作流程：`docs/verification/thumbnail-r2-20261105/ACCEPTANCE_SYNTHETIC.md`。
