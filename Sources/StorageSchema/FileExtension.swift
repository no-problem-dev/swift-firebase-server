import Foundation

/// ストレージファイルの拡張子
public enum FileExtension: String, Sendable, CaseIterable {
    // 画像
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

    // ドキュメント
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

    // 動画
    case mp4
    case mov
    case avi
    case mkv
    case webm
    case m4v

    // 音声
    case mp3
    case wav
    case aac
    case m4a
    case ogg
    case flac

    // アーカイブ
    case zip
    case tar
    case gz
    case rar
    case sevenZ = "7z"

    // データ
    case json
    case xml
    case yaml
    case yml

    // その他
    case html
    case css
    case js

    /// ドット付きの拡張子（例: ".jpg"）
    public var withDot: String {
        ".\(rawValue)"
    }

    /// Content-Type（MIME タイプ）
    public var contentType: String {
        switch self {
        // 画像
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

        // ドキュメント
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

        // 動画
        case .mp4: return "video/mp4"
        case .mov: return "video/quicktime"
        case .avi: return "video/x-msvideo"
        case .mkv: return "video/x-matroska"
        case .webm: return "video/webm"
        case .m4v: return "video/x-m4v"

        // 音声
        case .mp3: return "audio/mpeg"
        case .wav: return "audio/wav"
        case .aac: return "audio/aac"
        case .m4a: return "audio/mp4"
        case .ogg: return "audio/ogg"
        case .flac: return "audio/flac"

        // アーカイブ
        case .zip: return "application/zip"
        case .tar: return "application/x-tar"
        case .gz: return "application/gzip"
        case .rar: return "application/vnd.rar"
        case .sevenZ: return "application/x-7z-compressed"

        // データ
        case .json: return "application/json"
        case .xml: return "application/xml"
        case .yaml, .yml: return "application/x-yaml"

        // その他
        case .html: return "text/html"
        case .css: return "text/css"
        case .js: return "application/javascript"
        }
    }
}
