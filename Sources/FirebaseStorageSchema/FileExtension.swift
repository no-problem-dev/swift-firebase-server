import Foundation

/// A file extension the schema can build a path from, together with the MIME type it uploads under.
///
/// The set is closed: an extension not listed here cannot be used with `@Object`. The raw value is
/// the extension without its dot, except `sevenZ`, whose raw value is `"7z"` because that is not a
/// valid Swift identifier.
public enum FileExtension: String, Sendable, CaseIterable {
    // Images
    case jpg
    case jpeg
    case png
    case gif
    case webp
    case heic
    case heif
    case svg
    case bmp
    case ico
    case tiff

    // Documents
    case pdf
    case doc
    case docx
    case xls
    case xlsx
    case ppt
    case pptx
    case txt
    case rtf
    case csv

    // Video
    case mp4
    case mov
    case avi
    case mkv
    case webm
    case m4v

    // Audio
    case mp3
    case wav
    case aac
    case m4a
    case ogg
    case flac

    // Archives
    case zip
    case tar
    case gz
    case rar
    case sevenZ = "7z"

    // Data
    case json
    case xml
    case yaml
    case yml

    // Other
    case html
    case css
    case js

    /// The extension with its leading dot, as it is appended to an object path.
    public var withDot: String {
        ".\(rawValue)"
    }

    /// The MIME type sent as `Content-Type` when uploading a file with this extension.
    ///
    /// Fixed per extension, so it reflects the declared type and not the bytes actually uploaded.
    public var contentType: String {
        switch self {
        // Images
        case .jpg, .jpeg: return "image/jpeg"
        case .png: return "image/png"
        case .gif: return "image/gif"
        case .webp: return "image/webp"
        case .heic: return "image/heic"
        case .heif: return "image/heif"
        case .svg: return "image/svg+xml"
        case .bmp: return "image/bmp"
        case .ico: return "image/x-icon"
        case .tiff: return "image/tiff"

        // Documents
        case .pdf: return "application/pdf"
        case .doc: return "application/msword"
        case .docx: return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case .xls: return "application/vnd.ms-excel"
        case .xlsx: return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case .ppt: return "application/vnd.ms-powerpoint"
        case .pptx: return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case .txt: return "text/plain"
        case .rtf: return "application/rtf"
        case .csv: return "text/csv"

        // Video
        case .mp4: return "video/mp4"
        case .mov: return "video/quicktime"
        case .avi: return "video/x-msvideo"
        case .mkv: return "video/x-matroska"
        case .webm: return "video/webm"
        case .m4v: return "video/x-m4v"

        // Audio
        case .mp3: return "audio/mpeg"
        case .wav: return "audio/wav"
        case .aac: return "audio/aac"
        case .m4a: return "audio/mp4"
        case .ogg: return "audio/ogg"
        case .flac: return "audio/flac"

        // Archives
        case .zip: return "application/zip"
        case .tar: return "application/x-tar"
        case .gz: return "application/gzip"
        case .rar: return "application/vnd.rar"
        case .sevenZ: return "application/x-7z-compressed"

        // Data
        case .json: return "application/json"
        case .xml: return "application/xml"
        case .yaml, .yml: return "application/x-yaml"

        // Other
        case .html: return "text/html"
        case .css: return "text/css"
        case .js: return "application/javascript"
        }
    }
}
