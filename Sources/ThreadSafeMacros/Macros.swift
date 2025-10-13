import Foundation

/// Makes the variable thread-safe and allows its owner to conform to Sendable "honestly" without using @unchecked.
@attached(peer, names: suffixed(BackingValue), suffixed(BackingLock))
@attached(accessor, names: named(_read), named(_modify))
public macro ThreadSafe() = #externalMacro(module: "ThreadSafeMacrosImpl", type: "ThreadSafeMacro")
