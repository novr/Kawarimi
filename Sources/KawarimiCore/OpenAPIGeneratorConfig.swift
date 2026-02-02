import Foundation

/// swift-openapi-generator openapi-generator-config.yaml 形式（_UserConfig 相当）。openapi.yaml と同じディレクトリに kawarimi.yaml または openapi-generator-config.yaml で置く。
public struct OpenAPIGeneratorConfig: Codable {
    /// swift-openapi-generatorの generate（types/client/server のどれを生成するか）。未指定 or 空なら標準の3種。指定ありならそのリスト。Kawarimi.swift は指定に関わらず常に出力する。
    public var generate: [String]?
    public var accessModifier: String?
    public var additionalImports: [String]?
    public var additionalFileComments: [String]?
    public var filter: DocumentFilterYAML?
    public var namingStrategy: String?
    public var nameOverrides: [String: String]?
    public var typeOverrides: TypeOverrides?
    public var featureFlags: [String]?

    public init(
        generate: [String]? = nil,
        accessModifier: String? = nil,
        additionalImports: [String]? = nil,
        additionalFileComments: [String]? = nil,
        filter: DocumentFilterYAML? = nil,
        namingStrategy: String? = nil,
        nameOverrides: [String: String]? = nil,
        typeOverrides: TypeOverrides? = nil,
        featureFlags: [String]? = nil
    ) {
        self.generate = generate
        self.accessModifier = accessModifier
        self.additionalImports = additionalImports
        self.additionalFileComments = additionalFileComments
        self.filter = filter
        self.namingStrategy = namingStrategy
        self.nameOverrides = nameOverrides
        self.typeOverrides = typeOverrides
        self.featureFlags = featureFlags
    }

    /// swift-openapi-generator typeOverrides 相当。
    public struct TypeOverrides: Codable {
        public var schemas: [String: String]?
        public init(schemas: [String: String]? = nil) {
            self.schemas = schemas
        }
    }
}

/// swift-openapi-generator DocumentFilter 相当の YAML 用。operations / tags / schemas で生成対象を絞る。
public struct DocumentFilterYAML: Codable {
    public var operations: [String]?
    public var tags: [String]?
    public var schemas: [String]?
    public init(operations: [String]? = nil, tags: [String]? = nil, schemas: [String]? = nil) {
        self.operations = operations
        self.tags = tags
        self.schemas = schemas
    }
}
