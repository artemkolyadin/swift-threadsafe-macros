import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct ThreadSafeMacro {}

extension ThreadSafeMacro: AccessorMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingAccessorsOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.AccessorDeclSyntax] {
        guard let varDeclaration = validate(declaration, node: node, addingDiagnosticsTo: context) else {
            return []
        }
        let backingTuple = backingTupleName(varDeclaration.identifier.with(\.trailingTrivia, []))

        return [
            """
            get {
                \(backingTuple).lock.lock()
                defer {
                    \(backingTuple).lock.unlock()
                }

                return \(backingTuple).value
            }
            """,
            """
            _modify {
                \(backingTuple).lock.lock()
                defer { 
                    \(backingTuple).lock.unlock()
                }

                yield &\(backingTuple).value
            }
            """,
        ]
    }
}

extension ThreadSafeMacro: PeerMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in _: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        guard let varDeclaration = validate(
            declaration,
            node: node,
            // Validation errors are shown during accessor macro expansion.
            // There's no need to duplicate them in the peer expansion.
            addingDiagnosticsTo: nil
        )
        else {
            return []
        }

        let name = backingTupleName(varDeclaration.identifier)

        return [
            """
            private nonisolated(unsafe) var \(name): (value: \(varDeclaration.type), lock: NSLock) = (\(varDeclaration.value), NSLock())
            """,
        ]
    }
}

extension ThreadSafeMacro {
    struct ValidDeclaration {
        let type: TypeSyntax
        let value: ExprSyntax

        private let decl: VariableDeclSyntax

        init(
            type: TypeSyntax,
            value: ExprSyntax,
            decl: VariableDeclSyntax
        ) {
            self.type = type
            self.value = value
            self.decl = decl
        }

        var identifier: TokenSyntax {
            decl.identifier
        }
    }

    private static func validate(
        _ declaration: DeclSyntaxProtocol,
        node: AttributeSyntax,
        addingDiagnosticsTo context: MacroExpansionContext?
    ) -> ValidDeclaration? {
        guard let decl = declaration.as(VariableDeclSyntax.self), decl.isVar else {
            context?.addDiagnostics(from: Error.notAVar, node: node)
            return nil
        }
        guard let type = decl.type?.type.trimmed else {
            context?.addDiagnostics(from: Error.typeNotProvided, node: node)
            return nil
        }
        guard let value = decl.bindings.first?.initializer?.value else {
            context?.addDiagnostics(from: Error.valueNotProvided, node: node)
            return nil
        }

        return ValidDeclaration(
            type: type,
            value: value,
            decl: decl
        )
    }

    private static func backingTupleName(_ identifier: TokenSyntax) -> IdentifierPatternSyntax {
        IdentifierPatternSyntax(identifier: "_\(identifier)")
    }
}

extension ThreadSafeMacro {
    enum Error: String, Swift.Error, DiagnosticMessage {
        case notAVar
        case typeNotProvided
        case valueNotProvided

        var message: String {
            switch self {
            case .notAVar:
                return "@ThreadSafe can only be used with variables."
            case .typeNotProvided:
                return "The variable must have an explicit type annotation after ':'."
            case .valueNotProvided:
                return "The variable must have an initial value."
            }
        }

        var diagnosticID: MessageID {
            .init(domain: "ThreadSafeMacro", id: rawValue)
        }

        var severity: DiagnosticSeverity { .error }
    }
}
