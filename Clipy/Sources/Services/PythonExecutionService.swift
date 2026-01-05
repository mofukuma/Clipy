//
//  PythonExecutionService.swift
//  Clipy
//
//  Created by Claude on 2026-01-05.
//

import Foundation
import RealmSwift

final class PythonExecutionService {

    // MARK: - Properties
    private var pythonExecutablePath: String {
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

        var outputBuffer = ""
        var errorBuffer = ""
        var rpcQueue: [String] = []

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

            // タイムアウト設定（30秒）
            let timeout: TimeInterval = 30.0
            let timeoutTimer = DispatchSource.makeTimerSource(queue: .global())
            timeoutTimer.schedule(deadline: .now() + timeout)
            timeoutTimer.setEventHandler {
                if process.isRunning {
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
        // クリップボードにテキストを設定
        // ClipServiceが自動的にクリップボードの変更を監視して履歴に追加する
        DispatchQueue.main.sync {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }

        // ClipServiceが変更を検出するまで少し待つ
        Thread.sleep(forTimeInterval: 0.1)

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
