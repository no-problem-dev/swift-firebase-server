# トークン検証

AuthClientを使用したFirebase IDトークンの検証です。

## クライアントの初期化

```swift
import FirebaseAuthServer

// 本番環境
let authClient = AuthClient(projectId: "your-project-id")

// または設定を指定
let config = AuthConfiguration(projectId: "your-project-id")
let authClient = AuthClient(configuration: config)

// エミュレーター
let emulatorConfig = AuthConfiguration.emulator(projectId: "your-project-id")
let authClient = AuthClient(configuration: emulatorConfig)
```

## IDトークンの検証

### 直接検証

```swift
let verifiedToken = try await authClient.verifyIDToken(idToken)
print("User ID: \(verifiedToken.uid)")
print("Email: \(verifiedToken.email ?? "none")")
```

### Authorizationヘッダーから検証

```swift
// "Bearer {token}" 形式を自動解析
let authHeader = request.headers["Authorization"].first ?? ""
let verifiedToken = try await authClient.verifyAuthorizationHeader(authHeader)
```

## VerifiedToken

検証成功時に返される情報：

| プロパティ | 型 | 説明 |
|-----------|-----|------|
| `uid` | `String` | Firebase UID |
| `email` | `String?` | メールアドレス |
| `emailVerified` | `Bool` | メール確認済みか |
| `name` | `String?` | ユーザー名 |
| `picture` | `String?` | プロフィール画像URL |
| `phoneNumber` | `String?` | 電話番号 |
| `authTime` | `Date` | 認証時刻 |
| `issuedAt` | `Date` | トークン発行時刻 |
| `expiresAt` | `Date` | トークン有効期限 |
| `signInProvider` | `String?` | サインインプロバイダー |

### サインインプロバイダー例

- `"password"` - メール/パスワード
- `"google.com"` - Google
- `"apple.com"` - Apple
- `"phone"` - 電話番号

## 検証内容

トークン検証では以下をチェックします：

1. **JWT形式**: 3パートに分割可能か
2. **アルゴリズム**: RS256であるか
3. **有効期限（exp）**: 未来であること
4. **発行時刻（iat）**: 過去であること
5. **認証時刻（auth_time）**: 過去であること
6. **対象者（aud）**: プロジェクトIDと一致
7. **発行者（iss）**: `https://securetoken.google.com/{projectId}` と一致
8. **ユーザーID（sub）**: 非空文字列
9. **署名**: Google公開鍵で検証

## エラーハンドリング

```swift
do {
    let token = try await authClient.verifyIDToken(idToken)
} catch AuthError.tokenMissing {
    // Authorizationヘッダーがない
} catch AuthError.tokenInvalid(let reason) {
    // トークン形式が不正
} catch AuthError.tokenExpired(let expiredAt) {
    // トークンの有効期限切れ
} catch AuthError.signatureInvalid {
    // 署名が不正
} catch AuthError.invalidAudience(let expected, let actual) {
    // 対象者（プロジェクトID）が不一致
} catch AuthError.invalidIssuer(let expected, let actual) {
    // 発行者が不一致
} catch AuthError.userNotFound {
    // ユーザーIDが空
} catch {
    // その他のエラー
}
```

## Vaporでの使用例

### ミドルウェア

```swift
struct FirebaseAuthMiddleware: AsyncMiddleware {
    let authClient: AuthClient

    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let authHeader = request.headers["Authorization"].first else {
            throw Abort(.unauthorized, reason: "Missing authorization header")
        }

        let token = try await authClient.verifyAuthorizationHeader(authHeader)

        // リクエストにユーザー情報を保存
        request.storage.set(VerifiedTokenKey.self, to: token)

        return try await next.respond(to: request)
    }
}

struct VerifiedTokenKey: StorageKey {
    typealias Value = VerifiedToken
}
```

### ルートでの使用

```swift
func getProfile(req: Request) async throws -> UserProfile {
    guard let token = req.storage.get(VerifiedTokenKey.self) else {
        throw Abort(.unauthorized)
    }

    let userId = token.uid
    // ユーザー情報を取得...
}
```

## HTTPClientの共有

複数のFirebaseサービスでHTTPClientを共有する場合：

```swift
let httpProvider = HTTPClientProvider()

let authClient = AuthClient(
    configuration: AuthConfiguration(projectId: "my-project"),
    httpClientProvider: httpProvider
)

let firestoreClient = FirestoreClient(
    configuration: FirestoreConfiguration(projectId: "my-project"),
    httpClientProvider: httpProvider
)
```
