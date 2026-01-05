//
//  PythonEnvironmentDetector.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Claude on 2026/01/05.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation

struct PythonEnvironment: Equatable {
    let path: String
    let version: String
    let displayName: String

    static func == (lhs: PythonEnvironment, rhs: PythonEnvironment) -> Bool {
        return lhs.path == rhs.path
    }
}

final class PythonEnvironmentDetector {

    // MARK: - Properties

    /// Python実行ファイルを検索する候補パス
    private static let searchPaths = [
        // システムPython
        "/usr/bin/python3",
        "/usr/local/bin/python3",

        // Homebrew (Intel Mac)
        "/usr/local/bin/python3.11",
        "/usr/local/bin/python3.12",
        "/usr/local/bin/python3.13",

        // Homebrew (Apple Silicon)
        "/opt/homebrew/bin/python3",
        "/opt/homebrew/bin/python3.11",
        "/opt/homebrew/bin/python3.12",
        "/opt/homebrew/bin/python3.13",

        // Anaconda
        "~/anaconda3/bin/python",
        "~/anaconda3/bin/python3",
        "~/miniconda3/bin/python",
        "~/miniconda3/bin/python3",

        // pyenv
        "~/.pyenv/shims/python3",

        // Python.org
        "/Library/Frameworks/Python.framework/Versions/3.11/bin/python3",
        "/Library/Frameworks/Python.framework/Versions/3.12/bin/python3",
        "/Library/Frameworks/Python.framework/Versions/3.13/bin/python3"
    ]

    // MARK: - Detection

    /// システム内のすべてのPython環境を検出
    static func detectAllEnvironments() -> [PythonEnvironment] {
        var environments: [PythonEnvironment] = []
        var seenPaths = Set<String>()

        // 候補パスから検索
        for path in searchPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath

            if FileManager.default.fileExists(atPath: expandedPath),
               !seenPaths.contains(expandedPath) {
                if let env = createEnvironment(path: expandedPath) {
                    environments.append(env)
                    seenPaths.insert(expandedPath)
                }
            }
        }

        // PATHから追加検索
        if let pathEnv = ProcessInfo.processInfo.environment["PATH"] {
            let paths = pathEnv.components(separatedBy: ":")
            for pathDir in paths {
                let pythonPath = (pathDir as NSString).appendingPathComponent("python3")
                if FileManager.default.fileExists(atPath: pythonPath),
                   !seenPaths.contains(pythonPath) {
                    if let env = createEnvironment(path: pythonPath) {
                        environments.append(env)
                        seenPaths.insert(pythonPath)
                    }
                }
            }
        }

        // pyenvのバージョン一覧から検索
        if let pyenvRoot = pyenvRoot() {
            let versionsDir = (pyenvRoot as NSString).appendingPathComponent("versions")
            if let versions = try? FileManager.default.contentsOfDirectory(atPath: versionsDir) {
                for version in versions {
                    let versionPath = (versionsDir as NSString).appendingPathComponent(version)
                    let binPath = (versionPath as NSString).appendingPathComponent("bin")
                    let pythonPath = (binPath as NSString).appendingPathComponent("python3")
                    if FileManager.default.fileExists(atPath: pythonPath),
                       !seenPaths.contains(pythonPath) {
                        if let env = createEnvironment(path: pythonPath) {
                            environments.append(env)
                            seenPaths.insert(pythonPath)
                        }
                    }
                }
            }
        }

        return environments
    }

    // MARK: - Helper Methods

    /// Pythonパスから環境情報を生成
    private static func createEnvironment(path: String) -> PythonEnvironment? {
        guard let version = getPythonVersion(path: path) else {
            return nil
        }

        let displayName = generateDisplayName(path: path, version: version)
        return PythonEnvironment(path: path, version: version, displayName: displayName)
    }

    /// Pythonのバージョンを取得
    private static func getPythonVersion(path: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["--version"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                // "Python 3.11.7" のような形式からバージョンを抽出
                let version = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "Python ", with: "")
                return version
            }
        } catch {
            return nil
        }

        return nil
    }

    /// 表示名を生成
    private static func generateDisplayName(path: String, version: String) -> String {
        // パスから種類を判定
        if path.contains("/opt/homebrew/") {
            return "Homebrew (Apple Silicon) - Python \(version)"
        } else if path.contains("/usr/local/bin/") && !path.contains("Framework") {
            return "Homebrew (Intel) - Python \(version)"
        } else if path.contains("anaconda") {
            return "Anaconda - Python \(version)"
        } else if path.contains("miniconda") {
            return "Miniconda - Python \(version)"
        } else if path.contains(".pyenv") {
            return "pyenv - Python \(version)"
        } else if path.contains("/Library/Frameworks/Python.framework") {
            return "Python.org - Python \(version)"
        } else if path == "/usr/bin/python3" {
            return "System - Python \(version)"
        } else {
            return "Python \(version) (\(path))"
        }
    }

    /// pyenvのルートディレクトリを取得
    private static func pyenvRoot() -> String? {
        // 環境変数からPYENV_ROOTを取得
        if let pyenvRoot = ProcessInfo.processInfo.environment["PYENV_ROOT"] {
            return pyenvRoot
        }

        // デフォルトの ~/.pyenv を確認
        let defaultPath = NSString(string: "~/.pyenv").expandingTildeInPath
        if FileManager.default.fileExists(atPath: defaultPath) {
            return defaultPath
        }

        return nil
    }

    /// デフォルトのPython環境を取得
    static func getDefaultEnvironment() -> PythonEnvironment? {
        let environments = detectAllEnvironments()

        // 優先順位: システム > Homebrew > その他
        let systemPython = environments.first { $0.path == "/usr/bin/python3" }
        if let systemPython = systemPython {
            return systemPython
        }

        let homebrewPython = environments.first { $0.path.contains("/homebrew/") }
        if let homebrewPython = homebrewPython {
            return homebrewPython
        }

        return environments.first
    }
}
