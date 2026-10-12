# LocalWrite 與 Typeless 的差距及修改計畫 — 2026-10-13

對照基準（Typeless 的行為）：

- **Mac：** 按住一個鍵（預設 Fn）說話，放開即填入；連按兩下可免持續錄。任何 App 都能用，包括 Slack、Chrome 及其他網頁或 Electron 輸入框。AI 會移除贅字、重複與自我更正（「明天，不對，後天」→「後天」），整理條列，並保留你的語氣。
- **iOS 鍵盤：** 真正的鍵盤裡有一顆說話按鈕。空心麥克風表示需要先開一次 App 取得麥克風；實心麥克風表示可直接在原本的輸入框聽寫，不會切換（[Typeless 說明](https://www.typeless.com/help/release-notes/ios/when-does-app-switching-happen)）。切換過那一次之後，之後每次聽寫都留在原本的 App。結果可以先潤稿或翻譯再填入。

## iOS 鍵盤目前為何無法使用

1. **每次聽寫都會離開原本的 App。** 麥克風會透過 Link 開啟 LocalWrite 錄音，使用者必須滑回原 App 再點一次。每次出結果後，App 都會關閉音訊工作階段（`KeyboardVoiceHelper.stopCapture`，且 `KeyboardVoiceHelper.swift` 的 `tick()` 刻意忽略 `.start` 指令），所以下一次聽寫又得跳轉。Typeless 是每個工作階段跳一次，不是每句跳一次。
2. **最根本的需求訂錯了。** `Documentation/Keyboard-Requirements.md` 要求冷啟動時第一次點擊就能錄音、完全不開 App。iOS 鍵盤擴充功能無法使用麥克風，所以沒有任何 App 做得到，Typeless 也一樣。Codex 為了追一個做不到的需求，把唯一可行的設計（在背景保持暖機的工作階段）拿掉了。
3. **結果常常被拒絕填入。** 只有在 `documentContextBeforeInput`／`AfterInput` 與切換前逐字完全相同時才會填入（`KeyboardViewController.swift:184`）。原 App 在切換後常會回傳不同或被截斷的前後文，結果因此被無聲取消。裝置紀錄顯示有一筆從未被取用的待處理請求。
4. **它稱不上是鍵盤。** 只有刪除、麥克風、換行三個鍵。沒有空白、標點、地球鍵、逐字稿預覽、復原，也沒有潤稿／翻譯選擇。`needsInputModeSwitchKey` 被忽略。
5. **App 與鍵盤之間的溝通很脆弱。** 兩邊每 100–150 ms 輪詢 JSON 檔，心跳 4 秒；稍微卡頓就會取消工作階段。
6. **模型忙碌時直接失敗。** Foundation Models 無法使用（或在背景被限流）時，整次聽寫失敗，而不是填入原始逐字稿。

## Mac 的差距

1. **再按一次快捷鍵會取消而不是完成**（`LocalWriteController.toggleListening`）：你說的話被丟掉。只有靜音 1.25 秒自動停止（`SpeechSession.tick`）才會完成，常在話說到一半時被切斷。
2. **沒有按住說話。** 只有 Carbon 的 Option+Space 切換；這種方式偵測不到 Fn 和放開按鍵。
3. **大多數輸入框都被拒絕。** 填入要求 AX 角色必須是 TextField／TextArea／ComboBox，所以網頁和 Electron App（Slack、Chrome、Notion）都會顯示「找不到輸入框」。
4. **「AI 潤稿」實際上只改標點。** `RefinementPolicy.preserveWording` 只要有任何字被改動就還原成原文，唯一例外是開頭的單一個「嗯／呃／um」。句中的贅字、重複和自我更正從來不會被移除。
5. 沒有翻譯模式、不能選語言（寫死 zh-TW）、沒有個人字典、沒有歷史紀錄。

## 計畫（依優先順序）

v1 範圍（nina，2026-10-12）：介面像 Typeless 一樣乾淨簡約；只做語音整理和翻譯。iOS 上的產品是鍵盤擴充功能，任何 App 都能用；主 App 只用來維持麥克風工作階段和設定，這是 iOS 的規定。

整理和翻譯在 Mac 與 iOS 上都使用 Apple 的 Foundation Models 框架（`SystemLanguageModel`），不使用其他模型或伺服器。iOS 上模型在 LocalWrite App 的暖機工作階段裡執行，而不是在鍵盤擴充功能裡，因為鍵盤的記憶體上限太小，載不了模型。如果 App 在背景時 Foundation Models 無法使用或被限流，LocalWrite 會填入原始逐字稿並說明，而不是改用其他模型。

### 第一階段：讓 iOS 鍵盤能用（Typeless 式暖機工作階段）

1. **App 內的暖機工作階段。** 第一次點麥克風（空心）會開一次 LocalWrite；App 啟動 `AVAudioSession`（`.playAndRecord`、`.mixWithOthers`），並讓 `AVAudioEngine` 在背景持續運作（使用既有的 `audio` 背景模式），閒置時丟棄音訊。App 顯示「滑回原本的 App」，鍵盤麥克風變成實心。工作階段持續時間由使用者選擇（5 分鐘／15 分鐘／1 小時／直到停止），遇到中斷就結束，橘色麥克風指示燈會一直亮著，誠實告知使用者。
2. **暖機期間直接聽寫。** 鍵盤點擊 → `start` 指令 → App 在運作中的音訊引擎上開始辨識；再點一次 → `finish` → 潤稿 → 結果。不會切換 App。
3. **事件驅動的溝通。** 狀態仍用 App Group 檔案保存，但改用 Darwin 通知（`CFNotificationCenterGetDarwinNotifyCenter`）通知對方，取代 150 ms 輪詢；放寬心跳限制。
4. **可靠的填入。** 只要文件識別碼相符就填入；拿掉前後文必須逐字相同的檢查。保留一次性領取，避免重複填入。
5. **簡約鍵盤介面（v1 範圍：只有整理和翻譯）。** 一顆大麥克風，上方顯示即時逐字稿；整理／翻譯二選一切換（目標語言在 App 裡設定）；另外只有空白、刪除（長按連續刪）、換行，以及在 `needsInputModeSwitchKey` 時顯示的地球鍵。v1 沒有歷史紀錄、字典或其他按鍵列。
6. **備援。** 模型無法使用或出錯時，填入原始逐字稿並說明。
7. 依暖機工作階段改寫 `Keyboard-Requirements.md` 的驗收標準；在 iPhone 實機測試。

### 第二階段：整理品質（Mac 與 iOS 共用）

1. 把「全有或全無」的逐字檢查換成有防護的規則：允許刪除任何位置的贅字、重複字和自我更正；仍拒絕新增內容、未要求的翻譯或摘要（以長度／新詞檢查）。
2. 潤稿與翻譯使用 `@Generable` 結構化輸出；翻譯模式可指定目標語言。
3. 把 `Scripts/EvaluateRefinement.swift` 擴充為固定的繁中／英文／中英混合測試語料，修改須通過才能合併。

### 第三階段：Mac 對齊

1. 透過 `CGEventTap`／`flagsChanged` 實作按住說話（Fn 或右 Option），放開即完成；連按兩下免持續錄；再按一次是完成而非取消；按住期間不因靜音自動停止。
2. 任何地方都能填入：先試 AX，不行就貼到最前面的 App 並還原剪貼簿（`TextInserter` 已實作），只拒絕密碼欄位。
3. 原始逐字稿備援，以及選單列中的整理／翻譯選擇；v1 不加其他功能。

## 需要你決定

暖機工作階段代表每個工作階段的第一次聽寫會開一次 LocalWrite，你再滑回原 App；之後的聽寫都留在原 App。這就是 Typeless 的做法，也是 iOS 唯一允許的方式，但和 2026-10-11「完全不開 App」的需求相衝突。
