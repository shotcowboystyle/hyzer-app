/// Thread-safe actor for collecting values in async tests.
///
/// Usage:
/// ```swift
/// let collector = ValueCollector<Bool>()
/// let task = Task {
///     for await value in someStream {
///         await collector.append(value)
///     }
/// }
/// // ... trigger events ...
/// let values = await collector.values
/// ```
public actor ValueCollector<T> {
    public private(set) var values: [T] = []

    public var count: Int { values.count }

    public init() {}

    public func append(_ value: T) {
        values.append(value)
    }
}
