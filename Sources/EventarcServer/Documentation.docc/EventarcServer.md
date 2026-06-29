# ``EventarcServer``

Google Cloud Eventarc イベント型（CloudEvents）

## Overview

EventarcServer は、Google Cloud Eventarc から送信される CloudEvents を受信・解析するための型を提供する。

Firestore ドキュメント変更イベント、Firebase Auth ユーザーイベント、Cloud Audit Logs イベントに対応する。Protobuf 形式のバイナリペイロードのデコードも含む。

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

### Firestore ドキュメントイベント

- ``FirestoreDocumentEvent``
- ``FirestoreProtobufDecoder``

### 認証イベント

- ``AuthUserCreatedEvent``

### Cloud Audit Logs イベント

- ``CloudAuditLogEvent``

### CloudEvents メタデータ

- ``CloudEventHeaders``

### 値の型

- ``FirestoreDocument``
- ``FirestoreValue``
- ``DynamicValue``
- ``JSONValue``
