import Foundation
import Testing
@testable import StorageServer

@Suite("Storage Object Tests")
struct StorageObjectTests {

    @Test("Parse from JSON - complete")
    func parseFromJSONComplete() {
        let json: [String: Any] = [
            "id": "test-bucket/images/photo.jpg/1234567890",
            "name": "images/photo.jpg",
            "bucket": "test-bucket",
            "contentType": "image/jpeg",
            "size": "1024",
            "md5Hash": "abc123",
            "timeCreated": "2025-01-15T10:00:00.000Z",
            "updated": "2025-01-15T12:00:00.000Z",
            "mediaLink": "https://storage.googleapis.com/download/storage/v1/b/test-bucket/o/images%2Fphoto.jpg"
        ]

        let object = StorageObject.fromJSON(json)

        #expect(object != nil)
        #expect(object?.id == "test-bucket/images/photo.jpg/1234567890")
        #expect(object?.name == "images/photo.jpg")
        #expect(object?.bucket == "test-bucket")
        #expect(object?.contentType == "image/jpeg")
        #expect(object?.size == 1024)
        #expect(object?.md5Hash == "abc123")
        #expect(object?.mediaLink != nil)
    }

    @Test("Parse from JSON - minimal")
    func parseFromJSONMinimal() {
        let json: [String: Any] = [
            "id": "test-bucket/photo.jpg/123",
            "name": "photo.jpg",
            "bucket": "test-bucket"
        ]

        let object = StorageObject.fromJSON(json)

        #expect(object != nil)
        #expect(object?.id == "test-bucket/photo.jpg/123")
        #expect(object?.name == "photo.jpg")
        #expect(object?.bucket == "test-bucket")
        #expect(object?.size == 0)
        #expect(object?.contentType == nil)
    }

    @Test("Parse from JSON - missing required fields")
    func parseFromJSONMissingFields() {
        let json: [String: Any] = [
            "id": "test-id",
            "name": "photo.jpg"
            // missing bucket
        ]

        let object = StorageObject.fromJSON(json)
        #expect(object == nil)
    }

    @Test("Parse from JSON - size as Int64")
    func parseFromJSONSizeAsInt64() {
        let json: [String: Any] = [
            "id": "test-id",
            "name": "photo.jpg",
            "bucket": "test-bucket",
            "size": Int64(2048)
        ]

        let object = StorageObject.fromJSON(json)

        #expect(object?.size == 2048)
    }

    @Test("StorageObject initialization")
    func initialization() {
        let object = StorageObject(
            id: "test-id",
            name: "images/photo.jpg",
            bucket: "test-bucket",
            contentType: "image/png",
            size: 512
        )

        #expect(object.id == "test-id")
        #expect(object.name == "images/photo.jpg")
        #expect(object.bucket == "test-bucket")
        #expect(object.contentType == "image/png")
        #expect(object.size == 512)
    }
}
