import SwiftSyntax

extension VariableDeclSyntax {
    /// The identifier (name) of the property
    public var identifier: TokenSyntax {
        guard
            let identifier = bindings.lazy.compactMap({ $0.pattern.as(IdentifierPatternSyntax.self) }).first
        else {
            fatalError("Property without an identifier")
        }

        return identifier.identifier
    }

    /// The type of the property (only if explicitly specified)
    public var type: TypeAnnotationSyntax? {
        bindings.lazy.compactMap(\.typeAnnotation).first
    }
    
    public var isVar: Bool {
        bindingSpecifier.tokenKind == .keyword(.var)
    }

    /// Names of the accessors declared on the property (`get`, `set`, `willSet`, `didSet`, etc.).
    /// A shorthand getter (`var x: Int { 0 }`) is reported as `get`.
    public var accessorNames: [String] {
        switch bindings.first?.accessorBlock?.accessors {
        case let .accessors(accessors):
            return accessors.map(\.accessorSpecifier.text)
        case .getter:
            return ["get"]
        case nil:
            return []
        }
    }
}
