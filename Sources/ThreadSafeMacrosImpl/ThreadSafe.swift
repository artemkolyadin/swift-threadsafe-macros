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
        let identifier = varDeclaration.identifier.with(\.trailingTrivia, [])
        let backingValue = backingValueName(identifier)
        let backingLock = backingLockName(identifier)

        return [
            """
            get {
                \(backingLock).lock()
                defer {
                    \(backingLock).unlock()
                }

                return \(backingValue)
            }
            """,
            """
            _modify {
                \(backingLock).lock()
                defer {
                    \(backingLock).unlock()
                }

                yield &\(backingValue)
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

        let valueName = backingValueName(varDeclaration.identifier)
        let lockName = backingLockName(varDeclaration.identifier)
        let ownership = varDeclaration.ownershipModifier.map { "\($0) " } ?? ""

        // An unowned reference has no sensible default, so it's left for the initializer to set.
        let valueDecl: DeclSyntax = if varDeclaration.isUnowned {
            "private nonisolated(unsafe) \(raw: ownership)var \(valueName): \(varDeclaration.type)"
        } else {
            "private nonisolated(unsafe) \(raw: ownership)var \(valueName): \(varDeclaration.type) = \(varDeclaration.value)"
        }

        return [
            valueDecl,
            "private let \(lockName) = ThreadSafeMacros.ThreadSafeLock()",
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

        /// `weak`, `unowned` or `unowned(unsafe)`, if the property has one.
        var ownershipModifier: String? {
            decl.modifiers
                .first { $0.name.tokenKind == .keyword(.weak) || $0.name.tokenKind == .keyword(.unowned) }?
                .trimmedDescription
        }

        var isUnowned: Bool {
            decl.isUnowned
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
        let accessorNames = decl.accessorNames
        guard accessorNames.isEmpty else {
            context?.addDiagnostics(from: Error.accessorsAlreadyProvided(accessorNames), node: node)
            return nil
        }
        guard let type = decl.type?.type.trimmed else {
            context?.addDiagnostics(from: Error.typeNotProvided, node: node)
            return nil
        }

        let value: ExprSyntax
        if let initialValue = decl.bindings.first?.initializer?.value {
            value = initialValue
        } else if isOptional(type) || decl.isUnowned {
            value = "nil"
        } else {
            context?.addDiagnostics(from: Error.valueNotProvided, node: node)
            return nil
        }

        return ValidDeclaration(
            type: type,
            value: value,
            decl: decl
        )
    }

    private static func backingValueName(_ identifier: TokenSyntax) -> IdentifierPatternSyntax {
        IdentifierPatternSyntax(identifier: "\(identifier)BackingValue")
    }

    private static func backingLockName(_ identifier: TokenSyntax) -> IdentifierPatternSyntax {
        IdentifierPatternSyntax(identifier: "\(identifier)BackingLock")
    }

    private static func isOptional(_ type: TypeSyntax) -> Bool {
        if type.is(OptionalTypeSyntax.self) {
            return true
        }
        if let identifier = type.as(IdentifierTypeSyntax.self), identifier.name.text == "Optional" {
            return true
        }
        return false
    }
}

extension ThreadSafeMacro {
    enum Error: Swift.Error, DiagnosticMessage {
        case notAVar
        case typeNotProvided
        case valueNotProvided
        case accessorsAlreadyProvided(_ accessors: [String])

        var message: String {
            switch self {
            case .notAVar:
                return "@ThreadSafe can only be used with variables."
            case .typeNotProvided:
                return "The variable must have an explicit type annotation after ':'."
            case .valueNotProvided:
                return "The variable must have an initial value."
            case let .accessorsAlreadyProvided(accessors):
                return "@ThreadSafe can't be used on a variable that already has accessors: \(accessors.joined(separator: ", "))."
            }
        }

        var diagnosticID: MessageID {
            let id = switch self {
            case .notAVar: "notAVar"
            case .typeNotProvided: "typeNotProvided"
            case .valueNotProvided: "valueNotProvided"
            case .accessorsAlreadyProvided: "accessorsAlreadyProvided"
            }
            return MessageID(domain: "ThreadSafeMacro", id: id)
        }

        var severity: DiagnosticSeverity { .error }
    }
}
