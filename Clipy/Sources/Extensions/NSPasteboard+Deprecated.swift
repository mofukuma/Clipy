//
//  NSPasteboard+Deprecated.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2017/12/30.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa

/**
 *  The contents of PasteboardType has been changed with swift 4.
 *  However, we will use the swift 3 style to keep compatibility with existing items
 *  Help wanted - If there is a good implementation I would like to replace it.
 **/
extension NSPasteboard.PasteboardType {

    static var deprecatedString: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "NSStringPboardType")
    }

    static var deprecatedRTF: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "NSRTFPboardType")
    }

    static var deprecatedRTFD: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "NSRTFDPboardType")
    }

    static var deprecatedPDF: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "NSPDFPboardType")
    }

    static var deprecatedFilenames: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")
    }

    static var deprecatedURL: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "NSURLPboardType")
    }

    static var deprecatedTIFF: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "NSTIFFPboardType")
    }

}

/**
 *  Modern (UTI based) pasteboard types.
 *  Office applications and modern browsers declare these instead of the
 *  legacy NSxxxPboardType names.
 **/
extension NSPasteboard.PasteboardType {

    static var modernString: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "public.utf8-plain-text")
    }

    static var modernPlainText: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "public.plain-text")
    }

    static var modernRTF: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "public.rtf")
    }

    static var modernRTFD: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "com.apple.flat-rtfd")
    }

    static var modernPDF: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "com.adobe.pdf")
    }

    static var modernURL: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "public.url")
    }

    static var modernTIFF: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "public.tiff")
    }

    static var nextTIFF: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "NeXT TIFF v4.0 pasteboard type")
    }

    static var modernPNG: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "public.png")
    }

    static var modernHTML: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "public.html")
    }

    static var deprecatedHTML: NSPasteboard.PasteboardType {
        return NSPasteboard.PasteboardType(rawValue: "Apple HTML pasteboard type")
    }

}

/**
 *  A single clip usually carries the very same payload several times.
 *  Excel for example puts plain text, RTF, HTML, PDF and TIFF on the pasteboard
 *  at once - the TIFF being nothing but a rendered preview of the copied cells.
 *
 *  `CPYPasteboardKind` groups the equivalent (legacy / modern) type names together
 *  so that a clip can be restored without duplicated or contradicting representations.
 **/
enum CPYPasteboardKind {
    case string
    case rtf
    case rtfd
    case html
    case pdf
    case fileNames
    case url
    case tiff
    case png

    // MARK: - Initialize
    init?(type: NSPasteboard.PasteboardType) {
        switch type {
        case .deprecatedString, .modernString, .modernPlainText:
            self = .string
        case .deprecatedRTF, .modernRTF:
            self = .rtf
        case .deprecatedRTFD, .modernRTFD:
            self = .rtfd
        case .modernHTML, .deprecatedHTML:
            self = .html
        case .deprecatedPDF, .modernPDF:
            self = .pdf
        case .deprecatedFilenames:
            self = .fileNames
        case .deprecatedURL, .modernURL:
            self = .url
        case .deprecatedTIFF, .modernTIFF, .nextTIFF:
            self = .tiff
        case .modernPNG:
            self = .png
        default:
            return nil
        }
    }

    // MARK: - Properties
    /// The type actually written back to the pasteboard for this kind.
    var canonicalType: NSPasteboard.PasteboardType {
        switch self {
        case .string: return .deprecatedString
        case .rtf: return .deprecatedRTF
        case .rtfd: return .deprecatedRTFD
        case .html: return .modernHTML
        case .pdf: return .deprecatedPDF
        case .fileNames: return .deprecatedFilenames
        case .url: return .deprecatedURL
        case .tiff: return .deprecatedTIFF
        case .png: return .modernPNG
        }
    }

    /// Rendered representations of the copied content (a preview, not the payload itself).
    var isRenderedMedia: Bool {
        switch self {
        case .pdf, .tiff, .png: return true
        case .string, .rtf, .rtfd, .html, .fileNames, .url: return false
        }
    }

    var isImage: Bool {
        switch self {
        case .tiff, .png: return true
        case .string, .rtf, .rtfd, .html, .pdf, .fileNames, .url: return false
        }
    }

}

/// The payload of a single pasteboard representation.
enum CPYPasteboardContent {
    case string(String)
    case data(Data)
    case propertyList(Any)
}
