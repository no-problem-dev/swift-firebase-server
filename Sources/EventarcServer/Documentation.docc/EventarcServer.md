# ``EventarcServer``

Google Cloud Eventarc イベント型（CloudEvents）

## Overview

EventarcServer は、Google Cloud Eventarc から送信される CloudEvents を受信・解析するための型を提供します。

Firestore ドキュメント変更イベント、Firebase Auth ユーザーイベント、Cloud Audit Logs イベントに対応しています。Protobuf 形式のバイナリペイロードのデコードも含みます。

### 初期化例

```swift
// Firestore ドキュメントイベントの受信（Protobuf）
let data: Data = ... // リクエストボディ
let event = try FirestoreProtobufDecoder.decode(data)
if let message = event.value?.getString("message") {
    print("New document field: \(message)")
}

// CloudEvents ヘッダーの解析
let headers = CloudEventHeaders(from: requestHeaders)
if headers.type == CloudEventHeaders.FirestoreEventType.documentCreated {
    // ドキュメント作成イベントを処理
}
```

## Topics

### Firestore Document Events

- ``FirestoreDocumentEvent``
- ``FirestoreProtobufDecoder``

### Auth Events

- ``AuthUserCreatedEvent``

### Cloud Audit Logs

- ``CloudAuditLogEvent``

### CloudEvents Metadata

- ``CloudEventHeaders``

### Value Types

- ``FirestoreDocument``
- ``FirestoreValue``
- ``DynamicValue``
- ``JSONValue``
