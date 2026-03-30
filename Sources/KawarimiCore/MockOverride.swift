import Foundation

public struct MockOverride: Codable, Sendable, Equatable {
    public var name: String?
    public var path: String
    public var method: String
    public var statusCode: Int
    public var exampleId: String?
    public var isEnabled: Bool
    /// 非空なら spec の例より優先。空文字は「未指定」とみなし spec に戻す。
    public var body: String?
    /// body があるのに nil のとき、サーバー側で JSON とみなす。
    public var contentType: String?

    public var hasEffectiveCustomBody: Bool { body.map { !$0.isEmpty } ?? false }

    /// 設定ファイルと HTTP で巨大 JSON を運ばないための上限（UTF-8 バイト）。
    public static let maxBodyLength = 1_000_000

    public init(
        name: String? = nil,
        path: String,
        method: String,
        statusCode: Int,
        exampleId: String? = nil,
        isEnabled: Bool = true,
        body: String? = nil,
        contentType: String? = nil
    ) {
        self.name = name
        self.path = path
        self.method = method
        self.statusCode = statusCode
        self.exampleId = exampleId
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

    enum CodingKeys: String, CodingKey {
        case overrides
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.overrides = try container.decodeIfPresent([MockOverride].self, forKey: .overrides) ?? []
    }
}

extension MockOverride {
    /// 複数ヒット時は先頭だけ使うため、常に同じ優先順で並べる（同順位は入力順を保つ安定ソート）。
    public static func sortedForInterceptorTieBreak(_ hits: [MockOverride]) -> [MockOverride] {
        hits.sorted { interceptorTieBreakKey($0) < interceptorTieBreakKey($1) }
    }

    private static func interceptorTieBreakKey(_ o: MockOverride)
        -> (String, Int, String, String)
    {
        (
            o.path,
            o.statusCode,
            o.name ?? "",
            o.exampleId ?? ""
        )
    }
}
