import Foundation
import NIOCore
import NIOFoundationCompat

extension ByteBuffer {
    /// ByteBufferをDataに変換（Linux/macOS両対応）
    ///
    /// NIOFoundationCompatモジュールの`readData`メソッドを使用して
    /// クロスプラットフォーム対応する。
    ///
    /// - Returns: ByteBufferの読み取り可能なバイトを含むData
    public func toData() -> Data {
        guard readableBytes > 0 else {
            return Data()
        }
        var mutableSelf = self
        return mutableSelf.readData(length: mutableSelf.readableBytes) ?? Data()
    }
}
