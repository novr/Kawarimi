import Foundation

public struct MockOverride: Codable, Sendable {
    public var name: String?
    public var path: String
    public var method: String
    public var statusCode: Int
    public var exampleId: String?
    public var mockId: String?
    public var isEnabled: Bool
    /// 非空なら spec の responseMap より優先して返す。空文字は未指定扱いで spec にフォールバック。
    public var body: String?
    /// nil かつ body ありのときミドルウェアは `application/json` にする。
    public var contentType: String?

    public var hasEffectiveCustomBody: Bool { body.map { !$0.isEmpty } ?? false }

    /// 設定と転送での過大ペイロードを防ぐ（UTF-8 バイト）。
    public static let maxBodyLength = 1_000_000  // 1 MiB

    public init(
        name: String? = nil,
        path: String,
        method: String,
        statusCode: Int,
        exampleId: String? = nil,
        mockId: String? = nil,
        isEnabled: Bool = true,
        body: String? = nil,
        contentType: String? = nil
    ) {
        self.name = name
        self.path = path
        self.method = method
        self.statusCode = statusCode
        self.exampleId = exampleId
        self.mockId = mockId
        self.isEnabled = isEnabled
        self.body = body
        self.contentType = contentType
    }
}

public struct KawarimiConfig: Codable, Sendable {
    public var overrides: [MockOverride]

    public init(overrides: [MockOverride] = []) {
        self.overrides = overrides
    }
}
