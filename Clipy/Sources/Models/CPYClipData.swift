//
//  CPYClipData.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2015/06/21.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import SwiftHEXColors

final class CPYClipData: NSObject {

    // MARK: - Properties
    fileprivate let kTypesKey       = "types"
    fileprivate let kStringValueKey = "stringValue"
    fileprivate let kRTFDataKey     = "RTFData"
    fileprivate let kRTFDDataKey    = "RTFDData"
    fileprivate let kHTMLDataKey    = "HTMLData"
    fileprivate let kPDFKey         = "PDF"
    fileprivate let kFileNamesKey   = "filenames"
    fileprivate let kURLsKey        = "URL"
    fileprivate let kImageKey       = "image"
    fileprivate let kImageDataKey   = "imageData"
    fileprivate let kImageIsPNGKey  = "imageDataIsPNG"
    fileprivate let kNativeDataKey  = "nativeData"

    var types          = [NSPasteboard.PasteboardType]()
    var fileNames      = [String]()
    var URLs           = [String]()
    var stringValue    = ""
    var RTFData: Data?
    var RTFDData: Data?
    var HTMLData: Data?
    var PDF: Data?
    var image: NSImage?
    /// Original bytes of the copied image. Keeping them avoids a lossy
    /// NSImage round trip when the clip is pasted or exported again.
    var imageData: Data?
    var imageDataIsPNG = false
    /// Application native representations, keyed by their pasteboard type.
    /// This is what makes a copied Excel range paste back into Excel as cells
    /// instead of as a picture of cells.
    var nativeData = [String: Data]()

    override var hash: Int {
        var hash = types.map { $0.rawValue }.joined().hash
        if let image = self.image, let imageData = image.tiffRepresentation {
            hash ^= imageData.count
        } else if let image = self.image {
            hash ^= image.hash
        }
        if !fileNames.isEmpty {
            fileNames.forEach { hash ^= $0.hash }
        } else if !self.URLs.isEmpty {
            URLs.forEach { hash ^= $0.hash }
        } else if let pdf = PDF {
            hash ^= pdf.count
        } else if !stringValue.isEmpty {
            hash ^= stringValue.hash
        }
        if let data = RTFData {
            hash ^= data.count
        }
        return hash
    }
    /// The representation that describes the clip best.
    ///
    /// Rendered previews are ignored on purpose, a copied Excel range is text
    /// and has to be listed as such in the history menu.
    var primaryType: NSPasteboard.PasteboardType? {
        guard let kind = pasteKinds(dropsRenderedMedia: false).first else { return types.first }
        return (kind.isImage) ? .deprecatedTIFF : kind.canonicalType
    }
    var isOnlyStringType: Bool {
        let kinds = self.kinds
        return !kinds.isEmpty && kinds.allSatisfy { $0 == .string }
    }
    var thumbnailImage: NSImage? {
        let defaults = UserDefaults.standard
        let width = defaults.integer(forKey: Constants.UserDefaults.thumbnailWidth)
        let height = defaults.integer(forKey: Constants.UserDefaults.thumbnailHeight)

        if let image = image, fileNames.isEmpty {
            // Image only data
            return image.resizeImage(CGFloat(width), CGFloat(height))
        } else if let fileName = fileNames.first, let path = fileName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let url = URL(string: path) {
             // In the case of the local file correct data is not included in the image variable
             // Judge the image from the path and create a thumbnail
            switch url.pathExtension.lowercased() {
            case "jpg", "jpeg", "png", "bmp", "tiff":
                return NSImage(contentsOfFile: fileName)?.resizeImage(CGFloat(width), CGFloat(height))
            default: break
            }
        }
        return nil
    }
    var colorCodeImage: NSImage? {
        guard let color = NSColor(hexString: stringValue) else { return nil }
        return NSImage.create(with: color, size: NSSize(width: 20, height: 20))
    }

    static let availableTypesDictinary: [NSPasteboard.PasteboardType: String] = [
        // String types
        .deprecatedString: "String",
        .modernString: "String",
        .modernPlainText: "String",

        // Rich text types
        .deprecatedRTF: "RTF",
        .deprecatedRTFD: "RTFD",
        .modernRTF: "RTF",
        .modernRTFD: "RTFD",
        // HTML is what Office applications and browsers use to keep the
        // layout alive. Stored together with the other rich text types.
        .modernHTML: "RTF",
        .deprecatedHTML: "RTF",

        // Document types
        .deprecatedPDF: "PDF",
        .modernPDF: "PDF",

        // File and URL types
        .deprecatedFilenames: "Filenames",
        .deprecatedURL: "URL",

        // Image types - legacy
        .deprecatedTIFF: "TIFF",

        // Image types - modern
        .modernTIFF: "TIFF",
        .nextTIFF: "TIFF",
        .modernPNG: "TIFF"
    ]

    static var availableTypes: [NSPasteboard.PasteboardType] {
        return Array(availableTypesDictinary.keys)
    }

    static var availableTypesString: [String] {
        return Array(Set(availableTypesDictinary.values)).sorted()
    }

    // MARK: - Init
    init(pasteboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) {
        super.init()
        self.types = types
        types.forEach { type in
            guard let kind = CPYPasteboardKind(type: type) else { return }
            switch kind {
            case .string:
                guard stringValue.isEmpty else { return }
                guard let string = pasteboard.string(forType: type) else { return }
                stringValue = string
            case .rtf:
                guard RTFData == nil else { return }
                RTFData = pasteboard.data(forType: type)
            case .rtfd:
                guard RTFDData == nil else { return }
                RTFDData = pasteboard.data(forType: type)
            case .html:
                guard HTMLData == nil else { return }
                HTMLData = pasteboard.data(forType: type)
            case .pdf:
                guard PDF == nil else { return }
                PDF = pasteboard.data(forType: type)
            case .fileNames:
                guard let filenames = pasteboard.propertyList(forType: type) as? [String] else { return }
                self.fileNames = filenames
            case .url:
                guard let urls = pasteboard.propertyList(forType: type) as? [String] else { return }
                URLs = urls
            case .tiff:
                guard imageData == nil else { return }
                imageData = pasteboard.data(forType: type)
                imageDataIsPNG = false
            case .png:
                // PNG keeps transparency and is smaller, so it always wins over TIFF
                guard let data = pasteboard.data(forType: type) else { return }
                imageData = data
                imageDataIsPNG = true
            }
        }
        readNativeData(from: pasteboard)
        // Legacy behaviour - some applications only vend the image through NSImage
        if let imageData = imageData {
            image = NSImage(data: imageData)
        }
        if image == nil, kinds.contains(where: { $0.isImage }) {
            image = pasteboard.readObjects(forClasses: [NSImage.self], options: nil)?.first as? NSImage
        }
    }

    init(image: NSImage) {
        self.types = [.deprecatedTIFF]
        self.image = image
        // Screenshots are stored as PNG, a TIFF of the same screen is several times bigger
        if let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) {
            if let png = bitmap.representation(using: .png, properties: [:]) {
                self.imageData = png
                self.imageDataIsPNG = true
            } else {
                self.imageData = tiff
            }
        }
    }

    deinit {
        self.RTFData = nil
        self.RTFDData = nil
        self.HTMLData = nil
        self.PDF = nil
        self.image = nil
        self.imageData = nil
        self.nativeData = [String: Data]()
    }

    // MARK: - NSCoding
    @objc func encodeWithCoder(_ aCoder: NSCoder) {
        aCoder.encode(types.map { $0.rawValue }, forKey: kTypesKey)
        aCoder.encode(stringValue, forKey: kStringValueKey)
        aCoder.encode(RTFData, forKey: kRTFDataKey)
        aCoder.encode(RTFDData, forKey: kRTFDDataKey)
        aCoder.encode(HTMLData, forKey: kHTMLDataKey)
        aCoder.encode(PDF, forKey: kPDFKey)
        aCoder.encode(fileNames, forKey: kFileNamesKey)
        aCoder.encode(URLs, forKey: kURLsKey)
        // The image is rebuilt from imageData, storing both would double the file
        aCoder.encode((imageData == nil) ? image : nil, forKey: kImageKey)
        aCoder.encode(imageData, forKey: kImageDataKey)
        aCoder.encode(imageDataIsPNG, forKey: kImageIsPNGKey)
        aCoder.encode(nativeData, forKey: kNativeDataKey)
    }

    @objc required init(coder aDecoder: NSCoder) {
        types = (aDecoder.decodeObject(forKey: kTypesKey) as? [String])?.compactMap { NSPasteboard.PasteboardType(rawValue: $0) } ?? []
        fileNames = aDecoder.decodeObject(forKey: kFileNamesKey) as? [String] ?? [String]()
        URLs = aDecoder.decodeObject(forKey: kURLsKey) as? [String] ?? [String]()
        stringValue = aDecoder.decodeObject(forKey: kStringValueKey) as? String ?? ""
        RTFData = aDecoder.decodeObject(forKey: kRTFDataKey) as? Data
        RTFDData = aDecoder.decodeObject(forKey: kRTFDDataKey) as? Data
        HTMLData = aDecoder.decodeObject(forKey: kHTMLDataKey) as? Data
        PDF = aDecoder.decodeObject(forKey: kPDFKey) as? Data
        let decodedImageData = aDecoder.decodeObject(forKey: kImageDataKey) as? Data
        let decodedImage = aDecoder.decodeObject(forKey: kImageKey) as? NSImage
        imageData = decodedImageData
        image = decodedImage ?? decodedImageData.flatMap { NSImage(data: $0) }
        imageDataIsPNG = aDecoder.decodeBool(forKey: kImageIsPNGKey)
        nativeData = aDecoder.decodeObject(forKey: kNativeDataKey) as? [String: Data] ?? [String: Data]()
        super.init()
    }
}

// MARK: - Pasteboard Representations
extension CPYClipData {

    /// Every representation this clip carries, without legacy / modern duplicates.
    var kinds: [CPYPasteboardKind] {
        var result = [CPYPasteboardKind]()
        types.compactMap { CPYPasteboardKind(type: $0) }.forEach { kind in
            if !result.contains(kind) { result.append(kind) }
        }
        return result
    }

    /// The clip carries something the user can read as text.
    var hasTextualContent: Bool {
        if !stringValue.isEmpty { return true }
        return RTFData != nil || RTFDData != nil || HTMLData != nil
    }

    var hasImage: Bool {
        return imageData != nil || image != nil
    }

    /// RTF payload. Old histories stored the RTFD bytes under the very same key,
    /// so the content is checked before it is handed back.
    var rtfPayload: Data? {
        guard let data = RTFData else { return nil }
        return CPYClipData.isRTF(data) ? data : nil
    }

    var rtfdPayload: Data? {
        if let data = RTFDData { return data }
        guard let data = RTFData, !CPYClipData.isRTF(data) else { return nil }
        return data
    }

    /// Rich text starts with `{\rtf`, flat RTFD with the `rtfd` magic number.
    fileprivate static func isRTF(_ data: Data) -> Bool {
        let prefix = [UInt8](data.prefix(5))
        return prefix == [0x7B, 0x5C, 0x72, 0x74, 0x66] // {\rtf
    }

    /// Image bytes converted to TIFF, whatever the clip stored originally.
    var tiffData: Data? {
        if let data = imageData, !imageDataIsPNG { return data }
        if let data = imageData, let rep = NSBitmapImageRep(data: data) {
            return rep.tiffRepresentation
        }
        return image?.tiffRepresentation
    }

    /// Image bytes converted to PNG, whatever the clip stored originally.
    var pngData: Data? {
        if let data = imageData, imageDataIsPNG { return data }
        return bitmapRepresentation(using: .png, properties: [:])
    }

    /// Image bytes converted to an arbitrary bitmap file format.
    func bitmapRepresentation(using type: NSBitmapImageRep.FileType, properties: [NSBitmapImageRep.PropertyKey: Any]) -> Data? {
        var representation: NSBitmapImageRep?
        if let data = imageData {
            representation = NSBitmapImageRep(data: data)
        }
        if representation == nil, let tiff = image?.tiffRepresentation {
            representation = NSBitmapImageRep(data: tiff)
        }
        guard let bitmap = representation else { return nil }
        return bitmap.representation(using: type, properties: properties)
    }

    /// Representations in the order they are written back to the pasteboard.
    ///
    /// Applications pick the representation they like best, so a rendered preview
    /// (the TIFF Excel adds to every copy) must never come before the real content.
    /// Otherwise a copied cell range is pasted as a picture.
    func pasteKinds(dropsRenderedMedia: Bool) -> [CPYPasteboardKind] {
        var kinds = self.kinds.filter { hasPayload(for: $0) }
        // Offer both image representations so that legacy and modern
        // applications alike find something they understand
        if let index = kinds.firstIndex(where: { $0.isImage }) {
            let imageKinds: [CPYPasteboardKind] = (imageDataIsPNG) ? [.png, .tiff] : [.tiff, .png]
            kinds.removeAll { $0.isImage }
            kinds.insert(contentsOf: imageKinds, at: Swift.min(index, kinds.count))
        }
        guard hasTextualContent else { return kinds }

        let content = kinds.filter { !$0.isRenderedMedia }
        if dropsRenderedMedia { return content }
        return content + kinds.filter { $0.isRenderedMedia }
    }

    /// The payload written to the pasteboard for the given representation,
    /// `nil` when the clip cannot provide it.
    func pasteboardContent(for kind: CPYPasteboardKind) -> CPYPasteboardContent? {
        switch kind {
        case .string:
            return stringValue.isEmpty ? nil : .string(stringValue)
        case .rtf:
            guard let payload = rtfPayload else { return nil }
            return .data(payload)
        case .rtfd:
            guard let payload = rtfdPayload else { return nil }
            return .data(payload)
        case .html:
            guard let payload = HTMLData else { return nil }
            return .data(payload)
        case .pdf:
            guard let pdfData = PDF, let pdfRep = NSPDFImageRep(data: pdfData) else { return nil }
            return .data(pdfRep.pdfRepresentation)
        case .fileNames:
            return fileNames.isEmpty ? nil : .propertyList(fileNames)
        case .url:
            return URLs.isEmpty ? nil : .propertyList(URLs)
        case .tiff:
            guard let payload = tiffData else { return nil }
            return .data(payload)
        case .png:
            guard let payload = pngData else { return nil }
            return .data(payload)
        }
    }

    /// Whether the clip really holds data for the given representation.
    func hasPayload(for kind: CPYPasteboardKind) -> Bool {
        switch kind {
        case .string: return !stringValue.isEmpty
        case .rtf: return rtfPayload != nil
        case .rtfd: return rtfdPayload != nil
        case .html: return HTMLData != nil
        case .pdf: return PDF != nil
        case .fileNames: return !fileNames.isEmpty
        case .url: return !URLs.isEmpty
        case .tiff, .png: return hasImage
        }
    }

}

// MARK: - Application Native Representations
extension CPYClipData {

    /// A single native representation is never allowed to grow bigger than this.
    /// Office attaches whole embedded pictures to `Art--GVML-ClipFormat`.
    fileprivate static let maxNativeDataSize = 4 * 1024 * 1024
    /// Upper bound for all native representations of one clip together.
    fileprivate static let maxTotalNativeDataSize = 12 * 1024 * 1024

    /// Pasteboard types owned by an application rather than by the system.
    /// They keep formulas, cell borders, shapes and other things no generic
    /// representation can express.
    static let nativeTypePrefixes = [
        "com.microsoft.",           // Excel, Word, PowerPoint
        "org.openxmlformats.",      // Office Open XML payloads
        "com.apple.iWork",          // Numbers, Pages, Keynote
        "com.apple.Numbers",
        "com.apple.Pages",
        "com.apple.Keynote",
        "com.apple.notes",
        "com.libreoffice.",
        "application/x-openoffice"
    ]

    /// Native representations are saved together with the rich text they belong to.
    static let nativeTypeStoreCategory = "RTF"

    static func isNativeDocumentType(_ type: NSPasteboard.PasteboardType) -> Bool {
        // Known representations are stored on their own, no need to duplicate them
        guard CPYPasteboardKind(type: type) == nil else { return false }
        let rawValue = type.rawValue
        return nativeTypePrefixes.contains { rawValue.hasPrefix($0) }
    }

    /// Native representations in the order the source application declared them.
    var nativeTypes: [NSPasteboard.PasteboardType] {
        return types.filter { nativeData[$0.rawValue] != nil }
    }

    fileprivate func readNativeData(from pasteboard: NSPasteboard) {
        var totalSize = 0
        types.forEach { type in
            guard CPYClipData.isNativeDocumentType(type) else { return }
            guard let data = pasteboard.data(forType: type), !data.isEmpty else { return }
            guard data.count <= CPYClipData.maxNativeDataSize else { return }
            guard totalSize + data.count <= CPYClipData.maxTotalNativeDataSize else { return }
            totalSize += data.count
            nativeData[type.rawValue] = data
        }
    }

}
