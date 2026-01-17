import Foundation
import SwiftProtobuf

/// Firestore Protobuf イベントデコーダー
///
/// Eventarc から送信される Firestore イベントの Protobuf ペイロードを
/// デコードし、既存の `FirestoreDocumentEvent` 型に変換します。
///
/// ## Eventarc Firestore トリガー
///
/// Firestore の Eventarc トリガーは `application/protobuf` 形式のみをサポートします。
/// JSON 形式は利用できません。
///
/// ### gcloud トリガー作成コマンド
/// ```bash
/// gcloud eventarc triggers create firestore-chat-created \
///   --location=asia-northeast1 \
///   --destination-run-service=your-service \
///   --destination-run-region=asia-northeast1 \
///   --destination-run-path="/webhooks/firestore/chat-created" \
///   --event-filters="type=google.cloud.firestore.document.v1.created" \
///   --event-filters="database=(default)" \
///   --event-filters-path-pattern="document=users/*/books/*/chats/*" \
///   --event-data-content-type="application/protobuf" \
///   --service-account="PROJECT_NUMBER-compute@developer.gserviceaccount.com"
/// ```
///
/// ### 使用例
/// ```swift
/// routes.post("webhook", "firestore", "chat-created") { request async throws -> HTTPStatus in
///     let headers = CloudEventHeaders(from: request.headers.all)
///
///     // Content-Type に基づいてデコード方法を判定
///     let contentType = request.headers["content-type"]
///     if contentType == "application/protobuf" {
///         let data = try await request.body.collect()
///         let event = try FirestoreProtobufDecoder.decode(data)
///         // event は FirestoreDocumentEvent 型
///     }
///
///     return .ok
/// }
/// ```
///
/// ## 参考
/// - [Eventarc Firestore Events](https://cloud.google.com/eventarc/docs/reference/supported-events#firestore)
/// - [google-cloudevents Protobuf](https://github.com/googleapis/google-cloudevents)
public enum FirestoreProtobufDecoder {
    /// Protobuf バイナリデータを FirestoreDocumentEvent にデコード
    ///
    /// - Parameter data: Protobuf エンコードされたバイナリデータ
    /// - Returns: デコードされた FirestoreDocumentEvent
    /// - Throws: デコードエラー
    public static func decode(_ data: Data) throws -> FirestoreDocumentEvent {
        let protoEvent = try Google_Events_Cloud_Firestore_V1_DocumentEventData(serializedBytes: data)
        return convert(protoEvent)
    }

    /// Protobuf バイナリデータを FirestoreDocumentEvent にデコード
    ///
    /// - Parameter bytes: Protobuf エンコードされたバイト配列
    /// - Returns: デコードされた FirestoreDocumentEvent
    /// - Throws: デコードエラー
    public static func decode(_ bytes: [UInt8]) throws -> FirestoreDocumentEvent {
        let protoEvent = try Google_Events_Cloud_Firestore_V1_DocumentEventData(serializedBytes: bytes)
        return convert(protoEvent)
    }

    // MARK: - Private Conversion Methods

    private static func convert(_ proto: Google_Events_Cloud_Firestore_V1_DocumentEventData) -> FirestoreDocumentEvent {
        FirestoreDocumentEvent(
            value: proto.hasValue ? convert(proto.value) : nil,
            oldValue: proto.hasOldValue ? convert(proto.oldValue) : nil,
            updateMask: proto.hasUpdateMask ? convert(proto.updateMask) : nil
        )
    }

    private static func convert(_ proto: Google_Events_Cloud_Firestore_V1_Document) -> FirestoreDocument {
        FirestoreDocument(
            name: proto.name,
            fields: proto.fields.mapValues { convert($0) },
            createTime: proto.hasCreateTime ? formatTimestamp(proto.createTime) : nil,
            updateTime: proto.hasUpdateTime ? formatTimestamp(proto.updateTime) : nil
        )
    }

    private static func convert(_ proto: Google_Events_Cloud_Firestore_V1_DocumentMask) -> FirestoreDocumentEvent.UpdateMask {
        FirestoreDocumentEvent.UpdateMask(fieldPaths: proto.fieldPaths.isEmpty ? nil : proto.fieldPaths)
    }

    private static func convert(_ proto: Google_Events_Cloud_Firestore_V1_Value) -> FirestoreValue {
        switch proto.valueType {
        case .nullValue:
            return FirestoreValue(nullValue: "NULL_VALUE")
        case .booleanValue(let v):
            return FirestoreValue(booleanValue: v)
        case .integerValue(let v):
            return FirestoreValue(integerValue: String(v))
        case .doubleValue(let v):
            return FirestoreValue(doubleValue: v)
        case .timestampValue(let v):
            return FirestoreValue(timestampValue: formatTimestamp(v))
        case .stringValue(let v):
            return FirestoreValue(stringValue: v)
        case .bytesValue(let v):
            return FirestoreValue(bytesValue: v.base64EncodedString())
        case .referenceValue(let v):
            return FirestoreValue(referenceValue: v)
        case .geoPointValue(let v):
            return FirestoreValue(geoPointValue: FirestoreValue.GeoPointValue(
                latitude: v.latitude,
                longitude: v.longitude
            ))
        case .arrayValue(let v):
            return FirestoreValue(arrayValue: FirestoreValue.ArrayValue(
                values: v.values.map { convert($0) }
            ))
        case .mapValue(let v):
            return FirestoreValue(mapValue: FirestoreValue.MapValue(
                fields: v.fields.mapValues { convert($0) }
            ))
        case .none:
            return FirestoreValue()
        }
    }

    private static func formatTimestamp(_ timestamp: SwiftProtobuf.Google_Protobuf_Timestamp) -> String {
        let date = timestamp.date
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
