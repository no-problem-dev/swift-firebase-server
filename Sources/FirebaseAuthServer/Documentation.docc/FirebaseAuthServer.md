# ``FirebaseAuthServer``

サーバーサイド Swift 向け Firebase Authentication トークン検証

## Overview

FirebaseAuthServer は、サーバーサイド Swift アプリケーションで Firebase ID トークンを検証するためのライブラリ。

主な特徴:
- **JWT 検証**: RS256 署名の完全な検証
- **公開鍵キャッシュ**: Google の公開鍵を自動キャッシュ
- **クレーム検証**: exp, iat, aud, iss, sub, auth_time の検証
- **エミュレーター対応**: ローカル開発環境のサポート

## Topics

### 基本

- ``AuthClient``
- ``AuthConfiguration``
- ``AuthAdminClient``

### トークン検証

- ``IDTokenVerifier``
- ``IDTokenVerifying``
- ``VerifiedToken``
- ``PublicKeyCache``

### クレーム

- ``FirebaseClaim``

### エラー

- ``AuthError``
