//
//  FinderService.swift
//  Clipy
//
//  Talks to the Finder through AppleScript to find out where the user
//  is currently working, so that scripts can drop files right there.
//

import Foundation
import Cocoa

final class FinderService {

    // MARK: - Error
    enum FinderError: LocalizedError {
        case notPermitted
        case scriptFailed(String)

        var errorDescription: String? {
            switch self {
            case .notPermitted:
                return "Finderの操作が許可されていません。システム設定 > プライバシーとセキュリティ > オートメーション から ClipyAI に Finder へのアクセスを許可してください。"
            case .scriptFailed(let message):
                return "Finderとの通信に失敗しました: \(message)"
            }
        }
    }

    // MARK: - Properties
    /// Apple event error code returned when the automation permission is missing.
    private static let notPermittedErrorNumber = -1743

    // MARK: - Current Location
    /**
     *  Folder the user is looking at right now.
     *
     *  A single selected folder wins over the folder of the front window, so
     *  clicking a folder in the Finder is enough to choose the destination.
     *  Falls back to the desktop when no Finder window is open.
     */
    func currentFolderPath() throws -> String {
        let source = """
            tell application "Finder"
                try
                    set theSelection to selection
                    if (count of theSelection) is 1 then
                        set theItem to item 1 of theSelection
                        if class of theItem is folder then
                            return POSIX path of (theItem as alias)
                        end if
                    end if
                end try
                try
                    if (count of Finder windows) > 0 then
                        return POSIX path of (target of front Finder window as alias)
                    end if
                end try
                return ""
            end tell
            """
        let descriptor = try execute(source: source)
        let path = descriptor.stringValue ?? ""
        if path.isEmpty { return FinderService.desktopPath }
        return standardized(path)
    }

    /// Files and folders selected in the Finder right now.
    func selectedPaths() throws -> [String] {
        let source = """
            tell application "Finder"
                set thePaths to {}
                repeat with theItem in (get selection)
                    try
                        set end of thePaths to POSIX path of (theItem as alias)
                    end try
                end repeat
                return thePaths
            end tell
            """
        let descriptor = try execute(source: source)
        if let single = descriptor.stringValue, descriptor.numberOfItems == 0 {
            return single.isEmpty ? [] : [standardized(single)]
        }
        guard descriptor.numberOfItems > 0 else { return [] }
        return (1...descriptor.numberOfItems).compactMap { index -> String? in
            guard let path = descriptor.atIndex(index)?.stringValue, !path.isEmpty else { return nil }
            return standardized(path)
        }
    }

    /// Shows the given files in the Finder and selects them.
    func reveal(paths: [String]) {
        let urls = paths.map { URL(fileURLWithPath: $0) }
        guard !urls.isEmpty else { return }
        DispatchQueue.main.async {
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        }
    }

    static var desktopPath: String {
        let paths = NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true)
        return paths.first ?? NSHomeDirectory()
    }

    // MARK: - AppleScript
    private func execute(source: String) throws -> NSAppleEventDescriptor {
        var descriptor: NSAppleEventDescriptor?
        var thrownError: Error?

        let work: () -> Void = {
            guard let script = NSAppleScript(source: source) else {
                thrownError = FinderError.scriptFailed("スクリプトを生成できませんでした")
                return
            }
            var errorInfo: NSDictionary?
            let result = script.executeAndReturnError(&errorInfo)
            if let errorInfo = errorInfo {
                let number = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
                if number == FinderService.notPermittedErrorNumber {
                    thrownError = FinderError.notPermitted
                } else {
                    let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "\(number)"
                    thrownError = FinderError.scriptFailed(message)
                }
                return
            }
            descriptor = result
        }

        // NSAppleScript is not thread safe, it has to run on the main thread
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.sync(execute: work)
        }

        if let thrownError = thrownError { throw thrownError }
        guard let result = descriptor else {
            throw FinderError.scriptFailed("応答がありませんでした")
        }
        return result
    }

    private func standardized(_ path: String) -> String {
        // Finder hands back directory paths with a trailing slash
        if path.count > 1 && path.hasSuffix("/") {
            return String(path.dropLast())
        }
        return path
    }

}
