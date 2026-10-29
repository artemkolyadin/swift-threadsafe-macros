import Foundation

/// The lock that `@ThreadSafe` puts next to every property it wraps.
///
/// It's a plain `NSLock` underneath, but all instances compare as equal, hash the same
/// and look identical to `Mirror`. Otherwise the lock would make two otherwise identical
/// values differ in synthesized `Equatable`/`Hashable` and in reflection-based comparisons
/// (`dump`, snapshot tests and so on), since every `NSLock` is a distinct object.
public final class ThreadSafeLock: Sendable {
    private let _lock = NSLock()

    public init() {}

    public func lock() {
        _lock.lock()
    }

    public func unlock() {
        _lock.unlock()
    }
}

extension ThreadSafeLock: Hashable {
    public static func == (_: ThreadSafeLock, _: ThreadSafeLock) -> Bool {
        true
    }

    public func hash(into _: inout Hasher) {}
}

extension ThreadSafeLock: CustomReflectable {
    public var customMirror: Mirror {
        Mirror(self, children: [])
    }
}
