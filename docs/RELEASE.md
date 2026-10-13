# NoMess 上架指南

兩條路都需要 **Apple Developer Program**（US$99／年，<https://developer.apple.com/programs/>）。
建議順序：**先自行發佈（官網下載）→ 穩定後再上 Mac App Store**。

| | 自行發佈（Developer ID + 公證） | Mac App Store |
|---|---|---|
| 審核 | 只有自動化的公證掃描，通常幾分鐘 | 人工審核，數天，可能被退 |
| 沙盒（App Sandbox） | 不需要 | 必須 |
| 專案 | 目前的 SwiftPM + `scripts/bundle.sh` 就能用 | 需要 Xcode 專案（app target） |
| 更新 | 自己做（建議 Sparkle） | App Store 自動更新 |
| 收費 | 自選金流（Paddle、Lemon Squeezy 等） | Apple 抽 15%（小型開發者方案）～30% |
| 曝光 | 靠自己（nomess.noky.dev） | App Store 搜尋 |

---

## 0. 兩條路都要先補的東西

1. **剪貼簿隱私提示（最重要）**
   新版 macOS 會在 app 未經使用者「貼上」動作、用程式讀取剪貼簿時跳出提示，而 NoMess 正是這樣運作的。
   - 用 `NSPasteboard` 新的 `detect` 系列 API 先判斷剪貼簿裡有沒有文字（不會觸發提示），再決定要不要讀內容
   - 讀取 `NSPasteboard.accessBehavior`，被拒絕時在選單列顯示「需要允許讀取剪貼簿」並引導到系統設定
   - 測試方式：`defaults write dev.noky.nomess EnablePasteboardPrivacyDeveloperPreview -bool yes`，重開 NoMess
2. **開機自動啟動**：選單加「登入時啟動」，用 `SMAppService.mainApp.register()`（沙盒內也可用）
3. **第一次啟動的說明**：NoMess 讀什麼（只有從終端機複製的內容）、做什麼、資料不離開這台 Mac
4. **隱私權政策與支援頁**：例如 `nomess.noky.dev/privacy`、`nomess.noky.dev/support`（App Store 必填，自行發佈也建議有）
5. **macOS 26 的 icon**：舊式 `.icns` 若有陰影或超出新遮罩的像素，會被縮小放進灰色圓角方框。用 Xcode 附的 **Icon Composer** 製作 `.icon`（分層：背景漸層、三條線、星芒），舊系統繼續用 `Resources/AppIcon.icns`
6. **名稱**：規格書提到的 LessMess 要先確認定位不重疊；上 App Store 前確認「NoMess」這個名稱還沒被使用

---

## A. 自行發佈（建議先走這條）

1. **加入 Apple Developer Program**，記下 Team ID（Membership 頁面）
2. **建立「Developer ID Application」憑證**
   Xcode → Settings → Accounts → 選帳號 → Manage Certificates → ＋ → Developer ID Application
3. **用 hardened runtime 簽署**
   ```sh
   scripts/bundle.sh
   codesign --force --options runtime --timestamp \
     --sign "Developer ID Application: 你的名字 (TEAMID)" build/NoMess.app
   ```
4. **儲存公證用的登入資訊**（在 appleid.apple.com 產生 App 專用密碼）
   ```sh
   xcrun notarytool store-credentials nomess \
     --apple-id 你的AppleID --team-id TEAMID --password App專用密碼
   ```
5. **打包並送公證**
   ```sh
   ditto -c -k --keepParent build/NoMess.app build/NoMess.zip
   xcrun notarytool submit build/NoMess.zip --keychain-profile nomess --wait
   ```
6. **把公證結果釘進 app，再重新打包給使用者下載**
   ```sh
   xcrun stapler staple build/NoMess.app
   ditto -c -k --keepParent build/NoMess.app build/NoMess.zip
   ```
   （想要拖曳安裝的視窗，可改做 DMG：`hdiutil create -volname NoMess -srcfolder build/NoMess.app -ov -format UDZO build/NoMess.dmg`，DMG 本身也要簽署、公證、staple）
7. **驗證**：`spctl -a -vvv build/NoMess.app` 應顯示 `source=Notarized Developer ID`
8. **放上網站**：在 `nomess.noky.dev` 做下載頁（例如部署到 Vercel），附上系統需求與隱私說明
9. **自動更新**：整合 [Sparkle](https://sparkle-project.org)，產生 EdDSA 金鑰、在網站放 `appcast.xml`

步驟 3–7 可以整合成 `scripts/release.sh`，之後每次發版一個指令完成。

---

## B. Mac App Store

1. **建立 Xcode 專案**：新增 macOS App target，把 `NoMessCore` 當成本地 Swift Package 依賴，搬入 `Sources/NoMess/` 的程式；設定
   - Bundle ID `dev.noky.nomess`、版本號
   - `LSUIElement = YES`（只在選單列）
   - App Category：Productivity 或 Developer Tools
   - App icon（Icon Composer 的 `.icon` 或 asset catalog）
2. **開啟 App Sandbox**（Signing & Capabilities），重新測一次：讀寫剪貼簿、判斷前景 App、切換 App 時替換剪貼簿都要正常
3. **App Store Connect** → My Apps → ＋ New App，填：
   - 名稱、主要語言、Bundle ID、SKU
   - 價格與地區
   - App 隱私：「不收集資料」（NoMess 不傳任何資料出去）
   - 隱私權政策網址、支援網址
   - 描述、關鍵字、截圖（至少一張 1280×800、1440×900、2560×1600 或 2880×1800）
4. **上傳**：Xcode → Product → Archive → Distribute App → App Store Connect
   （可先用 TestFlight for Mac 給朋友測）
5. **送審**：在審核備註寫清楚
   - NoMess 為什麼要在背景讀剪貼簿、只在前景是終端機時讀、內容不離開裝置
   - 給審核員的測試步驟（例如：在 Terminal 執行 `cat` 一個附上的範例檔 → 複製 → 貼到備忘錄）
   常見退件點：沒有說明剪貼簿用途、自動開機啟動沒有經過使用者同意、選單列 app 缺少「結束」選項（NoMess 已有）
