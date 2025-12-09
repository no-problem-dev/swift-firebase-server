import Foundation
import NIOCore

extension ByteBuffer {
    /// ByteBufferをDataに変換（Linux/macOS両対応）
    ///
    /// macOSでは`Data(buffer:)`が使えるが、LinuxではAPIが異なるため、
    /// `getData(at:length:)` を使用してクロスプラットフォーム対応する。
    ///
    /// - Returns: ByteBufferの読み取り可能なバイトを含むData
    public func toData() -> Data {
        guard readableBytes > 0 else {
            return Data()
        }
        return getData(at: readerIndex, length: readableBytes) ?? Data()
    }
}
