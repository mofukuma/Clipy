//
//  PythonExecutionService.swift
//  Clipy
//
//  Created by Claude on 2026-01-05.
//

import Foundation
import Cocoa
import RealmSwift

final class PythonExecutionService {

    // MARK: - Properties
    /// base64でPythonに渡せる画像サイズの上限
    private static let maxTransferableImageSize = 24 * 1024 * 1024

    /// Pythonスニペットの実行時間の上限（秒）
    private var executionTimeout: TimeInterval {
        let defaults = AppEnvironment.current.defaults
        let configured = defaults.double(forKey: Constants.Python.pythonExecutionTimeout)
        return (configured > 0) ? configured : 30.0
    }

    private var pythonExecutablePath: String {
        // UserDefaultsから設定を取得、デフォルトは /usr/bin/python3
        let defaults = AppEnvironment.current.defaults
        return defaults.string(forKey: Constants.Python.pythonPath) ?? "/usr/bin/python3"
    }

    private let clipyAPIModule = """
        import sys
        import json
        import base64

        class ClipyAPI:
            def __init__(self):
                pass

            def _rpc_call(self, method, params):
                \"\"\"ClipyにJSON-RPCリクエストを送信\"\"\"
                request = {"method": method, "params": params}
                print("__CLIPY_RPC__" + json.dumps(request) + "__END__", file=sys.stderr, flush=True)
                # Clipyからのレスポンスを待つ（stdinから読み取る想定）
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

            def has_image(self, index=0):
                \"\"\"履歴N番が画像を持っているか\"\"\"
                return bool(self._rpc_call("has_image", [index]))

            def find_image_clip(self):
                \"\"\"画像を持つ最も新しい履歴の番号を返す（無ければNone）\"\"\"
                return self._rpc_call("find_image_clip", [])

            def get_clip_image(self, index=None, format="png"):
                \"\"\"履歴N番の画像をbytesで取得する

                index を省略すると、画像を持つ最も新しい履歴を使う。
                画像が無い場合は None を返す。
                \"\"\"
                encoded = self._rpc_call("get_clip_image", [index, format])
                if not encoded:
                    return None
                return base64.b64decode(encoded)

            def save_clip_image(self, index=None, path=None, format="png"):
                \"\"\"履歴N番の画像をファイルに保存し、保存先のパスを返す

                index を省略すると、画像を持つ最も新しい履歴を使う。
                path を省略すると、Finderで開いている（選択している）フォルダに保存する。
                path にフォルダを渡すとファイル名は自動で決まる。
                \"\"\"
                return self._rpc_call("save_clip_image", [index, path, format])

            def get_finder_path(self):
                \"\"\"Finderで開いている（選択している）フォルダのパスを取得\"\"\"
                return self._rpc_call("get_finder_path", [])

            def get_finder_selection(self):
                \"\"\"Finderで選択中のファイル・フォルダのパス一覧を取得\"\"\"
                return self._rpc_call("get_finder_selection", []) or []

            def reveal(self, path):
                \"\"\"Finderでファイルを表示して選択する\"\"\"
                paths = [path] if isinstance(path, str) else list(path)
                return self._rpc_call("reveal", [paths])

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

        process.executableURL = URL(fileURLWithPath: pythonExecutablePath)
        // -u: unbuffered output（リアルタイム出力）
        // -c: inline code execution
        let fullCode = clipyAPIModule + "\n" + code
        process.arguments = ["-u", "-c", fullCode]
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.standardInput = inputPipe

        var errorBuffer = ""

        // Pythonパスが存在するかチェック
        if !FileManager.default.fileExists(atPath: pythonExecutablePath) {
            return .failure(PythonExecutionError.executionFailed("Pythonが見つかりません: \(pythonExecutablePath)\n\n設定からPythonパスを確認してください。"))
        }

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
                    while let rpcCall = self.extractRPCCall(from: errorBuffer) {
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

            // タイムアウト設定（デフォルト30秒、設定で変更可能）
            // Finder操作の初回はオートメーションの許可ダイアログを待つため余裕を持たせる
            let timeout = executionTimeout
            var didTimeout = false
            let timeoutTimer = DispatchSource.makeTimerSource(queue: .global())
            timeoutTimer.schedule(deadline: .now() + timeout)
            timeoutTimer.setEventHandler {
                if process.isRunning {
                    didTimeout = true
                    process.terminate()
                }
            }
            timeoutTimer.resume()

            process.waitUntilExit()
            timeoutTimer.cancel()
            errorHandle.readabilityHandler = nil

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""

            // エラーバッファからRPC部分以外を抽出
            let cleanedError = errorBuffer.replacingOccurrences(
                of: #"__CLIPY_RPC__.*?__END__"#,
                with: "",
                options: .regularExpression
            ).trimmingCharacters(in: .whitespacesAndNewlines)

            // タイムアウトの場合
            if didTimeout {
                return .failure(PythonExecutionError.executionFailed("実行がタイムアウトしました（\(Int(timeout))秒以内に完了しませんでした）"))
            }

            if process.terminationStatus == 0 {
                return .success(output.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                let error = cleanedError.isEmpty ? "Python実行エラー（終了コード: \(process.terminationStatus)）" : cleanedError
                return .failure(PythonExecutionError.executionFailed(error))
            }
        } catch {
            let errorMsg = "Pythonプロセスの起動に失敗しました:\n\n\(error.localizedDescription)\n\nPythonパス: \(pythonExecutablePath)"
            return .failure(PythonExecutionError.executionFailed(errorMsg))
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

        case "has_image":
            guard let index = params.first as? Int else {
                return jsonResponse(error: "Invalid index parameter")
            }
            return jsonResponse(result: clipData(at: index)?.hasImage ?? false)

        case "find_image_clip":
            guard let index = indexOfClipWithImage() else { return jsonResponse() }
            return jsonResponse(result: index)

        case "get_clip_image":
            return handleGetClipImage(params: params)

        case "save_clip_image":
            return handleSaveClipImage(params: params)

        case "get_finder_path":
            do {
                return jsonResponse(result: try AppEnvironment.current.finderService.currentFolderPath())
            } catch {
                return jsonResponse(error: error.localizedDescription)
            }

        case "get_finder_selection":
            do {
                return jsonResponse(result: try AppEnvironment.current.finderService.selectedPaths())
            } catch {
                return jsonResponse(error: error.localizedDescription)
            }

        case "reveal":
            let paths = (params.first as? [String]) ?? [String]()
            guard !paths.isEmpty else { return jsonResponse(error: "Invalid path parameter") }
            AppEnvironment.current.finderService.reveal(paths: paths)
            return jsonResponse(result: true)

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

    /// 履歴N番のデータを取得
    private func clipData(at index: Int) -> CPYClipData? {
        let realm = try! Realm()
        let clips = realm.objects(CPYClip.self)
            .sorted(byKeyPath: #keyPath(CPYClip.updateTime), ascending: false)

        guard index >= 0, index < clips.count else { return nil }
        let clip = clips[index]

        return NSKeyedUnarchiver.unarchiveObject(withFile: clip.dataPath) as? CPYClipData
    }

    /// 画像を持つ最も新しい履歴の番号を取得
    private func indexOfClipWithImage(searchLimit: Int = 50) -> Int? {
        let realm = try! Realm()
        let clips = realm.objects(CPYClip.self)
            .sorted(byKeyPath: #keyPath(CPYClip.updateTime), ascending: false)

        let count = min(clips.count, searchLimit)
        guard count > 0 else { return nil }
        for index in 0..<count {
            guard let data = NSKeyedUnarchiver.unarchiveObject(withFile: clips[index].dataPath) as? CPYClipData else { continue }
            if data.hasImage { return index }
        }
        return nil
    }

    /// 履歴N番のテキストを取得
    private func getClipText(at index: Int) -> String? {
        return clipData(at: index)?.stringValue
    }

    /// 履歴N番の詳細データを取得
    private func getClipData(at index: Int) -> [String: Any]? {
        guard let data = clipData(at: index) else { return nil }

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
        if data.hasImage {
            result["has_image"] = true
            if let size = AppEnvironment.current.imageExportService.pixelSize(of: data) {
                result["image_width"] = size.width
                result["image_height"] = size.height
            }
        }

        return result
    }

    /// 画像取得RPC
    private func handleGetClipImage(params: [Any]) -> String {
        let formatName = stringParameter(params, at: 1) ?? "png"
        guard let format = ClipImageExportService.ImageFormat(name: formatName) else {
            return jsonResponse(error: ClipImageExportService.ExportError.unsupportedFormat(formatName).localizedDescription)
        }
        guard let data = resolveImageClipData(from: params.first) else { return jsonResponse() }
        guard let imageData = AppEnvironment.current.imageExportService.imageData(of: data, format: format) else {
            return jsonResponse()
        }
        guard imageData.count <= PythonExecutionService.maxTransferableImageSize else {
            return jsonResponse(error: "画像が大きすぎます（\(imageData.count / 1024 / 1024)MB）。save_clip_image を使ってください。")
        }
        return jsonResponse(result: imageData.base64EncodedString())
    }

    /// 画像保存RPC
    private func handleSaveClipImage(params: [Any]) -> String {
        let path = stringParameter(params, at: 1)
        let formatName = stringParameter(params, at: 2) ?? "png"
        guard let format = ClipImageExportService.ImageFormat(name: formatName) else {
            return jsonResponse(error: ClipImageExportService.ExportError.unsupportedFormat(formatName).localizedDescription)
        }
        guard let data = resolveImageClipData(from: params.first) else {
            return jsonResponse(error: ClipImageExportService.ExportError.noImage.localizedDescription)
        }
        do {
            let savedPath = try AppEnvironment.current.imageExportService.save(data, to: path, format: format)
            return jsonResponse(result: savedPath)
        } catch {
            return jsonResponse(error: error.localizedDescription)
        }
    }

    /// パラメータから文字列を取り出す（未指定・None は nil）
    private func stringParameter(_ params: [Any], at index: Int) -> String? {
        guard index < params.count else { return nil }
        return params[index] as? String
    }

    /// index が省略された場合は画像を持つ最も新しい履歴を探す
    private func resolveImageClipData(from parameter: Any?) -> CPYClipData? {
        if let index = parameter as? Int { return clipData(at: index) }
        guard let index = indexOfClipWithImage() else { return nil }
        return clipData(at: index)
    }

    /// テキストを履歴に追加
    private func addClip(text: String) -> Bool {
        // メインスレッドで実行（Realmの書き込みはメインスレッドから）
        var success = false
        let semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.main.async {
            do {
                let realm = try Realm()

                // 一時的なNSPasteboardを作成してCPYClipDataを初期化
                let tempPasteboard = NSPasteboard(name: .init("com.clipy.python.temp.\(UUID().uuidString)"))
                tempPasteboard.clearContents()
                tempPasteboard.setString(text, forType: .string)

                // CPYClipDataを作成
                let data = CPYClipData(pasteboard: tempPasteboard, types: [.string])

                // ハッシュ値を計算
                let hash = data.hash

                // 保存パスを生成
                let unixTime = Int(Date().timeIntervalSince1970)
                let savedPath = CPYUtilities.applicationSupportFolder() + "/\(NSUUID().uuidString).data"

                // CPYClipオブジェクトを作成
                let clip = CPYClip()
                clip.dataPath = savedPath
                clip.title = String(text.prefix(10000))
                clip.dataHash = "\(hash)"
                clip.updateTime = unixTime
                clip.primaryType = NSPasteboard.PasteboardType.string.rawValue

                // データをファイルに保存
                if CPYUtilities.prepareSaveToPath(CPYUtilities.applicationSupportFolder()) {
                    if NSKeyedArchiver.archiveRootObject(data, toFile: savedPath) {
                        // Realmに保存
                        try realm.write {
                            realm.add(clip, update: .all)
                        }
                        success = true
                    }
                }

                // 一時的なPasteboardを解放
                tempPasteboard.releaseGlobally()
            } catch {
                print("Error adding clip to Realm: \(error)")
                success = false
            }
            semaphore.signal()
        }

        // メインスレッドの処理完了を待つ（タイムアウト2秒）
        _ = semaphore.wait(timeout: .now() + 2.0)

        return success
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

        let lowercasedLine = firstLine.lowercased()

        // コメント（#で始まる）かつ "python" が含まれる
        // 例: # python, #python, #!/bin/bash python, # Python script
        if lowercasedLine.hasPrefix("#") && lowercasedLine.contains("python") {
            return true
        }

        return false
    }

    /// Pythonスニペットからコード部分を抽出
    func extractPythonCode(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        // 最初の行（# python や shebang）を除いたコードを返す
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
