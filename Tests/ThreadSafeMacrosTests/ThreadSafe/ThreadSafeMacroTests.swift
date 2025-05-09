import MacrosImpl
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
                    _result.lock.lock()
                    defer {
                        _result.lock.unlock()
                    }

                    return _result.value
                }
                _modify {
                    _result.lock.lock()
                    defer {
                        _result.lock.unlock()
                    }

                    yield &_result.value
                }
            }

            private nonisolated(unsafe) var _result: (value: Result<[Int], MockError>, lock: NSLock) = (.failure(MockError()), NSLock())
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
                    _result.lock.lock()
                    defer {
                        _result.lock.unlock()
                    }

                    return _result.value
                }
                _modify {
                    _result.lock.lock()
                    defer {
                        _result.lock.unlock()
                    }

                    yield &_result.value
                }
            }

            private nonisolated(unsafe) var _result: (value: Result<[Int], MockError>, lock: NSLock) = (Result<[Int], MockError>.failure(MockError()), NSLock())
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
                    message: "Необходимо явно задать тип переменной после :",
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
                    message: "Необходимо явно задать тип переменной после :",
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
                    message: "@ThreadSafe используется только с variables.",
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
                    message: "Начальное значение переменной должно быть указано",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
    }
}
