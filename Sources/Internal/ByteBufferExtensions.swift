import Foundation
import NIOCore
import NIOFoundationCompat

extension ByteBuffer {
    /// Copies the readable bytes into `Data`, or returns empty `Data` when there are none.
    ///
    /// The read happens on a local copy, so the receiver's reader index does not move and the
    /// same buffer can be converted more than once. Goes through NIOFoundationCompat's
    /// `readData`, which behaves the same on macOS and Linux.
    public func toData() -> Data {
        guard readableBytes > 0 else {
            return Data()
        }
        var mutableSelf = self
        return mutableSelf.readData(length: mutableSelf.readableBytes) ?? Data()
    }
}
