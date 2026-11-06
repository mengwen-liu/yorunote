# Windows 精靈動畫與滑鼠提示：使用者確認

- 回報日期：2026-11-07（Asia/Taipei）。
- 對應本對話提供的修正版：`07406c9f6a6d105fd854cb3ddc22cfcc6dacfd9b`。
- 提供的檔案：`Yorunote_windows_x64_07406c9f_preview.zip`。
- 使用者原文：「有的 確認精靈與滑鼠提示正常」。
- 分類：**OWNER_REPORTED（使用者實機回報）**。
- 確認範圍：左上角精靈動畫與滑鼠提示。
- 使用者同時提供執行畫面，可見左上角角色圖示；靜態截圖本身不能證明動畫播放或滑鼠提示行為，這兩項以使用者明確回報為據。
- 未從使用者電腦回讀 ZIP／執行檔雜湊、Windows 版本或裝置規格；不能將這次回報延伸為所有功能、全部漫畫來源、所有 DPI／多螢幕或長時間使用均通過。
- 公開紀錄不附使用者的私人漫畫畫面、書名、來源、收藏或閱讀紀錄。

## 既有工程證據

- [建置與原生驗收 run 42229100772](https://github.com/mengwen-liu/yorunote/actions/runs/42229100772)。
- [另行下載核對 run 42231651219](https://github.com/mengwen-liu/yorunote/actions/runs/42231651219)。
- [修正、指定測試與限制](README.md)。
- [成品與原生驗收數值](ARTIFACT_VERIFICATION.json)。

上述是既有 CI 結果；本次記錄回報沒有重跑 App 測試或重新建置。公開發行狀態另外記錄，不以本文件表示已發布。

## English

On 2026-11-07 (Asia/Taipei), the user explicitly confirmed that the elf animation and mouse tooltip work normally in the supplied Windows candidate. This is a user-reported check of those two UI behaviors, separate from CI verification. A screenshot shows the character, but cannot establish animation or hover behavior on its own. No hash was read from the user's computer, and no broader device acceptance is claimed. Private reading content is not included.
