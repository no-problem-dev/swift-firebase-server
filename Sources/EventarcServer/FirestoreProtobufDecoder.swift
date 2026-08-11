import Foundation
import SwiftProtobuf

/// Decodes the protobuf body of a Firestore document event into `FirestoreDocumentEvent`.
///
/// ## Eventarc Firestore triggers
///
/// Firestore triggers deliver `application/protobuf` only — there is no JSON delivery — so this
/// is the entry point for every Firestore event, and JSON decoding the body will always fail.
///
/// Absent protobuf fields become `nil` rather than empty values, which is what makes the payload
/// tell creates, updates, and deletes apart: no `oldValue` on a create, no `value` on a delete,
/// an `updateMask` only on an update.
///
/// Conversion also normalises a few representations: timestamps become ISO 8601 strings with
/// fractional seconds, 64-bit integers become decimal strings, blobs become Base64, an empty
/// field-path list becomes `nil`, and a value whose type is unset becomes an all-`nil`
/// `FirestoreValue`.
///
/// ### Creating the trigger with gcloud
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
/// ### Example
/// ```swift
/// routes.post("webhook", "firestore", "chat-created") { request async throws -> HTTPStatus in
///     let headers = CloudEventHeaders(from: request.headers.all)
///
///     // Pick the decoder from the Content-Type
///     let contentType = request.headers["content-type"]
///     if contentType == "application/protobuf" {
///         let data = try await request.body.collect()
///         let event = try FirestoreProtobufDecoder.decode(data)
///         // event is a FirestoreDocumentEvent
///     }
///
///     return .ok
/// }
/// ```
///
/// ## References
/// - [Eventarc Firestore Events](https://cloud.google.com/eventarc/docs/reference/supported-events#firestore)
/// - [google-cloudevents Protobuf](https://github.com/googleapis/google-cloudevents)
public enum FirestoreProtobufDecoder {
    /// Decodes a request body carrying a Firestore document event.
    ///
    /// - Parameter data: The whole `application/protobuf` body, as a serialized
    ///   `DocumentEventData` message.
    /// - Throws: `SwiftProtobuf.BinaryDecodingError` when the bytes are truncated or are not
    ///   that message.
    public static func decode(_ data: Data) throws -> FirestoreDocumentEvent {
        let protoEvent = try Google_Events_Cloud_Firestore_V1_DocumentEventData(serializedBytes: data)
        return convert(protoEvent)
    }

    /// Decodes a request body already collected into a byte array.
    ///
    /// - Parameter bytes: The whole `application/protobuf` body, as a serialized
    ///   `DocumentEventData` message.
    /// - Throws: `SwiftProtobuf.BinaryDecodingError` when the bytes are truncated or are not
    ///   that message.
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
