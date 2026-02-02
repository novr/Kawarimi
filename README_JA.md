日本語 | [English](README.md)

# Kawarimi（代わり身）

swift-openapi-generator を使って Types / Client / Server と Kawarimi（ClientTransport モック）・KawarimiHandler（APIProtocol のデフォルト実装）をビルド時に生成する SwiftPM Build Tool Plugin。

## 使い方

### 1. 依存とプラグインを追加する

```swift
dependencies: [
    .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
    .package(url: "https://github.com/novr/Kawarimi.git", from: "0.2.0"),
],
targets: [
    .target(
        name: "MyAPI",
        dependencies: [.product(name: "OpenAPIRuntime", package: "swift-openapi-runtime")],
        plugins: [.plugin(name: "KawarimiPlugin", package: "Kawarimi")]
    ),
]
```

### 2. OpenAPI を置く

ターゲットのソースディレクトリに openapi.yaml を 1 つ置く。ビルドで Types.swift / Client.swift / Server.swift / Kawarimi.swift / KawarimiHandler.swift が生成される。

### 3. オプション: 設定ファイル

同じディレクトリに kawarimi.yaml（または openapi-generator-config.yaml）を置くと、generate / filter / featureFlags など swift-openapi-generator 向けの設定を指定できる。

### 4. テストでモックを使う

```swift
let client = Client(serverURL: url, transport: Kawarimi())
let response = try await client.getGreeting(...)
```

## Example

```bash
cd Example && swift build
swift run DemoServer   # 別ターミナルで
swift run DemoApp      # クライアント
```

## 要件・詳細

- Swift 6.2+ / macOS 14+
- 生成対象: 200 + application/json の operation、$ref で components/schemas を参照する schema
- 詳しくはリポジトリを参照
