//
//  ClipImageExportService.swift
//  Clipy
//
//  Writes the image of a clip to disk. Used by the Python API to turn a
//  copied image into a real PNG file.
//

import Foundation
import Cocoa

final class ClipImageExportService {

    // MARK: - Format
    enum ImageFormat {
        case png
        case jpeg
        case tiff
        case bmp
        case gif

        init?(name: String) {
            switch name.lowercased() {
            case "png": self = .png
            case "jpg", "jpeg": self = .jpeg
            case "tif", "tiff": self = .tiff
            case "bmp": self = .bmp
            case "gif": self = .gif
            default: return nil
            }
        }

        var fileType: NSBitmapImageRep.FileType {
            switch self {
            case .png: return .png
            case .jpeg: return .jpeg
            case .tiff: return .tiff
            case .bmp: return .bmp
            case .gif: return .gif
            }
        }

        var pathExtension: String {
            switch self {
            case .png: return "png"
            case .jpeg: return "jpg"
            case .tiff: return "tiff"
            case .bmp: return "bmp"
            case .gif: return "gif"
            }
        }

        var properties: [NSBitmapImageRep.PropertyKey: Any] {
            switch self {
            case .jpeg: return [.compressionFactor: 0.9]
            default: return [:]
            }
        }

        static var availableNames: [String] {
            return ["png", "jpg", "jpeg", "tiff", "bmp", "gif"]
        }
    }

    // MARK: - Error
    enum ExportError: LocalizedError {
        case noImage
        case unsupportedFormat(String)
        case conversionFailed
        case destinationUnavailable(String)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .noImage:
                return "クリップボード履歴に画像がありません"
            case .unsupportedFormat(let format):
                return "未対応の画像形式です: \(format) (利用可能: \(ImageFormat.availableNames.joined(separator: ", ")))"
            case .conversionFailed:
                return "画像の変換に失敗しました"
            case .destinationUnavailable(let path):
                return "保存先のフォルダがありません: \(path)"
            case .writeFailed(let message):
                return "画像の保存に失敗しました: \(message)"
            }
        }
    }

    // MARK: - Properties
    fileprivate let finderService: FinderService

    // MARK: - Initialize
    init(finderService: FinderService = FinderService()) {
        self.finderService = finderService
    }

}

// MARK: - Export
extension ClipImageExportService {

    /// Image bytes of the clip in the requested format.
    func imageData(of clipData: CPYClipData, format: ImageFormat) -> Data? {
        // Bytes that already are in the requested format are handed back untouched
        if let data = clipData.imageData, !data.isEmpty {
            if format == .png && clipData.imageDataIsPNG { return data }
            if format == .tiff && !clipData.imageDataIsPNG { return data }
        }
        guard let bitmap = bitmapRepresentation(of: clipData) else { return nil }
        return bitmap.representation(using: format.fileType, properties: format.properties)
    }

    /// Pixel size of the image the clip carries.
    func pixelSize(of clipData: CPYClipData) -> (width: Int, height: Int)? {
        guard let bitmap = bitmapRepresentation(of: clipData) else { return nil }
        return (bitmap.pixelsWide, bitmap.pixelsHigh)
    }

    /**
     *  Saves the image of a clip.
     *
     *  - parameter destination: A folder, a full file path or `nil`.
     *                           `nil` means the folder the Finder is showing.
     *  - returns: The path of the written file.
     */
    func save(_ clipData: CPYClipData, to destination: String?, format: ImageFormat) throws -> String {
        guard let data = imageData(of: clipData, format: format) else {
            if bitmapRepresentation(of: clipData) == nil { throw ExportError.noImage }
            throw ExportError.conversionFailed
        }

        let url = try destinationURL(for: destination, format: format)
        let directory = url.deletingLastPathComponent()
        guard CPYUtilities.prepareSaveToPath(directory.path) else {
            throw ExportError.destinationUnavailable(directory.path)
        }

        let finalURL = uniqueURL(for: url)
        do {
            try data.write(to: finalURL, options: .atomic)
        } catch {
            throw ExportError.writeFailed(error.localizedDescription)
        }
        return finalURL.path
    }

    /// Default file name for a freshly exported image, e.g. `Clipboard 2026-08-21 09.41.20.png`.
    func defaultFileName(format: ImageFormat, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        return "Clipboard \(formatter.string(from: date)).\(format.pathExtension)"
    }

}

// MARK: - Destination
private extension ClipImageExportService {

    func destinationURL(for destination: String?, format: ImageFormat) throws -> URL {
        let fileManager = FileManager.default
        var expandedPath: String?
        if let destination = destination, !destination.isEmpty {
            expandedPath = (destination as NSString).expandingTildeInPath
        }

        guard let path = expandedPath else {
            // No destination given, use whatever the Finder is showing
            let folder = (try? finderService.currentFolderPath()) ?? FinderService.desktopPath
            return URL(fileURLWithPath: folder).appendingPathComponent(defaultFileName(format: format))
        }

        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
            return URL(fileURLWithPath: path).appendingPathComponent(defaultFileName(format: format))
        }
        // A path ending with a separator is meant to be a folder as well
        if path.hasSuffix("/") {
            return URL(fileURLWithPath: path).appendingPathComponent(defaultFileName(format: format))
        }

        let url = URL(fileURLWithPath: path)
        if url.pathExtension.isEmpty {
            return url.appendingPathExtension(format.pathExtension)
        }
        return url
    }

    /// Never overwrites an existing file, `image.png` becomes `image-2.png`.
    func uniqueURL(for url: URL) -> URL {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return url }

        let directory = url.deletingLastPathComponent()
        let pathExtension = url.pathExtension
        let baseName = url.deletingPathExtension().lastPathComponent

        for suffix in 2...1000 {
            let candidate = directory
                .appendingPathComponent("\(baseName)-\(suffix)")
                .appendingPathExtension(pathExtension)
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
        }
        return url
    }

    func bitmapRepresentation(of clipData: CPYClipData) -> NSBitmapImageRep? {
        if let data = clipData.imageData, let representation = NSBitmapImageRep(data: data) {
            return representation
        }
        if let tiff = clipData.image?.tiffRepresentation, let representation = NSBitmapImageRep(data: tiff) {
            return representation
        }
        // Clips holding a copied file keep the image on disk only
        for path in clipData.fileNames {
            guard let image = NSImage(contentsOfFile: path),
                  let tiff = image.tiffRepresentation,
                  let representation = NSBitmapImageRep(data: tiff) else { continue }
            return representation
        }
        return nil
    }

}
