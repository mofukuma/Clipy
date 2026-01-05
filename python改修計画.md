# Clipy Python実行機能 実装計画（改訂版）

## 概要

スニペット機能に、行頭が `# python` で始まるスニペットを実行する機能を追加する。

### 実装例

**基本的な使い方:**
```
# python
print("hello world")
```
→ `hello world` が貼り付けられる

**Clipy履歴データを活用:**
```
# python
# clipy.get_clip(0) で履歴0番（最新）のテキストを取得
text = clipy.get_clip(0)
# DeepL APIで翻訳（例）
import urllib.request, urllib.parse, json
url = "https://api-free.deepl.com/v2/translate"
data = urllib.parse.urlencode({"text": text, "target_lang": "EN", "auth_key": "YOUR_KEY"})
result = json.loads(urllib.request.urlopen(url, data.encode()).read())
print(result["translations"][0]["text"])
```
→ 最新のクリップボード履歴が英訳されて貼り付けられる

**履歴への追加:**
```
# python
import datetime
timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
clipy.add_clip(f"生成時刻: {timestamp}")
print("履歴に追加しました")
```
→ タイムスタンプがClipyの履歴に追加される

---

## 現状分析

### スニペットの実装フロー

1. **データモデル**: `CPYSnippet.content` (String) にスニペット内容を保存
2. **選択処理**: `AppDelegate.selectSnippetMenuItem()` で選択されたスニペットを処理
3. **貼り付け**: `PasteService.copyToPasteboard(with:)` → `PasteService.paste()` で貼り付け

### クリップボード履歴の実装

- **データ保存**: RealmSwift (`CPYClip`) + NSKeyedArchiver (`.data`ファイル)
- **履歴取得**: `Realm().objects(CPYClip.self).sorted(byKeyPath: "updateTime")`
- **データ復元**: `NSKeyedUnarchiver.unarchiveObject(withFile:)` → `CPYClipData`
- **履歴追加**: `ClipService.create(with: image)` または内部の `save(with: CPYClipData)`

### 修正が必要な箇所

- **AppDelegate.swift:110-125** - スニペット選択時の処理
  - 現在: `snippet.content` をそのまま貼り付け
  - 修正後: Pythonコード判定 → 実行（Clipy APIあり） → 結果を貼り付け

---

## 実装方針

### 1. Python実行環境の選択

**採用: ユーザーの既存Python環境を活用（システムPython/Homebrew/Anaconda）**

| アプローチ | メリット | デメリット | 選定理由 |
|----------|---------|-----------|---------|
| **A. ユーザーのPython（採用）** | ・アプリサイズ増加なし<br>・ユーザーの既存環境活用<br>・pipパッケージ利用可能 | ・環境依存 | ✅ VSCode方式で選択可能に |
| B. バンドルPython | ・完全自己完結 | ・アプリサイズ+50MB<br>・外部パッケージ不可 | ❌ サイズ増加、柔軟性低 |
| C. PythonKit | ・Swift統合が綺麗 | ・環境依存は同じ<br>・Clipy API橋が複雑 | ❌ 後述のStdin/Stdout方式が簡単 |

**実装方針:**
- デフォルト: `/usr/bin/python3`（macOS標準）
- 設定でPythonパス変更可能（`/opt/homebrew/bin/python3`, `~/anaconda3/bin/python` など）
- VSCodeのように「Python実行環境を選択」UI提供

### 2. Clipy↔Python間のAPI橋の設計

**採用: Stdin/Stdout JSON-RPC方式**

Pythonスクリプト実行時に、標準入力でClipyが提供するAPI関数を渡し、標準出力でやり取りする。

**API仕様:**

| API関数 | 説明 | 戻り値 |
|--------|-----|-------|
| `clipy.get_clip(index)` | 履歴N番のテキストを取得 | String |
| `clipy.get_clip_data(index)` | 履歴N番の詳細データ取得 | Dict (type, text, image, files) |
| `clipy.add_clip(text)` | テキストを履歴に追加 | Bool (成功/失敗) |
| `clipy.get_clip_count()` | 履歴の総数を取得 | Int |

**技術方式比較:**

| 方式 | メリット | デメリット | 選定 |
|-----|---------|-----------|-----|
| **Stdin/Stdout JSON-RPC** | ・実装簡単<br>・依存なし<br>・デバッグ容易 | ・若干オーバーヘッド | ✅ 採用 |
| XPC Service | ・macOS標準<br>・セキュア | ・実装複雑<br>・Pythonから呼びにくい | ❌ |
| HTTP localhost API | ・言語非依存 | ・ポート管理必要<br>・セキュリティ | ❌ |
| PythonKit経由 | ・直接呼び出し | ・PythonKitの制約<br>・環境依存 | ❌ |

**選定理由: Stdin/Stdout JSON-RPC**
- Pythonスクリプトに`clipy`モジュール（埋め込み）を自動注入
- `print()`の出力は通常通り取得
- `clipy.get_clip(0)`などはJSON-RPCでSwift側に問い合わせ
- 実装がシンプルで、既存のProcess APIをそのまま活用可能

---

## 実装詳細

### Phase 1: Python実行サービスの作成

#### 新規ファイル: `Clipy/Sources/Services/PythonExecutionService.swift`

```swift
import Foundation
import RealmSwift

final class PythonExecutionService {

    // MARK: - Properties
    private var pythonPath: String {
        // UserDefaultsから設定を取得、デフォルトは /usr/bin/python3
        let defaults = AppEnvironment.current.defaults
        return defaults.string(forKey: Constants.Python.pythonPath) ?? "/usr/bin/python3"
    }

    private let clipyAPIModule = """
        import sys
        import json

        class ClipyAPI:
            def __init__(self):
                pass

            def _rpc_call(self, method, params):
                \"\"\"ClipyにJSON-RPCリクエストを送信\"\"\"
                request = {"method": method, "params": params}
                print("__CLIPY_RPC__" + json.dumps(request) + "__END__", file=sys.stderr, flush=True)
                # Clipyからのレスポンスを待つ（stderrから読み取る想定）
                response_line = sys.stdin.readline().strip()
                if response_line.startswith("__CLIPY_RESPONSE__"):
                    response_json = response_line.replace("__CLIPY_RESPONSE__", "").replace("__END__", "")
                    response = json.loads(response_json)
                    if "error" in response:
                        raise Exception(response["error"])
                    return response.get("result")
                return None

            def get_clip(self, index):
                \"\"\"履歴N番のテキストを取得\"\"\"
                return self._rpc_call("get_clip", [index])

            def get_clip_data(self, index):
                \"\"\"履歴N番の詳細データを取得\"\"\"
                return self._rpc_call("get_clip_data", [index])

            def add_clip(self, text):
                \"\"\"テキストを履歴に追加\"\"\"
                return self._rpc_call("add_clip", [text])

            def get_clip_count(self):
                \"\"\"履歴の総数を取得\"\"\"
                return self._rpc_call("get_clip_count", [])

        # グローバル変数として clipy を提供
        clipy = ClipyAPI()
        """

    // MARK: - Execution

    /// Pythonコードを実行して結果を返す（Clipy APIサポート付き）
    func execute(_ code: String) -> Result<String, Error> {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let inputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: pythonPath)
        // -u: unbuffered output（リアルタイム出力）
        // -c: inline code execution
        let fullCode = clipyAPIModule + "\n" + code
        process.arguments = ["-u", "-c", fullCode]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = inputPipe

        var outputBuffer = ""
        var errorBuffer = ""

        do {
            try process.run()

            // 非同期でエラー出力を監視（RPC呼び出しを検出）
            let errorHandle = errorPipe.fileHandleForReading
            errorHandle.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }

                if let line = String(data: data, encoding: .utf8) {
                    errorBuffer += line

                    // RPC呼び出しを検出
                    if let rpcCall = self.extractRPCCall(from: errorBuffer) {
                        // RPC処理
                        if let response = self.handleRPCCall(rpcCall) {
                            let responseData = "__CLIPY_RESPONSE__\(response)__END__\n".data(using: .utf8)!
                            inputPipe.fileHandleForWriting.write(responseData)
                        }
                        // バッファからRPC部分を削除
                        errorBuffer = errorBuffer.replacingOccurrences(
                            of: "__CLIPY_RPC__\(rpcCall)__END__",
                            with: ""
                        )
                    }
                }
            }

            process.waitUntilExit()
            errorHandle.readabilityHandler = nil

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            // エラーバッファからRPC部分以外を抽出
            let cleanedError = errorBuffer.replacingOccurrences(
                of: #"__CLIPY_RPC__.*?__END__"#,
                with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            if process.terminationStatus == 0 {
                return .success(output.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                let error = cleanedError.isEmpty ? "Unknown error" : cleanedError
                return .failure(PythonExecutionError.executionFailed(error))
            }
        } catch {
            return .failure(error)
        }
    }

    // MARK: - RPC Handling

    /// エラー出力からRPC呼び出しを抽出
    private func extractRPCCall(from buffer: String) -> String? {
        guard let range = buffer.range(of: #"__CLIPY_RPC__(.*?)__END__"#, options: .regularExpression) else {
            return nil
        }
        let matched = String(buffer[range])
        return matched
            .replacingOccurrences(of: "__CLIPY_RPC__", with: "")
            .replacingOccurrences(of: "__END__", with: "")
    }

    /// RPC呼び出しを処理してレスポンスを返す
    private func handleRPCCall(_ rpcJSON: String) -> String? {
        guard let data = rpcJSON.data(using: .utf8),
              let rpc = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let method = rpc["method"] as? String,
              let params = rpc["params"] as? [Any] else {
            return jsonResponse(error: "Invalid RPC request")
        }

        switch method {
        case "get_clip":
            guard let index = params.first as? Int else {
                return jsonResponse(error: "Invalid index parameter")
            }
            return jsonResponse(result: getClipText(at: index))

        case "get_clip_data":
            guard let index = params.first as? Int else {
                return jsonResponse(error: "Invalid index parameter")
            }
            return jsonResponse(result: getClipData(at: index))

        case "add_clip":
            guard let text = params.first as? String else {
                return jsonResponse(error: "Invalid text parameter")
            }
            let success = addClip(text: text)
            return jsonResponse(result: success)

        case "get_clip_count":
            return jsonResponse(result: getClipCount())

        default:
            return jsonResponse(error: "Unknown method: \(method)")
        }
    }

    /// JSONレスポンスを生成
    private func jsonResponse(result: Any? = nil, error: String? = nil) -> String {
        var response: [String: Any] = [:]
        if let result = result {
            response["result"] = result
        }
        if let error = error {
            response["error"] = error
        }
        guard let data = try? JSONSerialization.data(withJSONObject: response),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"error\": \"Failed to serialize response\"}"
        }
        return json
    }

    // MARK: - Clipy Data Access

    /// 履歴N番のテキストを取得
    private func getClipText(at index: Int) -> String? {
        let realm = try! Realm()
        let clips = realm.objects(CPYClip.self)
            .sorted(byKeyPath: #keyPath(CPYClip.updateTime), ascending: false)

        guard index >= 0, index < clips.count else { return nil }
        let clip = clips[index]

        guard let data = NSKeyedUnarchiver.unarchiveObject(withFile: clip.dataPath) as? CPYClipData else {
            return nil
        }

        return data.stringValue
    }

    /// 履歴N番の詳細データを取得
    private func getClipData(at index: Int) -> [String: Any]? {
        let realm = try! Realm()
        let clips = realm.objects(CPYClip.self)
            .sorted(byKeyPath: #keyPath(CPYClip.updateTime), ascending: false)

        guard index >= 0, index < clips.count else { return nil }
        let clip = clips[index]

        guard let data = NSKeyedUnarchiver.unarchiveObject(withFile: clip.dataPath) as? CPYClipData else {
            return nil
        }

        var result: [String: Any] = [
            "text": data.stringValue,
            "type": data.primaryType?.rawValue ?? "",
            "types": data.types.map { $0.rawValue }
        ]

        if !data.fileNames.isEmpty {
            result["files"] = data.fileNames
        }
        if !data.URLs.isEmpty {
            result["urls"] = data.URLs
        }
        if data.image != nil {
            result["has_image"] = true
        }

        return result
    }

    /// テキストを履歴に追加
    private func addClip(text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // ClipServiceが自動的に検出して保存するのを待つ
        // または直接保存
        DispatchQueue.main.async {
            AppEnvironment.current.clipService.create()
        }

        return true
    }

    /// 履歴の総数を取得
    private func getClipCount() -> Int {
        let realm = try! Realm()
        return realm.objects(CPYClip.self).count
    }

    // MARK: - Snippet Detection

    /// スニペットがPythonコードかどうか判定
    func isPythonSnippet(_ content: String) -> Bool {
        let lines = content.components(separatedBy: .newlines)
        guard let firstLine = lines.first?.trimmingCharacters(in: .whitespaces) else {
            return false
        }
        // 行頭が # python で始まるかチェック（大文字小文字区別なし）
        return firstLine.lowercased().hasPrefix("# python") ||
               firstLine.lowercased().hasPrefix("#python")
    }

    /// Pythonスニペットからコード部分を抽出
    func extractPythonCode(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        // 最初の行（# python）を除いたコードを返す
        return lines.dropFirst().joined(separator: "\n")
    }
}

// MARK: - Error
enum PythonExecutionError: LocalizedError {
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "Python実行エラー: \(message)"
        }
    }
}
```

#### 新規ファイル: `Clipy/Sources/Utility/Constants+Python.swift`

```swift
import Foundation

extension Constants {
    enum Python {
        static let pythonPath = "com.clipy-app.Clipy.pythonPath"
        static let pythonExecutionTimeout = "com.clipy-app.Clipy.pythonExecutionTimeout"
    }
}
```

---

### Phase 2: AppDelegateの修正

#### 修正ファイル: `Clipy/Sources/AppDelegate.swift:110-125`

**変更前:**
```swift
@objc func selectSnippetMenuItem(_ sender: AnyObject) {
    CPYUtilities.sendCustomLog(with: "selectSnippetMenuItem")
    guard let primaryKey = sender.representedObject as? String else {
        CPYUtilities.sendCustomLog(with: "Cannot fetch snippet primary key")
        NSSound.beep()
        return
    }
    let realm = try! Realm()
    guard let snippet = realm.object(ofType: CPYSnippet.self, forPrimaryKey: primaryKey) else {
        CPYUtilities.sendCustomLog(with: "Cannot fetch snippet data")
        NSSound.beep()
        return
    }
    AppEnvironment.current.pasteService.copyToPasteboard(with: snippet.content)
    AppEnvironment.current.pasteService.paste()
}
```

**変更後:**
```swift
@objc func selectSnippetMenuItem(_ sender: AnyObject) {
    CPYUtilities.sendCustomLog(with: "selectSnippetMenuItem")
    guard let primaryKey = sender.representedObject as? String else {
        CPYUtilities.sendCustomLog(with: "Cannot fetch snippet primary key")
        NSSound.beep()
        return
    }
    let realm = try! Realm()
    guard let snippet = realm.object(ofType: CPYSnippet.self, forPrimaryKey: primaryKey) else {
        CPYUtilities.sendCustomLog(with: "Cannot fetch snippet data")
        NSSound.beep()
        return
    }

    // Pythonスニペットかチェック
    let pythonService = AppEnvironment.current.pythonService
    if pythonService.isPythonSnippet(snippet.content) {
        let code = pythonService.extractPythonCode(snippet.content)
        let result = pythonService.execute(code)

        switch result {
        case .success(let output):
            AppEnvironment.current.pasteService.copyToPasteboard(with: output)
            AppEnvironment.current.pasteService.paste()
        case .failure(let error):
            // エラーをユーザーに通知
            NSSound.beep()
            CPYUtilities.sendCustomLog(with: "Python execution failed: \(error.localizedDescription)")

            // オプション: エラーメッセージをアラート表示
            let alert = NSAlert()
            alert.messageText = "Pythonスニペット実行エラー"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    } else {
        // 通常のスニペット処理
        AppEnvironment.current.pasteService.copyToPasteboard(with: snippet.content)
        AppEnvironment.current.pasteService.paste()
    }
}
```

---

### Phase 3: Environmentへの追加

#### 修正ファイル: `Clipy/Sources/Environments/Environment.swift`

**変更前:**
```swift
struct Environment {
    let clipService: ClipService
    let hotKeyService: HotKeyService
    let dataCleanService: DataCleanService
    let pasteService: PasteService
    let excludeAppService: ExcludeAppService
    let accessibilityService: AccessibilityService
    let menuManager: MenuManager
    let defaults: UserDefaults

    init(clipService: ClipService = ClipService(),
         hotKeyService: HotKeyService = HotKeyService(),
         dataCleanService: DataCleanService = DataCleanService(),
         pasteService: PasteService = PasteService(),
         excludeAppService: ExcludeAppService = ExcludeAppService(applications: []),
         accessibilityService: AccessibilityService = AccessibilityService(),
         menuManager: MenuManager = MenuManager(),
         defaults: UserDefaults = .standard) {
        // ...
    }
}
```

**変更後:**
```swift
struct Environment {
    let clipService: ClipService
    let hotKeyService: HotKeyService
    let dataCleanService: DataCleanService
    let pasteService: PasteService
    let excludeAppService: ExcludeAppService
    let accessibilityService: AccessibilityService
    let menuManager: MenuManager
    let pythonService: PythonExecutionService  // ← 追加
    let defaults: UserDefaults

    init(clipService: ClipService = ClipService(),
         hotKeyService: HotKeyService = HotKeyService(),
         dataCleanService: DataCleanService = DataCleanService(),
         pasteService: PasteService = PasteService(),
         excludeAppService: ExcludeAppService = ExcludeAppService(applications: []),
         accessibilityService: AccessibilityService = AccessibilityService(),
         menuManager: MenuManager = MenuManager(),
         pythonService: PythonExecutionService = PythonExecutionService(),  // ← 追加
         defaults: UserDefaults = .standard) {

        self.clipService = clipService
        self.hotKeyService = hotKeyService
        self.dataCleanService = dataCleanService
        self.pasteService = pasteService
        self.excludeAppService = excludeAppService
        self.accessibilityService = accessibilityService
        self.menuManager = menuManager
        self.pythonService = pythonService  // ← 追加
        self.defaults = defaults
    }
}
```

#### 修正ファイル: `Clipy/Sources/Environments/AppEnvironment.swift`

`push()` と `replaceCurrent()` メソッドにも `pythonService` パラメータを追加する必要があります。

**追加箇所（例）:**
```swift
static func push(clipService: ClipService = current.clipService,
                 hotKeyService: HotKeyService = current.hotKeyService,
                 dataCleanService: DataCleanService = current.dataCleanService,
                 pasteService: PasteService = current.pasteService,
                 excludeAppService: ExcludeAppService = current.excludeAppService,
                 accessibilityService: AccessibilityService = current.accessibilityService,
                 menuManager: MenuManager = current.menuManager,
                 pythonService: PythonExecutionService = current.pythonService,  // ← 追加
                 defaults: UserDefaults = current.defaults) {
    push(environment: Environment(clipService: clipService,
                                  hotKeyService: hotKeyService,
                                  dataCleanService: dataCleanService,
                                  pasteService: pasteService,
                                  excludeAppService: excludeAppService,
                                  accessibilityService: accessibilityService,
                                  menuManager: menuManager,
                                  pythonService: pythonService,  // ← 追加
                                  defaults: defaults))
}
```

同様に `replaceCurrent()` と `fromStorage()` にも追加します。

---

### Phase 4: Python実行環境の設定UI（オプション）

Preferences画面にPython実行環境を選択するUIを追加します。

#### 新規ファイル（または既存のPreferenceタブに追加）: Python設定タブ

**機能:**
1. Pythonインタープリタのパス選択
2. 「Browse...」ボタンでファイル選択ダイアログ
3. 自動検出ボタン（システム、Homebrew、Anacondaを検索）
4. バージョン表示
5. テスト実行ボタン

**実装例（擬似コード）:**
```swift
class PythonPreferenceViewController: NSViewController {
    @IBOutlet weak var pythonPathTextField: NSTextField!
    @IBOutlet weak var pythonVersionLabel: NSTextField!
    @IBOutlet weak var autoDetectButton: NSButton!
    @IBOutlet weak var browseButton: NSButton!
    @IBOutlet weak var testButton: NSButton!

    @IBAction func autoDetectPython(_ sender: Any) {
        // システム内のPythonを自動検出
        let candidates = [
            "/usr/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            NSString(string: "~/anaconda3/bin/python").expandingTildeInPath,
            NSString(string: "~/.pyenv/shims/python3").expandingTildeInPath
        ]

        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                pythonPathTextField.stringValue = path
                updatePythonVersion(path)
                break
            }
        }
    }

    @IBAction func browsePython(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK, let url = openPanel.url {
            pythonPathTextField.stringValue = url.path
            updatePythonVersion(url.path)
        }
    }

    @IBAction func testPython(_ sender: Any) {
        let code = "print('Python execution test successful')"
        let pythonService = PythonExecutionService()
        // 一時的にパスを設定
        AppEnvironment.current.defaults.set(pythonPathTextField.stringValue,
                                          forKey: Constants.Python.pythonPath)
        let result = pythonService.execute(code)

        switch result {
        case .success(let output):
            showAlert(title: "テスト成功", message: output)
        case .failure(let error):
            showAlert(title: "テスト失敗", message: error.localizedDescription)
        }
    }

    private func updatePythonVersion(_ path: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let version = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                pythonVersionLabel.stringValue = version
            }
        } catch {
            pythonVersionLabel.stringValue = "バージョン取得失敗"
        }
    }
}
```

---

## テスト計画

### 単体テスト

#### 新規ファイル: `ClipyTests/PythonExecutionServiceSpec.swift`

```swift
import Quick
import Nimble
import RealmSwift
@testable import Clipy

class PythonExecutionServiceSpec: QuickSpec {
    override func spec() {
        describe("PythonExecutionService") {
            var service: PythonExecutionService!

            beforeEach {
                service = PythonExecutionService()
            }

            describe("isPythonSnippet") {
                it("# python で始まるスニペットを検出") {
                    let content = "# python\nprint('test')"
                    expect(service.isPythonSnippet(content)).to(beTrue())
                }

                it("#pythonも検出") {
                    let content = "#python\nprint('test')"
                    expect(service.isPythonSnippet(content)).to(beTrue())
                }

                it("大文字小文字を区別しない") {
                    let content = "# PYTHON\nprint('test')"
                    expect(service.isPythonSnippet(content)).to(beTrue())
                }

                it("通常のスニペットは検出しない") {
                    let content = "normal snippet"
                    expect(service.isPythonSnippet(content)).to(beFalse())
                }
            }

            describe("extractPythonCode") {
                it("最初の行を除いたコードを抽出") {
                    let content = "# python\nprint('hello')\nprint('world')"
                    let code = service.extractPythonCode(content)
                    expect(code).to(equal("print('hello')\nprint('world')"))
                }
            }

            describe("execute") {
                it("単純なprintを実行") {
                    let result = service.execute("print('hello')")
                    expect(result).to(beSuccess { output in
                        expect(output).to(equal("hello"))
                    })
                }

                it("計算結果を実行") {
                    let result = service.execute("print(1 + 2 + 3)")
                    expect(result).to(beSuccess { output in
                        expect(output).to(equal("6"))
                    })
                }

                it("エラーコードでfailureを返す") {
                    let result = service.execute("invalid python code")
                    expect(result).to(beFailure())
                }
            }

            describe("Clipy API integration") {
                it("clipy.get_clip(0) でクリップボード履歴を取得") {
                    // テスト用にクリップを追加
                    let testText = "Test clipboard content"
                    // ... テストデータ準備 ...

                    let code = """
                    text = clipy.get_clip(0)
                    print(text)
                    """
                    let result = service.execute(code)
                    expect(result).to(beSuccess { output in
                        expect(output).to(contain("Test clipboard content"))
                    })
                }

                it("clipy.add_clip() で履歴に追加") {
                    let code = """
                    clipy.add_clip("New clip from Python")
                    print("Added")
                    """
                    let result = service.execute(code)
                    expect(result).to(beSuccess())

                    // 履歴に追加されたか確認
                    let realm = try! Realm()
                    let clips = realm.objects(CPYClip.self)
                    expect(clips.count).to(beGreaterThan(0))
                }

                it("clipy.get_clip_count() で履歴数を取得") {
                    let code = """
                    count = clipy.get_clip_count()
                    print(count)
                    """
                    let result = service.execute(code)
                    expect(result).to(beSuccess { output in
                        expect(Int(output)).to(beGreaterThanOrEqualTo(0))
                    })
                }
            }
        }
    }
}
```

---

## スケジュール

| フェーズ | タスク | 所要時間（目安） |
|---------|-------|---------|
| **Phase 1** | PythonExecutionService実装（JSON-RPC含む） | 4時間 |
| **Phase 2** | AppDelegate修正 | 1時間 |
| **Phase 3** | Environment/AppEnvironment修正 | 1時間 |
| **Phase 4** | Python設定UI実装（オプション） | 2時間 |
| **Phase 5** | テスト作成・実行 | 2時間 |
| **Phase 6** | 動作確認・デバッグ | 2時間 |
| **合計（基本）** | Phase 1-3, 5-6 | **10時間** |
| **合計（UI含む）** | 全Phase | **12時間** |

---


### タイムアウト設定

長時間実行されるPythonコードを防ぐため30秒タイムアウトを実装:

```swift
// Constants+Python.swift に追加
static let pythonExecutionTimeout = "com.clipy-app.Clipy.pythonExecutionTimeout"

// PythonExecutionService に追加
private var timeout: TimeInterval {
    let defaults = AppEnvironment.current.defaults
    return TimeInterval(defaults.integer(forKey: Constants.Python.pythonExecutionTimeout))
}

// execute() 内で
DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
    if process.isRunning {
        process.terminate()
    }
}
```


#### タイムアウト実装（必須）

無限ループや長時間実行を防止:

```swift
let timeout: TimeInterval = 30.0  // 30秒
let timer = DispatchSource.makeTimerSource(queue: .global())
timer.schedule(deadline: .now() + timeout)
timer.setEventHandler {
    if process.isRunning {
        process.terminate()
    }
}
timer.resume()
```

## 追加機能案（将来の拡張）
## セキュリティ考慮事項

#### 3. プロセス分離

Pythonプロセスは別プロセスとして実行されるため、クラッシュしてもClipy本体には影響なし。

#### 4. ユーザーの自己責任

- スニペットは完全にユーザー管理
- App Sandboxは有効化しない（ユーザーのPython環境にアクセスするため）
- 設定画面に「信頼できるスニペットのみ実行してください」と明記

---

