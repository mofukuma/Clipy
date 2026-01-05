//
//  CPYPythonPreferenceViewController.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Claude on 2026/01/05.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa

final class CPYPythonPreferenceViewController: NSViewController {

    // MARK: - Properties
    @IBOutlet private weak var pythonEnvironmentPopup: NSPopUpButton?
    @IBOutlet private weak var pythonPathTextField: NSTextField?
    @IBOutlet private weak var pythonVersionLabel: NSTextField?
    @IBOutlet private weak var autoDetectButton: NSButton?
    @IBOutlet private weak var browseButton: NSButton?
    @IBOutlet private weak var testButton: NSButton?
    @IBOutlet private weak var statusLabel: NSTextField?

    private var environments: [PythonEnvironment] = []
    private let defaults = AppEnvironment.current.defaults

    // MARK: - Initialize
    override func loadView() {
        // プログラマティックにUIを作成
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))

        // タイトル
        let titleLabel = NSTextField(labelWithString: "Python実行環境")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: 350, width: 560, height: 24)
        view.addSubview(titleLabel)

        // 説明
        let descLabel = NSTextField(wrappingLabelWithString: "Pythonスニペット実行に使用するPython環境を選択してください。")
        descLabel.frame = NSRect(x: 20, y: 310, width: 560, height: 40)
        view.addSubview(descLabel)

        // 環境選択ラベル
        let envLabel = NSTextField(labelWithString: "Python環境:")
        envLabel.frame = NSRect(x: 20, y: 270, width: 120, height: 20)
        envLabel.alignment = .right
        view.addSubview(envLabel)

        // 環境選択ポップアップ
        let popup = NSPopUpButton(frame: NSRect(x: 150, y: 265, width: 400, height: 25))
        popup.target = self
        popup.action = #selector(pythonEnvironmentChanged(_:))
        view.addSubview(popup)
        self.pythonEnvironmentPopup = popup

        // パスラベル
        let pathLabel = NSTextField(labelWithString: "Pythonパス:")
        pathLabel.frame = NSRect(x: 20, y: 230, width: 120, height: 20)
        pathLabel.alignment = .right
        view.addSubview(pathLabel)

        // パステキストフィールド
        let pathField = NSTextField(frame: NSRect(x: 150, y: 225, width: 400, height: 25))
        pathField.isEditable = false
        pathField.isBezeled = true
        pathField.bezelStyle = .roundedBezel
        view.addSubview(pathField)
        self.pythonPathTextField = pathField

        // バージョンラベル
        let versionLabel = NSTextField(labelWithString: "バージョン:")
        versionLabel.frame = NSRect(x: 20, y: 190, width: 120, height: 20)
        versionLabel.alignment = .right
        view.addSubview(versionLabel)

        // バージョン表示
        let versionField = NSTextField(labelWithString: "")
        versionField.frame = NSRect(x: 150, y: 190, width: 400, height: 20)
        view.addSubview(versionField)
        self.pythonVersionLabel = versionField

        // 自動検出ボタン
        let autoButton = NSButton(frame: NSRect(x: 150, y: 150, width: 120, height: 32))
        autoButton.title = "自動検出"
        autoButton.bezelStyle = .rounded
        autoButton.target = self
        autoButton.action = #selector(autoDetectPython(_:))
        view.addSubview(autoButton)
        self.autoDetectButton = autoButton

        // 参照ボタン
        let browseBtn = NSButton(frame: NSRect(x: 280, y: 150, width: 120, height: 32))
        browseBtn.title = "参照..."
        browseBtn.bezelStyle = .rounded
        browseBtn.target = self
        browseBtn.action = #selector(browsePython(_:))
        view.addSubview(browseBtn)
        self.browseButton = browseBtn

        // テストボタン
        let testBtn = NSButton(frame: NSRect(x: 410, y: 150, width: 120, height: 32))
        testBtn.title = "テスト実行"
        testBtn.bezelStyle = .rounded
        testBtn.target = self
        testBtn.action = #selector(testPython(_:))
        view.addSubview(testBtn)
        self.testButton = testBtn

        // ステータスラベル
        let statusLbl = NSTextField(labelWithString: "")
        statusLbl.frame = NSRect(x: 150, y: 110, width: 400, height: 40)
        statusLbl.isEditable = false
        statusLbl.isBordered = false
        statusLbl.backgroundColor = .clear
        view.addSubview(statusLbl)
        self.statusLabel = statusLbl

        // 使用方法
        let usageLabel = NSTextField(wrappingLabelWithString: "使用方法:\nスニペットの先頭に「# python」を付けると、Pythonコードとして実行されます。\n\n例:\n# python\nprint(\"Hello from Python!\")")
        usageLabel.frame = NSRect(x: 20, y: 20, width: 560, height: 80)
        usageLabel.font = NSFont.systemFont(ofSize: 11)
        usageLabel.textColor = .secondaryLabelColor
        view.addSubview(usageLabel)

        self.view = view
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadPythonEnvironments()
        loadCurrentSettings()
    }

    // MARK: - Setup
    private func setupUI() {
        statusLabel?.stringValue = ""
        pythonVersionLabel?.stringValue = ""
    }

    private func loadPythonEnvironments() {
        guard let popup = pythonEnvironmentPopup else { return }

        // Python環境を自動検出
        environments = PythonEnvironmentDetector.detectAllEnvironments()

        // ポップアップメニューを更新
        popup.removeAllItems()

        if environments.isEmpty {
            popup.addItem(withTitle: "Python環境が見つかりません")
            popup.isEnabled = false
        } else {
            for env in environments {
                popup.addItem(withTitle: env.displayName)
            }
            popup.isEnabled = true
        }

        // カスタムパスオプションを追加
        popup.menu?.addItem(NSMenuItem.separator())
        popup.addItem(withTitle: "カスタムパス...")
    }

    private func loadCurrentSettings() {
        guard let popup = pythonEnvironmentPopup, let pathField = pythonPathTextField else { return }

        // 現在の設定を読み込む
        if let savedPath = defaults.string(forKey: Constants.Python.pythonPath) {
            pathField.stringValue = savedPath
            updatePythonVersion(path: savedPath)

            // ポップアップで対応する環境を選択
            if let index = environments.firstIndex(where: { $0.path == savedPath }) {
                popup.selectItem(at: index)
            } else {
                // カスタムパスを選択
                popup.selectItem(at: popup.numberOfItems - 1)
            }
        } else {
            // デフォルト値を設定
            if let defaultEnv = PythonEnvironmentDetector.getDefaultEnvironment() {
                pathField.stringValue = defaultEnv.path
                updatePythonVersion(path: defaultEnv.path)
                if let index = environments.firstIndex(where: { $0.path == defaultEnv.path }) {
                    popup.selectItem(at: index)
                }
            } else {
                pathField.stringValue = "/usr/bin/python3"
                updatePythonVersion(path: "/usr/bin/python3")
            }
        }
    }

    // MARK: - IBActions
    @IBAction private func pythonEnvironmentChanged(_ sender: NSPopUpButton) {
        guard let popup = pythonEnvironmentPopup,
              let pathField = pythonPathTextField,
              let versionLabel = pythonVersionLabel,
              let status = statusLabel else { return }

        let selectedIndex = sender.indexOfSelectedItem

        // カスタムパスが選択された場合
        if selectedIndex == popup.numberOfItems - 1 {
            browsePython(sender)
            return
        }

        // 通常の環境が選択された場合
        if selectedIndex >= 0 && selectedIndex < environments.count {
            let env = environments[selectedIndex]
            pathField.stringValue = env.path
            versionLabel.stringValue = env.version
            savePythonPath(env.path)
            status.stringValue = "✓ 設定を保存しました"
            status.textColor = .systemGreen
        }
    }

    @IBAction private func autoDetectPython(_ sender: NSButton) {
        guard let status = statusLabel else { return }

        status.stringValue = "Python環境を検索中..."
        status.textColor = .labelColor

        // 非同期で検索
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let newEnvironments = PythonEnvironmentDetector.detectAllEnvironments()

            DispatchQueue.main.async {
                guard let self = self,
                      let status = self.statusLabel,
                      let pathField = self.pythonPathTextField,
                      let versionLabel = self.pythonVersionLabel,
                      let popup = self.pythonEnvironmentPopup else { return }

                self.environments = newEnvironments
                self.loadPythonEnvironments()

                if newEnvironments.isEmpty {
                    status.stringValue = "⚠ Python環境が見つかりませんでした"
                    status.textColor = .systemOrange
                } else {
                    status.stringValue = "✓ \(newEnvironments.count)個のPython環境を検出しました"
                    status.textColor = .systemGreen

                    // 最初の環境を自動選択
                    if let firstEnv = newEnvironments.first {
                        pathField.stringValue = firstEnv.path
                        versionLabel.stringValue = firstEnv.version
                        popup.selectItem(at: 0)
                        self.savePythonPath(firstEnv.path)
                    }
                }
            }
        }
    }

    @IBAction private func browsePython(_ sender: Any) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.message = "Python実行ファイルを選択してください"

        // Pythonインタープリタがありそうなディレクトリを初期位置に設定
        openPanel.directoryURL = URL(fileURLWithPath: "/usr/bin")
        openPanel.allowsOtherFileTypes = true

        openPanel.begin { [weak self] response in
            guard let self = self,
                  response == .OK,
                  let url = openPanel.url,
                  let pathField = self.pythonPathTextField,
                  let popup = self.pythonEnvironmentPopup,
                  let status = self.statusLabel else { return }

            let path = url.path
            pathField.stringValue = path
            self.updatePythonVersion(path: path)
            self.savePythonPath(path)

            // ポップアップをカスタムパスに設定
            popup.selectItem(at: popup.numberOfItems - 1)

            status.stringValue = "✓ カスタムパスを設定しました"
            status.textColor = .systemGreen
        }
    }

    @IBAction private func testPython(_ sender: NSButton) {
        guard let pathField = pythonPathTextField,
              let status = statusLabel else { return }

        let path = pathField.stringValue

        guard !path.isEmpty else {
            showAlert(title: "エラー", message: "Pythonパスが設定されていません")
            return
        }

        status.stringValue = "テスト実行中..."
        status.textColor = .labelColor

        // 一時的にパスを設定してテスト実行
        let originalPath = defaults.string(forKey: Constants.Python.pythonPath)
        defaults.set(path, forKey: Constants.Python.pythonPath)

        let code = "print('Python実行テスト成功！')"
        let pythonService = PythonExecutionService()
        let result = pythonService.execute(code)

        // 元のパスに戻す
        if let originalPath = originalPath {
            defaults.set(originalPath, forKey: Constants.Python.pythonPath)
        }

        switch result {
        case .success(let output):
            status.stringValue = "✓ テスト成功: \(output)"
            status.textColor = .systemGreen
            showAlert(title: "テスト成功", message: "Pythonコードが正常に実行されました。\n\n出力: \(output)")
        case .failure(let error):
            status.stringValue = "✗ テスト失敗"
            status.textColor = .systemRed
            showAlert(title: "テスト失敗", message: error.localizedDescription)
        }
    }

    // MARK: - Helper Methods
    private func updatePythonVersion(path: String) {
        guard let versionLabel = pythonVersionLabel else { return }

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
            if let version = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                versionLabel.stringValue = version
            } else {
                versionLabel.stringValue = "バージョン取得失敗"
            }
        } catch {
            versionLabel.stringValue = "バージョン取得失敗"
        }
    }

    private func savePythonPath(_ path: String) {
        defaults.set(path, forKey: Constants.Python.pythonPath)
        defaults.synchronize()
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
