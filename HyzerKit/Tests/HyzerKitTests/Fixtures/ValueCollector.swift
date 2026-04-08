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
actor ValueCollector<T> {
    private(set) var values: [T] = []

    var count: Int { values.count }

    func append(_ value: T) {
        values.append(value)
    }
}
