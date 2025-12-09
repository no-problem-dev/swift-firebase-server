# ``FirebaseStorageServer``

サーバーサイド Swift 向け Cloud Storage for Firebase クライアント

## Overview

FirebaseStorageServer は、サーバーサイド Swift アプリケーションから Cloud Storage for Firebase を操作するためのクライアントです。

主な特徴:
- **REST API ベース**: gRPC 依存なしで動作
- **Swift Concurrency**: async/await によるモダンな非同期処理
- **ストリーミング対応**: 大きなファイルの効率的なアップロード/ダウンロード
- **エミュレーター対応**: ローカル開発環境のサポート

## Topics

### Essentials

- ``StorageClient``
- ``StorageConfiguration``

### Models

- ``StorageObject``

### Errors

- ``StorageError``
