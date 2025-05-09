import Foundation

/// Makes the variable thread-safe and allows its owner to conform to Sendable "honestly" without using @unchecked.
@attached(peer, names: prefixed(`_`))
@attached(accessor, names: named(_read), named(_modify))
public macro ThreadSafe() = #externalMacro(module: "ThreadSafeMacrosImpl", type: "ThreadSafeMacro")
