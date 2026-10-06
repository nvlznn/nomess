# NoMess

背景常駐的 macOS 選單列小工具：從終端機複製出來、被視窗寬度硬折行的文字，在剪貼簿裡自動接回成完整段落。規格見 [docs/SPEC.md](docs/SPEC.md)。

目前是 **V0**：處理終端機硬換行，並讓圖表貼到格式文字 App 時維持對齊；只有一個開關。

## 使用

```sh
scripts/bundle.sh          # 產生 build/NoMess.app（ad-hoc 簽署，僅限本機）
open build/NoMess.app      # 選單列出現圖示，點開可切換啟用 / 結束
```

## 開發

```sh
swift test                                # 清理規則的單元測試
pbpaste | swift run nomess-clean          # 拿剪貼簿裡的真實案例試清理結果
pbpaste | swift run nomess-clean --html   # 看圖表會產生的 HTML
```

遇到漏判或誤判時，用 `nomess-clean` 重現，再把案例加進 `Tests/NoMessCoreTests/HardWrapCleanerTests.swift`。

## 結構

- `Sources/NoMessCore/HardWrapCleaner.swift`：判斷與清理規則（純邏輯，不依賴 AppKit）
- `Sources/NoMessCore/DiagramDetector.swift`：圖表偵測與 HTML 產生
- `Sources/NoMess/`：選單列 app、剪貼簿監聽、終端機 App 白名單
- `Sources/nomess-clean/`：測試用 CLI

## V0 判斷規則（保守，寧可漏判）

只在前景 App 是終端機（Terminal、iTerm2、Ghostty、WezTerm、kitty、Alacritty、Warp）時才讀剪貼簿內容；帶有密碼管理器標記（`org.nspasteboard.ConcealedType` 等）的內容一律跳過。

兩行只有在以下條件全部成立時才會接回：

- 下一行的第一個字放不進上一行（`上一行寬度 + 空白 + 下一個字寬度 > 最寬行寬度`）
- 下一行的縮排對齊上一段的文字欄（例如 `⏺ ` 底下的兩格），或跟段首縮排相同
- 下一行不是列表、標題、引用、指令提示、數字開頭（log 時間戳）
- 兩行都不像程式碼或表格（tab、連續空白、框線字元、以 `{ } ; \ :` 結尾）
- 上一行有多個字（單一 token 例如檔名、hash、網址不接）
- 沒有 `⏺`/`-` 這類標記可以依靠時，至少要有兩行接近右邊界，而且不在句尾＋大寫開頭的地方接

中日韓文字之間接回時不插入空白；``` 圍欄內一律不動。

## 圖表保持對齊

框線圖、樹狀圖（`├──`）、點字圖表（braille）、ASCII/Markdown 表格，以及用空白對齊的欄位表格，偵測到時：

- **純文字一個字都不改**，貼到終端機、編輯器拿到的跟原本一樣
- 剪貼簿另外附一份 HTML：圖表包在等寬字型的 `<pre>`，其他文字是一般段落。備忘錄、Notion、Google Docs、Mail 等格式文字 App 會用這份，圖表就不會走位

限制：只吃純文字的地方（Messenger、LINE 等）用的是比例字型，無法修正；圖表中有中日韓文字時，等寬字型的寬度不一定剛好是兩倍，可能仍有些微偏移。
