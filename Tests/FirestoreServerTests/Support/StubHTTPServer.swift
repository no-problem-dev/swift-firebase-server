import Foundation
import NIOConcurrencyHelpers
import NIOCore
import NIOHTTP1
import NIOPosix

/// One request the stub server received, kept whole so a test can assert on the wire format.
struct RecordedRequest: Sendable {
    let method: HTTPMethod
    let uri: String
    let headers: [(name: String, value: String)]
    let body: Data

    /// The path and query of the request line, split apart.
    var path: String {
        String(uri.split(separator: "?", maxSplits: 1)[0])
    }

    /// The query items of the request line, in the order they were sent, percent-decoded.
    var queryItems: [(name: String, value: String)] {
        let parts = uri.split(separator: "?", maxSplits: 1)
        guard parts.count == 2 else { return [] }
        return parts[1].split(separator: "&").map { item in
            let pair = item.split(separator: "=", maxSplits: 1)
            let name = String(pair[0]).removingPercentEncoding ?? String(pair[0])
            let value = pair.count == 2 ? (String(pair[1]).removingPercentEncoding ?? String(pair[1])) : ""
            return (name, value)
        }
    }

    func queryValues(named name: String) -> [String] {
        queryItems.filter { $0.name == name }.map(\.value)
    }

    var bodyJSON: [String: Any] {
        (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] ?? [:]
    }
}

/// What the stub server answers with.
struct StubResponse: Sendable {
    var status: HTTPResponseStatus = .ok
    var body: String = "{}"

    static let ok = StubResponse()
}

/// A local HTTP server that records what a client sent it and answers with a canned response.
///
/// It exists so a test can point a real ``FirestoreClient`` at a real socket and assert on the
/// request that comes out, rather than on a request builder that may or may not be what the client
/// calls.
final class StubHTTPServer: Sendable {
    private let group: MultiThreadedEventLoopGroup
    private let channel: Channel
    private let recorded: NIOLockedValueBox<[RecordedRequest]>

    let port: Int

    private init(group: MultiThreadedEventLoopGroup, channel: Channel, recorded: NIOLockedValueBox<[RecordedRequest]>) {
        self.group = group
        self.channel = channel
        self.recorded = recorded
        self.port = channel.localAddress?.port ?? 0
    }

    /// Starts a server on an ephemeral port of the loopback interface.
    ///
    /// Everything here is `async` rather than `wait()`-based: a blocking call inside a test would
    /// hold a thread of the cooperative pool, and enough of those at once deadlock a parallel run.
    /// - Parameter respond: Decides the answer for each request. Defaults to `200 {}`.
    static func start(respond: @escaping @Sendable (RecordedRequest) -> StubResponse = { _ in .ok }) async throws -> StubHTTPServer {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let recorded = NIOLockedValueBox<[RecordedRequest]>([])

        let bootstrap = ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 16)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(StubHandler(recorded: recorded, respond: respond))
                }
            }

        let channel = try await bootstrap.bind(host: "127.0.0.1", port: 0).get()
        return StubHTTPServer(group: group, channel: channel, recorded: recorded)
    }

    var requests: [RecordedRequest] {
        recorded.withLockedValue { $0 }
    }

    func stop() async {
        try? await channel.close().get()
        try? await group.shutdownGracefully()
    }
}

private final class StubHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let recorded: NIOLockedValueBox<[RecordedRequest]>
    private let respond: @Sendable (RecordedRequest) -> StubResponse

    private var head: HTTPRequestHead?
    private var body = Data()

    init(recorded: NIOLockedValueBox<[RecordedRequest]>, respond: @escaping @Sendable (RecordedRequest) -> StubResponse) {
        self.recorded = recorded
        self.respond = respond
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .head(let head):
            self.head = head
            self.body = Data()

        case .body(var buffer):
            if let bytes = buffer.readBytes(length: buffer.readableBytes) {
                body.append(contentsOf: bytes)
            }

        case .end:
            guard let head else { return }
            let request = RecordedRequest(
                method: head.method,
                uri: head.uri,
                headers: head.headers.map { ($0.name, $0.value) },
                body: body
            )
            recorded.withLockedValue { $0.append(request) }

            let response = respond(request)
            let responseBody = Data(response.body.utf8)

            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "application/json")
            headers.add(name: "Content-Length", value: String(responseBody.count))
            headers.add(name: "Connection", value: "close")

            context.write(
                wrapOutboundOut(.head(HTTPResponseHead(version: head.version, status: response.status, headers: headers))),
                promise: nil
            )
            var buffer = context.channel.allocator.buffer(capacity: responseBody.count)
            buffer.writeBytes(responseBody)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil))).whenComplete { _ in
                context.close(promise: nil)
            }
        }
    }
}
