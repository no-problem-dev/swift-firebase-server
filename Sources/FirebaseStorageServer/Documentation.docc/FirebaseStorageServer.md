# ``FirebaseStorageServer``

サーバーサイド Swift 向け Cloud Storage for Firebase クライアント

## Overview

FirebaseStorageServer は、サーバーサイド Swift アプリケーションから Cloud Storage for Firebase を操作するためのクライアントです。

主な特徴:
- **REST API ベース**: gRPC 依存なしで動作
- **Swift Concurrency**: async/await によるモダンな非同期処理
- **ストリーミング対応**: 大きなファイルの効率的なアップロード/ダウンロード
- **自動認証**: Cloud Run / ローカル gcloud の自動検出
- **エミュレーター対応**: ローカル開発環境のサポート

### 初期化

```swift
// Cloud Run / ローカル gcloud 自動検出
let client = try await StorageClient(.auto, bucket: "my-bucket.appspot.com")

// エミュレーター
let client = StorageClient(.emulator(projectId: "demo-project"), bucket: "my-bucket")

// 明示指定
let client = StorageClient(.explicit(projectId: "my-project", token: accessToken), bucket: "my-bucket")
```

## Topics

### Essentials

- ``StorageClient``
- ``StorageConfiguration``

### Models

- ``StorageObject``

### Errors

- ``StorageError``
