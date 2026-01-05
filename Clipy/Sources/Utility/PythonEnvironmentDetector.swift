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

    /// Python実行ファイルを検索する固定パス
    private static let fixedSearchPaths = [
        // システムPython（固定）
        "/usr/bin/python3",
        "/usr/bin/python",

        // Homebrew (固定パス)
        "/usr/local/bin/python3",           // Intel Mac
        "/usr/local/bin/python",
        "/opt/homebrew/bin/python3",        // Apple Silicon
        "/opt/homebrew/bin/python",

        // Anaconda/Miniconda/Miniforge (base環境)
        "~/anaconda3/bin/python3",
        "~/anaconda3/bin/python",
        "~/miniconda3/bin/python3",
        "~/miniconda3/bin/python",
        "~/miniforge3/bin/python3",
        "~/miniforge3/bin/python",

        // pyenv
        "~/.pyenv/shims/python3",
        "~/.pyenv/shims/python"
    ]

    /// conda仮想環境の検索対象ディレクトリ
    private static let condaEnvsDirectories = [
        "~/anaconda3/envs",
        "~/miniconda3/envs",
        "~/miniforge3/envs"
    ]

    // MARK: - Detection

    /// システム内のすべてのPython環境を検出
    static func detectAllEnvironments() -> [PythonEnvironment] {
        var environments: [PythonEnvironment] = []
        var seenPaths = Set<String>()

        // 固定パスから検索
        for path in fixedSearchPaths {
            let expandedPath = NSString(string: path).expandingTildeInPath
            addPythonIfExists(expandedPath, environments: &environments, seenPaths: &seenPaths)
        }

        // conda仮想環境を検索
        for envsDir in condaEnvsDirectories {
            let expandedEnvsDir = NSString(string: envsDir).expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expandedEnvsDir) else { continue }

            if let envNames = try? FileManager.default.contentsOfDirectory(atPath: expandedEnvsDir) {
                for envName in envNames {
                    // 隠しファイル/ディレクトリをスキップ
                    if envName.hasPrefix(".") { continue }

                    let envPath = (expandedEnvsDir as NSString).appendingPathComponent(envName)
                    let binPath = (envPath as NSString).appendingPathComponent("bin")

                    // bin/python3 と bin/python をチェック
                    let python3Path = (binPath as NSString).appendingPathComponent("python3")
                    let pythonPath = (binPath as NSString).appendingPathComponent("python")

                    addPythonIfExists(python3Path, environments: &environments, seenPaths: &seenPaths)
                    addPythonIfExists(pythonPath, environments: &environments, seenPaths: &seenPaths)
                }
            }
        }

        // pyenvのバージョン一覧から検索
        if let pyenvRoot = pyenvRoot() {
            let versionsDir = (pyenvRoot as NSString).appendingPathComponent("versions")
            if let versions = try? FileManager.default.contentsOfDirectory(atPath: versionsDir) {
                for version in versions {
                    // 隠しファイル/ディレクトリをスキップ
                    if version.hasPrefix(".") { continue }

                    let versionPath = (versionsDir as NSString).appendingPathComponent(version)
                    let binPath = (versionPath as NSString).appendingPathComponent("bin")

                    let python3Path = (binPath as NSString).appendingPathComponent("python3")
                    let pythonPath = (binPath as NSString).appendingPathComponent("python")

                    addPythonIfExists(python3Path, environments: &environments, seenPaths: &seenPaths)
                    addPythonIfExists(pythonPath, environments: &environments, seenPaths: &seenPaths)
                }
            }
        }

        return environments
    }

    /// Pythonパスが存在し、実行可能であれば環境リストに追加
    private static func addPythonIfExists(_ pythonPath: String, environments: inout [PythonEnvironment], seenPaths: inout Set<String>) {
        guard FileManager.default.fileExists(atPath: pythonPath) else { return }
        guard FileManager.default.isExecutableFile(atPath: pythonPath) else { return }

        // シンボリックリンクの実体パスを取得
        let realPath: String
        if let resolved = try? FileManager.default.destinationOfSymbolicLink(atPath: pythonPath) {
            // 相対パスの場合は絶対パスに変換
            if resolved.hasPrefix("/") {
                realPath = resolved
            } else {
                let directory = (pythonPath as NSString).deletingLastPathComponent
                realPath = (directory as NSString).appendingPathComponent(resolved)
            }
        } else {
            realPath = pythonPath
        }

        // 既に登録済みの場合はスキップ
        guard !seenPaths.contains(realPath) else { return }

        // 環境を作成して追加
        if let env = createEnvironment(path: pythonPath) {
            environments.append(env)
            seenPaths.insert(realPath)
        }
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
        // conda仮想環境の判定（anaconda3/envs/*, miniconda3/envs/*, miniforge3/envs/*）
        if path.contains("/envs/") {
            if let envName = extractCondaEnvName(from: path) {
                if path.contains("anaconda") {
                    return "Anaconda (\(envName)) - Python \(version)"
                } else if path.contains("miniconda") {
                    return "Miniconda (\(envName)) - Python \(version)"
                } else if path.contains("miniforge") {
                    return "Miniforge (\(envName)) - Python \(version)"
                }
            }
        }

        // パスから種類を判定
        if path.contains("/opt/homebrew/") {
            return "Homebrew (Apple Silicon) - Python \(version)"
        } else if path.contains("/usr/local/bin/") && !path.contains("Framework") {
            return "Homebrew (Intel) - Python \(version)"
        } else if path.contains("anaconda") {
            return "Anaconda - Python \(version)"
        } else if path.contains("miniconda") {
            return "Miniconda - Python \(version)"
        } else if path.contains("miniforge") {
            return "Miniforge - Python \(version)"
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

    /// conda仮想環境名をパスから抽出
    private static func extractCondaEnvName(from path: String) -> String? {
        let components = path.components(separatedBy: "/")
        if let envsIndex = components.firstIndex(of: "envs"),
           envsIndex + 1 < components.count {
            return components[envsIndex + 1]
        }
        return nil
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
