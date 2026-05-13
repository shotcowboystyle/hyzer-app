import MetricKit
import os.log

/// Receives MetricKit payloads and crash diagnostics delivered by the OS.
///
/// MetricKit collects system performance data (launch time, memory, CPU, battery, hangs)
/// and crash diagnostics. Payloads are delivered once per day on the first launch
/// after the reporting period ends, or the first launch after a crash.
///
/// Usage: call `MetricKitObserver.shared.register()` once at app startup.
final class MetricKitObserver: NSObject, MXMetricManagerSubscriber {
  @MainActor static let shared = MetricKitObserver()

    private let logger = Logger(subsystem: "com.shotcowboystyle.hyzerapp", category: "MetricKit")

    private override init() {}

    func register() {
        MXMetricManager.shared.add(self)
        logger.info("MetricKitObserver registered")
    }

    // MARK: - MXMetricManagerSubscriber

    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            logger.info("MetricKit metrics received for period \(payload.timeStampBegin) – \(payload.timeStampEnd)")
            writePayloadToFile(payload.jsonRepresentation(), prefix: "metrics")
        }
    }

    @available(iOS 14, *)
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let json = payload.jsonRepresentation()
            writePayloadToFile(json, prefix: "diagnostic")

            if let crashes = payload.crashDiagnostics, !crashes.isEmpty {
                logger.critical("Crash diagnostic received — \(crashes.count) crash(es) since last launch")
            }
            if let hangs = payload.hangDiagnostics, !hangs.isEmpty {
                logger.error("Hang diagnostic received — \(hangs.count) hang(s) since last launch")
            }
        }
    }

    // MARK: - Private

    private func writePayloadToFile(_ data: Data, prefix: String) {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            logger.error("MetricKit: cannot resolve applicationSupportDirectory")
            return
        }
        let logsDir = dir.appendingPathComponent("MetricKitLogs", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
            pruneOldPayloads(in: logsDir, prefix: prefix)
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileURL = logsDir.appendingPathComponent("\(prefix)-\(timestamp).json")
            try data.write(to: fileURL)
            logger.info("MetricKit payload written to \(fileURL.lastPathComponent)")
        } catch {
            logger.error("MetricKit: failed to write payload: \(error)")
        }
    }

    /// Removes files older than 7 days and keeps at most 20 per prefix, newest first.
    private func pruneOldPayloads(in dir: URL, prefix: String) {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3_600)
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let matching = contents
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
            .compactMap { url -> (URL, Date)? in
                let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                return (url, date)
            }
            .sorted { $0.1 > $1.1 } // newest first

        for (index, (url, creationDate)) in matching.enumerated() {
            if creationDate < cutoff || index >= 20 {
                try? fm.removeItem(at: url)
            }
        }
    }
}
