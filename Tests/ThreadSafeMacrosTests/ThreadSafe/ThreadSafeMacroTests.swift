import ThreadSafeMacrosImpl
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

final class ThreadSafeMacroTests: XCTestCase {
    private let testMacros: [String: Macro.Type] = [
        "ThreadSafe": ThreadSafeMacro.self,
    ]

    func test_TypeExplicitlyProvided_ImplicitInitializer_Expands() throws {
        assertMacroExpansion(
            """
            @ThreadSafe
            public var result: Result<[Int], MockError> = .failure(MockError())
            """,
            expandedSource: """
            public var result: Result<[Int], MockError> {
                get {
                    resultBackingLock.lock()
                    defer {
                        resultBackingLock.unlock()
                    }

                    return resultBackingValue
                }
                _modify {
                    resultBackingLock.lock()
                    defer {
                        resultBackingLock.unlock()
                    }

                    yield &resultBackingValue
                }
            }

            private nonisolated(unsafe) var resultBackingValue: Result<[Int], MockError> = .failure(MockError())

            private let resultBackingLock = ThreadSafeMacros.ThreadSafeLock()
            """,
            macros: testMacros
        )
    }

    func test_TypeExplicitlyProvided_ExplicitInitializer_Expands() throws {
        assertMacroExpansion(
            """
            @ThreadSafe
            public var result: Result<[Int], MockError> = Result<[Int], MockError>.failure(MockError())
            """,
            expandedSource: """
            public var result: Result<[Int], MockError> {
                get {
                    resultBackingLock.lock()
                    defer {
                        resultBackingLock.unlock()
                    }

                    return resultBackingValue
                }
                _modify {
                    resultBackingLock.lock()
                    defer {
                        resultBackingLock.unlock()
                    }

                    yield &resultBackingValue
                }
            }

            private nonisolated(unsafe) var resultBackingValue: Result<[Int], MockError> = Result<[Int], MockError>.failure(MockError())

            private let resultBackingLock = ThreadSafeMacros.ThreadSafeLock()
            """,
            macros: testMacros
        )
    }

    func test_WeakVariable_KeepsOwnership() throws {
        assertMacroExpansion(
            """
            @ThreadSafe
            public weak var delegate: Delegate? = nil
            """,
            expandedSource: """
            public weak var delegate: Delegate? {
                get {
                    delegateBackingLock.lock()
                    defer {
                        delegateBackingLock.unlock()
                    }

                    return delegateBackingValue
                }
                _modify {
                    delegateBackingLock.lock()
                    defer {
                        delegateBackingLock.unlock()
                    }

                    yield &delegateBackingValue
                }
            }

            private nonisolated(unsafe) weak var delegateBackingValue: Delegate? = nil

            private let delegateBackingLock = ThreadSafeMacros.ThreadSafeLock()
            """,
            macros: testMacros
        )
    }

    func test_WeakVariable_WithoutInitializer_DefaultsToNil() throws {
        assertMacroExpansion(
            """
            @ThreadSafe
            public weak var delegate: Delegate?
            """,
            expandedSource: """
            public weak var delegate: Delegate? {
                get {
                    delegateBackingLock.lock()
                    defer {
                        delegateBackingLock.unlock()
                    }

                    return delegateBackingValue
                }
                _modify {
                    delegateBackingLock.lock()
                    defer {
                        delegateBackingLock.unlock()
                    }

                    yield &delegateBackingValue
                }
            }

            private nonisolated(unsafe) weak var delegateBackingValue: Delegate? = nil

            private let delegateBackingLock = ThreadSafeMacros.ThreadSafeLock()
            """,
            macros: testMacros
        )
    }

    func test_WeakVariable_CustomInitialValue_KeepsOwnership() throws {
        assertMacroExpansion(
            """
            @ThreadSafe
            public weak var delegate: Delegate? = someDelegate
            """,
            expandedSource: """
            public weak var delegate: Delegate? {
                get {
                    delegateBackingLock.lock()
                    defer {
                        delegateBackingLock.unlock()
                    }

                    return delegateBackingValue
                }
                _modify {
                    delegateBackingLock.lock()
                    defer {
                        delegateBackingLock.unlock()
                    }

                    yield &delegateBackingValue
                }
            }

            private nonisolated(unsafe) weak var delegateBackingValue: Delegate? = someDelegate

            private let delegateBackingLock = ThreadSafeMacros.ThreadSafeLock()
            """,
            macros: testMacros
        )
    }

    func test_WeakVariable_OptionalGenericSyntax_KeepsOwnership() throws {
        assertMacroExpansion(
            """
            @ThreadSafe
            public weak var delegate: Optional<Delegate>
            """,
            expandedSource: """
            public weak var delegate: Optional<Delegate> {
                get {
                    delegateBackingLock.lock()
                    defer {
                        delegateBackingLock.unlock()
                    }

                    return delegateBackingValue
                }
                _modify {
                    delegateBackingLock.lock()
                    defer {
                        delegateBackingLock.unlock()
                    }

                    yield &delegateBackingValue
                }
            }

            private nonisolated(unsafe) weak var delegateBackingValue: Optional<Delegate> = nil

            private let delegateBackingLock = ThreadSafeMacros.ThreadSafeLock()
            """,
            macros: testMacros
        )
    }

    func test_UnownedVariable_KeepsOwnership_WithoutInitialValue() throws {
        assertMacroExpansion(
            """
            @ThreadSafe
            public unowned var owner: Owner
            """,
            expandedSource: """
            public unowned var owner: Owner {
                get {
                    ownerBackingLock.lock()
                    defer {
                        ownerBackingLock.unlock()
                    }

                    return ownerBackingValue
                }
                _modify {
                    ownerBackingLock.lock()
                    defer {
                        ownerBackingLock.unlock()
                    }

                    yield &ownerBackingValue
                }
            }

            private nonisolated(unsafe) unowned var ownerBackingValue: Owner

            private let ownerBackingLock = ThreadSafeMacros.ThreadSafeLock()
            """,
            macros: testMacros
        )
    }

    func test_UnownedUnsafeVariable_KeepsOwnership_WithoutInitialValue() throws {
        assertMacroExpansion(
            """
            @ThreadSafe
            public unowned(unsafe) var owner: Owner
            """,
            expandedSource: """
            public unowned(unsafe) var owner: Owner {
                get {
                    ownerBackingLock.lock()
                    defer {
                        ownerBackingLock.unlock()
                    }

                    return ownerBackingValue
                }
                _modify {
                    ownerBackingLock.lock()
                    defer {
                        ownerBackingLock.unlock()
                    }

                    yield &ownerBackingValue
                }
            }

            private nonisolated(unsafe) unowned(unsafe) var ownerBackingValue: Owner

            private let ownerBackingLock = ThreadSafeMacros.ThreadSafeLock()
            """,
            macros: testMacros
        )
    }

    func test_OptionalWithoutInitializer_DefaultsToNil() throws {
        assertMacroExpansion(
            """
            @ThreadSafe
            public var value: String?
            """,
            expandedSource: """
            public var value: String? {
                get {
                    valueBackingLock.lock()
                    defer {
                        valueBackingLock.unlock()
                    }

                    return valueBackingValue
                }
                _modify {
                    valueBackingLock.lock()
                    defer {
                        valueBackingLock.unlock()
                    }

                    yield &valueBackingValue
                }
            }

            private nonisolated(unsafe) var valueBackingValue: String? = nil

            private let valueBackingLock = ThreadSafeMacros.ThreadSafeLock()
            """,
            macros: testMacros
        )
    }

    func test_TypeNotProvidedExplicitly_Diagnoses() throws {
        assertMacroExpansion(
            """
            @ThreadSafe
            public var counter = 0
            """,
            expandedSource: """
            public var counter = 0
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "The variable must have an explicit type annotation after ':'.",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }

    /// Without an explicit type annotation using ':', it's not always possible to separate and extract the variable's type and initial value after the '=' sign.
    func test_TypeNotProvidedExplicitly_ExplicitInitalizer_Diagnoses() throws {
        assertMacroExpansion(
            """
            @ThreadSafe
            public var result = Result<[Int], MockError>.failure(MockError())
            """,
            expandedSource: """
            public var result = Result<[Int], MockError>.failure(MockError())
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "The variable must have an explicit type annotation after ':'.",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }

    func test_Not_A_Variable_Diagnoses() throws {
        assertMacroExpansion(
            """
            @ThreadSafe
            public let result: Result<[Int], MockError> = .failure(MockError())
            """,
            expandedSource: """
            public let result: Result<[Int], MockError> = .failure(MockError())
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@ThreadSafe can only be used with variables.",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }

    func test_InitialValueNotProvided_Diagnoses() throws {
        assertMacroExpansion(
            """
            @ThreadSafe
            public var counter: Int
            """,
            expandedSource: """
            public var counter: Int
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "The variable must have an initial value.",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }

    func test_AccessorsAlreadyProvided_Diagnoses() throws {
        assertMacroExpansion(
            """
            @ThreadSafe
            public var result: Result<[Int], MockError> = .failure(MockError()) {
                willSet {
                    log("Will change to \\(newValue)")
                }
                didSet {
                    log("Changed to \\(result)")
                }
            }
            """,
            expandedSource: """
            public var result: Result<[Int], MockError> = .failure(MockError()) {
                willSet {
                    log("Will change to \\(newValue)")
                }
                didSet {
                    log("Changed to \\(result)")
                }
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@ThreadSafe can't be used on a variable that already has accessors: willSet, didSet.",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }

    func test_ComputedProperty_Diagnoses() throws {
        assertMacroExpansion(
            """
            @ThreadSafe
            public var count: Int { 0 }
            """,
            expandedSource: """
            public var count: Int { 0 }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@ThreadSafe can't be used on a variable that already has accessors: get.",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }
}
