# ThreadSafe Macro for Swift Concurrency

## Overview

The `@ThreadSafe` macro enables classes with mutable properties to conform to the `Sendable` protocol **without** using the `@unchecked` attribute. It ensures thread-safe access to specific properties while preserving strict concurrency checks for other members of the `Sendable` class. This is especially helpful when migrating to **Swift 6** with **strict concurrency checking** enabled.

Unlike the widely known `@Atomic` property wrapper—which also provides thread-safe access—`@ThreadSafe` does not require applying `@unchecked Sendable` to the entire class.

## Motivation

In my work on the iOS DX team, I focus on simplifying daily development workflows. Inspired by [Nikita Zemlin's talk at Mobius Conference](https://youtu.be/035WscXr7Xo?t=937), I developed this macro to support a fast and convenient migration of a large codebase to Swift 6. The implementation is based on his idea, with additional improvements and refinements made along the way.

---

## Example Usage

Here’s how the `@ThreadSafe` macro transforms your code under the hood:

<details open>
<summary><strong>Original Code</strong></summary>

```swift
final class BankAccount: Sendable {
    @ThreadSafe var balance: Double = 0
    @ThreadSafe var transactions: [String] = []

    init(balance: Double, transactions: [String]) {
        self.balance = balance
        self.transactions = transactions
    }

    func deposit(_ amount: Double) {
        Task.detached { [self] in
            balance += amount
            transactions.append("Deposited \(amount)")
        }
    }
}
```
</details>

<details open>
<summary><strong>Expanded Code (for <code>@ThreadSafe var transactions</code>)</strong></summary>

```swift
final class BankAccount: Sendable {
    @ThreadSafe var balance: Double = 0
    var transactions: [String] {
        get {
            _transactions.lock.lock()
            defer {
                _transactions.lock.unlock()
            }
            return _transactions.value
        }
        _modify {
            _transactions.lock.lock()
            defer {
                _transactions.lock.unlock()
            }
            yield &_transactions.value
        }
    }
    private nonisolated(unsafe) var _transactions: (value: [String], lock: NSLock) = ([], NSLock())

    init(balance: Double, transactions: [String]) {
        self.balance = balance
        self.transactions = transactions
    }

    func deposit(_ amount: Double) {
        Task.detached { [self] in
            balance += amount
            transactions.append("Deposited \(amount)")
        }
    }
}
```
</details>

---

## Advantages over `@Atomic` property wrapper

With `@ThreadSafe`, the expanded code is fully under your control. This means you can mark helper properties (such as the lock) as `nonisolated`, knowing they’re internally synchronized.

By contrast, using `@Atomic` introduces an internal property (typically prefixed with an underscore) that **cannot** be marked `nonisolated`. This often forces developers to apply `@unchecked Sendable`, weakening concurrency guarantees across the entire class and increasing the risk of subtle multithreading bugs.

---

## Installation

You can add `@ThreadSafe` to your project using Swift Package Manager.

In your `Package.swift` file:

```swift
.package(url: "https://github.com/artemkolyadin/swift-threadsafe-macro.git", from: "1.0.0")
```

Then import it:

```swift
internal import ThreadSafeMacros
```

---

## Requirements

* Swift 5.9 or later

---

## Macro Internals

The `@ThreadSafe` macro uses **yielding accessors** to allow fast in-place read/write operations.

For a deep dive into yielding accessors, check out this [great post](https://trycombine.com/posts/swift-read-modify-coroutines/).

In multithreaded environments, a typical `set` operation (read → modify → write) can be interrupted, leading to race conditions. Yielding accessors (`_modify`) help prevent this by ensuring atomic modification sequences.

Earlier versions of the macro also used `_read` for reading, but as of Xcode 16.3, switching to a simple get accessor resolved a segmentation fault: 11 issue, without affecting concurrency guarantees.

---

## Notes on `xcodebuild`

When building a project using this macro via `xcodebuild`, especially when targets include frameworks that depend on this Swift Package:

1. **Avoid using `BUILD_LIBRARY_FOR_DISTRIBUTION` globally.** Instead, set it per-target. The macro depends on `SwiftSyntax 600.0.1`, which may not compile with this flag.

2. **Use `-destination` instead of `-arch`**:

   ```bash
   -destination "generic/platform=iOS"
   ```

   Macro expansion happens on macOS, before app compilation. The macro itself does **not** get embedded in the final app/framework.

3. **Use `internal import`** for the macro package to prevent macro symbols from leaking into public APIs and causing compile-time errors in downstream projects.

---

## Equality in Tests

Both `@ThreadSafe` and `@Atomic` introduce hidden helper properties (like locks), which may cause equality checks between two seemingly identical objects to fail. That’s because the default `NSLock` doesn’t conform to `Equatable` in a meaningful way—each instance points to a different memory address.

### Recommended Solution:

1. Define a custom lock wrapper:

```swift
import Foundation

/// Custom wrapper over NSLock that always compares as equal.
public final class ThreadSafeLock: Equatable, Sendable {
    private let _lock = NSLock()

    public init() {}

    public func lock() {
        _lock.lock()
    }

    public func unlock() {
        _lock.unlock()
    }

    public static func == (_: ThreadSafeLock, _: ThreadSafeLock) -> Bool {
        true
    }
}

extension ThreadSafeLock: CustomReflectable {
    /// Provides a stable mirror value for ThreadSafeLock, 
    /// so that objects containing it can be reliably compared via Swift Reflection in tests.
    /// This helps avoid test failures when using Mirror(reflecting:) to compare object structures.
    static nonisolated(unsafe) private let mirror = Mirror(reflecting: "ThreadSafeLock")
    
    public var customMirror: Mirror { ThreadSafeLock.mirror }
}
```

2. Place this code in a base framework that's commonly imported.
3. In your macro implementation, replace `NSLock` with `ThreadSafeLock`.
4. In files that use `@ThreadSafe`, import the framework where `ThreadSafeLock` is defined.

This avoids test failures due to lock inequality while preserving concurrency guarantees.

---

## Acknowledgments

Special thanks to:

* [**Alexander Bodrov**](https://github.com/amidaleet) – for identifying and solving the `BUILD_LIBRARY_FOR_DISTRIBUTION` issue in `xcodebuild` with the updated version of SwiftSyntax.
* **Vyacheslav Mirgorod** – for the idea to store the synchronization `NSLock` inside a tuple instead of using a wrapper class as in the original macro concept, which removed the need for extra imports at the macro usage site (when using the `NSLock`-based implementation).

## License

MIT License — see [LICENSE](/LICENSE.md) for details.
